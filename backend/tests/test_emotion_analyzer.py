from app.services.emotion_analyzer import detect_emotion


def test_detect_emotion_cases():
    assert detect_emotion("I feel hopeless and overwhelmed") == "distressed"
    assert detect_emotion("I have imposter syndrome") == "low_confidence"
    assert detect_emotion("I am excited and ready") == "motivated"
    assert detect_emotion("I'm not sure, maybe") == "uncertain"
    assert detect_emotion("normal update") == "neutral"
