class FinancialAssistance {
  const FinancialAssistance({
    required this.providerName,
    required this.amount,
    required this.distance,
    required this.category,
  });

  final String providerName;
  final String amount;
  final String distance;
  final String category;

  factory FinancialAssistance.fromJson(Map<String, dynamic> json) {
    return FinancialAssistance(
      providerName: json['provider_name'] as String,
      amount: json['amount'] as String,
      distance: json['distance'] as String,
      category: json['category'] as String,
    );
  }
}
