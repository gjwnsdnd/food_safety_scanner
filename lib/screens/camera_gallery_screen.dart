import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';

import 'analysis_result_screen.dart';
import '../services/api_service.dart';

class CameraGalleryScreen extends StatefulWidget {
  const CameraGalleryScreen({Key? key}) : super(key: key);

  @override
  State<CameraGalleryScreen> createState() => _CameraGalleryScreenState();
}

class _CameraGalleryScreenState extends State<CameraGalleryScreen> {
  final Logger logger = Logger();
  final ImagePicker _picker = ImagePicker();
  final ApiService _apiService = ApiService();
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isAnalyzing = false;

  Future<void> _selectAndAnalyze(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 95,
      );

      if (image == null) {
        logger.d('갤러리 선택이 취소되었습니다.');
        return;
      }

      logger.d('갤러리 선택 성공: ${image.path}');
      final bytes = await image.readAsBytes();

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedImage = image;
        _selectedImageBytes = bytes;
      });

      await _startAnalysis();
    } catch (e) {
      logger.d('갤러리 선택 에러: $e');
      if (!mounted) {
        return;
      }
      final message = source == ImageSource.camera
          ? '카메라에서 이미지를 불러오지 못했습니다.'
          : '갤러리에서 이미지를 불러오지 못했습니다.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    await _selectAndAnalyze(ImageSource.gallery);
  }

  Future<void> _pickFromCamera() async {
    await _selectAndAnalyze(ImageSource.camera);
  }

  Future<void> _startAnalysis() async {
    if (_selectedImage == null || _isAnalyzing) {
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final result = await _apiService.scanImageWithOcr(_selectedImage!.path);
      if (!mounted) {
        return;
      }

      final ingredients = (result['ingredients'] as List?) ?? const [];
      final extractedText = (result['extracted_text'] ?? '').toString();

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AnalysisResultScreen(),
          settings: RouteSettings(
            arguments: {
              'ingredients': ingredients,
              'extracted_text': extractedText,
              'file_name': _selectedImage?.name ?? '',
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OCR 실행 실패: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSelectedImage = _selectedImage != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FA),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '성분표 분석',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 2),
            Text(
              '성분표를 촬영하거나 선택하세요',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFCBD5E1),
                  width: 1.5,
                ),
              ),
              child: hasSelectedImage
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: _selectedImageBytes == null
                                ? Container(
                                    color: const Color(0xFFE5E7EB),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      '이미지를 표시할 수 없습니다',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                : Image.memory(
                                    _selectedImageBytes!,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: FilledButton.tonal(
                            onPressed: _pickFromGallery,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xDD0B1730),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            child: const Text('다시 선택'),
                          ),
                        ),
                      ],
                    )
                  : const Column(
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: Color(0xFFE5E7EB),
                          child: Icon(
                            Icons.photo_camera_outlined,
                            size: 34,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                        SizedBox(height: 22),
                        Text(
                          '성분표를 촬영하세요',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          '제품 뒷면의 원재료명 또는 성분표를\n선명하게 촬영해 주세요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.45,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
            ),
            if (hasSelectedImage) ...[
              const SizedBox(height: 10),
              Text(
                _selectedImage!.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: const Color(0xFFEBF3FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD0E2FF)),
              ),
              child: const Text(
                '촬영 가이드\n• 빛 반사가 없는 곳에서 촬영하세요\n• 성분표가 화면 가운데 오도록 정렬하세요\n• 초점이 맞고 흔들리지 않게 촬영하세요',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: Color(0xFF1D4ED8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: _isAnalyzing ? null : _pickFromCamera,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00A63E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.photo_camera, size: 20),
                label: const Text(
                  '카메라로 촬영하기',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 56,
              child: OutlinedButton.icon(
                onPressed: _isAnalyzing ? null : _pickFromGallery,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF111827),
                  side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.photo_library_outlined, size: 20),
                label: const Text(
                  '갤러리에서 선택하기',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            if (hasSelectedImage) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _isAnalyzing ? null : _startAnalysis,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isAnalyzing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          '분석 시작하기',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
