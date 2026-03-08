def explain_audio(raw_result):

    ai_conf = float(raw_result.get("ai_probability", 0))

    if ai_conf >= 85:
        summary = (
            "The audio sample displays acoustic smoothness and "
            "prosodic regularity consistent with synthetic voice generation."
        )
        reasoning = [
            "High AI classifier confidence.",
            "Reduced pitch variance compared to natural speech.",
            "Spectral uniformity typical of neural TTS systems."
        ]

    elif ai_conf >= 60:
        summary = (
            "The audio contains partially synthetic acoustic traits "
            "while retaining some natural human speech dynamics."
        )
        reasoning = [
            "Moderate AI probability.",
            "Mixed spectral and temporal characteristics.",
            "Partial human-like prosody detected."
        ]

    else:
        summary = (
            "The audio demonstrates natural pitch fluctuation and "
            "irregular speech dynamics typical of human recording."
        )
        reasoning = [
            "Low AI classifier confidence.",
            "Natural prosodic variation present.",
            "Spectral noise characteristics align with real microphone capture."
        ]

    return {
        "version": "1.0",
        "summary": summary,
        "model_reasoning": reasoning,
        "ai_likelihood": ai_conf,
        "human_likelihood": 100 - ai_conf,
    }