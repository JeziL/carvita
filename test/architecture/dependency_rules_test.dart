import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('data models do not depend on Flutter UI or localization', () {
    final violations = _dartFilesUnder('lib/data/models')
        .where((file) {
          final source = file.readAsStringSync();
          return source.contains("import 'package:flutter/") ||
              source.contains("import 'package:carvita/i18n/generated/");
        })
        .map((file) => file.path)
        .toList();

    expect(violations, isEmpty);
  });

  test('core services do not depend on screens or presentation managers', () {
    final violations = _dartFilesUnder('lib/core/services')
        .where((file) {
          final source = file.readAsStringSync();
          return source.contains(
                "import 'package:carvita/presentation/screens/",
              ) ||
              source.contains("import 'package:carvita/presentation/manager/");
        })
        .map((file) => file.path)
        .toList();

    expect(violations, isEmpty);
  });

  test('screens receive repositories and platform services by injection', () {
    final directConstruction = RegExp(
      r'\b(?:VehicleRepository|MaintenanceRepository|PreferencesService|'
      r'BackupService|NotificationService)\s*\(',
    );
    final violations = _dartFilesUnder('lib/presentation/screens')
        .where((file) => directConstruction.hasMatch(file.readAsStringSync()))
        .map((file) => file.path)
        .toList();

    expect(violations, isEmpty);
  });

  test('presentation does not depend on concrete data repositories', () {
    final violations = _dartFilesUnder('lib/presentation')
        .where(
          (file) => file.readAsStringSync().contains(
            "import 'package:carvita/data/repositories/",
          ),
        )
        .map((file) => file.path)
        .toList();

    expect(violations, isEmpty);
  });

  test(
    'application use cases remain independent of Flutter and presentation',
    () {
      final violations = _dartFilesUnder('lib/application')
          .where((file) {
            final source = file.readAsStringSync();
            return source.contains("import 'package:flutter/") ||
                source.contains("import 'package:carvita/presentation/") ||
                source.contains("import 'package:carvita/i18n/generated/");
          })
          .map((file) => file.path)
          .toList();

      expect(violations, isEmpty);
    },
  );

  test('presentation reaches device plugins through injected ports', () {
    final pluginImports = RegExp(
      r"import 'package:(?:file_picker|image_picker|package_info_plus|"
      r"share_plus|url_launcher|quick_actions|flutter_local_notifications)/",
    );
    final violations = _dartFilesUnder('lib/presentation')
        .where((file) => pluginImports.hasMatch(file.readAsStringSync()))
        .map((file) => file.path)
        .toList();

    expect(violations, isEmpty);
  });

  test('concrete repositories and platform services are composed in main', () {
    final directConstruction = RegExp(
      r'\b(?:VehicleRepository|MaintenanceRepository|BackupService|'
      r'NotificationService|PredictionService)\s*\(',
    );
    final violations = _dartFilesUnder('lib')
        .where((file) {
          final normalizedPath = file.path.replaceAll('\\', '/');
          if (normalizedPath == 'lib/main.dart') return false;
          if (normalizedPath.startsWith('lib/data/repositories/')) return false;
          if (normalizedPath.startsWith('lib/core/services/')) return false;
          return directConstruction.hasMatch(file.readAsStringSync());
        })
        .map((file) => file.path)
        .toList();

    expect(violations, isEmpty);
  });
}

Iterable<File> _dartFilesUnder(String path) {
  return Directory(path)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
}
