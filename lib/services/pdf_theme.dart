import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

pw.ThemeData? _cachedTheme;

/// PDF theme with a font that includes the ₹ glyph.
Future<pw.ThemeData> loadPdfTheme() async {
  final cached = _cachedTheme;
  if (cached != null) return cached;
  try {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
    );
    return _cachedTheme = pw.ThemeData.withFont(base: regular, bold: bold);
  } catch (error) {
    debugPrint('PDF font load failed, using default font: $error');
    return pw.ThemeData();
  }
}
