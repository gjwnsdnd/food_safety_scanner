from __future__ import annotations

from dataclasses import dataclass

import cv2
import numpy as np

RESIZE_WIDTH = 1024
BRIGHT_THRESHOLD = 245
OVEREXPOSED_RATIO_THRESHOLD = 0.08
GLARE_BLOB_RATIO_THRESHOLD = 0.02


@dataclass(frozen=True)
class ImageQualityScore:
    overexposed_ratio: float
    max_bright_blob_ratio: float


@dataclass(frozen=True)
class ImageQualityResult:
    ok: bool
    warning: bool
    reasons: list[str]
    score: ImageQualityScore

    def to_dict(self) -> dict:
        return {
            "ok": self.ok,
            "warning": self.warning,
            "reasons": self.reasons,
            "score": {
                "overexposed_ratio": self.score.overexposed_ratio,
                "max_bright_blob_ratio": self.score.max_bright_blob_ratio,
            },
        }


def evaluate_image_quality(image_bytes: bytes) -> ImageQualityResult:
    np_buffer = np.frombuffer(image_bytes, np.uint8)
    image = cv2.imdecode(np_buffer, cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError("유효한 이미지 파일이 아닙니다.")

    resized = _resize_keep_ratio(image, target_width=RESIZE_WIDTH)
    gray = cv2.cvtColor(resized, cv2.COLOR_BGR2GRAY)

    total_pixels = float(gray.size)
    overexposed_ratio = float(np.count_nonzero(gray >= BRIGHT_THRESHOLD) / total_pixels)

    _, bright_mask = cv2.threshold(gray, BRIGHT_THRESHOLD, 255, cv2.THRESH_BINARY)
    max_bright_blob_ratio = _calculate_max_bright_blob_ratio(bright_mask)

    reasons: list[str] = []
    if overexposed_ratio >= OVEREXPOSED_RATIO_THRESHOLD:
        reasons.append("overexposed")
    if max_bright_blob_ratio >= GLARE_BLOB_RATIO_THRESHOLD:
        reasons.append("glare_blob")

    score = ImageQualityScore(
        overexposed_ratio=overexposed_ratio,
        max_bright_blob_ratio=max_bright_blob_ratio,
    )
    return ImageQualityResult(
        ok=True,
        warning=bool(reasons),
        reasons=reasons,
        score=score,
    )


def _resize_keep_ratio(image: np.ndarray, target_width: int) -> np.ndarray:
    height, width = image.shape[:2]
    if width <= 0:
        raise ValueError("유효하지 않은 이미지 너비입니다.")
    if width == target_width:
        return image

    ratio = target_width / float(width)
    target_height = max(1, int(round(height * ratio)))
    return cv2.resize(image, (target_width, target_height), interpolation=cv2.INTER_AREA)


def _calculate_max_bright_blob_ratio(bright_mask: np.ndarray) -> float:
    total_pixels = float(bright_mask.size)
    num_labels, _, stats, _ = cv2.connectedComponentsWithStats(bright_mask, connectivity=8)
    if num_labels <= 1:
        return 0.0

    # stats[0]은 배경이므로 제외합니다.
    max_area = float(np.max(stats[1:, cv2.CC_STAT_AREA]))
    return max_area / total_pixels
