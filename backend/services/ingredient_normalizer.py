from __future__ import annotations

import re

_DASH_VARIANTS_PATTERN = re.compile(r"[‐‑‒–—―﹘﹣－]")
_MULTI_SPACE_PATTERN = re.compile(r"\s+")
_STEREO_PREFIX_PATTERN = re.compile(r"^(?:d\s*,\s*l|dl|d|l)\s*(?:-|\s)\s*", re.IGNORECASE)
_PARENTHESIS_GROUP_PATTERN = re.compile(r"\([^)]*\)")
_MATCHING_SPACE_HYPHEN_PATTERN = re.compile(r"[\s-]+")


def normalize_ingredient_name(value: str) -> str:
    normalized = _DASH_VARIANTS_PATTERN.sub("-", str(value or ""))
    normalized = _MULTI_SPACE_PATTERN.sub(" ", normalized).strip()
    normalized = _STEREO_PREFIX_PATTERN.sub("", normalized)
    normalized = _PARENTHESIS_GROUP_PATTERN.sub("", normalized)
    normalized = _MULTI_SPACE_PATTERN.sub(" ", normalized).strip()
    return normalized


def normalize_ingredient_for_matching(value: str) -> str:
    normalized = normalize_ingredient_name(value)
    return _MATCHING_SPACE_HYPHEN_PATTERN.sub("", normalized.lower())
