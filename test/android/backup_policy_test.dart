import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android backup policy disables cloud and device transfer data', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final legacyRules = File(
      'android/app/src/main/res/xml/backup_rules.xml',
    ).readAsStringSync();
    final extractionRules = File(
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="@xml/backup_rules"'));
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
    expect(extractionRules, contains('<cloud-backup>'));
    expect(extractionRules, contains('<device-transfer>'));

    const domains = [
      'root',
      'file',
      'database',
      'sharedpref',
      'external',
      'device_root',
      'device_file',
      'device_database',
      'device_sharedpref',
    ];
    for (final domain in domains) {
      final exclusion = '<exclude domain="$domain" path="." />';
      expect(legacyRules, contains(exclusion));
      expect(
        exclusion.allMatches(extractionRules),
        hasLength(2),
        reason: '$domain must be excluded from cloud and device transfer',
      );
    }
  });
}
