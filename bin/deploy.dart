import 'dart:convert';
import 'dart:async';
import 'dart:io';

final RegExp _versionPattern = RegExp(r'^version:\s*(.+)\s*$');

class DeployConfig {
  DeployConfig({
    required this.appId,
    required this.firebaseToken,
    required this.apkPath,
    required this.releaseNotes,
    required this.groups,
    required this.buildOnly,
  });

  final String appId;
  final String firebaseToken;
  final String apkPath;
  final String releaseNotes;
  final String groups;
  final bool buildOnly;
}

Future<void> main(List<String> arguments) async {
  final config = _parseArguments(arguments);
  final appVersion = _readAppVersion();

  stdout.writeln('Deploying version $appVersion');

  if (!config.buildOnly) {
    _requireTool('flutter');
    _requireTool('firebase');
  }

  stdout.writeln('Building Android arm64 release APK for version $appVersion...');
  await _run('flutter', [
    'build',
    'apk',
    '--release',
    '--target-platform',
    'android-arm64',
    '--split-per-abi',
  ]);

  if (config.buildOnly) {
    stdout.writeln('Build completed. APK expected at ${config.apkPath}.');
    return;
  }

  final apkFile = File(config.apkPath);
  if (!await apkFile.exists()) {
    throw StateError(
      'APK not found at ${config.apkPath}. Run the build step again.',
    );
  }

  stdout.writeln(
    'Uploading ${config.apkPath} for version $appVersion to Firebase App Distribution...',
  );
  final firebaseArgs = <String>[
    'appdistribution:distribute',
    config.apkPath,
    '--app',
    config.appId,
    '--token',
    config.firebaseToken,
  ];

  if (config.groups.isNotEmpty) {
    firebaseArgs
      ..add('--groups')
      ..add(config.groups);
  }

  if (config.releaseNotes.isNotEmpty) {
    firebaseArgs
      ..add('--release-notes')
      ..add(config.releaseNotes);
  }

  await _run('firebase', firebaseArgs);
  stdout.writeln('Deployment for version $appVersion finished successfully.');
}

String _readAppVersion() {
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    return 'unknown';
  }

  final match = _versionPattern.firstMatch(pubspecFile.readAsStringSync().split('\n').firstWhere(
        (line) => line.trimLeft().startsWith('version:'),
        orElse: () => '',
      ));
  if (match == null) {
    return 'unknown';
  }

  return match.group(1)!.trim();
}

DeployConfig _parseArguments(List<String> arguments) {
  final values = <String, String>{};
  var buildOnly = false;

  for (var index = 0; index < arguments.length; index++) {
    final arg = arguments[index];
    if (arg == '--build-only') {
      buildOnly = true;
      continue;
    }

    if (!arg.startsWith('--')) {
      throw FormatException('Unknown argument: $arg');
    }

    final keyValue = arg.substring(2);
    final separatorIndex = keyValue.indexOf('=');
    if (separatorIndex != -1) {
      values[keyValue.substring(0, separatorIndex)] = keyValue.substring(
        separatorIndex + 1,
      );
      continue;
    }

    final key = keyValue;
    if (index + 1 >= arguments.length ||
        arguments[index + 1].startsWith('--')) {
      throw FormatException('Missing value for --$key');
    }
    values[key] = arguments[++index];
  }

  final appId =
      values['app-id'] ?? Platform.environment['FIREBASE_APP_ID'] ?? '';
  final firebaseToken =
      values['firebase-token'] ?? Platform.environment['FIREBASE_TOKEN'] ?? '';
  final groups =
      values['groups'] ?? Platform.environment['FIREBASE_GROUPS'] ?? 'testers';
  final releaseNotes =
      values['release-notes'] ??
      Platform.environment['RELEASE_NOTES'] ??
      'Android arm64 release from bin/deploy.dart';

  if (appId.isEmpty && !buildOnly) {
    throw ArgumentError(
      'Missing Firebase app id. Pass --app-id or set FIREBASE_APP_ID.',
    );
  }

  if (firebaseToken.isEmpty && !buildOnly) {
    throw ArgumentError(
      'Missing Firebase token. Pass --firebase-token or set FIREBASE_TOKEN.',
    );
  }

  return DeployConfig(
    appId: appId,
    firebaseToken: firebaseToken,
    apkPath:
        values['apk-path'] ??
        'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk',
    releaseNotes: releaseNotes,
    groups: groups,
    buildOnly: buildOnly,
  );
}

void _requireTool(String tool) {
  final result = Process.runSync('which', [tool]);
  if (result.exitCode != 0) {
    throw StateError('Required tool not found: $tool');
  }
}

Future<void> _run(String executable, List<String> args) async {
  final process = await Process.start(
    executable,
    args,
    runInShell: Platform.isWindows,
  );

  final stdoutSubscription = process.stdout
      .transform(utf8.decoder)
      .listen(stdout.write);
  final stderrSubscription = process.stderr
      .transform(utf8.decoder)
      .listen(stderr.write);

  final exitCode = await process.exitCode;
  await Future.wait([stdoutSubscription.cancel(), stderrSubscription.cancel()]);

  if (exitCode != 0) {
    throw ProcessException(
      executable,
      args,
      'Command failed with exit code $exitCode',
      exitCode,
    );
  }
}
