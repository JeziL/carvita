import 'package:flutter/widgets.dart';

import 'package:carvita/core/services/preferences_service.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';

extension AppThemePreferenceLocalizer on AppThemePreference {
  String displayString(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return switch (this) {
      AppThemePreference.system => l10n.themeSystem,
      AppThemePreference.light => l10n.themeLight,
      AppThemePreference.dark => l10n.themeDark,
      AppThemePreference.custom => l10n.themeCustom,
    };
  }
}

extension DueReminderThresholdLocalizer on DueReminderThresholdValue {
  String displayString(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return switch (this) {
      DueReminderThresholdValue.week => l10n.thresholdWeek,
      DueReminderThresholdValue.month => l10n.thresholdMonth,
      DueReminderThresholdValue.halfYear => l10n.thresholdHalfYear,
    };
  }
}
