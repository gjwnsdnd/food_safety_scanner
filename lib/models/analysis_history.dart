import 'package:hive/hive.dart';

@HiveType(typeId: 0)
class AnalysisHistory extends HiveObject {
  AnalysisHistory({
    required this.id,
    required this.productName,
    required this.analyzedDate,
    required this.ingredients,
    required this.userAvoidIngredients,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String productName;

  @HiveField(2)
  DateTime analyzedDate;

  @HiveField(3)
  List<HistoryIngredient> ingredients;

  @HiveField(4)
  List<String> userAvoidIngredients;

  int get ingredientCount => ingredients.length;

  int get avoidCount {
    if (userAvoidIngredients.isEmpty || ingredients.isEmpty) {
      return 0;
    }

    final avoidSet = userAvoidIngredients
        .map((item) => item.replaceAll(RegExp(r'\s+'), '').toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet();

    if (avoidSet.isEmpty) {
      return 0;
    }

    var count = 0;
    for (final ingredient in ingredients) {
      final normalizedName = ingredient.name.replaceAll(RegExp(r'\s+'), '').toLowerCase();
      if (normalizedName.isEmpty) {
        continue;
      }
      if (avoidSet.contains(normalizedName)) {
        count += 1;
      }
    }
    return count;
  }
}

@HiveType(typeId: 1)
class HistoryIngredient {
  HistoryIngredient({
    required this.name,
    required this.caution,
    required this.description,
    required this.engName,
    required this.classification,
  });

  @HiveField(0)
  String name;

  @HiveField(1)
  String caution;

  @HiveField(2)
  String description;

  @HiveField(3)
  String engName;

  @HiveField(4)
  String classification;
}

class AnalysisHistoryAdapter extends TypeAdapter<AnalysisHistory> {
  @override
  final int typeId = 0;

  @override
  AnalysisHistory read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < fieldCount; i += 1) {
      fields[reader.readByte()] = reader.read();
    }

    return AnalysisHistory(
      id: fields[0] as String? ?? '',
      productName: fields[1] as String? ?? '제품명 미입력',
      analyzedDate: fields[2] as DateTime? ?? DateTime.now(),
      ingredients: (fields[3] as List?)?.cast<HistoryIngredient>() ?? <HistoryIngredient>[],
      userAvoidIngredients: (fields[4] as List?)?.map((item) => item.toString()).toList() ?? <String>[],
    );
  }

  @override
  void write(BinaryWriter writer, AnalysisHistory obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.productName)
      ..writeByte(2)
      ..write(obj.analyzedDate)
      ..writeByte(3)
      ..write(obj.ingredients)
      ..writeByte(4)
      ..write(obj.userAvoidIngredients);
  }
}

class HistoryIngredientAdapter extends TypeAdapter<HistoryIngredient> {
  @override
  final int typeId = 1;

  @override
  HistoryIngredient read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < fieldCount; i += 1) {
      fields[reader.readByte()] = reader.read();
    }

    return HistoryIngredient(
      name: fields[0] as String? ?? '',
      caution: fields[1] as String? ?? '',
      description: fields[2] as String? ?? '',
      engName: fields[3] as String? ?? '',
      classification: fields[4] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, HistoryIngredient obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.caution)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.engName)
      ..writeByte(4)
      ..write(obj.classification);
  }
}
