import 'package:flutter/widgets.dart';

import 'package:carvita/data/models/predicted_maintenance.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';

extension PredictedMaintenanceLocalizer on PredictedMaintenanceInfo {
  String displayInfo(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final daysRemaining = predictedDueDate.difference(DateTime.now()).inDays;
    final dueLabel = daysRemaining >= 0
        ? l10n.daysLater(daysRemaining)
        : l10n.daysOverdue(-daysRemaining);
    return '${l10n.nextMaintenanceShort}: '
        '${planItem.itemName} - $dueLabel';
  }
}
