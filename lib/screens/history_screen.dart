import 'package:flutter/material.dart';

import '../models/analysis_history.dart';
import '../services/history_service.dart';
import '../widgets/history_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<AnalysisHistory> _historyItems = <AnalysisHistory>[];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    if (!mounted) {
      return;
    }
    setState(() {
      _historyItems = HistoryService.getAllHistory();
    });
  }

  List<AnalysisHistory> get _filteredHistory {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return _historyItems;
    }
    return _historyItems.where((item) => item.productName.toLowerCase().contains(query)).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '분석 히스토리',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              '총 ${_historyItems.length}개의 분석 기록',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFEFEFF1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: const InputDecoration(
                  hintText: '제품명으로 검색...',
                  prefixIcon: Icon(Icons.search, color: Color(0xFF94A3B8)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Expanded(
            child: _filteredHistory.isEmpty
                ? const Center(
                    child: Text(
                      '기록이 없습니다',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: _filteredHistory.length,
                    itemBuilder: (context, index) {
                      final history = _filteredHistory[index];
                      return HistoryCard(
                        history: history,
                        onDeleted: _loadHistory,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
