from __future__ import annotations

import logging
import re

import numpy as np
from rapidfuzz import fuzz

from google.auth.exceptions import DefaultCredentialsError
from google.cloud import vision

from backend.services.db_service import get_db_service

logger = logging.getLogger(__name__)


def preprocess_image(image_bytes: bytes) -> np.ndarray:
	if not image_bytes:
		raise ValueError("이미지 데이터가 비어 있습니다.")

	try:
		import cv2
	except Exception as exc:
		raise RuntimeError(
			"OpenCV를 사용할 수 없습니다. 현재 환경의 NumPy/OpenCV 버전 호환성을 확인하세요."
		) from exc

	image_array = np.frombuffer(image_bytes, dtype=np.uint8)
	source_image = cv2.imdecode(image_array, cv2.IMREAD_COLOR)
	if source_image is None:
		raise ValueError("이미지 파일을 읽을 수 없습니다.")

	gray_image = cv2.cvtColor(source_image, cv2.COLOR_BGR2GRAY)
	blurred_image = cv2.GaussianBlur(gray_image, (3, 3), 0)
	clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
	enhanced_image = clahe.apply(blurred_image)

	return enhanced_image


async def search_ingredients(extracted_text: str) -> list[dict]:
	text = extracted_text.strip()
	if not text:
		return []

	db_service = get_db_service()
	if db_service.db is None:
		return []

	words = [part.strip() for part in re.split(r"[\n,·/|()\[\]{}<>:;\s]+", text) if part.strip()]
	if not words:
		words = [text]

	try:
		cursor = db_service.db["food_ingredients"].find({}, {"_id": 0})
		documents = await cursor.to_list(length=5000)
	except Exception:
		logger.exception("Failed to load ingredients for OCR search")
		return []

	matches: list[dict] = []
	seen_names: set[str] = set()

	for document in documents:
		name = str(document.get("name", "")).strip()
		if not name or name in seen_names:
			continue

		score = max(fuzz.token_set_ratio(name, word) for word in words)
		if score < 70:
			continue

		seen_names.add(name)
		matches.append(
			{
				"name": name,
				"eng_name": str(document.get("eng_name", "")),
				"classification": str(document.get("classification", "")),
				"source": str(document.get("source", "")),
				"score": score,
			}
		)

	matches.sort(key=lambda item: item["score"], reverse=True)
	return matches


def extract_text_from_image(image_bytes: bytes) -> str:
	if not image_bytes:
		return ""

	try:
		client = vision.ImageAnnotatorClient()
	except DefaultCredentialsError as exc:
		raise RuntimeError(
			"Google Vision 인증 키가 설정되지 않았습니다. GOOGLE_APPLICATION_CREDENTIALS를 설정하세요."
		) from exc

	try:
		processed_image = preprocess_image(image_bytes)
		import cv2
		encoded_ok, encoded_image = cv2.imencode(".jpg", processed_image)
		if not encoded_ok:
			raise RuntimeError("전처리된 이미지를 인코딩할 수 없습니다.")
		image_content = encoded_image.tobytes()
	except Exception as exc:
		logger.warning("전처리 실패로 원본 이미지를 사용합니다: %s", exc)
		image_content = image_bytes

	image = vision.Image(content=image_content)
	response = client.text_detection(image=image)

	if response.error.message:
		raise RuntimeError(response.error.message)

	if not response.text_annotations:
		return ""

	return response.text_annotations[0].description
