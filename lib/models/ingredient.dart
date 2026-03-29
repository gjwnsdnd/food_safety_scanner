class Ingredient {
  final String name;
  final String engName;
  final String injuryYn;
  final String useCondition;
  final bool isAvoidedIngredient;

  Ingredient({
    required this.name,
    required this.engName,
    required this.injuryYn,
    required this.useCondition,
    this.isAvoidedIngredient = false,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      name: json['name'] as String,
      engName: json['engName'] as String,
      injuryYn: json['injuryYn'] as String,
      useCondition: json['useCondition'] as String,
      isAvoidedIngredient: json['isAvoidedIngredient'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'engName': engName,
      'injuryYn': injuryYn,
      'useCondition': useCondition,
      'isAvoidedIngredient': isAvoidedIngredient,
    };
  }

  @override
  String toString() {
    return 'Ingredient(name: $name, engName: $engName, injuryYn: $injuryYn, useCondition: $useCondition, isAvoidedIngredient: $isAvoidedIngredient)';
  }
}
