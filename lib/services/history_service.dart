import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/analysis_history.dart';

class HistoryService {
  HistoryService._();

  static const String boxName = 'analysis_history';
  static const Uuid _uuid = Uuid();

  static Box<AnalysisHistory> get _box => Hive.box<AnalysisHistory>(boxName);

  static Future<AnalysisHistory> saveAnalysis({
    String? historyId,
    required String productName,
    required List<HistoryIngredient> ingredients,
    required List<String> userAvoidIngredients,
    DateTime? analyzedDate,
  }) async {
    final history = AnalysisHistory(
      id: historyId ?? _uuid.v4(),
      productName: productName.trim().isEmpty ? '제품명 미입력' : productName.trim(),
      analyzedDate: analyzedDate ?? DateTime.now(),
      ingredients: ingredients,
      userAvoidIngredients: userAvoidIngredients,
    );

    await _box.put(history.id, history);
    return history;
  }

  static Future<AnalysisHistory?> updateHistory({
    required String historyId,
    required String productName,
  }) async {
    final existing = _box.get(historyId);
    if (existing == null) {
      return null;
    }

    final updated = AnalysisHistory(
      id: existing.id,
      productName: productName.trim().isEmpty ? '제품명 미입력' : productName.trim(),
      analyzedDate: existing.analyzedDate,
      ingredients: existing.ingredients,
      userAvoidIngredients: existing.userAvoidIngredients,
    );

    await _box.put(updated.id, updated);
    return updated;
  }

  static List<AnalysisHistory> getAllHistory() {
    final all = _box.values.toList(growable: false);
    all.sort((a, b) => b.analyzedDate.compareTo(a.analyzedDate));
    return all;
  }

  static AnalysisHistory? getHistory(String id) {
    return _box.get(id);
  }

  static Future<void> deleteHistory(String id) async {
    await _box.delete(id);
  }

  static Future<void> clearAllHistory() async {
    await _box.clear();
  }

  static int get historyCount => _box.length;
}
