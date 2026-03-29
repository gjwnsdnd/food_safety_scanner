import 'ingredient.dart';

class AnalysisHistory {
  final String id;
  final String productName;
  final DateTime analysisDate;
  final List<Ingredient> analyzedIngredients;
  final int warningCount;
  final int totalIngredientCount;

  AnalysisHistory({
    required this.id,
    required this.productName,
    required this.analysisDate,
    required this.analyzedIngredients,
    required this.warningCount,
    required this.totalIngredientCount,
  });

  factory AnalysisHistory.fromJson(Map<String, dynamic> json) {
    return AnalysisHistory(
      id: json['id'] as String,
      productName: json['productName'] as String,
      analysisDate: DateTime.parse(json['analysisDate'] as String),
      analyzedIngredients: (json['analyzedIngredients'] as List)
          .map((item) => Ingredient.fromJson(item as Map<String, dynamic>))
          .toList(),
      warningCount: json['warningCount'] as int,
      totalIngredientCount: json['totalIngredientCount'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productName': productName,
      'analysisDate': analysisDate.toIso8601String(),
      'analyzedIngredients': analyzedIngredients.map((item) => item.toJson()).toList(),
      'warningCount': warningCount,
      'totalIngredientCount': totalIngredientCount,
    };
  }

  @override
  String toString() {
    return 'AnalysisHistory(id: $id, productName: $productName, analysisDate: $analysisDate, warningCount: $warningCount, totalIngredientCount: $totalIngredientCount)';
  }
}
