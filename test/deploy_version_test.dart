import 'package:flutter_test/flutter_test.dart';

import '../bin/deploy_version.dart';

void main() {
  group('bumpPubspecBuildNumber', () {
    test('increments the existing Flutter build number', () {
      const pubspec = 'name: app\nversion: 1.2.3+8\nenvironment:\n';

      expect(
        bumpPubspecBuildNumber(pubspec),
        'name: app\nversion: 1.2.3+9\nenvironment:\n',
      );
    });

    test('adds a build number when the version has none', () {
      expect(
        bumpPubspecBuildNumber('version: 1.2.3\n'),
        'version: 1.2.3+1\n',
      );
    });

    test('rejects an unsupported version instead of reusing it', () {
      expect(
        () => bumpPubspecBuildNumber('version: latest\n'),
        throwsFormatException,
      );
    });
  });
}
