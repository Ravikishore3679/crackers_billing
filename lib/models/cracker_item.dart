class CrackerItem {
  const CrackerItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unitPrice,
    required this.stockAvailable,
    this.taxRate = 0.18,
  })  : assert(unitPrice >= 0, 'unitPrice must be non-negative'),
        assert(stockAvailable >= 0, 'stockAvailable must be non-negative'),
        assert(taxRate >= 0, 'taxRate must be non-negative');

  final String id;
  final String name;
  final String category;
  final double unitPrice;
  final int stockAvailable;
  final double taxRate;

  CrackerItem copyWith({
    String? id,
    String? name,
    String? category,
    double? unitPrice,
    int? stockAvailable,
    double? taxRate,
  }) {
    return CrackerItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      unitPrice: unitPrice ?? this.unitPrice,
      stockAvailable: stockAvailable ?? this.stockAvailable,
      taxRate: taxRate ?? this.taxRate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'unitPrice': unitPrice,
      'stockAvailable': stockAvailable,
      'taxRate': taxRate,
    };
  }

  factory CrackerItem.fromMap(Map<String, dynamic> map) {
    return CrackerItem(
      id: map['id'] as String,
      name: map['name'] as String,
      category: map['category'] as String,
      unitPrice: (map['unitPrice'] as num).toDouble(),
      stockAvailable: map['stockAvailable'] as int,
      taxRate: (map['taxRate'] as num?)?.toDouble() ?? 0.18,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is CrackerItem &&
        other.id == id &&
        other.name == name &&
        other.category == category &&
        other.unitPrice == unitPrice &&
        other.stockAvailable == stockAvailable &&
        other.taxRate == taxRate;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, category, unitPrice, stockAvailable, taxRate);
  }
}
