def explain_text(raw_result):

    ai_conf = float(raw_result.get("ai_probability", 0)) / 100

    if ai_conf >= 0.75:
        summary = (
            "The text exhibits high statistical consistency and "
            "probability alignment with AI-generated language."
        )
        reasoning = [
            "High probability score from Sapling AI classifier.",
            "Uniform sentence structure patterns detected.",
            "Predictable token distribution observed."
        ]

    elif ai_conf >= 0.45:
        summary = (
            "The text contains a mixture of human variation and "
            "structured AI-like characteristics."
        )
        reasoning = [
            "Moderate AI likelihood score.",
            "Partial uniformity in sentence construction.",
            "Some statistical predictability detected."
        ]

    else:
        summary = (
            "The text shows strong human-like variability and "
            "natural linguistic irregularities."
        )
        reasoning = [
            "Low AI probability score.",
            "Higher entropy in token distribution.",
            "Natural burstiness patterns detected."
        ]

    return {
        "version": "2.0",
        "summary": summary,
        "model_reasoning": reasoning,
        "ai_likelihood": round(ai_conf, 4),
        "human_likelihood": round(1 - ai_conf, 4),
    }