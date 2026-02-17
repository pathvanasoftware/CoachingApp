from typing import Literal

EmotionLabel = Literal["neutral", "distressed", "low_confidence", "motivated", "uncertain"]


def detect_emotion(message: str) -> EmotionLabel:
    text = (message or "").lower()

    if any(k in text for k in ["hopeless", "panic", "can't", "overwhelmed", "burnout", "anxious"]):
        return "distressed"
    if any(k in text for k in ["imposter", "not good enough", "doubt", "afraid to fail"]):
        return "low_confidence"
    if any(k in text for k in ["excited", "ready", "committed", "motivated"]):
        return "motivated"
    if any(k in text for k in ["not sure", "confused", "unclear", "maybe"]):
        return "uncertain"

    return "neutral"
