import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carvita/main.dart' as app;

void main() {
  test('ARB files correspond one-to-one with supported locales', () {
    final files = _arbFiles();
    final supportedLocales = [
      for (final language in app.appSupportedLocales)
        language['locale']! as Locale,
    ];
    final matchedPaths = <String>[];

    for (final locale in supportedLocales) {
      final exactMatches = files
          .where((file) => _arbLocale(file) == locale)
          .toList();
      final matches = exactMatches.isNotEmpty
          ? exactMatches
          : files.where((file) {
              final arbLocale = _arbLocale(file);
              return arbLocale.languageCode == locale.languageCode &&
                  arbLocale.scriptCode == null &&
                  arbLocale.countryCode == null;
            }).toList();

      expect(
        matches,
        hasLength(1),
        reason: '${locale.toLanguageTag()} must have exactly one ARB file',
      );
      matchedPaths.add(matches.single.path);
    }

    expect(
      matchedPaths.toSet(),
      hasLength(matchedPaths.length),
      reason: 'Each supported locale must use a different ARB file',
    );
    expect(
      matchedPaths.toSet(),
      files.map((file) => file.path).toSet(),
      reason: 'Every ARB file must correspond to a supported locale',
    );
  });

  test('all locale ARB files cover template messages and placeholders', () {
    final files = _arbFiles();
    final templateFile = File('lib/i18n/app_en.arb');
    final template = _messages(templateFile);
    final templatePlaceholders = _templatePlaceholders(templateFile);

    for (final file in files) {
      final messages = _messages(file);
      final missingMessages = template.keys.toSet().difference(
        messages.keys.toSet(),
      );
      expect(
        missingMessages,
        isEmpty,
        reason: '${file.path} must contain every template message',
      );
      for (final entry in template.entries) {
        for (final placeholder in templatePlaceholders[entry.key] ?? const {}) {
          expect(
            RegExp('\\{${RegExp.escape(placeholder)}(?:[},])')
                .hasMatch(messages[entry.key]!),
            isTrue,
            reason: '${file.path} is missing {$placeholder} in ${entry.key}',
          );
        }
      }
    }
  });
}

List<File> _arbFiles() =>
    Directory('lib/i18n')
        .listSync()
        .whereType<File>()
        .where((file) => RegExp(r'app_.+\.arb$').hasMatch(file.path))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

Locale _arbLocale(File file) {
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final localeParts = (json['@@locale']! as String).split('_');
  return Locale.fromSubtags(
    languageCode: localeParts.first,
    scriptCode: localeParts.where((part) => part.length == 4).firstOrNull,
    countryCode: localeParts
        .where((part) => part.length == 2 && part != localeParts.first)
        .firstOrNull,
  );
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
