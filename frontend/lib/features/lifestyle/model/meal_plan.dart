/// Macronutrient breakdown for a meal plan.
class Macronutrients {
  const Macronutrients({
    required this.carbsGrams,
    required this.proteinGrams,
    required this.fatGrams,
    required this.caloriesKcal,
  });

  final int carbsGrams;
  final int proteinGrams;
  final int fatGrams;
  final int caloriesKcal;

  // Calorie fractions for proportional bar visualization.
  // Carbs: 4 kcal/g, Protein: 4 kcal/g, Fat: 9 kcal/g
  double get carbFraction => (carbsGrams * 4) / _totalMacroKcal;
  double get proteinFraction => (proteinGrams * 4) / _totalMacroKcal;
  double get fatFraction => (fatGrams * 9) / _totalMacroKcal;

  double get _totalMacroKcal =>
      (carbsGrams * 4 + proteinGrams * 4 + fatGrams * 9).toDouble();

  factory Macronutrients.fromJson(Map<String, dynamic> json) {
    return Macronutrients(
      carbsGrams: (json['carbs_grams'] as num).toInt(),
      proteinGrams: (json['protein_grams'] as num).toInt(),
      fatGrams: (json['fat_grams'] as num).toInt(),
      caloriesKcal: (json['calories_kcal'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'carbs_grams': carbsGrams,
    'protein_grams': proteinGrams,
    'fat_grams': fatGrams,
    'calories_kcal': caloriesKcal,
  };
}

/// A single recipe suggestion within a meal plan.
class Recipe {
  const Recipe({
    required this.name,
    required this.description,
    required this.ingredients,
    required this.prepTime,
  });

  final String name;
  final String description;
  final List<String> ingredients;
  final String prepTime;

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      name: json['name'] as String,
      description: json['description'] as String,
      ingredients: (json['ingredients'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      prepTime: json['prep_time'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'ingredients': ingredients,
    'prep_time': prepTime,
  };
}

/// A complete meal plan tailored to a target health condition.
class MealPlan {
  const MealPlan({
    required this.id,
    required this.targetCondition,
    required this.name,
    required this.macronutrients,
    required this.recipes,
  });

  final String id;
  final String targetCondition;
  final String name;
  final Macronutrients macronutrients;
  final List<Recipe> recipes;

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    return MealPlan(
      id: json['id'] as String,
      targetCondition: json['target_condition'] as String,
      name: json['name'] as String,
      macronutrients: Macronutrients.fromJson(
        json['macronutrients'] as Map<String, dynamic>,
      ),
      recipes: (json['recipes'] as List<dynamic>)
          .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'target_condition': targetCondition,
    'name': name,
    'macronutrients': macronutrients.toJson(),
    'recipes': recipes.map((r) => r.toJson()).toList(),
  };
}
