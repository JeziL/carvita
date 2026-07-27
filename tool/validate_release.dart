import 'dart:io';

import 'release_validation.dart';

void main(List<String> arguments) {
  final repositoryRoot = Directory.current;
  final version = readAppVersion(
    File('${repositoryRoot.path}/pubspec.yaml').readAsStringSync(),
  );
  final tagArgumentIndex = arguments.indexOf('--tag');
  final tag = tagArgumentIndex >= 0 && tagArgumentIndex + 1 < arguments.length
      ? arguments[tagArgumentIndex + 1]
      : version.tag;
  final tagsResult = Process.runSync('git', ['tag', '--list']);
  if (tagsResult.exitCode != 0) {
    stderr.writeln('Unable to read Git tags: ${tagsResult.stderr}');
    exitCode = 1;
    return;
  }

  final existingTags = (tagsResult.stdout as String)
      .split('\n')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty);
  final errors = validateReleaseMetadata(
    repositoryRoot: repositoryRoot,
    tag: tag,
    existingTags: existingTags,
  );
  if (errors.isNotEmpty) {
    for (final error in errors) {
      stderr.writeln('Release validation failed: $error');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('Release metadata validated for $tag');
}
