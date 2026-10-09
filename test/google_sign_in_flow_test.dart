import 'package:crackers_billing/views/sign_in_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() {
  group('Google sign-in flow selection', () {
    test('uses authenticate when the platform supports it', () async {
      final mockAccount = Object();

      final result = await signInWithGoogleFlow<Object>(
        supportsAuthenticate: true,
        authenticate: () async => mockAccount,
      );

      expect(result, same(mockAccount));
    });

    test('returns null when the platform requires the rendered web button', () async {
      final result = await signInWithGoogleFlow<Object>(
        supportsAuthenticate: false,
        authenticate: () async => throw StateError('authenticate should not run'),
      );

      expect(result, isNull);
    });
  });
}
