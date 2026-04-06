class PreferencesGroup {
  final String groupName;
  final List<String> ingredients;

  PreferencesGroup({
    required this.groupName,
    required this.ingredients,
  });

  factory PreferencesGroup.fromJson(Map<String, dynamic> json) {
    final dynamic rawIngredients = json['ingredients'] ?? [];

    return PreferencesGroup(
      groupName: json['group_name'] ?? '',
      ingredients: List<String>.from(rawIngredients as List),
    );
  }

  Map<String, dynamic> toJson() => {
    'group_name': groupName,
    'ingredients': ingredients,
  };
}

class PreferencesData {
  final List<String> avoidedIngredients;
  final List<PreferencesGroup> groups;

  PreferencesData({
    required this.avoidedIngredients,
    required this.groups,
  });

  factory PreferencesData.fromJson(Map<String, dynamic> json) {
    return PreferencesData(
      avoidedIngredients: List<String>.from(json['avoided_ingredients'] ?? []),
      groups: (json['groups'] as List?)
          ?.map((e) => PreferencesGroup.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'avoided_ingredients': avoidedIngredients,
    'groups': groups.map((g) => g.toJson()).toList(),
  };
}
