import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/analysis_history.dart';

class HistoryService {
  HistoryService._();

  static const String boxName = 'analysis_history';
  static const Uuid _uuid = Uuid();

  static Box<AnalysisHistory> get _box => Hive.box<AnalysisHistory>(boxName);

  static Future<AnalysisHistory> saveAnalysis({
    required String productName,
    required List<HistoryIngredient> ingredients,
    required List<String> userAvoidIngredients,
  }) async {
    final history = AnalysisHistory(
      id: _uuid.v4(),
      productName: productName.trim().isEmpty ? '제품명 미입력' : productName.trim(),
      analyzedDate: DateTime.now(),
      ingredients: ingredients,
      userAvoidIngredients: userAvoidIngredients,
    );

    await _box.put(history.id, history);
    return history;
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
