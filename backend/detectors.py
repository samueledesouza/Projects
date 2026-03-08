import torch
import torch.nn.functional as F
import numpy as np
import tempfile
import os
import cv2
import librosa
import io
from PIL import Image
from sightengine_client import detect_image_sightengine

from transformers import (
    AutoTokenizer,
    AutoModelForSequenceClassification,
    GPT2TokenizerFast,
    GPT2LMHeadModel,
    AutoFeatureExtractor,
    AutoModelForAudioClassification,
    pipeline
)

# =====================================================
# Motion Consistency score
# =====================================================
def motion_vector_score(video_path):

    mv = extract_motion_vectors(video_path)

    if len(mv) == 0:
        return 0.5

    variance = np.var(mv)

    # AI videos often have unnatural motion smoothness
    score = 1 / (1 + variance)

    return float(score)
# =====================================================
# Motion vector Extractor
# =====================================================
import subprocess
def extract_motion_vectors(video_path):

    cmd = [
        "ffmpeg",
        "-flags2", "+export_mvs",
        "-i", video_path,
        "-vf", "codecview=mv=pf+bf+bb",
        "-f", "null",
        "-"
    ]

    result = subprocess.run(cmd, stderr=subprocess.PIPE, text=True)

    vectors = []

    for line in result.stderr.split("\n"):

        if "motion_vector" in line:

            try:
                parts = line.split()

                dx = float(parts[-2])
                dy = float(parts[-1])

                vectors.append(np.sqrt(dx*dx + dy*dy))
            except:
                pass

    return np.array(vectors)


# =====================================================
# DEVICE (CPU / CUDA / Apple Metal)
# =====================================================

if torch.cuda.is_available():
    device = "cuda"
    device_id = 0

elif torch.backends.mps.is_available():
    device = "mps"
    device_id = -1

else:
    device = "cpu"
    device_id = -1
# =====================================================
# TEXT MODELS
# =====================================================

TEXT_MODEL = "Hello-SimpleAI/chatgpt-detector-roberta"
PPL_MODEL = "distilgpt2"

text_tokenizer = AutoTokenizer.from_pretrained(TEXT_MODEL)
text_model = AutoModelForSequenceClassification.from_pretrained(TEXT_MODEL).to(device)
text_model.eval()

ppl_tokenizer = GPT2TokenizerFast.from_pretrained(PPL_MODEL)
ppl_model = GPT2LMHeadModel.from_pretrained(PPL_MODEL).to(device)
ppl_model.eval()

# =====================================================
# AUDIO MODEL
# =====================================================

AUDIO_MODEL = "garystafford/wav2vec2-deepfake-voice-detector"

audio_feature_extractor = AutoFeatureExtractor.from_pretrained(AUDIO_MODEL)
audio_model = AutoModelForAudioClassification.from_pretrained(AUDIO_MODEL).to(device)
audio_model.eval()

# =====================================================
# IMAGE MODELS
# =====================================================

sdxl_detector = pipeline(
    "image-classification",
    model="Organika/sdxl-detector",
    device=device
)

deepfake_detector = pipeline(
    "image-classification",
    model="dima806/deepfake_vs_real_image_detection",
    device=device
)

# =====================================================
# GLOBAL FACE DETECTOR
# =====================================================

FACE_CASCADE = cv2.CascadeClassifier(
    cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
)

# =====================================================
# UTILITIES
# =====================================================

def confidence_tier(score):

    if score < 30:
        return "Low confidence"
    if score < 50:
        return "Uncertain"
    if score < 65:
        return "Mixed signals"
    if score < 80:
        return "Moderate AI indicators"

    return "Strong AI indicators"

# =====================================================
# TEXT DETECTOR
# =====================================================

def detect_text(text, mode="accurate"):

    chosen_mode = "fast" if str(mode).lower() == "fast" else "accurate"

    if not text.strip():
        return {
            "label": "Unknown",
            "ai_probability": 0,
            "human_probability": 0
        }

    max_len = 256 if chosen_mode == "fast" else 512

    inputs = text_tokenizer(
        text,
        return_tensors="pt",
        truncation=True,
        max_length=max_len
    ).to(device)

    with torch.inference_mode():
        outputs = text_model(**inputs)

    probs = F.softmax(outputs.logits, dim=-1)[0]

    ai_prob = float(probs[1].cpu().item())

    # Accurate mode adds a perplexity-based signal to improve robustness.
    if chosen_mode == "accurate":
        ppl_inputs = ppl_tokenizer(
            text,
            return_tensors="pt",
            truncation=True,
            max_length=512,
        ).to(device)

        with torch.inference_mode():
            ppl_out = ppl_model(**ppl_inputs, labels=ppl_inputs["input_ids"])

        loss = float(ppl_out.loss.detach().cpu().item())
        ppl = float(np.exp(min(loss, 20)))
        ppl_ai = float(1 / (1 + np.exp((ppl - 35) / 8)))
        ai_prob = (ai_prob * 0.75) + (ppl_ai * 0.25)

    # Very short texts are intrinsically uncertain; pull toward neutral.
    if len(text.strip()) < 80:
        ai_prob = 0.5 + ((ai_prob - 0.5) * 0.6)

    ai_prob = max(0.0, min(ai_prob, 1.0))

    ai_percent = round(ai_prob * 100, 2)

    return {

        "label": "AI-generated text" if ai_percent > 60 else "Likely human-written",

        "ai_probability": ai_percent,

        "human_probability": round(100 - ai_percent, 2),

        "confidence": confidence_tier(ai_percent),

        "method": f"RoBERTa classifier ({chosen_mode})"

    }

# =====================================================
# IMAGE DETECTOR
# =====================================================

def detect_image(image_bytes):

    image = Image.open(image_bytes).convert("RGB")

    result1 = sdxl_detector(image)[0]
    result2 = deepfake_detector(image)[0]

    score1 = result1["score"]
    score2 = result2["score"]

    ai_score = (score1 + score2) / 2

    ai_percent = round(ai_score * 100, 2)

    return {

        "label": "AI-generated image" if ai_percent > 60 else "Likely real image",

        "ai_probability": ai_percent,

        "human_probability": round(100 - ai_percent, 2),

        "confidence": confidence_tier(ai_percent),

        "method": "SDXL + Deepfake ensemble"

    }


# =====================================================
# AUDIO DETECTOR
# =====================================================

def detect_audio(audio_bytes, mode="accurate"):

    chosen_mode = "fast" if str(mode).lower() == "fast" else "accurate"

    with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as tmp:
        tmp.write(audio_bytes)
        path = tmp.name

    waveform, sr = librosa.load(path, sr=16000)

    labels = audio_model.config.id2label

    fake_index = next(
        (i for i, l in labels.items() if "fake" in l.lower()),
        1
    )

    if chosen_mode == "fast":
        waveform = waveform[: 16000 * 8]
        segments = [waveform]
    else:
        waveform = waveform[: 16000 * 30]
        seg_len = 16000 * 8
        if len(waveform) <= seg_len:
            segments = [waveform]
        else:
            starts = np.linspace(
                0,
                max(0, len(waveform) - seg_len),
                num=3
            ).astype(int).tolist()
            segments = [waveform[s:s + seg_len] for s in starts]

    scores = []

    for seg in segments:
        inputs = audio_feature_extractor(
            seg,
            sampling_rate=16000,
            return_tensors="pt"
        )
        inputs = {k: v.to(device) for k, v in inputs.items()}

        with torch.inference_mode():
            outputs = audio_model(**inputs)

        probs = torch.softmax(outputs.logits, dim=-1)[0]
        scores.append(float(probs[fake_index].cpu().item()))

    ai = float(np.mean(scores)) if scores else 0.5

    os.remove(path)

    ai_percent = round(ai * 100, 2)

    return {

        "label": "Possibly AI-generated audio" if ai_percent >= 50 else "Likely human audio",
        "ai_probability": ai_percent,
        "human_probability": round(100 - ai_percent, 2),
        "confidence": confidence_tier(ai_percent),
        "method": f"Wav2Vec2 deepfake classifier ({chosen_mode}, segments={len(segments)})"

    }

# =====================================================
# PRODUCTION SPEED TRICK
# Skip low quality frames
# =====================================================

def frame_quality(frame):

    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

    blur = cv2.Laplacian(gray, cv2.CV_64F).var()

    brightness = np.mean(gray)

    if blur < 10:
        return False

    if brightness < 15 or brightness > 240:
        return False

    return True

# =====================================================
# FRAME SAMPLING
# =====================================================

def sample_frames(cap, sequential=8, random_count=4):

    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    if total <= 0:
        return []

    frames = []

    seq_idx = np.linspace(0, total-1, sequential).astype(int).tolist()
    used_idx = set(seq_idx)

    for i in seq_idx:
        cap.set(cv2.CAP_PROP_POS_FRAMES, i)
        ret, frame = cap.read()
        if ret and frame_quality(frame):
            frames.append(frame)

    rng = np.random.default_rng(seed=42)
    remaining = [i for i in range(total) if i not in used_idx]
    if remaining:
        rand_idx = rng.choice(
            remaining,
            size=min(random_count, len(remaining)),
            replace=False
        )
    else:
        rand_idx = []

    for i in rand_idx:
        cap.set(cv2.CAP_PROP_POS_FRAMES, int(i))
        ret, frame = cap.read()
        if ret and frame_quality(frame):
            frames.append(frame)

    # Keep only visually diverse frames so repeated near-identical shots
    # don't dominate model voting.
    diverse_frames = []
    prev_gray = None
    for frame in frames:
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        if prev_gray is None:
            diverse_frames.append(frame)
            prev_gray = gray
            continue

        delta = np.mean(np.abs(gray.astype(np.float32) - prev_gray.astype(np.float32)))
        if delta >= 3.0:
            diverse_frames.append(frame)
            prev_gray = gray

    return diverse_frames if diverse_frames else frames

# =====================================================
# NORMALIZATION
# =====================================================

def normalize_frame(frame):

    frame = frame.astype(np.float32)

    mean = np.mean(frame)
    std = np.std(frame) + 1e-6

    frame = (frame - mean) / std

    frame = np.clip(frame * 64 + 128, 0, 255)

    return frame.astype(np.uint8)


def resize_for_video_models(frame, max_side=640):

    h, w = frame.shape[:2]
    longest = max(h, w)

    if longest <= max_side:
        return frame

    scale = max_side / float(longest)
    nw = max(1, int(w * scale))
    nh = max(1, int(h * scale))

    return cv2.resize(frame, (nw, nh), interpolation=cv2.INTER_AREA)


def _robust_average(scores, neutral=0.5, trim_ratio=0.2):

    if not scores:
        return neutral

    arr = np.array(scores, dtype=np.float32)
    arr = np.clip(arr, 0.0, 1.0)

    if len(arr) >= 5:
        arr = np.sort(arr)
        trim = int(len(arr) * trim_ratio)
        if trim > 0 and (2 * trim) < len(arr):
            arr = arr[trim:-trim]

    return float(np.mean(arr))


def _soften_towards_neutral(score, factor=0.7):

    return float(0.5 + (score - 0.5) * factor)

# =====================================================
# DIFFUSION DETECTOR
# =====================================================

def diffusion_detector(frames):

    scores = []

    for frame in frames:

        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

        pil = Image.fromarray(rgb)

        try:

            result = sdxl_detector(pil)[0]

            ai_score = _label_to_ai_score(
                result.get("label", ""),
                result.get("score", 0.5)
            )

            scores.append(ai_score)

        except:
            continue

    if not scores:
        return 0.5

    return _robust_average(scores)


def _label_to_ai_score(label: str, raw_score: float) -> float:

    l = (label or "").lower()
    s = float(raw_score)

    ai_hints = ("ai", "fake", "synthetic", "generated", "deepfake")
    human_hints = ("real", "human", "authentic", "natural")

    if any(h in l for h in ai_hints):
        return s
    if any(h in l for h in human_hints):
        return 1 - s

    # Fall back to neutral interpretation if label is unknown.
    return 0.5


def deepfake_frame_detector(frames):

    scores = []

    for frame in frames:
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        pil = Image.fromarray(rgb)

        try:
            result = deepfake_detector(pil)[0]
            ai_score = _label_to_ai_score(result.get("label", ""), result.get("score", 0.5))
            scores.append(ai_score)
        except:
            continue

    if not scores:
        return 0.5

    return _robust_average(scores)


def sightengine_frame_detector(frames, max_frames=3, timeout_seconds=8):

    if not frames:
        return 0.5, []

    scores = []
    step = max(1, len(frames) // max_frames)

    for i in range(0, len(frames), step):
        if len(scores) >= max_frames:
            break

        frame = frames[i]
        ok, encoded = cv2.imencode(".jpg", frame, [int(cv2.IMWRITE_JPEG_QUALITY), 90])
        if not ok:
            continue

        try:
            response = detect_image_sightengine(
                encoded.tobytes(),
                timeout_seconds=timeout_seconds
            )
            if "error" in response:
                continue

            ai_score = float(response.get("ai_score", 0.5))
            ai_score = max(0.0, min(ai_score, 1.0))
            scores.append(ai_score)
        except:
            continue

    if not scores:
        return 0.5, []

    return _robust_average(scores), scores

# =====================================================
# DIFFUSION NOISE RESIDUAL DETECTOR
# =====================================================

def diffusion_residual_detector(frames):

    scores = []

    for frame in frames:

        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

        blur = cv2.GaussianBlur(gray,(7,7),0)

        residual = gray.astype(np.float32) - blur.astype(np.float32)

        score = 1/(1+np.var(residual))

        scores.append(score)

    return float(np.mean(scores))

# =====================================================
# FREQUENCY ARTIFACT DETECTOR
# =====================================================

def frequency_detector(frames):

    scores = []

    for frame in frames:

        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

        f = np.fft.fft2(gray)

        fshift = np.fft.fftshift(f)

        magnitude = np.log(np.abs(fshift)+1)

        high = np.mean(magnitude[10:-10,10:-10])

        low = np.mean(magnitude[:10,:10])

        score = high/(low+1e-6)

        scores.append(score)

    score = np.mean(scores)

    return float(1/(1+np.exp(-score)))

# =====================================================
# GAN FINGERPRINT
# =====================================================

def gan_detector(frames):

    scores=[]

    for frame in frames:

        gray=cv2.cvtColor(frame,cv2.COLOR_BGR2GRAY)

        lap=cv2.Laplacian(gray,cv2.CV_64F)

        var=lap.var()

        scores.append(1/(1+var))

    return float(np.mean(scores))

# =====================================================
# PRNU SENSOR NOISE
# =====================================================

def prnu_detector(frames):

    scores=[]

    for frame in frames:

        gray=cv2.cvtColor(frame,cv2.COLOR_BGR2GRAY)

        blur=cv2.GaussianBlur(gray,(5,5),0)

        residual=gray.astype(np.float32)-blur.astype(np.float32)

        noise=np.var(residual)

        scores.append(1/(1+noise))

    return float(np.mean(scores))

# =====================================================
# COMPRESSION ARTIFACTS
# =====================================================

def compression_artifact_detector(frames):

    scores=[]

    for frame in frames:

        gray=cv2.cvtColor(frame,cv2.COLOR_BGR2GRAY)

        h,w=gray.shape

        block=8

        vars=[]

        for y in range(0,h-block,block):
            for x in range(0,w-block,block):

                vars.append(np.var(gray[y:y+block,x:x+block]))

        scores.append(1/(1+np.var(vars)))

    return float(np.mean(scores))

# =====================================================
# OPTICAL FLOW
# =====================================================

def optical_flow_detector(frames):

    if len(frames)<2:
        return 0.5

    flows=[]

    prev=cv2.cvtColor(frames[0],cv2.COLOR_BGR2GRAY)

    for i in range(1,len(frames)):

        gray=cv2.cvtColor(frames[i],cv2.COLOR_BGR2GRAY)

        flow=cv2.calcOpticalFlowFarneback(prev,gray,None,0.5,3,15,3,5,1.2,0)

        mag,_=cv2.cartToPolar(flow[...,0],flow[...,1])

        flows.append(np.var(mag))

        prev=gray

    return float(1/(1+np.var(flows)))

# =====================================================
# TEMPORAL ARTIFACT
# =====================================================

def temporal_detector(frames):

    if len(frames)<2:
        return 0.5

    diffs=[]

    for i in range(len(frames)-1):

        g1=cv2.cvtColor(frames[i],cv2.COLOR_BGR2GRAY)

        g2=cv2.cvtColor(frames[i+1],cv2.COLOR_BGR2GRAY)

        diffs.append(np.mean(np.abs(g1.astype(float)-g2.astype(float))))

    return float(1/(1+np.var(diffs)))

# =====================================================
# FACE DEEPFAKE
# =====================================================

def face_detector(frames):

    scores=[]

    for frame in frames:

        gray=cv2.cvtColor(frame,cv2.COLOR_BGR2GRAY)

        faces=FACE_CASCADE.detectMultiScale(gray,1.3,5)

        for (x,y,w,h) in faces:

            face=gray[y:y+h,x:x+w]

            scores.append(1/(1+np.var(face)))

    if not scores:
        return 0.5

    return float(np.mean(scores))


# =====================================================
# COMPRESSION SCORE
# =====================================================
def compression_score(frames):
    return compression_artifact_detector(frames)

# =====================================================
# DCT COMPRESSION DETECTOR (YouTube / TikTok detection)
# =====================================================

def dct_compression_detector(frames):

    scores = []

    for frame in frames:

        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY).astype(np.float32)

        # Apply block DCT
        h, w = gray.shape
        block = 8

        dct_vals = []

        for y in range(0, h-block, block):
            for x in range(0, w-block, block):

                patch = gray[y:y+block, x:x+block]
                dct = cv2.dct(patch)

                # Ignore DC component
                dct_vals.append(np.var(dct[1:,1:]))

        if dct_vals:
            scores.append(1/(1+np.var(dct_vals)))

    if not scores:
        return 0.5

    return float(np.mean(scores))
# =====================================================
# FINAL DETECTOR
# =====================================================

def detect_video(video_file, mode="accurate"):
    path = None
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".mp4") as tmp:
            tmp.write(video_file.read())
            path = tmp.name

        chosen_mode = "fast" if str(mode).lower() == "fast" else "accurate"

        sequential = 6 if chosen_mode == "fast" else 10
        random_count = 2 if chosen_mode == "fast" else 6
        resize_max_side = 512 if chosen_mode == "fast" else 768
        quick_sightengine_frames = 2 if chosen_mode == "fast" else 3
        quick_sightengine_timeout = 6 if chosen_mode == "fast" else 10
        analysis_cap = 8 if chosen_mode == "fast" else 14

        cap = cv2.VideoCapture(path)
        frames = sample_frames(cap, sequential=sequential, random_count=random_count)
        cap.release()

        if not frames:
            return {
                "label": "Unable to analyze",
                "ai_probability": 0,
                "human_probability": 100
            }

        frames = [resize_for_video_models(f, max_side=resize_max_side) for f in frames]

        # Fast-path only when two independent ML signals strongly agree.
        quick_frames = frames[:8]
        quick_diffusion = diffusion_detector(quick_frames)
        quick_deepfake = deepfake_frame_detector(quick_frames)
        quick_sightengine, quick_sightengine_scores = sightengine_frame_detector(
            quick_frames,
            max_frames=quick_sightengine_frames if len(quick_frames) >= 6 else 2,
            timeout_seconds=quick_sightengine_timeout
        )
        quick_score = (
            (quick_diffusion * 0.30) +
            (quick_deepfake * 0.20) +
            (quick_sightengine * 0.50)
        )

        if len(frames) >= 8 and quick_score > (0.91 if chosen_mode == "fast" else 0.93):
            ai_percent = round(quick_score * 100, 2)
            return {
                "label": "AI-generated video",
                "ai_probability": ai_percent,
                "human_probability": round(100 - ai_percent, 2),
                "confidence": confidence_tier(ai_percent),
                "method": "Fast dual-model early exit",
                "mode": chosen_mode
            }

        analysis_frames = frames[:analysis_cap]

        diffusion = diffusion_detector(analysis_frames)
        deepfake_frame = deepfake_frame_detector(analysis_frames)
        sightengine_frame = quick_sightengine
        freq = frequency_detector(analysis_frames)
        gan = gan_detector(analysis_frames)
        prnu = prnu_detector(analysis_frames)
        comp = compression_artifact_detector(analysis_frames)
        flow = optical_flow_detector(analysis_frames)
        temporal = temporal_detector(analysis_frames)
        face = face_detector(analysis_frames)
        residual = diffusion_residual_detector(analysis_frames)
        dct = dct_compression_detector(analysis_frames)
        motion_score = 0.5

        model_consensus = (
            (diffusion * 0.20) +
            (deepfake_frame * 0.15) +
            (sightengine_frame * 0.65)
        )
        raw_heuristic_consensus = (
            freq * 0.14 +
            gan * 0.11 +
            prnu * 0.11 +
            comp * 0.07 +
            dct * 0.07 +
            flow * 0.12 +
            temporal * 0.10 +
            residual * 0.10 +
            face * 0.06 +
            motion_score * 0.12
        )

        heuristic_values = [freq, gan, prnu, comp, dct, flow, temporal, residual, face, motion_score]
        heuristic_std = float(np.std(np.array(heuristic_values, dtype=np.float32)))
        heuristic_agreement = max(0.0, min(1.0, 1.0 - (heuristic_std * 1.5)))
        heuristic_consensus = _soften_towards_neutral(
            raw_heuristic_consensus,
            factor=(0.35 + 0.65 * heuristic_agreement)
        )

        # Model-first calibration to avoid heuristic-heavy false negatives.
        strongest_ml_signal = max(diffusion, deepfake_frame, sightengine_frame)
        model_consensus = (model_consensus * 0.85) + (strongest_ml_signal * 0.15)

        heuristic_weight = 0.12 + (0.16 * heuristic_agreement)
        final = (model_consensus * (1.0 - heuristic_weight)) + (heuristic_consensus * heuristic_weight)

        # Strong model agreement should not be dragged down by weak heuristics.
        if model_consensus >= 0.72 and strongest_ml_signal >= 0.80:
            final = max(final, 0.72 + ((model_consensus - 0.72) * 0.35))
        elif model_consensus >= 0.66 and strongest_ml_signal >= 0.74:
            final = max(final, 0.66 + ((model_consensus - 0.66) * 0.30))
        elif sightengine_frame >= 0.92:
            # Soft boost rather than hard floor to preserve score differentiation.
            final = max(final, 0.68 + ((sightengine_frame - 0.92) * 0.30))
        elif sightengine_frame >= 0.85 and model_consensus >= 0.58:
            final = max(final, 0.62 + ((sightengine_frame - 0.85) * 0.40))

        # Expensive ffmpeg pass only in borderline cases.
        if 0.45 <= final <= 0.72:
            motion_score = motion_vector_score(path)
            final = (final * 0.92) + (motion_score * 0.08)

        # When very few frames pass quality filtering, reduce overconfidence.
        if len(frames) < 6:
            final = (final * 0.6) + 0.2

        # Adjust certainty based on cross-frame variation from Sightengine.
        # Low variation means stable evidence (slight confidence bump),
        # high variation means unstable evidence (slight pull to neutral).
        se_std = float(np.std(np.array(quick_sightengine_scores, dtype=np.float32))) if quick_sightengine_scores else 0.0
        consistency = max(0.0, min(1.0, 1.0 - (se_std * 2.5)))
        if consistency >= 0.75:
            final = (final * 0.94) + 0.03
        elif consistency <= 0.40:
            final = (final * 0.88) + 0.06

        final = max(0.0, min(final, 1.0))
        ai_percent = round(final * 100, 2)

        return {
            "label": "AI-generated video" if ai_percent >= 60 else "Likely real video",
            "ai_probability": ai_percent,
            "human_probability": round(100 - ai_percent, 2),
            "confidence": confidence_tier(ai_percent),
            "method": "Detectify rebalanced multi-signal ensemble",
            "mode": chosen_mode,
            "signals": {
                "diffusion": round(diffusion, 4),
                "deepfake_frame": round(deepfake_frame, 4),
                "sightengine_frame": round(sightengine_frame, 4),
                "sightengine_frame_std": round(se_std, 4),
                "sightengine_frames_scored": len(quick_sightengine_scores),
                "frequency": round(freq, 4),
                "gan": round(gan, 4),
                "prnu": round(prnu, 4),
                "compression": round(comp, 4),
                "dct": round(dct, 4),
                "optical_flow": round(flow, 4),
                "temporal": round(temporal, 4),
                "residual": round(residual, 4),
                "face": round(face, 4),
                "motion": round(motion_score, 4),
                "model_consensus": round(model_consensus, 4),
                "heuristic_agreement": round(heuristic_agreement, 4),
                "heuristic_consensus": round(heuristic_consensus, 4),
                "frames_used": len(frames)
            }
        }
    finally:
        if path and os.path.exists(path):
            os.remove(path)
