import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carvita/core/constants/app_routes.dart';
import 'package:carvita/core/services/navigation_service.dart';
import 'package:carvita/presentation/navigation/app_route_arguments.dart';
import 'package:carvita/presentation/navigation/default_maintenance_reminder_navigation.dart';
import 'package:carvita/presentation/navigation/main_navigation_controller.dart';

void main() {
  testWidgets('valid reminder navigation opens the maintenance-plan tab', (
    tester,
  ) async {
    RouteSettings? capturedSettings;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: NavigationService.navigatorKey,
        onGenerateRoute: (settings) {
          capturedSettings = settings;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const SizedBox(),
          );
        },
        home: const SizedBox(),
      ),
    );

    DefaultMaintenanceReminderNavigation(
      MainNavigationController(),
    ).openVehicleMaintenancePlan(42);
    await tester.pumpAndSettle();

    expect(capturedSettings?.name, AppRoutes.vehicleDetailsRoute);
    final arguments =
        capturedSettings?.arguments as VehicleDetailsRouteArguments;
    expect(arguments.vehicleId, 42);
    expect(arguments.initialTab, VehicleDetailsTab.maintenancePlan);
  });

  testWidgets('stale reminder navigation opens the upcoming list', (
    tester,
  ) async {
    final controller = MainNavigationController();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: NavigationService.navigatorKey,
        home: const SizedBox(),
      ),
    );

    Navigator.of(
      NavigationService.navigatorKey.currentContext!,
    ).push(MaterialPageRoute<void>(builder: (_) => const Text('details')));
    await tester.pumpAndSettle();

    DefaultMaintenanceReminderNavigation(controller).openUpcomingMaintenance();
    await tester.pumpAndSettle();

    expect(controller.selectedIndex, 2);
    expect(find.text('details'), findsNothing);
  });
}
