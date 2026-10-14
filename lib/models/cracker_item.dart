class CrackerItem {
  const CrackerItem({
    required this.id,
    required this.name,
    required this.category,
    this.subCategory = '',
    required this.unitPrice,
    required this.stockAvailable,
    this.taxRate = 0.18,
    this.itemCode,
  })  : assert(unitPrice >= 0, 'unitPrice must be non-negative'),
        assert(stockAvailable >= 0, 'stockAvailable must be non-negative'),
        assert(taxRate >= 0, 'taxRate must be non-negative');

  final String id;
  final String name;
  final String category;
  final String subCategory;
  final String? itemCode;
  final double unitPrice;
  final int stockAvailable;
  final double taxRate;

  CrackerItem copyWith({
    String? id,
    String? name,
    String? category,
    String? subCategory,
    double? unitPrice,
    int? stockAvailable,
    double? taxRate,
    String? itemCode,
  }) {
    return CrackerItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      unitPrice: unitPrice ?? this.unitPrice,
      stockAvailable: stockAvailable ?? this.stockAvailable,
      taxRate: taxRate ?? this.taxRate,
      itemCode: itemCode ?? this.itemCode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'subCategory': subCategory,
      'itemCode': itemCode,
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
      subCategory: map['subCategory'] as String? ?? '',
      itemCode: map['itemCode'] as String?,
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
        other.subCategory == subCategory &&
        other.itemCode == itemCode &&
        other.unitPrice == unitPrice &&
        other.stockAvailable == stockAvailable &&
        other.taxRate == taxRate;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      category,
      subCategory,
      itemCode,
      unitPrice,
      stockAvailable,
      taxRate,
    );
  }
}
