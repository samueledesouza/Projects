from explainability.text_explainer import explain_text
from explainability.image_explainer import explain_image
from explainability.audio_explainer import explain_audio
from explainability.video_explainer import explain_video


class ExplainabilityEngine:

    @staticmethod
    def generate(media_type, raw_result):

        if media_type == "image":
            return explain_image(raw_result)

        if media_type == "text":
            return explain_text(raw_result)

        if media_type == "audio":
            return explain_audio(raw_result)

        if media_type == "video":
            return explain_video(raw_result)

        return {
            "version": "1.0",
            "summary": "Explainability not available.",
            "model_reasoning": [],
        }