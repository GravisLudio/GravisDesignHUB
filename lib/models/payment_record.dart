class PaymentRecord {
  final String id;
  final double amount;
  final String type; // 'abono' or 'completo'
  final DateTime createdAt;

  PaymentRecord({
    required this.id,
    required this.amount,
    required this.type,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'type': type,
    'createdAt': createdAt.toIso8601String(),
  };

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      id: json['id'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      type: json['type'] ?? 'abono',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}
