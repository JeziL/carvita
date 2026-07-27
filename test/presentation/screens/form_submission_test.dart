import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carvita/core/services/preferences_service.dart';
import 'package:carvita/core/theme/app_theme.dart';
import 'package:carvita/data/models/maintenance_plan_item.dart';
import 'package:carvita/data/models/service_log_entry.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/data/repositories/maintenance_repository.dart';
import 'package:carvita/data/repositories/vehicle_repository.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/presentation/manager/locale_provider.dart';
import 'package:carvita/presentation/manager/maintenance_plan/maintenance_plan_cubit.dart';
import 'package:carvita/presentation/manager/service_log/service_log_cubit.dart';
import 'package:carvita/presentation/manager/vehicle_list/vehicle_cubit.dart';
import 'package:carvita/presentation/screens/maintenance/add_edit_maintenance_plan_item_screen.dart';
import 'package:carvita/presentation/screens/maintenance/log_maintenance_screen.dart';
import 'package:carvita/presentation/screens/vehicle/add_edit_vehicle_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('vehicle form ignores a second submit while saving', (
    tester,
  ) async {
    final repository = _BlockingVehicleRepository();
    final cubit = VehicleCubit(repository);

    await tester.pumpWidget(
      _testApp(
        providers: [BlocProvider<VehicleCubit>.value(value: cubit)],
        child: AddEditVehicleScreen(vehicle: _vehicle()),
      ),
    );
    await tester.pumpAndSettle();

    final submit = find.widgetWithText(ElevatedButton, 'Save changes');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(repository.updateCount, 1);
    expect(find.byKey(const ValueKey('vehicle-submit-progress')), findsOne);

    await tester.pumpWidget(const SizedBox());
    await cubit.close();
    repository.updateCompleter.complete();
    await tester.pump();
  });

  testWidgets('plan form ignores a second submit while saving', (tester) async {
    final repository = _BlockingMaintenanceRepository();
    final planCubit = MaintenancePlanCubit(repository, 1);
    final logCubit = ServiceLogCubit(repository, 1);

    await tester.pumpWidget(
      _testApp(
        providers: [
          BlocProvider<MaintenancePlanCubit>.value(value: planCubit),
          BlocProvider<ServiceLogCubit>.value(value: logCubit),
        ],
        child: AddEditMaintenancePlanItemScreen(
          vehicleId: 1,
          vehicleName: 'Vehicle',
          planItemToEdit: _planItem(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final submit = find.widgetWithText(ElevatedButton, 'Save changes');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(repository.planUpdateCount, 1);
    expect(find.byKey(const ValueKey('plan-submit-progress')), findsOne);

    await tester.pumpWidget(const SizedBox());
    await planCubit.close();
    await logCubit.close();
    repository.planUpdateCompleter.complete();
    await tester.pump();
  });

  testWidgets('service log form ignores a second submit while saving', (
    tester,
  ) async {
    final repository = _BlockingMaintenanceRepository();
    final planCubit = MaintenancePlanCubit(repository, 1);
    final logCubit = ServiceLogCubit(repository, 1);

    await tester.pumpWidget(
      _testApp(
        providers: [
          BlocProvider<MaintenancePlanCubit>.value(value: planCubit),
          BlocProvider<ServiceLogCubit>.value(value: logCubit),
        ],
        child: LogMaintenanceScreen(
          vehicleId: 1,
          vehicleName: 'Vehicle',
          logToEdit: _serviceLog(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final submit = find.widgetWithText(ElevatedButton, 'Save changes');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(repository.logUpdateCount, 1);
    expect(find.byKey(const ValueKey('log-submit-progress')), findsOne);

    await tester.pumpWidget(const SizedBox());
    await planCubit.close();
    await logCubit.close();
    repository.logUpdateCompleter.complete(true);
    await tester.pump();
  });

  testWidgets('vehicle write failure keeps input and re-enables submit', (
    tester,
  ) async {
    final repository = _BlockingVehicleRepository()
      ..writeError = StateError('write failed');
    final cubit = VehicleCubit(repository);

    await tester.pumpWidget(
      _testApp(
        providers: [BlocProvider<VehicleCubit>.value(value: cubit)],
        child: AddEditVehicleScreen(vehicle: _vehicle()),
      ),
    );
    await tester.pumpAndSettle();

    final submit = find.widgetWithText(ElevatedButton, 'Save changes');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Vehicle'), findsWidgets);
    expect(find.text('Bad state: write failed'), findsOne);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Save changes'),
          )
          .onPressed,
      isNotNull,
    );

    await cubit.close();
  });
}

Widget _testApp({
  required List<SingleChildWidget> providers,
  required Widget child,
}) {
  final preferences = PreferencesService();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LocaleProvider>(
        create: (_) => LocaleProvider(preferences),
      ),
      ...providers,
    ],
    child: MaterialApp(
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
      home: child,
    ),
  );
}

Vehicle _vehicle() {
  return Vehicle(
    id: 1,
    name: 'Vehicle',
    mileage: 1000,
    mileageLastUpdated: DateTime(2026, 1, 1),
    boughtDate: DateTime(2025, 1, 1),
  );
}

MaintenancePlanItem _planItem() {
  return const MaintenancePlanItem(
    id: 1,
    vehicleId: 1,
    itemName: 'Oil',
    intervalTimeMonths: 12,
  );
}

ServiceLogWithItems _serviceLog() {
  return ServiceLogWithItems(
    entry: ServiceLogEntry(
      id: 1,
      vehicleId: 1,
      serviceDate: DateTime(2026, 1, 1),
      mileageAtService: 1000,
    ),
    performedItems: const [
      ServiceLogPerformedItem(
        id: 1,
        serviceLogId: 1,
        customItemName: 'Inspection',
        displayName: 'Inspection',
      ),
    ],
  );
}

class _BlockingVehicleRepository extends VehicleRepository {
  final Completer<void> updateCompleter = Completer<void>();
  int updateCount = 0;
  Object? writeError;

  @override
  Future<void> updateVehicle(Vehicle vehicle) async {
    updateCount++;
    if (writeError case final error?) throw error;
    await updateCompleter.future;
  }

  @override
  Future<List<Vehicle>> getVehicles() async => [_vehicle()];
}

class _BlockingMaintenanceRepository extends MaintenanceRepository {
  final Completer<void> planUpdateCompleter = Completer<void>();
  final Completer<bool> logUpdateCompleter = Completer<bool>();
  int planUpdateCount = 0;
  int logUpdateCount = 0;

  @override
  Future<List<MaintenancePlanItem>> getPlanItems(int vehicleId) async => [
    _planItem(),
  ];

  @override
  Future<void> updatePlanItem(MaintenancePlanItem item) async {
    planUpdateCount++;
    await planUpdateCompleter.future;
  }

  @override
  Future<List<ServiceLogWithItems>> getServiceLogs(int vehicleId) async => [
    _serviceLog(),
  ];

  @override
  Future<bool> updateServiceLog(
    ServiceLogEntry logEntry,
    List<PerformedItemInput> performedItems,
  ) async {
    logUpdateCount++;
    return logUpdateCompleter.future;
  }
}
