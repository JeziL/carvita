import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carvita/core/theme/app_theme.dart';
import 'package:carvita/core/utils/preference_selection.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/presentation/screens/settings/preference_dialogs.dart';

void main() {
  testWidgets('dismissing default vehicle dialog keeps existing selection', (
    tester,
  ) async {
    PreferenceSelection<int>? result;
    await tester.pumpWidget(
      _testApp(
        onPressed: (context) async {
          result = await showDefaultVehicleSelectionDialog(
            context: context,
            vehicles: [_vehicle(1), _vehicle(2)],
            currentVehicleId: 1,
          );
        },
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('clear default is distinct from dismiss', (tester) async {
    PreferenceSelection<int>? result;
    await tester.pumpWidget(
      _testApp(
        onPressed: (context) async {
          result = await showDefaultVehicleSelectionDialog(
            context: context,
            vehicles: [_vehicle(1)],
            currentVehicleId: 1,
          );
        },
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(result, isA<PreferenceCleared<int>>());
  });

  testWidgets('dismissing language dialog keeps explicit locale', (
    tester,
  ) async {
    PreferenceSelection<Locale>? result;
    await tester.pumpWidget(
      _testApp(
        onPressed: (context) async {
          result = await showLanguageSelectionDialog(
            context: context,
            supportedLanguages: const [
              {'locale': null, 'name': 'System'},
              {'locale': Locale('de'), 'name': 'Deutsch'},
            ],
            currentLocale: const Locale('de'),
          );
        },
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('system language is distinct from dismiss', (tester) async {
    PreferenceSelection<Locale>? result;
    await tester.pumpWidget(
      _testApp(
        onPressed: (context) async {
          result = await showLanguageSelectionDialog(
            context: context,
            supportedLanguages: const [
              {'locale': null, 'name': 'System'},
              {'locale': Locale('de'), 'name': 'Deutsch'},
            ],
            currentLocale: const Locale('de'),
          );
        },
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();

    expect(result, isA<PreferenceCleared<Locale>>());
  });
}

Widget _testApp({
  required Future<void> Function(BuildContext context) onPressed,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.getThemeData(
      ColorScheme.fromSeed(seedColor: Colors.blue),
      Brightness.light,
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => onPressed(context),
          child: const Text('Open'),
        ),
      ),
    ),
  );
}

Vehicle _vehicle(int id) {
  return Vehicle(
    id: id,
    name: 'Vehicle $id',
    mileage: 1000,
    mileageLastUpdated: DateTime(2026, 1, 1),
    boughtDate: DateTime(2025, 1, 1),
  );
}
