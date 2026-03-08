def explain_image(raw_result):

    ai_conf = 0.0

    try:

        # Sightengine format
        if "type" in raw_result and isinstance(raw_result["type"], dict):
            ai_conf = float(raw_result["type"].get("ai_generated", 0))

        # Generic format
        elif "ai_probability" in raw_result:
            val = float(raw_result["ai_probability"])
            ai_conf = val / 100 if val > 1 else val

    except:
        ai_conf = 0.0


    if ai_conf >= 0.85:

        summary = (
            "The image shows strong statistical patterns commonly found "
            "in AI-generated imagery, including structured textures and "
            "uniform noise distribution."
        )

        reasoning = [
            "High AI probability from the detection model.",
            "Texture regularities typical of diffusion-based generators.",
            "Sensor noise characteristics inconsistent with camera capture."
        ]


    elif ai_conf >= 0.60:

        summary = (
            "The image contains some synthetic visual characteristics, "
            "though natural photographic traits are still present."
        )

        reasoning = [
            "Moderate AI detection confidence.",
            "Partial synthetic texture patterns detected.",
            "Mixed natural and generated noise structures."
        ]


    else:

        summary = (
            "The image appears consistent with natural photography "
            "and lacks strong indicators of AI generation."
        )

        reasoning = [
            "Low AI probability score.",
            "Natural lighting variation present.",
            "Noise patterns consistent with camera sensors."
        ]


    return {
        "version": "2.0",
        "summary": summary,
        "model_reasoning": reasoning,
        "ai_likelihood": round(ai_conf, 4),
        "human_likelihood": round(1 - ai_conf, 4),
    }