import 'package:firebase_auth/firebase_auth.dart';

import 'firestore_service.dart';

class InventoryCategory {
  InventoryCategory({
    required this.name,
    required this.categoryIndex,
  }) : code = InventoryCodeGenerator.generateCategoryCode(categoryIndex);

  final String name;
  final int categoryIndex;
  final String code;
}

class InventorySubCategory {
  InventorySubCategory({
    required this.name,
    required this.categoryIndex,
    required this.subCategoryIndex,
  }) : code = InventoryCodeGenerator.generateSubcategoryCode(
          categoryIndex,
          subCategoryIndex,
        );

  final String name;
  final int categoryIndex;
  final int subCategoryIndex;
  final String code;
}

class InventoryCatalogManager {
  static const List<String> defaultSubcategories = ['Standard', 'Others'];

  static final Map<String, List<String>> _catalog = {
    'Sparklers': [...defaultSubcategories],
    'Rockets': [...defaultSubcategories],
    'Flower Pots': [...defaultSubcategories],
    'Ground Crackers': [...defaultSubcategories],
    'Specials': [...defaultSubcategories],
  };

  static List<String> get categories => _catalog.keys.toList();

  static Future<void> loadFromFirestore() async {
    try {
      final catalog = await FirestoreService.instance.fetchCategoryCatalog(
        userId: FirebaseAuth.instance.currentUser?.uid,
      );
      if (catalog.isNotEmpty) {
        _catalog
          ..clear()
          ..addAll(catalog.map((key, value) => MapEntry(key, value)));
      }
    } catch (_) {
      // Keep existing defaults when Firestore is not available.
    }
  }

  static Future<void> persistToFirestore() async {
    try {
      await FirestoreService.instance.saveCategoryCatalog(
        Map<String, List<String>>.from(
          _catalog.map((key, value) => MapEntry(key, List<String>.from(value))),
        ),
        userId: FirebaseAuth.instance.currentUser?.uid,
      );
    } catch (_) {
      // Keep the app working even when persistence isn't available.
    }
  }

  static List<String> subcategoriesFor(String category) {
    final key = _normalize(category);
    if (key.isEmpty) return const [];
    return [...(_catalog[key] ?? const <String>[])] ;
  }

  static void addCategory(String category) {
    final normalized = _normalize(category);
    if (normalized.isEmpty) return;
    _catalog.putIfAbsent(normalized, () => [...defaultSubcategories]);
    Future.microtask(persistToFirestore);
  }

  static bool removeCategory(String category) {
    final normalized = _normalize(category);
    if (normalized.isEmpty) return false;

    final removed = _catalog.remove(normalized) != null;
    if (removed) {
      Future.microtask(persistToFirestore);
    }
    return removed;
  }

  static void addSubcategory(String category, String subCategory) {
    final categoryKey = _normalize(category);
    final subCategoryKey = _normalize(subCategory);
    if (categoryKey.isEmpty || subCategoryKey.isEmpty) return;

    final values = _catalog.putIfAbsent(categoryKey, () => <String>[]);
    if (!values.any((item) => _normalize(item) == subCategoryKey)) {
      values.add(subCategoryKey);
    }
    Future.microtask(persistToFirestore);
  }

  static bool removeSubcategory(String category, String subCategory) {
    final categoryKey = _normalize(category);
    final subCategoryKey = _normalize(subCategory);
    if (categoryKey.isEmpty || subCategoryKey.isEmpty) return false;

    final values = _catalog[categoryKey];
    if (values == null) return false;

    final removed = values.remove(subCategoryKey) != false;
    if (removed) {
      Future.microtask(persistToFirestore);
    }
    return removed;
  }

  static String _normalize(String value) => value.trim();
}

class InventoryCodeGenerator {
  static const Map<String, int> _categoryCodes = {
    'sparklers': 1,
    'rockets': 2,
    'flower pots': 3,
    'ground crackers': 4,
    'specials': 5,
  };

  static const Map<String, int> _subcategoryCodes = {
    'standard company': 1,
    'other companies': 2,
    'premium': 3,
    'local': 4,
  };

  static const Map<String, int> _variantCodes = {
    '15cm': 1,
    '15 cm': 1,
    '30cm': 2,
    '30 cm': 2,
    '45cm': 3,
    '45 cm': 3,
    'electric': 4,
    'crackling': 5,
    'ground': 6,
    'mini': 7,
    'large': 8,
    'special': 9,
  };

  static String generateCategoryCode(int categoryIndex) {
    _validateIndex('categoryIndex', categoryIndex, 1, 9);
    return '$categoryIndex' 'XXX';
  }

  static String generateSubcategoryCode(int categoryIndex, int subCategoryIndex) {
    _validateIndex('categoryIndex', categoryIndex, 1, 9);
    _validateIndex('subCategoryIndex', subCategoryIndex, 1, 9);
    return '$categoryIndex' '$subCategoryIndex' 'XX';
  }

  static String generateVariantCode(int categoryIndex, int subCategoryIndex, int variantIndex) {
    _validateIndex('categoryIndex', categoryIndex, 1, 9);
    _validateIndex('subCategoryIndex', subCategoryIndex, 1, 9);
    _validateIndex('variantIndex', variantIndex, 1, 9);
    return '$categoryIndex' '$subCategoryIndex' '$variantIndex' 'X';
  }

  static String generateItemCode(
    int categoryIndex,
    int subCategoryIndex,
    int variantIndex,
    int itemSequence,
  ) {
    _validateIndex('categoryIndex', categoryIndex, 1, 9);
    _validateIndex('subCategoryIndex', subCategoryIndex, 1, 9);
    _validateIndex('variantIndex', variantIndex, 1, 9);
    _validateIndex('itemSequence', itemSequence, 0, 9);
    return '$categoryIndex' '$subCategoryIndex' '$variantIndex' '$itemSequence';
  }

  static String generateAutoCode({
    required String category,
    required String subCategory,
    required String itemName,
    int itemSequence = 0,
  }) {
    final categoryCode = _categoryShortCode(category);
    final subCategoryCode = _subcategoryShortCode(subCategory);
    final safeSequence = _sequenceValue(category, subCategory, itemName, itemSequence);

    return '$categoryCode-$subCategoryCode-${safeSequence.toString().padLeft(3, '0')}';
  }

  static String generateUniqueAutoCode({
    required String category,
    required String subCategory,
    required String itemName,
    required Iterable<String> existingCodes,
    int startSequence = 1,
  }) {
    final normalizedExisting = existingCodes
        .map((code) => code.trim())
        .where((code) => code.isNotEmpty)
        .toSet();

    var sequence = startSequence;
    while (true) {
      final candidate = generateAutoCode(
        category: category,
        subCategory: subCategory,
        itemName: itemName,
        itemSequence: sequence,
      );

      if (!normalizedExisting.contains(candidate)) {
        return candidate;
      }
      sequence += 1;
    }
  }

  static String _categoryShortCode(String category) {
    final normalized = category.trim();
    if (normalized.isEmpty) {
      return 'XX';
    }

    final key = normalized.toLowerCase();
    final lookup = <String, String>{
      'sparklers': 'SP',
      'rockets': 'RK',
      'flower pots': 'FP',
      'flower pot': 'FP',
      'ground crackers': 'GC',
      'ground cracker': 'GC',
      'specials': 'SPC',
    };

    if (lookup.containsKey(key)) {
      return lookup[key]!;
    }

    final letters = key.replaceAll(RegExp(r'[^a-z]'), '');
    if (letters.isEmpty) {
      return 'XX';
    }

    return letters.substring(0, letters.length > 2 ? 2 : letters.length).toUpperCase();
  }

  static String _subcategoryShortCode(String subCategory) {
    final normalized = subCategory.trim().toLowerCase();
    if (normalized.isEmpty) {
      return 'OTH';
    }

    if (normalized.contains('standard')) return 'STD';
    if (normalized.contains('other')) return 'OTH';
    if (normalized.contains('premium')) return 'PRE';
    if (normalized.contains('local')) return 'LOC';
    if (normalized.contains('special')) return 'SPC';
    if (normalized.contains('electric')) return 'ELE';
    if (normalized.contains('crackling')) return 'CRK';
    if (normalized.contains('ground')) return 'GRD';
    if (normalized.contains('mini')) return 'MIN';
    if (normalized.contains('large')) return 'LRG';

    final letters = normalized.replaceAll(RegExp(r'[^a-z]'), '');
    if (letters.isEmpty) {
      return 'OTH';
    }

    return letters.substring(0, letters.length > 3 ? 3 : letters.length).toUpperCase();
  }

  static String _variantShortCode(String itemName) {
    final normalized = itemName.trim().toLowerCase();
    if (normalized.isEmpty) {
      return 'GEN';
    }

    if (normalized.contains('15cm') || normalized.contains('15 cm')) return '15';
    if (normalized.contains('30cm') || normalized.contains('30 cm')) return '30';
    if (normalized.contains('45cm') || normalized.contains('45 cm')) return '45';
    if (normalized.contains('electric')) return 'ELE';
    if (normalized.contains('crackling')) return 'CRK';
    if (normalized.contains('ground')) return 'GRD';
    if (normalized.contains('mini')) return 'MIN';
    if (normalized.contains('large')) return 'LRG';
    if (normalized.contains('special')) return 'SPC';

    final letters = normalized.replaceAll(RegExp(r'[^a-z]'), '');
    if (letters.isEmpty) {
      return 'GEN';
    }

    return letters.substring(0, letters.length > 3 ? 3 : letters.length).toUpperCase();
  }

  static int resolveCategoryIndex(String category) {
    final normalized = category.trim().toLowerCase();
    return _categoryCodes[normalized] ?? _stableIndex(normalized, maxValue: 9);
  }

  static int resolveSubCategoryIndex(String subCategory) {
    final normalized = subCategory.trim().toLowerCase();
    return _subcategoryCodes[normalized] ?? _stableIndex(normalized, maxValue: 9);
  }

  static int resolveVariantIndex(String itemName) {
    final normalized = itemName.trim().toLowerCase();
    for (final entry in _variantCodes.entries) {
      if (normalized.contains(entry.key)) {
        return entry.value;
      }
    }
    return _stableIndex(normalized, maxValue: 9);
  }

  static int _sequenceValue(String category, String subCategory, String itemName, int itemSequence) {
    if (itemSequence > 0) {
      return itemSequence.clamp(1, 99);
    }

    return 1;
  }

  static int _stableIndex(String value, {required int maxValue}) {
    final hash = value.isEmpty ? 0 : value.codeUnits.fold<int>(0, (sum, code) => sum + code);
    return ((hash % maxValue) + 1).clamp(1, maxValue);
  }

  static void _validateIndex(String name, int value, int minInclusive, int maxInclusive) {
    if (value < minInclusive || value > maxInclusive) {
      throw RangeError.range(
        value,
        minInclusive,
        maxInclusive,
        name,
      );
    }
  }
}
