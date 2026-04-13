from __future__ import annotations

from difflib import SequenceMatcher
import logging
import re

import numpy as np

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

	def normalize(value: str) -> str:
		return value.lower().replace(" ", "").replace("-", "")

	raw_chunks = [
		chunk.strip()
		for chunk in re.split(r"[,\n\r·•;:/|]+", text)
		if chunk and chunk.strip()
	]

	extracted_words: list[str] = []
	for chunk in raw_chunks:
		normalized_chunk = re.sub(r"\s+", " ", chunk).strip()
		if normalized_chunk:
			extracted_words.append(normalized_chunk)

		for token in re.findall(r"[가-힣A-Za-z][가-힣A-Za-z0-9()\-\s]{0,80}", chunk):
			normalized_token = re.sub(r"\s+", " ", token).strip()
			if len(normalized_token) >= 2:
				extracted_words.append(normalized_token)

	korean_words = re.findall(r"[가-힣]{2,}", text)
	extracted_words.extend(korean_words)
	extracted_words = list(set(extracted_words))

	if not extracted_words:
		logger.info("추출된 성분 후보 없음")
		return []

	logger.info("추출된 모든 후보: %s", extracted_words)
	logger.info("[OCR SEARCH] 과라나 후보 포함 여부: %s", "과라나" in extracted_words)

	try:
		cursor = db_service.db["ingredients"].find({})
		documents = await cursor.to_list(length=5000)
	except Exception:
		logger.exception("Failed to load ingredients for OCR search")
		return []

	logger.info(f"데이터베이스에서 {len(documents)}개의 성분 로드됨")

	matched_ingredients: list[dict] = []
	seen_names: set[str] = set()

	for document in documents:
		db_word = str(document.get("name", "")).strip()
		if not db_word:
			continue

		normalized_db = normalize(db_word)
		if not normalized_db or normalized_db in seen_names:
			continue

		for candidate in extracted_words:
			normalized_candidate = normalize(candidate)
			if not normalized_candidate:
				continue

			ratio = 1.0 if normalized_db == normalized_candidate else SequenceMatcher(
				None,
				normalized_db,
				normalized_candidate,
			).ratio()
			score = int(ratio * 100)
			logger.info(
				"[OCR SEARCH] 유사도 점수: db=%s, 후보=%s, score=%d",
				db_word,
				candidate,
				score,
			)

			if normalized_db == normalized_candidate:
				serialized_document = dict(document)
				if "_id" in serialized_document:
					serialized_document["_id"] = str(serialized_document["_id"])
				matched_ingredients.append(serialized_document)
				seen_names.add(normalized_db)
				break

			if normalized_db in normalized_candidate or normalized_candidate in normalized_db:
				serialized_document = dict(document)
				if "_id" in serialized_document:
					serialized_document["_id"] = str(serialized_document["_id"])
				matched_ingredients.append(serialized_document)
				seen_names.add(normalized_db)
				break

	result = matched_ingredients
	logger.info("[OCR SEARCH] 매칭된 성분명 목록: %s", [item.get("name", "") for item in result])
	logger.info("[OCR SEARCH] 과라나 포함 여부: %s", any("과라나" in str(item.get("name", "")) for item in result))
	
	# 디버깅: 최종 반환 결과 로그
	logger.info(f"최종 반환 성분 수: {len(result)}")
	if result:
		returned_names = [str(item.get("name", "")) for item in result[:5]]  # 처음 5개만 로그
		logger.info(f"반환된 성분 (상위 5개): {returned_names}")
		logger.info("[OCR SEARCH] 과라나 최종 포함 여부: %s", any("과라나" in str(item.get("name", "")) for item in result))
	
	return result


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
