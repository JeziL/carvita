import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carvita/core/failures/app_failure.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/i18n/generated/app_localizations_en.dart';
import 'package:carvita/presentation/failures/app_failure_localizer.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('maps typed failures to concise user messages', () {
    final messages = {
      AppFailureKind.load: 'Unable to load data. Try again.',
      AppFailureKind.save: 'Unable to save changes. Try again.',
      AppFailureKind.delete: 'Unable to delete. Try again.',
      AppFailureKind.refresh: 'Unable to refresh right now. Try again.',
      AppFailureKind.reminderUpdate: 'Saved, but reminder update failed.',
      AppFailureKind.export: 'Unable to export data. Try again.',
      AppFailureKind.restore:
          'Unable to restore data. Check the backup file and try again.',
    };

    for (final entry in messages.entries) {
      final failure = AppFailure.capture(
        entry.key,
        StateError('SQL failed at C:\\private\\carvita_v1.db'),
        StackTrace.current,
        context: 'AppFailureLocalizerTest',
      );

      final message = failure.toLocalizedMessage(l10n);

      expect(message, entry.value);
      expect(message, isNot(contains('SQL')));
      expect(message, isNot(contains('private')));
      expect(message, isNot(contains('carvita_v1.db')));
    }
  });

  test('all supported locales provide route and failure messages', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final localized = lookupAppLocalizations(locale);

      expect(localized.routeErrorTitle, isNotEmpty);
      expect(localized.routeErrorMessage, isNotEmpty);
      expect(localized.goToHome, isNotEmpty);
      expect(localized.loadErrorMessage, isNotEmpty);
      expect(localized.saveErrorMessage, isNotEmpty);
      expect(localized.deleteErrorMessage, isNotEmpty);
      expect(localized.refreshErrorMessage, isNotEmpty);
      expect(localized.reminderUpdateErrorMessage, isNotEmpty);
      expect(localized.exportErrorMessage, isNotEmpty);
      expect(localized.restoreErrorMessage, isNotEmpty);
    }

    final zh = lookupAppLocalizations(const Locale('zh'));
    expect(zh.refreshErrorMessage, '暂时无法刷新，请重试。');
    expect(zh.reminderUpdateErrorMessage, '已保存，提醒更新失败。');
  });
}
