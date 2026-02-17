from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Dict


EMOTION_LABELS = [
    "high_stress",
    "low_confidence",
    "high_energy",
    "frustration",
    "analytical_mode",
    "neutral",
]


@dataclass
class EmotionAnalysis:
    primary: str
    scores: Dict[str, float]
    sentiment: Dict[str, float]
    linguistic_markers: Dict[str, float]


def _clip01(v: float) -> float:
    return max(0.0, min(1.0, v))


def analyze_text_emotion(text: str) -> EmotionAnalysis:
    t = (text or "").lower()

    stress_terms = ["overwhelmed", "anxious", "pressure", "burnout", "panic", "stressed"]
    confidence_terms = ["not good enough", "imposter", "doubt", "hesitate", "afraid"]
    energy_terms = ["excited", "motivated", "energized", "ready", "let's do it"]
    frustration_terms = ["blocked", "stuck", "frustrated", "politics", "can't move"]
    analytical_terms = ["tradeoff", "framework", "strategy", "options", "prioritize", "roadmap"]

    def score_for(terms: list[str]) -> float:
        hits = sum(1 for x in terms if x in t)
        return _clip01(hits / 3.0)

    high_stress = score_for(stress_terms)
    low_confidence = score_for(confidence_terms)
    high_energy = score_for(energy_terms)
    frustration = score_for(frustration_terms)
    analytical_mode = score_for(analytical_terms)

    certainty_terms = ["definitely", "clearly", "certain", "must"]
    uncertainty_terms = ["maybe", "not sure", "unclear", "might", "perhaps"]

    certainty = _clip01(sum(1 for x in certainty_terms if x in t) / 3.0)
    uncertainty = _clip01(sum(1 for x in uncertainty_terms if x in t) / 3.0)

    words = [w for w in t.split() if w.strip()]
    complexity = _clip01(len(words) / 80.0)
    engagement = _clip01(len(words) / 50.0)

    neg = _clip01((high_stress + low_confidence + frustration) / 2.5)
    pos = _clip01((high_energy + certainty) / 2.0)
    neu = _clip01(1.0 - abs(pos - neg))

    scores = {
        "high_stress": high_stress,
        "low_confidence": low_confidence,
        "high_energy": high_energy,
        "frustration": frustration,
        "analytical_mode": analytical_mode,
    }

    if max(scores.values()) < 0.25:
        primary = "neutral"
    else:
        primary = max(scores, key=scores.get)

    return EmotionAnalysis(
        primary=primary,
        scores={**scores, "neutral": 1.0 if primary == "neutral" else 0.0},
        sentiment={"positive": pos, "negative": neg, "neutral": neu},
        linguistic_markers={
            "certainty": certainty,
            "uncertainty": uncertainty,
            "complexity": complexity,
            "engagement": engagement,
        },
    )


def infer_context_triggers(text: str, now: datetime | None = None) -> Dict[str, str]:
    t = (text or "").lower()
    now = now or datetime.now()

    trigger = "general"
    if any(k in t for k in ["deadline", "due", "urgent", "eod"]):
        trigger = "deadline_pressure"
    elif any(k in t for k in ["meeting", "1:1", "all-hands", "board"]):
        trigger = "meeting_context"
    elif any(k in t for k in ["team", "conflict", "manager", "stakeholder"]):
        trigger = "team_conflict"

    return {
        "situational_trigger": trigger,
        "time_of_day": str(now.hour),
        "day_of_week": str(now.weekday()),
    }
