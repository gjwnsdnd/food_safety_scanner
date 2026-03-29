class AvoidedIngredient {
  final String name;
  final String usage;
  final String characteristics;
  final String warningText;

  AvoidedIngredient({
    required this.name,
    required this.usage,
    required this.characteristics,
    required this.warningText,
  });

  factory AvoidedIngredient.fromJson(Map<String, dynamic> json) {
    return AvoidedIngredient(
      name: json['name'] as String,
      usage: json['usage'] as String,
      characteristics: json['characteristics'] as String,
      warningText: json['warningText'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'usage': usage,
      'characteristics': characteristics,
      'warningText': warningText,
    };
  }

  @override
  String toString() {
    return 'AvoidedIngredient(name: $name, usage: $usage, characteristics: $characteristics, warningText: $warningText)';
  }
}
