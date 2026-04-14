from __future__ import annotations

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
		"""공백과 하이픈을 제거하고 소문자로 변환"""
		return re.sub(r"[\s-]+", "", value.lower())

	def serialize_document(document: dict) -> dict:
		"""_id를 str로 변환하여 JSON 직렬화 가능하게 함"""
		serialized = dict(document)
		if "_id" in serialized:
			serialized["_id"] = str(serialized["_id"])
		return serialized

	# 1. DB에서 모든 성분 로드
	try:
		cursor = db_service.db["ingredients"].find({})
		all_documents = await cursor.to_list(length=5000)
	except Exception:
		logger.exception("Failed to load all ingredients from database")
		return []

	if not all_documents:
		return []

	# 정규화된 맵 생성: {정규화된이름: 원본문서}
	normalized_ingredient_map: dict[str, dict] = {}
	for document in all_documents:
		original_name = str(document.get("name", "")).strip()
		if original_name:
			normalized_name = normalize(original_name)
			if normalized_name:
				normalized_ingredient_map[normalized_name] = document

	if not normalized_ingredient_map:
		return []

	# 2. 텍스트에서 성분 후보 추출
	raw_chunks = [
		chunk.strip()
		for chunk in re.split(r"[,\n\r·•;:/|]+", text)
		if chunk and chunk.strip()
	]

	extracted_words: list[str] = []
	seen_candidates: set[str] = set()

	# 청크 단위 추가
	for chunk in raw_chunks:
		normalized_chunk = re.sub(r"\s+", " ", chunk).strip()
		if normalized_chunk and normalized_chunk not in seen_candidates:
			extracted_words.append(normalized_chunk)
			seen_candidates.add(normalized_chunk)

	# 토큰 단위 추가
	for chunk in raw_chunks:
		for token in re.findall(r"[가-힣A-Za-z][가-힣A-Za-z0-9()\-\s]{0,80}", chunk):
			normalized_token = re.sub(r"\s+", " ", token).strip()
			if len(normalized_token) >= 2 and normalized_token not in seen_candidates:
				extracted_words.append(normalized_token)
				seen_candidates.add(normalized_token)

	# 한글 단어 추가
	for word in re.findall(r"[가-힣]{2,}", text):
		if word not in seen_candidates:
			extracted_words.append(word)
			seen_candidates.add(word)

	if not extracted_words:
		return []

	# 추출된 단어도 정규화된 set으로 변환
	normalized_extracted: set[str] = set(normalize(word) for word in extracted_words if normalize(word))

	if not normalized_extracted:
		return []

	# 3. 매칭 로직 수행
	matched_ingredients: list[dict] = []
	seen_names: set[str] = set()

	# 정확일치(정규화된 맵 키와 비교)
	for normalized_extracted_word in normalized_extracted:
		if normalized_extracted_word in normalized_ingredient_map:
			if normalized_extracted_word not in seen_names:
				matched_ingredients.append(serialize_document(normalized_ingredient_map[normalized_extracted_word]))
				seen_names.add(normalized_extracted_word)

	# 부분일치 (정규화된 이름에 단어가 포함되거나, 단어에 이름이 포함)
	for normalized_extracted_word in normalized_extracted:
		if normalized_extracted_word in seen_names:
			continue

		for normalized_db_name, document in normalized_ingredient_map.items():
			if normalized_db_name in seen_names:
				continue

			if (normalized_db_name in normalized_extracted_word or
				normalized_extracted_word in normalized_db_name):
				matched_ingredients.append(serialize_document(document))
				seen_names.add(normalized_db_name)

	return matched_ingredients


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
