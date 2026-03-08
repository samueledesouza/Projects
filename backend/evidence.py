import numpy as np
import cv2
from PIL import Image, ExifTags

# ===============================
# FREQUENCY DOMAIN ANALYSIS
# ===============================
# Detects diffusion-style frequency residue
# Evidence only — NOT a verdict

def diffusion_frequency_residue(image: Image.Image) -> float:
    """
    Returns:
        mid-frequency energy / low-frequency energy

    Typical ranges (empirical):
        • Real photos:        ~0.8 – 1.2
        • Diffusion images:  ~1.35+

    Output is a raw ratio (not normalized).
    """

    # Convert to grayscale
    img = np.array(image.convert("L"))

    # Normalize size for consistency
    img = cv2.resize(img, (512, 512), interpolation=cv2.INTER_AREA)

    # FFT
    fft = np.fft.fft2(img)
    fft_shift = np.fft.fftshift(fft)
    magnitude = np.abs(fft_shift)

    h, w = magnitude.shape
    cy, cx = h // 2, w // 2

    # Radial frequency grid
    Y, X = np.ogrid[:h, :w]
    radius = np.sqrt((X - cx) ** 2 + (Y - cy) ** 2)

    # Frequency bands (empirically stable)
    low_band = magnitude[(radius > 5) & (radius < 40)]
    mid_band = magnitude[(radius > 40) & (radius < 120)]

    if low_band.size == 0 or mid_band.size == 0:
        return 1.0  # Neutral safe fallback

    low_energy = np.mean(low_band)
    mid_energy = np.mean(mid_band)

    ratio = mid_energy / (low_energy + 1e-6)
    return float(ratio)

# ===============================
# JPEG NOISE CONSISTENCY
# ===============================
# AI images often lack natural sensor noise

def jpeg_noise_inconsistency(image: Image.Image) -> float:
    """
    Returns:
        Standard deviation of residual noise.

    Interpretation:
        • Higher → more natural sensor noise
        • Lower  → overly clean / synthetic
    """

    gray = cv2.cvtColor(np.array(image), cv2.COLOR_RGB2GRAY)
    blur = cv2.GaussianBlur(gray, (3, 3), 0)

    noise = gray.astype(np.float32) - blur.astype(np.float32)
    return float(np.std(noise))

# ===============================
# EXIF METADATA EXTRACTION
# ===============================
# Evidence only — metadata can be forged

def extract_exif(image: Image.Image) -> dict:
    """
    Returns:
        Dictionary of EXIF tags if present, else empty dict.
    """

    try:
        exif_raw = image._getexif()
        if not exif_raw:
            return {}

        return {
            ExifTags.TAGS.get(k, k): v
            for k, v in exif_raw.items()
        }
    except Exception:
        return {}
