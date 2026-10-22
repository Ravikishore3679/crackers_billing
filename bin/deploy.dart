import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'deploy_version.dart';

const String _defaultAppId = '1:162682850132:android:4a8c1c35f11684d21c16c1';
const String _defaultFirebaseGroups = 'crackers2026';

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
  final config = _parseArguments(arguments, dotenv: _readDotEnvFile());

  if (!config.buildOnly) {
    _requireTool('flutter');
    _requireTool('firebase');
  }

  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    throw StateError('Run this script from the project root containing pubspec.yaml.');
  }

  if (!config.buildOnly) {
    final updatedPubspec = bumpPubspecBuildNumber(
      pubspecFile.readAsStringSync(),
    );
    pubspecFile.writeAsStringSync(updatedPubspec);
  }
  final appVersion = AppVersion.fromPubspec(
    pubspecFile.readAsStringSync(),
  ).value;

  stdout.writeln('Deploying version $appVersion');

  stdout.writeln(
    'Building Android arm64 release APK for version $appVersion...',
  );
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
  ];

  if (config.firebaseToken.isNotEmpty) {
    firebaseArgs
      ..add('--token')
      ..add(config.firebaseToken);
  }

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

DeployConfig _parseArguments(
  List<String> arguments, {
  required Map<String, String> dotenv,
}) {
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
      values['app-id'] ??
      Platform.environment['FIREBASE_APP_ID'] ??
      dotenv['FIREBASE_APP_ID'] ??
      _defaultAppId;
  final firebaseToken =
      values['firebase-token'] ??
      values['token'] ??
      Platform.environment['FIREBASE_TOKEN'] ??
      dotenv['FIREBASE_TOKEN'] ??
      '';
  final groups =
      values['groups'] ??
      values['testers'] ??
      Platform.environment['FIREBASE_GROUPS'] ??
      dotenv['FIREBASE_GROUPS'] ??
      _defaultFirebaseGroups;
  final releaseNotes =
      values['release-notes'] ??
      Platform.environment['RELEASE_NOTES'] ??
      dotenv['RELEASE_NOTES'] ??
      '';

  if (appId.isEmpty && !buildOnly) {
    throw ArgumentError(
      'Missing Firebase app id. Pass --app-id or set FIREBASE_APP_ID.',
    );
  }
  if (!buildOnly && releaseNotes.trim().isEmpty) {
    throw ArgumentError(
      'Release notes are required. Pass --release-notes or set RELEASE_NOTES.',
    );
  }

  return DeployConfig(
    appId: appId,
    firebaseToken: firebaseToken,
    apkPath:
        values['apk-path'] ??
        'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk',
    releaseNotes: releaseNotes.trim(),
    groups: groups,
    buildOnly: buildOnly,
  );
}

Map<String, String> _readDotEnvFile() {
  final file = File('.env');
  if (!file.existsSync()) {
    return const <String, String>{};
  }

  final data = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      continue;
    }

    final index = trimmed.indexOf('=');
    if (index <= 0) {
      continue;
    }

    final key = trimmed.substring(0, index).trim();
    var value = trimmed.substring(index + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.substring(1, value.length - 1);
    }
    data[key] = value;
  }

  return data;
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
