import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carvita/core/constants/app_routes.dart';
import 'package:carvita/core/services/navigation_service.dart';
import 'package:carvita/presentation/navigation/app_route_arguments.dart';
import 'package:carvita/presentation/navigation/default_maintenance_reminder_navigation.dart';

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

    const DefaultMaintenanceReminderNavigation().openVehicleMaintenancePlan(42);
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

    const DefaultMaintenanceReminderNavigation().openUpcomingMaintenance();
    await tester.pumpAndSettle();

    expect(capturedSettings?.name, AppRoutes.upcomingMaintenanceRoute);
  });
}
