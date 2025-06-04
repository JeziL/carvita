import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import 'package:carvita/core/constants/app_colors.dart';
import 'package:carvita/data/models/predicted_maintenance.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';

class MaintenanceListItemCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool isUrgent;

  const MaintenanceListItemCard({
    super.key,
    required this.title,
    required this.children,
    this.isUrgent = false,
  });

  factory MaintenanceListItemCard.planItem(
    BuildContext context,
    PredictedMaintenanceInfo item,
  ) {
    final daysRemaining =
        item.predictedDueDate.difference(DateTime.now()).inDays;
    bool isUrgent = daysRemaining <= 30;
    final dueDate = DateFormat.MMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(item.predictedDueDate);
    String daysRemainingText =
        daysRemaining >= 0
            ? AppLocalizations.of(context)!.daysLater(daysRemaining)
            : AppLocalizations.of(context)!.daysOverdue(-daysRemaining);
    String dueText = "$dueDate ($daysRemainingText)";
    return MaintenanceListItemCard(
      title: item.planItem.itemName,
      isUrgent: isUrgent,
      children: [
        Text(
          dueText,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color:
                isUrgent
                    ? AppColors.urgentReminderText
                    : Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline,
          width: 0.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
