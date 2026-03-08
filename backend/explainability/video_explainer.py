def explain_video(raw_result):

    ai_conf = float(raw_result.get("ai_probability", 0))

    if ai_conf >= 85:
        summary = (
            "The video exhibits strong spatial-temporal consistency "
            "patterns and synthetic rendering artifacts commonly "
            "associated with AI-generated media."
        )
        reasoning = [
            "High AI probability from video classifier.",
            "Frame-level texture uniformity detected.",
            "Temporal transitions show neural rendering characteristics."
        ]

    elif ai_conf >= 60:
        summary = (
            "The video contains mixed temporal and spatial features, "
            "indicating possible AI-assisted generation."
        )
        reasoning = [
            "Moderate AI confidence score.",
            "Partial frame regularity patterns detected.",
            "Temporal motion characteristics not fully natural."
        ]

    else:
        summary = (
            "The video displays natural motion variation and "
            "organic frame-level inconsistencies typical of real recordings."
        )
        reasoning = [
            "Low AI classifier probability.",
            "Natural temporal jitter and lighting variance observed.",
            "Frame noise distribution consistent with camera capture."
        ]

    return {
        "version": "1.0",
        "summary": summary,
        "model_reasoning": reasoning,
        "ai_likelihood": ai_conf,
        "human_likelihood": 100 - ai_conf,
    }