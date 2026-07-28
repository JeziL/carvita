import 'package:carvita/core/failures/app_failure.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';

extension AppFailureLocalizer on AppFailure {
  String toLocalizedMessage(AppLocalizations l10n) {
    return switch (kind) {
      AppFailureKind.load => l10n.loadErrorMessage,
      AppFailureKind.save => l10n.saveErrorMessage,
      AppFailureKind.delete => l10n.deleteErrorMessage,
      AppFailureKind.refresh => l10n.refreshErrorMessage,
      AppFailureKind.reminderUpdate => l10n.reminderUpdateErrorMessage,
      AppFailureKind.export => l10n.exportErrorMessage,
      AppFailureKind.restore => l10n.restoreErrorMessage,
    };
  }
}
