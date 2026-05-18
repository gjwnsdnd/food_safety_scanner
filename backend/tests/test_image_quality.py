import unittest

import cv2
import numpy as np

from backend.services.image_quality import evaluate_image_quality


def _encode_jpg(image: np.ndarray) -> bytes:
    ok, encoded = cv2.imencode(".jpg", image)
    if not ok:
        raise RuntimeError("테스트 이미지 인코딩에 실패했습니다.")
    return encoded.tobytes()


class ImageQualityTests(unittest.TestCase):
    def test_white_image_triggers_overexposed_warning(self):
        image = np.full((600, 900, 3), 255, dtype=np.uint8)

        result = evaluate_image_quality(_encode_jpg(image))

        self.assertTrue(result.warning)
        self.assertIn("overexposed", result.reasons)
        self.assertGreaterEqual(result.score.overexposed_ratio, 0.08)

    def test_heavy_blur_does_not_trigger_warning(self):
        rng = np.random.default_rng(seed=42)
        image = rng.integers(0, 220, size=(700, 1000, 3), dtype=np.uint8)
        blurred = cv2.GaussianBlur(image, (41, 41), 0)

        result = evaluate_image_quality(_encode_jpg(blurred))

        self.assertFalse(result.warning)
        self.assertNotIn("blurry", result.reasons)

    def test_normal_pattern_image_is_not_warning(self):
        h, w = 640, 960
        x = np.arange(w)
        y = np.arange(h)
        xx, yy = np.meshgrid(x, y)
        pattern = ((xx // 24 + yy // 24) % 2) * 140 + 40
        image = np.stack([pattern, pattern, pattern], axis=-1).astype(np.uint8)

        result = evaluate_image_quality(_encode_jpg(image))

        self.assertFalse(result.warning)
        self.assertEqual(result.reasons, [])


if __name__ == "__main__":
    unittest.main()
