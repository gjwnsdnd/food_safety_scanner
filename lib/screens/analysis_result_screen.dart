import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/analysis_history.dart';
import '../services/api_service.dart';
import '../services/history_service.dart';

class AnalysisResultScreen extends StatefulWidget {
  const AnalysisResultScreen({Key? key}) : super(key: key);

  @override
  State<AnalysisResultScreen> createState() => _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends State<AnalysisResultScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _productNameController = TextEditingController();

  bool _didReadArguments = false;
  bool _historySaved = false;
  bool _isHistoryView = false;
  bool _isLoadingPreferences = true;
  String _historyId = '';
  String _originalProductName = '';

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
      _isHistoryView = map['is_history_view'] == true;
      _historyId = (map['history_id'] ?? '').toString().trim();

      final productNameFromArgs = (map['product_name'] ?? '').toString().trim();
      if (productNameFromArgs.isNotEmpty) {
        _productNameController.text = productNameFromArgs;
        _originalProductName = productNameFromArgs;
      }

      final avoidedFromArgs = map['user_avoid_ingredients'];
      if (avoidedFromArgs is List) {
        _avoidedIngredients = avoidedFromArgs
            .map((item) => _normalizeIngredientName(item.toString()))
            .where((value) => value.isNotEmpty)
            .toSet();
        _isLoadingPreferences = false;
      }
    }

    if (_isLoadingPreferences) {
      _loadPreferences();
    }

    if (_isHistoryView) {
      _loadHistoryIngredientDetails();
    }
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

  Future<void> _loadHistoryIngredientDetails() async {
    if (!_isHistoryView || _ingredients.isEmpty) {
      return;
    }

    try {
      final enrichedIngredients = <Map<String, dynamic>>[];

      for (final ingredient in _ingredients) {
        final name = _ingredientName(ingredient);
        Map<String, dynamic>? detail;

        if (name.isNotEmpty) {
          detail = await _apiService.getIngredientDetail(name);
        }

        if (detail == null) {
          enrichedIngredients.add(ingredient);
          continue;
        }

        enrichedIngredients.add({
          ...ingredient,
          'description': (ingredient['description'] ?? detail['description'] ?? '').toString(),
          'caution': (ingredient['caution'] ?? detail['caution'] ?? '').toString(),
          'uses': (ingredient['uses'] ?? detail['uses'] ?? detail['useCondition'] ?? detail['use_condition'] ?? '').toString(),
          'engName': (ingredient['engName'] ?? detail['eng_name'] ?? detail['engName'] ?? '').toString(),
          'eng_name': (ingredient['eng_name'] ?? detail['eng_name'] ?? detail['engName'] ?? '').toString(),
          'classification': (ingredient['classification'] ?? detail['classification'] ?? '').toString(),
        });
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _ingredients = enrichedIngredients;
      });
    } catch (_) {
      // 히스토리 상세 보강 실패 시 저장된 데이터만 사용
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

  String _pickFirstNonEmpty(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = (source[key] ?? '').toString().trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  HistoryIngredient _toHistoryIngredient(Map<String, dynamic> ingredient) {
    return HistoryIngredient(
      name: _ingredientName(ingredient),
      caution: _pickFirstNonEmpty(ingredient, ['caution', 'warning', 'injuryYn', 'useCondition']),
      description: _pickFirstNonEmpty(ingredient, ['description']),
      engName: _pickFirstNonEmpty(ingredient, ['eng_name', 'engName']),
      classification: _pickFirstNonEmpty(ingredient, ['classification', 'class', 'injuryYn']),
      uses: _pickFirstNonEmpty(ingredient, ['uses', 'useCondition', 'use_condition']),
    );
  }

  Future<List<String>> _loadAvoidedIngredientNamesForHistory() async {
    try {
      final response = await _apiService.getPreferences('default');
      final avoided = response['avoided_ingredients'];
      if (avoided is List) {
        return avoided.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList();
      }
    } catch (_) {
      // 저장 실패를 막지 않기 위해 기피 성분 조회 실패는 무시
    }
    return <String>[];
  }

  Future<void> _saveAnalysisToHistory() async {
    if (_historySaved) {
      return;
    }

    if (_ingredients.isEmpty) {
      _historySaved = true;
      return;
    }

    final historyIngredients = <HistoryIngredient>[];
    for (final ingredient in _ingredients) {
      final name = _ingredientName(ingredient);
      Map<String, dynamic> mergedIngredient = ingredient;

      if (name.isNotEmpty) {
        try {
          final detail = await _apiService.getIngredientDetail(name);
          if (detail != null) {
            mergedIngredient = {
              ...ingredient,
              ...detail,
            };
          }
        } catch (_) {
          // 저장 시 상세 조회가 실패해도 기본 데이터는 유지
        }
      }

      final historyIngredient = _toHistoryIngredient(mergedIngredient);
      if (historyIngredient.name.trim().isNotEmpty) {
        historyIngredients.add(historyIngredient);
      }
    }

    if (historyIngredients.isEmpty) {
      _historySaved = true;
      return;
    }

    try {
      final avoidIngredients = await _loadAvoidedIngredientNamesForHistory();

      await HistoryService.saveAnalysis(
        productName: _productNameController.text,
        ingredients: historyIngredients,
        userAvoidIngredients: avoidIngredients,
      );
      _historySaved = true;
    } catch (_) {
      // 자동 저장 실패 시 화면 동작은 유지
    }
  }

  Future<void> _saveAndStay() async {
    final wasSaved = _historySaved;
    if (_isHistoryView && _historyId.isNotEmpty) {
      try {
        await HistoryService.updateHistory(
          historyId: _historyId,
          productName: _productNameController.text,
        );
        _historySaved = true;
      } catch (_) {
        // 변경 저장 실패 시 기존 UI 유지
      }
    } else {
      await _saveAnalysisToHistory();
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(wasSaved ? '이미 저장된 분석 결과입니다.' : '분석결과가 저장되었습니다.')),
    );
  }

  Future<void> _handleBackPressed() async {
    if (_isHistoryView && _historyId.isNotEmpty) {
      final currentName = _productNameController.text.trim();
      final originalName = _originalProductName.trim();
      if (currentName != originalName) {
        try {
          await HistoryService.updateHistory(
            historyId: _historyId,
            productName: currentName,
          );
        } catch (_) {
          // 뒤로가기 저장 실패 시에도 화면 복귀는 허용
        }
      }
      if (!mounted) {
        return;
      }
      Navigator.pop(context);
      return;
    }

    Navigator.of(context).popUntil((route) => route.isFirst);
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBackPressed,
        ),
        titleSpacing: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '분석 결과',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 2),
            Text(
              '제품의 성분을 확인하세요',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
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
            if (!_isHistoryView) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEBF3FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD0E2FF)),
                ),
                child: const Text(
                  '결과 가이드\n• 제품명을 입력해 저장하세요\n• 성분을 눌러 상세정보를 확인하세요',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: Color(0xFF1D4ED8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _saveAndStay,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '분석결과 저장하기',
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
