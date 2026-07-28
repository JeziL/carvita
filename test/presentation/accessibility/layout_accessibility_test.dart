import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carvita/core/theme/app_theme.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/presentation/screens/common_widgets/main_bottom_navigation_bar.dart';
import 'package:carvita/presentation/screens/dashboard/widgets/quick_action_button.dart';
import 'package:carvita/presentation/screens/dashboard/widgets/vehicle_summary_card.dart';

void main() {
  for (final textScale in [1.0, 1.3, 2.0]) {
    testWidgets('key dashboard controls fit at $textScale text scaling', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _accessibleApp(
          locale: const Locale('de'),
          textScaler: TextScaler.linear(textScale),
          child: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return Scaffold(
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        QuickActionButton(
                          label: l10n.addVehicle,
                          icon: Icons.add_circle_outline,
                          onPressed: () {},
                        ),
                        const SizedBox(width: 12),
                        QuickActionButton(
                          label: l10n.logMaintenance,
                          icon: Icons.edit_calendar_outlined,
                          onPressed: () {},
                        ),
                      ],
                    ),
                    VehicleSummaryCard(
                      vehicle: Vehicle(
                        id: 1,
                        name: 'Familienfahrzeug mit langem Namen',
                        mileage: 1000,
                        mileageLastUpdated: DateTime(2026, 1, 1),
                        boughtDate: DateTime(2025, 1, 1),
                      ),
                      nextMaintenanceInfo:
                          'Nächste Wartung mit einer langen Beschreibung',
                      onTap: () {},
                    ),
                  ],
                ),
                bottomNavigationBar: const MainBottomNavigationBar(
                  currentIndex: 0,
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('Fahrzeug hinzufügen'), findsOne);
      expect(find.bySemanticsLabel('Wartung protokollieren'), findsOne);
    });
  }

  testWidgets('directional action layout mirrors in RTL', (tester) async {
    await tester.pumpWidget(
      _accessibleApp(
        locale: const Locale('ar'),
        child: const Scaffold(
          body: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Icon(Icons.chevron_right),
          ),
        ),
      ),
    );

    expect(
      tester.getCenter(find.byIcon(Icons.chevron_right)).dx,
      lessThan(400),
    );
  });
}

Widget _accessibleApp({
  required Locale locale,
  required Widget child,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    locale: locale,
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
    builder: (context, appChild) {
      final mediaQuery = MediaQuery.of(context);
      return MediaQuery(
        data: mediaQuery.copyWith(textScaler: textScaler),
        child: appChild!,
      );
    },
    home: child,
  );
}
