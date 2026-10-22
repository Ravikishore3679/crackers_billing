final RegExp _versionLine = RegExp(
  r'^version:[ \t]*([^\s#]+)[ \t]*(?:#.*)?$',
  multiLine: true,
);
final RegExp _semanticVersion = RegExp(r'^(\d+\.\d+\.\d+)(?:\+(\d+))?$');

class AppVersion {
  const AppVersion({required this.name, required this.buildNumber});

  final String name;
  final int buildNumber;

  String get value => '$name+$buildNumber';

  factory AppVersion.fromPubspec(String pubspecContents) {
    final match = _versionLine.firstMatch(pubspecContents);
    if (match == null) {
      throw const FormatException('pubspec.yaml has no top-level version field.');
    }

    final versionMatch = _semanticVersion.firstMatch(match.group(1)!);
    if (versionMatch == null) {
      throw FormatException('Unsupported app version: ${match.group(1)}');
    }

    return AppVersion(
      name: versionMatch.group(1)!,
      buildNumber: int.tryParse(versionMatch.group(2) ?? '0') ?? 0,
    );
  }

  AppVersion nextBuild() =>
      AppVersion(name: name, buildNumber: buildNumber + 1);
}

String bumpPubspecBuildNumber(String pubspecContents) {
  final match = _versionLine.firstMatch(pubspecContents);
  if (match == null) {
    throw const FormatException('pubspec.yaml has no top-level version field.');
  }

  final nextVersion = AppVersion.fromPubspec(pubspecContents).nextBuild();
  return pubspecContents.replaceRange(
    match.start,
    match.end,
    'version: ${nextVersion.value}',
  );
}
