import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carvita/application/ports/clock.dart';
import 'package:carvita/application/ports/reminder_schedule_port.dart';
import 'package:carvita/application/use_cases/load_upcoming_maintenance.dart';
import 'package:carvita/application/use_cases/maintenance_plan_use_cases.dart';
import 'package:carvita/application/use_cases/service_log_use_cases.dart';
import 'package:carvita/application/use_cases/synchronize_maintenance_reminders.dart';
import 'package:carvita/application/use_cases/vehicle_use_cases.dart';
import 'package:carvita/core/services/notification_coordinator.dart';
import 'package:carvita/core/services/notification_service.dart';
import 'package:carvita/core/services/prediction_service.dart';
import 'package:carvita/core/services/preferences_service.dart';
import 'package:carvita/core/theme/app_theme.dart';
import 'package:carvita/data/models/maintenance_plan_item.dart';
import 'package:carvita/data/models/service_log_entry.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/data/repositories/maintenance_repository.dart';
import 'package:carvita/data/repositories/vehicle_repository.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/presentation/manager/locale_provider.dart';
import 'package:carvita/presentation/manager/upcoming_maintenance/upcoming_maintenance_cubit.dart';
import 'package:carvita/presentation/manager/vehicle_list/vehicle_cubit.dart';
import 'package:carvita/presentation/navigation/app_route_arguments.dart';
import 'package:carvita/presentation/screens/vehicle/vehicle_details_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('slow and null vehicle loads never build vehicle actions', (
    tester,
  ) async {
    final vehicleRepository = _DeferredVehicleRepository();
    final maintenanceRepository = _CountingMaintenanceRepository();
    final preferences = PreferencesService();
    final vehicleUseCases = VehicleUseCases(vehicleRepository, preferences);
    final maintenancePlanUseCases = MaintenancePlanUseCases(
      maintenanceRepository,
    );
    final serviceLogUseCases = ServiceLogUseCases(maintenanceRepository);
    final vehicleCubit = VehicleCubit(vehicleUseCases);

    await tester.pumpWidget(
      _testApp(
        vehicleCubit: vehicleCubit,
        vehicleRepository: vehicleRepository,
        maintenanceRepository: maintenanceRepository,
        vehicleUseCases: vehicleUseCases,
        maintenancePlanUseCases: maintenancePlanUseCases,
        serviceLogUseCases: serviceLogUseCases,
        child: VehicleDetailsScreen(
          vehicleId: 1,
          vehicleUseCases: vehicleUseCases,
          maintenancePlanUseCases: maintenancePlanUseCases,
          serviceLogUseCases: serviceLogUseCases,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOne);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(tester.takeException(), isNull);

    vehicleRepository.completer.complete(null);
    await tester.pumpAndSettle();

    expect(find.text('This vehicle may have been deleted.'), findsOne);
    expect(find.text('Back'), findsOne);
    expect(find.text('Retry'), findsOne);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(maintenanceRepository.planReads, 0);
    expect(maintenanceRepository.logReads, 0);
    expect(tester.takeException(), isNull);
    await vehicleCubit.close();
  });

  testWidgets('loaded vehicle creates each tab resource once', (tester) async {
    final vehicleRepository = _DeferredVehicleRepository()
      ..completer.complete(_vehicle());
    final maintenanceRepository = _CountingMaintenanceRepository();
    final preferences = PreferencesService();
    final vehicleUseCases = VehicleUseCases(vehicleRepository, preferences);
    final maintenancePlanUseCases = MaintenancePlanUseCases(
      maintenanceRepository,
    );
    final serviceLogUseCases = ServiceLogUseCases(maintenanceRepository);
    final vehicleCubit = VehicleCubit(vehicleUseCases);

    await tester.pumpWidget(
      _testApp(
        vehicleCubit: vehicleCubit,
        vehicleRepository: vehicleRepository,
        maintenanceRepository: maintenanceRepository,
        vehicleUseCases: vehicleUseCases,
        maintenancePlanUseCases: maintenancePlanUseCases,
        serviceLogUseCases: serviceLogUseCases,
        child: VehicleDetailsScreen(
          vehicleId: 1,
          initialTab: VehicleDetailsTab.maintenancePlan,
          vehicleUseCases: vehicleUseCases,
          maintenancePlanUseCases: maintenancePlanUseCases,
          serviceLogUseCases: serviceLogUseCases,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOne);
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.controller?.index, VehicleDetailsTab.maintenancePlan.index);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(maintenanceRepository.planReads, 1);
    expect(maintenanceRepository.logReads, 1);
    expect(tester.takeException(), isNull);
    await vehicleCubit.close();
  });
}

Widget _testApp({
  required VehicleCubit vehicleCubit,
  required VehicleRepository vehicleRepository,
  required MaintenanceRepository maintenanceRepository,
  required VehicleUseCases vehicleUseCases,
  required MaintenancePlanUseCases maintenancePlanUseCases,
  required ServiceLogUseCases serviceLogUseCases,
  required Widget child,
}) {
  final preferences = PreferencesService();
  const clock = SystemClock();
  final notificationCoordinator = NotificationCoordinator(
    _NoopNotificationGateway(),
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LocaleProvider(preferences)),
      Provider<VehicleUseCases>.value(value: vehicleUseCases),
      Provider<MaintenancePlanUseCases>.value(value: maintenancePlanUseCases),
      Provider<ServiceLogUseCases>.value(value: serviceLogUseCases),
      BlocProvider<VehicleCubit>.value(value: vehicleCubit),
      BlocProvider(
        create: (_) => UpcomingMaintenanceCubit(
          LoadUpcomingMaintenance(
            vehicleRepository,
            maintenanceRepository,
            PredictionService(clock),
            clock,
          ),
          SynchronizeMaintenanceReminders(
            preferences,
            notificationCoordinator,
            _FixedReminderSchedule(),
            clock,
          ),
        ),
      ),
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

class _DeferredVehicleRepository extends VehicleRepository {
  final Completer<Vehicle?> completer = Completer<Vehicle?>();

  @override
  Future<Vehicle?> getVehicleById(int id) => completer.future;
}

class _NoopNotificationGateway implements NotificationGateway {
  @override
  Future<void> cancelAllNotifications() async {}

  @override
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    String? payload,
  }) async {}
}

class _FixedReminderSchedule implements ReminderSchedulePort {
  @override
  DateTime? calculateNotificationTime({
    required DateTime predictedDueDate,
    required int leadTimeDays,
    required DateTime now,
  }) {
    return predictedDueDate
        .subtract(Duration(days: leadTimeDays))
        .copyWith(hour: 12);
  }

  @override
  Future<ReminderScheduleRefresh> refreshTimeZone() async {
    return const ReminderScheduleRefresh(
      timeZoneChanged: false,
      calendarDateChanged: false,
      timeZoneId: 'UTC',
      usedFallback: false,
    );
  }
}

class _CountingMaintenanceRepository extends MaintenanceRepository {
  int planReads = 0;
  int logReads = 0;

  @override
  Future<List<MaintenancePlanItem>> getPlanItems(int vehicleId) async {
    planReads++;
    return const [];
  }

  @override
  Future<List<ServiceLogWithItems>> getServiceLogs(int vehicleId) async {
    logReads++;
    return const [];
  }
}
