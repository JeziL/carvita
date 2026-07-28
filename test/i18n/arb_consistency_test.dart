import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all locale ARB files keep the same messages and placeholders', () {
    final files =
        Directory('lib/i18n')
            .listSync()
            .whereType<File>()
            .where((file) => RegExp(r'app_.+\.arb$').hasMatch(file.path))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final templateFile = File('lib/i18n/app_en.arb');
    final template = _messages(templateFile);
    final templatePlaceholders = _templatePlaceholders(templateFile);

    expect(files, hasLength(12));
    expect(template, hasLength(188));

    for (final file in files) {
      final messages = _messages(file);
      expect(
        messages.keys.toSet(),
        template.keys.toSet(),
        reason: '${file.path} must contain the same message keys',
      );
      for (final entry in template.entries) {
        for (final placeholder in templatePlaceholders[entry.key] ?? const {}) {
          expect(
            RegExp(
              '\\{${RegExp.escape(placeholder)}(?:[},])',
            ).hasMatch(messages[entry.key]!),
            isTrue,
            reason: '${file.path} is missing {$placeholder} in ${entry.key}',
          );
        }
      }
    }
  });
}

Map<String, String> _messages(File file) {
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final entry in json.entries)
      if (!entry.key.startsWith('@') && entry.value is String)
        entry.key: entry.value as String,
  };
}

Map<String, Set<String>> _templatePlaceholders(File file) {
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final entry in json.entries)
      if (entry.key.startsWith('@') && entry.value is Map<String, dynamic>)
        entry.key.substring(1): {
          for (final placeholder
              in ((entry.value as Map<String, dynamic>)['placeholders']
                          as Map<String, dynamic>? ??
                      const {})
                  .keys)
            placeholder,
        },
  };
}
