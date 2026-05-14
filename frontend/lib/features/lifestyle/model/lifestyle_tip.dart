/// A single actionable lifestyle recommendation.
class LifestyleTip {
  const LifestyleTip({
    required this.id,
    required this.category,
    required this.actionableAdvice,
  });

  final String id;

  /// One of: 'Exercise', 'Sleep', 'Stress', 'Hydration', 'Nutrition'
  final String category;
  final String actionableAdvice;

  factory LifestyleTip.fromJson(Map<String, dynamic> json) {
    return LifestyleTip(
      id: json['id'] as String,
      category: json['category'] as String,
      actionableAdvice: json['actionable_advice'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'actionable_advice': actionableAdvice,
  };
}
