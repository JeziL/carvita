import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:carvita/core/services/preferences_service.dart';

void main() {
  test('backup preferences use a typed allowlist', () async {
    SharedPreferences.setMockInitialValues({
      'locale_language_code': 'de',
      'notifications_enabled': true,
      'plugin_private_key': 'do-not-export',
    });
    final service = PreferencesService();

    final values = await service.readBackupPreferences();

    expect(values, {
      'locale_language_code': 'de',
      'notifications_enabled': true,
    });
  });

  test(
    'restore replaces allowlisted values and preserves unrelated keys',
    () async {
      SharedPreferences.setMockInitialValues({
        'locale_language_code': 'de',
        'notifications_enabled': true,
        'plugin_private_key': 'keep',
      });
      final service = PreferencesService();

      await service.replaceBackupPreferences({
        'locale_language_code': 'ja',
        'reminder_lead_time_days': 3,
      });

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('locale_language_code'), 'ja');
      expect(preferences.getInt('reminder_lead_time_days'), 3);
      expect(preferences.getBool('notifications_enabled'), isNull);
      expect(preferences.getString('plugin_private_key'), 'keep');
    },
  );

  test(
    'restore rejects unknown keys and invalid types before writing',
    () async {
      SharedPreferences.setMockInitialValues({'locale_language_code': 'de'});
      final service = PreferencesService();

      await expectLater(
        service.replaceBackupPreferences({'unknown_key': 'value'}),
        throwsFormatException,
      );
      await expectLater(
        service.replaceBackupPreferences({'notifications_enabled': 'yes'}),
        throwsFormatException,
      );

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('locale_language_code'), 'de');
    },
  );
}
