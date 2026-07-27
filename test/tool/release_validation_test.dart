import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/release_validation.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('carvita_release_validation_');
    File('${root.path}/pubspec.yaml')
      ..createSync(recursive: true)
      ..writeAsStringSync('name: carvita\nversion: 1.2.3+9\n');
    _writeChangelog(root, 'en-US', 9, 'English changes');
    _writeChangelog(root, 'zh-CN', 9, '中文更新');
  });

  tearDown(() {
    root.deleteSync(recursive: true);
  });

  test('accepts exact tag, increasing code, and bilingual changelogs', () {
    expect(
      validateReleaseMetadata(
        repositoryRoot: root,
        tag: 'v1.2.3+9',
        existingTags: const ['v1.2.2+8', 'not-a-release'],
      ),
      isEmpty,
    );
  });

  test('rejects a tag that does not exactly match pubspec', () {
    expect(
      validateReleaseMetadata(
        repositoryRoot: root,
        tag: 'v1.2.3+10',
        existingTags: const [],
      ),
      contains('Release tag v1.2.3+10 must exactly match v1.2.3+9'),
    );
  });

  test('requires non-empty English and Chinese changelogs', () {
    File(
      '${root.path}/fastlane/metadata/android/zh-CN/changelogs/9.txt',
    ).writeAsStringSync('  ');

    expect(
      validateReleaseMetadata(
        repositoryRoot: root,
        tag: 'v1.2.3+9',
        existingTags: const [],
      ),
      contains('zh-CN changelog for versionCode 9 is empty'),
    );
  });

  test('requires versionCode to increase over published tags', () {
    expect(
      validateReleaseMetadata(
        repositoryRoot: root,
        tag: 'v1.2.3+9',
        existingTags: const ['v1.1.0+10'],
      ),
      contains(
        'versionCode 9 must be greater than the published versionCode 10',
      ),
    );
  });
}

void _writeChangelog(
  Directory root,
  String locale,
  int versionCode,
  String contents,
) {
  File(
      '${root.path}/fastlane/metadata/android/$locale/'
      'changelogs/$versionCode.txt',
    )
    ..createSync(recursive: true)
    ..writeAsStringSync(contents);
}
