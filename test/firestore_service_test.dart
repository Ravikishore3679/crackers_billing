import 'package:crackers_billing/services/firestore_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirestoreService', () {
    test('prefers an explicit user id over the current auth state', () {
      expect(FirestoreService.resolveUserId(userId: 'user-42'), 'user-42');
    });
S
    test('returns null when no user is signed in', () {
      expect(FirestoreService.resolveUserId(), isNull);
    });
  });
}
