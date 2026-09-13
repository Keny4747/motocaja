import 'dart:convert';

enum MovementType { income, expense }

class Movement {
  final String id;
  final MovementType type;
  final double amount;
  final String category;
  final String paymentMethod;
  final DateTime date;

  const Movement({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.paymentMethod,
    required this.date,
  });

  Movement copyWith({
    String? id,
    MovementType? type,
    double? amount,
    String? category,
    String? paymentMethod,
    DateTime? date,
  }) {
    return Movement(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      date: date ?? this.date,
    );
  }

  // ============================================================
  // JSON / SharedPreferences
  // ============================================================

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'amount': amount,
      'category': category,
      'paymentMethod': paymentMethod,
      'date': date.toIso8601String(),
    };
  }

  factory Movement.fromMap(Map<String, dynamic> map) {
    return Movement(
      id: map['id'].toString(),
      type: MovementType.values.firstWhere(
        (e) => e.name == map['type'].toString(),
      ),
      amount: (map['amount'] as num).toDouble(),
      category: map['category'].toString(),

      // Compatibilidad con ambas versiones.
      paymentMethod: (map['paymentMethod'] ?? map['payment_method']).toString(),

      date: DateTime.parse(map['date'].toString()),
    );
  }

  String toJson() {
    return jsonEncode(toMap());
  }

  factory Movement.fromJson(String source) {
    return Movement.fromMap(jsonDecode(source) as Map<String, dynamic>);
  }

  // ============================================================
  // SQLite
  // ============================================================

  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'type': type.name,
      'amount': amount,
      'category': category,
      'payment_method': paymentMethod,
      'date': date.toIso8601String(),
    };
  }

  factory Movement.fromDatabaseMap(Map<String, dynamic> map) {
    return Movement(
      id: map['id'].toString(),
      type: MovementType.values.firstWhere(
        (e) => e.name == map['type'].toString(),
      ),
      amount: (map['amount'] as num).toDouble(),
      category: map['category'].toString(),
      paymentMethod: map['payment_method'].toString(),
      date: DateTime.parse(map['date'].toString()),
    );
  }
}
