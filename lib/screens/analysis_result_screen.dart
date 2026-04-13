import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/api_service.dart';

class AnalysisResultScreen extends StatefulWidget {
  const AnalysisResultScreen({Key? key}) : super(key: key);

  @override
  State<AnalysisResultScreen> createState() => _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends State<AnalysisResultScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _productNameController = TextEditingController();

  bool _didReadArguments = false;
  bool _isLoadingPreferences = true;

  List<Map<String, dynamic>> _ingredients = [];
  String _extractedText = '';
  String _fileName = '';
  Uint8List? _imageBytes;

  Set<String> _avoidedIngredients = <String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didReadArguments) {
      return;
    }
    _didReadArguments = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final map = args.map((key, value) => MapEntry(key.toString(), value));

      _ingredients = _parseIngredients(map['ingredients']);
      _extractedText = (map['extracted_text'] ?? '').toString().trim();
      _fileName = (map['file_name'] ?? '').toString().trim();
      _imageBytes = map['image_bytes'] is Uint8List ? map['image_bytes'] as Uint8List : null;
    }

    _loadPreferences();
  }

  @override
  void dispose() {
    _productNameController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    try {
      final response = await _apiService.getPreferences('default');
      final avoided = response['avoided_ingredients'];

      if (avoided is List) {
        _avoidedIngredients = avoided
            .map((item) => _normalizeIngredientName(item.toString()))
            .where((value) => value.isNotEmpty)
            .toSet();
      }
    } catch (_) {
      _avoidedIngredients = <String>{};
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingPreferences = false;
      });
    }
  }

  List<Map<String, dynamic>> _parseIngredients(dynamic raw) {
    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
        .toList(growable: false);
  }

  String _normalizeIngredientName(String value) {
    return value.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  }

  String _koreanOnlyName(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[A-Za-z]'), '')
        .replaceAll(RegExp(r'[^가-힣0-9\s()]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return cleaned.isNotEmpty ? cleaned : value.trim();
  }

  String _ingredientName(Map<String, dynamic> ingredient) {
    return (ingredient['name'] ?? '').toString().trim();
  }

  bool _isAvoidedIngredient(Map<String, dynamic> ingredient) {
    if (_avoidedIngredients.isEmpty) {
      return false;
    }

    final name = _normalizeIngredientName(_ingredientName(ingredient));
    if (name.isEmpty) {
      return false;
    }

    if (_avoidedIngredients.contains(name)) {
      return true;
    }

    for (final avoided in _avoidedIngredients) {
      if (avoided.isEmpty) {
        continue;
      }
      if (name.contains(avoided) || avoided.contains(name)) {
        return true;
      }
    }

    return false;
  }

  void _showIngredientDetailModal(Map<String, dynamic> ingredient) {
    final name = _koreanOnlyName(_ingredientName(ingredient));
    final description = (ingredient['description'] ?? '').toString().trim();
    var uses = (ingredient['uses'] ?? '').toString().trim();
    final caution = (ingredient['caution'] ?? '').toString().trim();
    
    // "다른 음식들" 섹션에 " 등" 추가 (이미 존재하면 중복 방지)
    if (uses.isNotEmpty && !uses.endsWith('등')) {
      uses = '$uses 등';
    }
    
    final cautionBanner = caution.isNotEmpty ? caution : '주의사항 정보가 없습니다.';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    name.isNotEmpty ? name : '성분 정보',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 특징
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '특징',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description.isNotEmpty ? description : '등록된 특징 정보가 없습니다.',
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 다른 음식들
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '다른 음식들',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          uses.isNotEmpty ? uses : '등록된 음식 정보가 없습니다.',
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 주의사항 배너 (노란색)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF8E8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF7D489)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '주의사항',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB45309),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          cautionBanner,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIngredientCard(Map<String, dynamic> ingredient) {
    final isAvoided = _isAvoidedIngredient(ingredient);
    final name = _koreanOnlyName(_ingredientName(ingredient));

    return InkWell(
      onTap: () => _showIngredientDetailModal(ingredient),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isAvoided ? const Color(0xFFFEE2E2) : const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isAvoided ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
            width: 1.4,
          ),
        ),
        child: Text(
          name.isNotEmpty ? name : '이름 없음',
          style: TextStyle(
            color: isAvoided ? const Color(0xFFB91C1C) : const Color(0xFF111827),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final warningCount = _ingredients.where(_isAvoidedIngredient).length;
    final totalCount = _ingredients.length;
    final hasAvoidedSetting = _avoidedIngredients.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FA),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '분석 결과',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _productNameController,
              decoration: InputDecoration(
                hintText: '제품명을 입력하세요',
                filled: true,
                fillColor: const Color(0xFFEFEFF1),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoadingPreferences)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        '기피 성분 정보를 불러오는 중...',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ),
                  if (hasAvoidedSetting)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: warningCount > 0 ? const Color(0xFFFEE2E2) : const Color(0xFFE9F8EE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: warningCount > 0 ? const Color(0xFFFCA5A5) : const Color(0xFFB8ECCA),
                        ),
                      ),
                      child: Text(
                        warningCount > 0 ? '경고 성분 ${warningCount}개 감지' : '경고 성분 없음',
                        style: TextStyle(
                          color: warningCount > 0 ? const Color(0xFFB91C1C) : const Color(0xFF159947),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '경고 성분',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${warningCount}개',
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 38,
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(
                        height: 72,
                        child: VerticalDivider(color: Color(0xFFE5E7EB), thickness: 1),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '전체 성분',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${totalCount}개',
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 38,
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '전체 성분',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (_ingredients.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Text(
                  _extractedText.isNotEmpty
                      ? '성분 매칭 결과가 없습니다.\n\nOCR 텍스트:\n$_extractedText'
                      : '표시할 성분이 없습니다.',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _ingredients.map(_buildIngredientCard).toList(growable: false),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
