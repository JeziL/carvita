import 'dart:io';

final class AppVersion {
  final String name;
  final int code;

  const AppVersion({required this.name, required this.code});

  String get tag => 'v$name+$code';
}

AppVersion readAppVersion(String pubspecContents) {
  final match = RegExp(
    r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$',
    multiLine: true,
  ).firstMatch(pubspecContents);
  if (match == null) {
    throw const FormatException(
      'pubspec.yaml must contain version: major.minor.patch+versionCode',
    );
  }
  return AppVersion(name: match.group(1)!, code: int.parse(match.group(2)!));
}

List<String> validateReleaseMetadata({
  required Directory repositoryRoot,
  required String tag,
  required Iterable<String> existingTags,
}) {
  final errors = <String>[];
  final pubspec = File('${repositoryRoot.path}/pubspec.yaml');
  if (!pubspec.existsSync()) {
    return ['pubspec.yaml was not found'];
  }

  late final AppVersion version;
  try {
    version = readAppVersion(pubspec.readAsStringSync());
  } on FormatException catch (error) {
    return [error.message];
  }

  if (tag != version.tag) {
    errors.add('Release tag $tag must exactly match ${version.tag}');
  }

  for (final locale in const ['en-US', 'zh-CN']) {
    final changelog = File(
      '${repositoryRoot.path}/fastlane/metadata/android/$locale/'
      'changelogs/${version.code}.txt',
    );
    if (!changelog.existsSync()) {
      errors.add(
        '$locale changelog for versionCode ${version.code} is missing',
      );
    } else if (changelog.readAsStringSync().trim().isEmpty) {
      errors.add('$locale changelog for versionCode ${version.code} is empty');
    }
  }

  final publishedCodes = existingTags
      .where((existingTag) => existingTag != tag)
      .map(
        (existingTag) => RegExp(
          r'^v[0-9]+\.[0-9]+\.[0-9]+\+([0-9]+)$',
        ).firstMatch(existingTag),
      )
      .whereType<RegExpMatch>()
      .map((match) => int.parse(match.group(1)!))
      .toList(growable: false);
  if (publishedCodes.isNotEmpty) {
    final highestPublishedCode = publishedCodes.reduce(
      (highest, code) => code > highest ? code : highest,
    );
    if (version.code <= highestPublishedCode) {
      errors.add(
        'versionCode ${version.code} must be greater than the published '
        'versionCode $highestPublishedCode',
      );
    }
  }

  return errors;
}
