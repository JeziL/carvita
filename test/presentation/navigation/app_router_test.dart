import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carvita/application/use_cases/maintenance_plan_use_cases.dart';
import 'package:carvita/application/use_cases/service_log_use_cases.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:carvita/core/constants/app_routes.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/data/repositories/maintenance_repository.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/presentation/manager/maintenance_plan/maintenance_plan_cubit.dart';
import 'package:carvita/presentation/manager/service_log/service_log_cubit.dart';
import 'package:carvita/presentation/navigation/app_route_arguments.dart';
import 'package:carvita/presentation/navigation/app_router.dart';

void main() {
  late MaintenancePlanCubit maintenancePlanCubit;
  late ServiceLogCubit serviceLogCubit;

  setUp(() {
    final repository = MaintenanceRepository();
    maintenancePlanCubit = MaintenancePlanCubit(
      MaintenancePlanUseCases(repository),
      1,
    );
    serviceLogCubit = ServiceLogCubit(ServiceLogUseCases(repository), 1);
  });

  tearDown(() async {
    await maintenancePlanCubit.close();
    await serviceLogCubit.close();
  });

  test('parameterless routes preserve their RouteSettings', () {
    for (final routeName in [
      AppRoutes.dashboardRoute,
      AppRoutes.vehicleListRoute,
      AppRoutes.settingsRoute,
      AppRoutes.upcomingMaintenanceRoute,
      AppRoutes.privacyRoute,
    ]) {
      final settings = RouteSettings(name: routeName);

      final route = AppRouter.generateRoute(settings);

      expect(route.settings, same(settings));
    }
  });

  test('typed argument routes preserve their RouteSettings', () {
    final vehicle = Vehicle(
      id: 1,
      name: 'Test vehicle',
      mileage: 12000,
      mileageLastUpdated: DateTime(2024),
      boughtDate: DateTime(2024),
    );
    final routeSettings = [
      RouteSettings(
        name: AppRoutes.addVehicleRoute,
        arguments: AddEditVehicleRouteArguments(vehicle: vehicle),
      ),
      const RouteSettings(
        name: AppRoutes.vehicleDetailsRoute,
        arguments: VehicleDetailsRouteArguments(vehicleId: 1),
      ),
      RouteSettings(
        name: AppRoutes.addManualItemRoute,
        arguments: AddEditMaintenancePlanItemRouteArguments(
          vehicleId: 1,
          vehicleName: vehicle.name,
          maintenancePlanCubit: maintenancePlanCubit,
          serviceLogCubit: serviceLogCubit,
        ),
      ),
      RouteSettings(
        name: AppRoutes.logMaintenanceRoute,
        arguments: LogMaintenanceRouteArguments(
          vehicleId: 1,
          vehicleName: vehicle.name,
          serviceLogCubit: serviceLogCubit,
          maintenancePlanCubit: maintenancePlanCubit,
        ),
      ),
    ];

    for (final settings in routeSettings) {
      final route = AppRouter.generateRoute(settings);

      expect(route.settings, same(settings));
    }
  });

  test('existing missing-argument routes preserve their RouteSettings', () {
    for (final routeName in [
      AppRoutes.vehicleDetailsRoute,
      AppRoutes.addManualItemRoute,
      AppRoutes.logMaintenanceRoute,
      '/unknown',
    ]) {
      final settings = RouteSettings(name: routeName);

      final route = AppRouter.generateRoute(settings);

      expect(route.settings, same(settings));
    }
  });

  test('wrong argument types return error routes without throwing', () {
    for (final routeName in [
      AppRoutes.addVehicleRoute,
      AppRoutes.vehicleDetailsRoute,
      AppRoutes.addManualItemRoute,
      AppRoutes.logMaintenanceRoute,
    ]) {
      final settings = RouteSettings(name: routeName, arguments: Object());

      final route = AppRouter.generateRoute(settings);

      expect(route.settings, same(settings));
    }
  });

  testWidgets('route errors show localized recovery actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        locale: const Locale('en'),
        onGenerateRoute: AppRouter.generateRoute,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              Navigator.pushNamed(
                context,
                AppRoutes.vehicleDetailsRoute,
                arguments: 'invalid internal details',
              );
            },
            child: const Text('Open invalid route'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open invalid route'));
    await tester.pumpAndSettle();

    expect(find.text('Unable to open page'), findsOneWidget);
    expect(
      find.text(
        'The page information is incomplete or no longer available. '
        'Go back and try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Go to home'), findsOneWidget);
    expect(find.textContaining('invalid internal details'), findsNothing);
  });
}
