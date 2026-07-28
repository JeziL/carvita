import 'package:flutter/widgets.dart';

import 'package:carvita/core/utils/calendar_day.dart';
import 'package:carvita/data/models/predicted_maintenance.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';

extension PredictedMaintenanceLocalizer on PredictedMaintenanceInfo {
  String displayInfo(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final daysRemaining = CalendarDay.daysUntil(predictedDueDate);
    final dueLabel = daysRemaining >= 0
        ? l10n.daysLater(daysRemaining)
        : l10n.daysOverdue(-daysRemaining);
    return l10n.nextMaintenanceSummary(planItem.itemName, dueLabel);
  }
}
