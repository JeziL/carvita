import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carvita/application/ports/clock.dart';
import 'package:carvita/application/ports/notification_tap_port.dart';
import 'package:carvita/application/ports/reminder_schedule_port.dart';
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
    final quickActionService = QuickActionService(
      vehicleRepository: vehicleRepository,
      preferencesService: preferences,
      navigation: const _NoopQuickActionNavigation(),
      platform: platform,
    );
    final upcomingCubit = _upcomingCubit(
      vehicleRepository,
      maintenanceRepository,
      preferences,
      reminderSchedule,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
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

    expect(vehicleRepository.readCount, 1);
    expect(platform.setItemsCount, 1);
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
    final quickActionService = QuickActionService(
      vehicleRepository: vehicleRepository,
      preferencesService: preferences,
      navigation: const _NoopQuickActionNavigation(),
      platform: platform,
    );
    final upcomingCubit = _upcomingCubit(
      vehicleRepository,
      maintenanceRepository,
      preferences,
      reminderSchedule,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
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
    expect(vehicleRepository.readCount, 1);
    expect(tester.takeException(), isNull);
    await upcomingCubit.close();
  });

  testWidgets('resume reschedules once when time zone context changed', (
    tester,
  ) async {
    final vehicleRepository = _CountingVehicleRepository();
    final maintenanceRepository = _FakeMaintenanceRepository();
    final preferences = _FakePreferencesService();
    final reminderSchedule = _FixedReminderSchedule();
    final notificationGateway = _NoopNotificationGateway();
    final quickActionService = QuickActionService(
      vehicleRepository: vehicleRepository,
      preferencesService: preferences,
      navigation: const _NoopQuickActionNavigation(),
      platform: _CountingQuickActionPlatform(),
    );
    final upcomingCubit = _upcomingCubit(
      vehicleRepository,
      maintenanceRepository,
      preferences,
      reminderSchedule,
      notificationGateway: notificationGateway,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
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

    reminderSchedule.nextContextChanged = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(notificationGateway.cancelCount, 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(notificationGateway.cancelCount, 2);
    await upcomingCubit.close();
  });
}

UpcomingMaintenanceCubit _upcomingCubit(
  VehicleRepository vehicleRepository,
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
      vehicleRepository,
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

class _FakeMaintenanceRepository extends MaintenanceRepository {}

class _FakePreferencesService extends PreferencesService {
  @override
  Future<bool> getNotificationsEnabled() async => false;
}

class _CountingQuickActionPlatform implements QuickActionPlatform {
  _CountingQuickActionPlatform({this.failSetItems = false});

  final bool failSetItems;
  int setItemsCount = 0;

  @override
  void initialize(ValueChanged<String> onShortcut) {}

  @override
  Future<void> setShortcutItems({
    required String logMaintenanceTitle,
    required String upcomingMaintenanceTitle,
  }) async {
    setItemsCount++;
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
