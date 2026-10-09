class WorkRecord {
  final String id;
  final String patternId;
  final String patternName;
  final double price;
  final DateTime createdAt;
  final String status; // 'hecho' or 'entregado'
  final int quantity; // New field for quantity

  WorkRecord({
    required this.id,
    required this.patternId,
    required this.patternName,
    required this.price,
    required this.createdAt,
    this.status = 'hecho',
    this.quantity = 1,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'patternId': patternId,
    'patternName': patternName,
    'price': price,
    'createdAt': createdAt.toIso8601String(),
    'status': status,
    'quantity': quantity,
  };

  factory WorkRecord.fromJson(Map<String, dynamic> json) {
    return WorkRecord(
      id: json['id'] ?? '',
      patternId: json['patternId'] ?? '',
      patternName: json['patternName'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      status: json['status'] ?? 'entregado',
      quantity: json['quantity'] as int? ?? 1,
    );
  }
}

