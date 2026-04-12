import 'package:flutter/material.dart';

class AnalysisResultScreen extends StatelessWidget {
  const AnalysisResultScreen({Key? key}) : super(key: key);

  Map<String, dynamic> _readArguments(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is Map) {
      return arguments.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  List<Map<String, dynamic>> _parseIngredients(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
        .toList(growable: false);
  }

  bool _isWarningIngredient(Map<String, dynamic> ingredient) {
    final dynamic explicitWarning =
        ingredient['is_warning'] ?? ingredient['warning'] ?? ingredient['matched'];
    if (explicitWarning is bool) {
      return explicitWarning;
    }

    final score = ingredient['score'];
    if (score is num) {
      return score >= 70;
    }

    return true;
  }

  String _formatIngredientLabel(Map<String, dynamic> ingredient) {
    final name = ingredient['name']?.toString().trim() ?? '';
    final engName = ingredient['eng_name']?.toString().trim() ?? '';
    final classification = ingredient['classification']?.toString().trim() ?? '';
    final score = ingredient['score'];

    final details = <String>[];
    if (engName.isNotEmpty) {
      details.add(engName);
    }
    if (classification.isNotEmpty) {
      details.add(classification);
    }
    if (score is num) {
      details.add('${score.toInt()}%');
    }

    if (details.isEmpty) {
      return name.isNotEmpty ? name : '알 수 없는 성분';
    }

    return '$name · ${details.join(' · ')}';
  }

  Widget _buildIngredientList({
    required List<Map<String, dynamic>> ingredients,
    required String emptyMessage,
    required Color emptyColor,
  }) {
    if (ingredients.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Text(
          emptyMessage,
          style: TextStyle(
            color: emptyColor,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: ingredients
            .map(
              (ingredient) => Chip(
                label: Text(
                  _formatIngredientLabel(ingredient),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: const Color(0xFFF2F5F8),
                side: const BorderSide(color: Color(0xFFDCE3EA)),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}. ${date.month}. ${date.day}.';
  }

  @override
  Widget build(BuildContext context) {
    final arguments = _readArguments(context);
    final ingredients = _parseIngredients(arguments['ingredients']);
    final warningIngredients = ingredients.where(_isWarningIngredient).toList(growable: false);
    final extractedText = arguments['extracted_text']?.toString().trim() ?? '';
    final fileName = arguments['file_name']?.toString().trim() ?? '';
    final totalIngredientCount = ingredients.length;
    final warningIngredientCount = warningIngredients.length;
    final now = DateTime.now();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '분석 결과',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                _formatDate(now),
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFEFF1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    fileName.isNotEmpty ? fileName : '제품명을 입력하세요',
                    style: TextStyle(
                      color: fileName.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                      fontSize: 16,
                      fontWeight: fileName.isNotEmpty ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: warningIngredientCount > 0 ? const Color(0xFFFDECEC) : const Color(0xFFE9F8EE),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: warningIngredientCount > 0 ? const Color(0xFFF4C7C3) : const Color(0xFFB8ECCA),
                          ),
                        ),
                        child: Text(
                          warningIngredientCount > 0 ? '• 경고 성분 $warningIngredientCount개' : '• 경고 성분 없음',
                          style: TextStyle(
                            color: warningIngredientCount > 0 ? const Color(0xFFB42318) : const Color(0xFF159947),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
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
                                  '$warningIngredientCount개',
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
                                  '$totalIngredientCount개',
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
              ),
              if (extractedText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Text(
                      extractedText,
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 22, 16, 10),
                child: Text(
                  '전체 성분',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const TabBar(
                    labelColor: Color(0xFF0F172A),
                    unselectedLabelColor: Color(0xFF94A3B8),
                    indicatorColor: Color(0xFF2563EB),
                    indicatorWeight: 3,
                    tabs: [
                      Tab(text: '경고 성분'),
                      Tab(text: '전체 성분'),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: SizedBox(
                  height: 220,
                  child: TabBarView(
                    children: [
                      _buildIngredientList(
                        ingredients: warningIngredients,
                        emptyMessage: '표시할 경고 성분이 없습니다.',
                        emptyColor: const Color(0xFF94A3B8),
                      ),
                      _buildIngredientList(
                        ingredients: ingredients,
                        emptyMessage: '표시할 성분이 없습니다.',
                        emptyColor: const Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
