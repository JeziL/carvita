import 'package:flutter/material.dart';

import 'package:carvita/core/constants/app_colors.dart';
import 'package:carvita/core/utils/preference_selection.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';

Future<PreferenceSelection<int>?> showDefaultVehicleSelectionDialog({
  required BuildContext context,
  required List<Vehicle> vehicles,
  required int? currentVehicleId,
}) {
  return showDialog<PreferenceSelection<int>>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        title: Text(
          AppLocalizations.of(context)!.chooseDefaultVehicle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 20,
          ),
        ),
        contentPadding: const EdgeInsets.only(top: 10, bottom: 0),
        content: SizedBox(
          width: double.maxFinite,
          child: vehicles.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 24,
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.noVehicles,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                )
              : RadioGroup<int>(
                  groupValue: currentVehicleId,
                  onChanged: (value) {
                    if (value != null) {
                      Navigator.of(
                        dialogContext,
                      ).pop(PreferenceSelected<int>(value));
                    }
                  },
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: vehicles.length,
                    itemBuilder: (_, index) {
                      final vehicle = vehicles[index];
                      return RadioListTile<int>(
                        title: Text(
                          vehicle.name,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        value: vehicle.id!,
                        activeColor: Theme.of(context).colorScheme.primary,
                      );
                    },
                  ),
                ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(const PreferenceCleared<int>()),
            child: Text(
              AppLocalizations.of(context)!.clearDefault,
              style: const TextStyle(color: AppColors.urgentReminderText),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              AppLocalizations.of(context)!.cancel,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      );
    },
  );
}

Future<PreferenceSelection<Locale>?> showLanguageSelectionDialog({
  required BuildContext context,
  required List<Map<String, dynamic>> supportedLanguages,
  required Locale? currentLocale,
}) {
  return showDialog<PreferenceSelection<Locale>>(
    context: context,
    builder: (dialogContext) {
      return SimpleDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        title: Text(
          AppLocalizations.of(context)!.chooseLanguage,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        children: supportedLanguages.map((language) {
          final locale = language['locale'] as Locale?;
          final name = language['name'] as String;
          final isSelected =
              currentLocale?.toLanguageTag() == locale?.toLanguageTag() ||
              (currentLocale == null && locale == null);
          return SimpleDialogOption(
            onPressed: () {
              if (locale == null) {
                Navigator.of(
                  dialogContext,
                ).pop(const PreferenceCleared<Locale>());
              } else {
                Navigator.of(
                  dialogContext,
                ).pop(PreferenceSelected<Locale>(locale));
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                name,
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      );
    },
  );
}
