import 'package:dio/dio.dart';

class ApiService {
	ApiService({Dio? dio})
			: _dio = dio ??
						Dio(
							BaseOptions(
								baseUrl: 'http://10.0.2.2:8010',
								connectTimeout: const Duration(seconds: 10),
								receiveTimeout: const Duration(seconds: 20),
								sendTimeout: const Duration(seconds: 20),
								headers: {
									'Content-Type': 'application/json',
									'Accept': 'application/json',
								},
							),
						);

	final Dio _dio;

	Future<Map<String, dynamic>> scanIngredients(String productName) async {
		if (productName.trim().isEmpty) {
			throw ArgumentError('productName cannot be empty');
		}

		try {
			final response = await _dio.post<Map<String, dynamic>>(
				'/api/scan',
				data: {
					'product_name': productName,
				},
			);

			final data = response.data;
			if (data == null) {
				throw Exception('서버 응답이 비어 있습니다.');
			}

			return data;
		} on DioException catch (e) {
			final statusCode = e.response?.statusCode;
			final responseData = e.response?.data;

			if (statusCode != null) {
				throw Exception('API 오류 ($statusCode): $responseData');
			}

			switch (e.type) {
				case DioExceptionType.connectionTimeout:
				case DioExceptionType.sendTimeout:
				case DioExceptionType.receiveTimeout:
					throw Exception('요청 시간이 초과되었습니다. 네트워크 상태를 확인해 주세요.');
				case DioExceptionType.connectionError:
					throw Exception('서버에 연결할 수 없습니다. 백엔드 실행 상태를 확인해 주세요.');
				case DioExceptionType.cancel:
					throw Exception('요청이 취소되었습니다.');
				case DioExceptionType.badCertificate:
					throw Exception('인증서 오류가 발생했습니다.');
				case DioExceptionType.badResponse:
					throw Exception('서버 응답 처리 중 오류가 발생했습니다.');
				case DioExceptionType.unknown:
					throw Exception('알 수 없는 네트워크 오류가 발생했습니다: ${e.message}');
			}
		} catch (e) {
			throw Exception('성분 분석 요청 중 오류가 발생했습니다: $e');
		}
	}

	Future<Map<String, dynamic>> scanImageWithOcr(String imagePath) async {
		if (imagePath.trim().isEmpty) {
			throw ArgumentError('imagePath cannot be empty');
		}

		try {
			final fileName = imagePath.split(RegExp(r'[\\/]')).last;
			final formData = FormData.fromMap({
				'file': await MultipartFile.fromFile(imagePath, filename: fileName),
			});

			final response = await _dio.post<Map<String, dynamic>>(
				'/api/scan/ocr',
				data: formData,
				options: Options(
					headers: {
						'Content-Type': 'multipart/form-data',
					},
				),
			);

			final data = response.data;
			if (data == null) {
				throw Exception('서버 응답이 비어 있습니다.');
			}

			return data;
		} on DioException catch (e) {
			_handleDioError(e);
		} catch (e) {
			throw Exception('OCR 요청 중 오류가 발생했습니다: $e');
		}
	}

	Future<Map<String, dynamic>> getPreferences(String userId) async {
		try {
			final response = await _dio.get<Map<String, dynamic>>(
				'/api/preferences/$userId',
			);

			final data = response.data;
			if (data == null) {
				throw Exception('서버 응답이 비어 있습니다.');
			}

			return data;
		} on DioException catch (e) {
			_handleDioError(e);
		} catch (e) {
			throw Exception('기피 성분 조회 중 오류가 발생했습니다: $e');
		}
	}

	Future<Map<String, dynamic>> savePreferences(
		String userId,
		List<String> avoidedIngredients,
		[List<Map<String, dynamic>>? groups]
	) async {
		try {
			final response = await _dio.post<Map<String, dynamic>>(
				'/api/preferences',
				data: {
					'user_id': userId,
					'avoided_ingredients': avoidedIngredients,
					'groups': groups ?? <Map<String, dynamic>>[],
				},
			);

			final data = response.data;
			if (data == null) {
				throw Exception('서버 응답이 비어 있습니다.');
			}

			return data;
		} on DioException catch (e) {
			_handleDioError(e);
		} catch (e) {
			throw Exception('기피 성분 저장 중 오류가 발생했습니다: $e');
		}
	}

	Never _handleDioError(DioException e) {
		final statusCode = e.response?.statusCode;
		final responseData = e.response?.data;

		if (statusCode != null) {
			throw Exception('API 오류 ($statusCode): $responseData');
		}

		switch (e.type) {
			case DioExceptionType.connectionTimeout:
			case DioExceptionType.sendTimeout:
			case DioExceptionType.receiveTimeout:
				throw Exception('요청 시간이 초과되었습니다. 네트워크 상태를 확인해 주세요.');
			case DioExceptionType.connectionError:
				throw Exception('서버에 연결할 수 없습니다. 백엔드 실행 상태를 확인해 주세요.');
			case DioExceptionType.cancel:
				throw Exception('요청이 취소되었습니다.');
			case DioExceptionType.badCertificate:
				throw Exception('인증서 오류가 발생했습니다.');
			case DioExceptionType.badResponse:
				throw Exception('서버 응답 처리 중 오류가 발생했습니다.');
			case DioExceptionType.unknown:
				throw Exception('알 수 없는 네트워크 오류가 발생했습니다: ${e.message}');
		}
	}
}
