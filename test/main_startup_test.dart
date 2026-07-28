import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carvita/application/ports/app_startup_port.dart';
import 'package:carvita/application/ports/clock.dart';
import 'package:carvita/application/ports/notification_tap_port.dart';
import 'package:carvita/application/ports/reminder_schedule_port.dart';
import 'package:carvita/application/queries/maintenance_data_snapshot.dart';
import 'package:carvita/application/use_cases/load_upcoming_maintenance.dart';
import 'package:carvita/application/use_cases/synchronize_maintenance_reminders.dart';
import 'package:carvita/core/services/notification_coordinator.dart';
import 'package:carvita/core/services/notification_service.dart';
import 'package:carvita/core/services/prediction_service.dart';
import 'package:carvita/core/services/preferences_service.dart';
import 'package:carvita/core/services/quick_action_service.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/data/repositories/maintenance_repository.dart';
import 'package:carvita/data/repositories/vehicle_repository.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/main.dart';
import 'package:carvita/presentation/manager/upcoming_maintenance/upcoming_maintenance_cubit.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('localized startup loads predictions and shortcuts once', (
    tester,
  ) async {
    final vehicleRepository = _CountingVehicleRepository();
    final maintenanceRepository = _FakeMaintenanceRepository();
    final preferences = _FakePreferencesService();
    final platform = _CountingQuickActionPlatform();
    final notificationTaps = _FakeNotificationTaps();
    final reminderSchedule = _FixedReminderSchedule();
    final appStartup = _FakeAppStartup();
    final quickActionService = QuickActionService(
      vehicleRepository: vehicleRepository,
      preferencesService: preferences,
      navigation: const _NoopQuickActionNavigation(),
      platform: platform,
    );
    final upcomingCubit = _upcomingCubit(
      maintenanceRepository,
      preferences,
      reminderSchedule,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppStartupPort>.value(value: appStartup),
          Provider<QuickActionService>.value(value: quickActionService),
          Provider<NotificationTapPort>.value(value: notificationTaps),
          Provider<ReminderSchedulePort>.value(value: reminderSchedule),
          BlocProvider<UpcomingMaintenanceCubit>.value(value: upcomingCubit),
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
          home: const ShortcutLocalizationWrapper(child: SizedBox()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pump();

    expect(maintenanceRepository.snapshotReadCount, 1);
    expect(platform.setItemsCount, 1);
    expect(appStartup.initializeCount, 1);
    await upcomingCubit.close();
  });

  testWidgets('shortcut update failure does not skip startup predictions', (
    tester,
  ) async {
    final vehicleRepository = _CountingVehicleRepository();
    final maintenanceRepository = _FakeMaintenanceRepository();
    final preferences = _FakePreferencesService();
    final platform = _CountingQuickActionPlatform(failSetItems: true);
    final notificationTaps = _FakeNotificationTaps();
    final reminderSchedule = _FixedReminderSchedule();
    final appStartup = _FakeAppStartup();
    final quickActionService = QuickActionService(
      vehicleRepository: vehicleRepository,
      preferencesService: preferences,
      navigation: const _NoopQuickActionNavigation(),
      platform: platform,
    );
    final upcomingCubit = _upcomingCubit(
      maintenanceRepository,
      preferences,
      reminderSchedule,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppStartupPort>.value(value: appStartup),
          Provider<QuickActionService>.value(value: quickActionService),
          Provider<NotificationTapPort>.value(value: notificationTaps),
          Provider<ReminderSchedulePort>.value(value: reminderSchedule),
          BlocProvider<UpcomingMaintenanceCubit>.value(value: upcomingCubit),
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
          home: const ShortcutLocalizationWrapper(child: SizedBox()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(platform.setItemsCount, 1);
    expect(maintenanceRepository.snapshotReadCount, 1);
    expect(tester.takeException(), isNull);
    await upcomingCubit.close();
  });

  testWidgets('resume reloads once when calendar context changed', (
    tester,
  ) async {
    final vehicleRepository = _CountingVehicleRepository();
    final maintenanceRepository = _FakeMaintenanceRepository();
    final preferences = _FakePreferencesService();
    final reminderSchedule = _FixedReminderSchedule();
    final appStartup = _FakeAppStartup();
    final notificationGateway = _NoopNotificationGateway();
    final quickActionService = QuickActionService(
      vehicleRepository: vehicleRepository,
      preferencesService: preferences,
      navigation: const _NoopQuickActionNavigation(),
      platform: _CountingQuickActionPlatform(),
    );
    final upcomingCubit = _upcomingCubit(
      maintenanceRepository,
      preferences,
      reminderSchedule,
      notificationGateway: notificationGateway,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppStartupPort>.value(value: appStartup),
          Provider<QuickActionService>.value(value: quickActionService),
          Provider<NotificationTapPort>.value(value: _FakeNotificationTaps()),
          Provider<ReminderSchedulePort>.value(value: reminderSchedule),
          BlocProvider<UpcomingMaintenanceCubit>.value(value: upcomingCubit),
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
          home: const ShortcutLocalizationWrapper(child: SizedBox()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(notificationGateway.cancelCount, 1);
    expect(maintenanceRepository.snapshotReadCount, 1);

    reminderSchedule.nextContextChanged = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(notificationGateway.cancelCount, 2);
    expect(maintenanceRepository.snapshotReadCount, 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(notificationGateway.cancelCount, 2);
    expect(maintenanceRepository.snapshotReadCount, 2);
    await upcomingCubit.close();
  });

  testWidgets('resolved locale changes refresh shortcuts and reminders', (
    tester,
  ) async {
    final vehicleRepository = _CountingVehicleRepository();
    final maintenanceRepository = _FakeMaintenanceRepository();
    final preferences = _FakePreferencesService();
    final platform = _CountingQuickActionPlatform();
    final reminderSchedule = _FixedReminderSchedule();
    final notificationGateway = _NoopNotificationGateway();
    final quickActionService = QuickActionService(
      vehicleRepository: vehicleRepository,
      preferencesService: preferences,
      navigation: const _NoopQuickActionNavigation(),
      platform: platform,
    );
    final upcomingCubit = _upcomingCubit(
      maintenanceRepository,
      preferences,
      reminderSchedule,
      notificationGateway: notificationGateway,
    );

    Widget app(Locale locale) {
      return MultiProvider(
        providers: [
          Provider<AppStartupPort>.value(value: _FakeAppStartup()),
          Provider<QuickActionService>.value(value: quickActionService),
          Provider<NotificationTapPort>.value(value: _FakeNotificationTaps()),
          Provider<ReminderSchedulePort>.value(value: reminderSchedule),
          BlocProvider<UpcomingMaintenanceCubit>.value(value: upcomingCubit),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ShortcutLocalizationWrapper(child: SizedBox()),
        ),
      );
    }

    await tester.pumpWidget(app(const Locale('en')));
    await tester.pumpAndSettle();
    expect(platform.setItemsCount, 1);
    expect(platform.lastLogTitle, 'Log Maintenance');
    expect(notificationGateway.cancelCount, 1);
    expect(maintenanceRepository.snapshotReadCount, 1);

    await tester.pumpWidget(app(const Locale('de')));
    await tester.pumpAndSettle();

    expect(platform.setItemsCount, 2);
    expect(platform.lastLogTitle, 'Wartung protokollieren');
    expect(notificationGateway.cancelCount, 2);
    expect(maintenanceRepository.snapshotReadCount, 1);
    await upcomingCubit.close();
  });

  testWidgets(
    'recoverable startup failure does not block the first frame or predictions',
    (tester) async {
      final vehicleRepository = _CountingVehicleRepository();
      final maintenanceRepository = _FakeMaintenanceRepository();
      final preferences = _FakePreferencesService();
      final startupGate = Completer<void>();
      final appStartup = _FakeAppStartup(
        gate: startupGate,
        throwOnInitialize: true,
      );
      final quickActionService = QuickActionService(
        vehicleRepository: vehicleRepository,
        preferencesService: preferences,
        navigation: const _NoopQuickActionNavigation(),
        platform: _CountingQuickActionPlatform(),
      );
      final upcomingCubit = _upcomingCubit(
        maintenanceRepository,
        preferences,
        _FixedReminderSchedule(),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppStartupPort>.value(value: appStartup),
            Provider<QuickActionService>.value(value: quickActionService),
            Provider<NotificationTapPort>.value(value: _FakeNotificationTaps()),
            Provider<ReminderSchedulePort>.value(
              value: _FixedReminderSchedule(),
            ),
            BlocProvider<UpcomingMaintenanceCubit>.value(value: upcomingCubit),
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
            home: const ShortcutLocalizationWrapper(
              child: SizedBox(key: Key('dashboard-content')),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('dashboard-content')), findsOne);
      expect(maintenanceRepository.snapshotReadCount, 0);

      startupGate.complete();
      await tester.pumpAndSettle();

      expect(maintenanceRepository.snapshotReadCount, 1);
      expect(tester.takeException(), isNull);
      await upcomingCubit.close();
    },
  );
}

UpcomingMaintenanceCubit _upcomingCubit(
  MaintenanceRepository maintenanceRepository,
  PreferencesService preferences,
  ReminderSchedulePort reminderSchedule, {
  _NoopNotificationGateway? notificationGateway,
}) {
  final clock = _FixedClock(DateTime(2026, 7, 27));
  final notificationCoordinator = NotificationCoordinator(
    notificationGateway ?? _NoopNotificationGateway(),
  );
  return UpcomingMaintenanceCubit(
    LoadUpcomingMaintenance(
      maintenanceRepository,
      PredictionService(clock),
      clock,
    ),
    SynchronizeMaintenanceReminders(
      preferences,
      notificationCoordinator,
      reminderSchedule,
      clock,
    ),
  );
}

class _CountingVehicleRepository extends VehicleRepository {
  int readCount = 0;

  @override
  Future<List<Vehicle>> getVehicles() async {
    readCount++;
    return const [];
  }
}

class _FakeMaintenanceRepository extends MaintenanceRepository {
  int snapshotReadCount = 0;

  @override
  Future<MaintenanceDataSnapshot> getPredictionSnapshot() async {
    snapshotReadCount++;
    return MaintenanceDataSnapshot(
      vehicles: const [],
      planItems: const [],
      serviceLogs: const [],
      performedItemLinks: const [],
    );
  }
}

class _FakePreferencesService extends PreferencesService {
  @override
  Future<bool> getNotificationsEnabled() async => false;
}

class _CountingQuickActionPlatform implements QuickActionPlatform {
  _CountingQuickActionPlatform({this.failSetItems = false});

  final bool failSetItems;
  int setItemsCount = 0;
  String? lastLogTitle;

  @override
  void initialize(ValueChanged<String> onShortcut) {}

  @override
  Future<void> setShortcutItems({
    required String logMaintenanceTitle,
    required String upcomingMaintenanceTitle,
  }) async {
    setItemsCount++;
    lastLogTitle = logMaintenanceTitle;
    if (failSetItems) throw StateError('shortcut platform failed');
  }
}

class _NoopQuickActionNavigation implements QuickActionNavigation {
  const _NoopQuickActionNavigation();

  @override
  bool get isReady => false;

  @override
  void openLogMaintenance({
    required int vehicleId,
    required String vehicleName,
  }) {}

  @override
  void openUpcomingMaintenance() {}

  @override
  void openVehicleSelection(List<Vehicle> vehicles) {}

  @override
  void showNoVehicleMessage() {}
}

class _FixedClock implements Clock {
  const _FixedClock(this.value);

  final DateTime value;

  @override
  DateTime now() => value;
}

class _NoopNotificationGateway implements NotificationGateway {
  int cancelCount = 0;

  @override
  Future<void> cancelAllNotifications() async {
    cancelCount++;
  }

  @override
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    String? payload,
  }) async {}
}

class _FakeNotificationTaps implements NotificationTapPort {
  int navigatorReadyCount = 0;

  @override
  void enqueuePayload(String? payload) {}

  @override
  void navigatorReady() {
    navigatorReadyCount++;
  }
}

class _FixedReminderSchedule implements ReminderSchedulePort {
  bool nextContextChanged = false;

  @override
  DateTime? calculateNotificationTime({
    required DateTime predictedDueDate,
    required int leadTimeDays,
    required DateTime now,
  }) {
    final result = predictedDueDate
        .subtract(Duration(days: leadTimeDays))
        .copyWith(hour: 12, minute: 0, second: 0, millisecond: 0);
    return result.isAfter(now) ? result : null;
  }

  @override
  Future<ReminderScheduleRefresh> refreshTimeZone() async {
    final contextChanged = nextContextChanged;
    nextContextChanged = false;
    return ReminderScheduleRefresh(
      timeZoneChanged: contextChanged,
      calendarDateChanged: false,
      timeZoneId: 'UTC',
      usedFallback: false,
    );
  }
}

class _FakeAppStartup implements AppStartupPort {
  _FakeAppStartup({this.gate, this.throwOnInitialize = false});

  final Completer<void>? gate;
  final bool throwOnInitialize;
  int initializeCount = 0;

  @override
  Future<AppStartupResult> initialize() async {
    initializeCount++;
    await gate?.future;
    if (throwOnInitialize) {
      throw StateError('recoverable startup failure');
    }
    return AppStartupResult(const []);
  }
}
