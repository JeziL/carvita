import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:intl/date_symbol_data_local.dart';

import 'package:carvita/application/ports/clock.dart';
import 'package:carvita/application/ports/reminder_schedule_port.dart';
import 'package:carvita/application/reminders/maintenance_reminder_payload.dart';
import 'package:carvita/application/use_cases/load_upcoming_maintenance.dart';
import 'package:carvita/application/use_cases/synchronize_maintenance_reminders.dart';
import 'package:carvita/core/services/notification_coordinator.dart';
import 'package:carvita/core/services/notification_service.dart';
import 'package:carvita/core/services/prediction_service.dart';
import 'package:carvita/core/services/preferences_service.dart';
import 'package:carvita/data/models/maintenance_plan_item.dart';
import 'package:carvita/data/models/service_log_entry.dart';
import 'package:carvita/data/models/service_log_performed_item_link.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/data/repositories/maintenance_repository.dart';
import 'package:carvita/data/repositories/vehicle_repository.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/presentation/manager/upcoming_maintenance/upcoming_maintenance_cubit.dart';
import 'package:carvita/presentation/manager/upcoming_maintenance/upcoming_maintenance_state.dart';

void main() {
  final now = DateTime(2026, 7, 27, 9);

  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  test(
    'disabled notifications replace the platform schedule with empty data',
    () async {
      final gateway = _RecordingNotificationGateway();
      final cubit = _cubit(
        gateway: gateway,
        preferences: _FakePreferencesService(notificationsEnabled: false),
        now: now,
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await cubit.loadAllUpcomingMaintenance(l10n);

      expect(cubit.state, isA<UpcomingMaintenanceLoaded>());
      expect(gateway.events, ['cancelAll']);
      expect(gateway.requests, isEmpty);
      await cubit.close();
    },
  );

  test('enabled notifications use locale and configured lead time', () async {
    final gateway = _RecordingNotificationGateway();
    final cubit = _cubit(
      gateway: gateway,
      preferences: _FakePreferencesService(
        notificationsEnabled: true,
        leadTimeDays: 3,
      ),
      now: now,
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await cubit.loadAllUpcomingMaintenance(l10n);

    expect(cubit.state, isA<UpcomingMaintenanceLoaded>());
    expect(gateway.events, ['cancelAll', 'schedule']);
    final request = gateway.requests.single;
    expect(request.title, 'Maintenance Reminder: Vehicle');
    expect(request.body, contains('Oil'));
    expect(request.scheduledDateTime, DateTime(2026, 12, 29, 12));
    final payload = MaintenanceReminderPayload.tryParse(request.payload);
    expect(payload?.vehicleId, 1);
    expect(payload?.planItemId, 1);
    await cubit.close();
  });

  test('notification platform failure does not discard predictions', () async {
    final gateway = _RecordingNotificationGateway()..failSchedule = true;
    final cubit = _cubit(
      gateway: gateway,
      preferences: _FakePreferencesService(
        notificationsEnabled: true,
        leadTimeDays: 3,
      ),
      now: now,
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await cubit.loadAllUpcomingMaintenance(l10n);

    final state = cubit.state;
    expect(state, isA<UpcomingMaintenanceLoaded>());
    expect((state as UpcomingMaintenanceLoaded).allPredictions, hasLength(1));
    expect(gateway.events, ['cancelAll', 'schedule', 'cancelAll']);
    await cubit.close();
  });

  test(
    'concurrent settings changes coalesce and every caller awaits latest sync',
    () async {
      final gateway = _RecordingNotificationGateway();
      final preferences = _FakePreferencesService(
        notificationsEnabled: false,
        leadTimeDays: 1,
      );
      final cubit = _cubit(
        gateway: gateway,
        preferences: preferences,
        now: now,
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await cubit.loadAllUpcomingMaintenance(l10n);
      gateway
        ..events.clear()
        ..requests.clear();

      preferences.notificationsEnabled = true;
      final enabledReadStarted = Completer<void>();
      final blockedEnabledRead = Completer<bool>();
      preferences
        ..enabledReadStarted = enabledReadStarted
        ..blockedEnabledRead = blockedEnabledRead;

      var firstCompleted = false;
      final firstSync = cubit
          .rescheduleNotificationsBasedOnNewSettings(l10n)
          .whenComplete(() => firstCompleted = true);
      await enabledReadStarted.future;

      preferences.leadTimeDays = 5;
      final latestSync = cubit.rescheduleNotificationsBasedOnNewSettings(l10n);
      await Future<void>.delayed(Duration.zero);
      expect(firstCompleted, isFalse);

      blockedEnabledRead.complete(true);
      await Future.wait([firstSync, latestSync]);

      expect(gateway.events, ['cancelAll', 'schedule']);
      expect(
        gateway.requests.single.scheduledDateTime,
        DateTime(2026, 12, 27, 12),
      );
      await cubit.close();
    },
  );

  test(
    'concurrent data loads keep the latest state and schedule only it',
    () async {
      final gateway = _RecordingNotificationGateway();
      final maintenanceRepository = _BlockingMaintenanceRepository();
      final preferences = _FakePreferencesService(notificationsEnabled: false);
      final cubit = _buildCubit(
        _FakeVehicleRepository(),
        maintenanceRepository,
        gateway,
        preferences,
        now,
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      final staleLoad = cubit.loadAllUpcomingMaintenance(l10n);
      await maintenanceRepository.firstPlanReadStarted.future;
      final latestLoad = cubit.loadAllUpcomingMaintenance(l10n);
      await latestLoad;

      maintenanceRepository.firstPlans.complete([
        const MaintenancePlanItem(
          id: 1,
          vehicleId: 1,
          itemName: 'Stale oil',
          intervalTimeMonths: 12,
        ),
      ]);
      await staleLoad;

      final state = cubit.state as UpcomingMaintenanceLoaded;
      expect(state.allPredictions.single.planItem.itemName, 'Latest oil');
      expect(gateway.events, ['cancelAll']);
      await cubit.close();
    },
  );

  test(
    'a superseded data caller waits for the latest load to finish',
    () async {
      final gateway = _RecordingNotificationGateway();
      final maintenanceRepository = _TwoBlockedMaintenanceRepository();
      final cubit = _buildCubit(
        _FakeVehicleRepository(),
        maintenanceRepository,
        gateway,
        _FakePreferencesService(notificationsEnabled: false),
        now,
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      var staleCompleted = false;
      final staleLoad = cubit
          .loadAllUpcomingMaintenance(l10n)
          .whenComplete(() => staleCompleted = true);
      await maintenanceRepository.firstPlanReadStarted.future;
      final latestLoad = cubit.loadAllUpcomingMaintenance(l10n);
      await maintenanceRepository.secondPlanReadStarted.future;

      maintenanceRepository.firstPlans.complete([
        const MaintenancePlanItem(
          id: 1,
          vehicleId: 1,
          itemName: 'Stale oil',
          intervalTimeMonths: 12,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(staleCompleted, isFalse);

      maintenanceRepository.secondPlans.complete([
        const MaintenancePlanItem(
          id: 2,
          vehicleId: 1,
          itemName: 'Latest oil',
          intervalTimeMonths: 12,
        ),
      ]);
      await Future.wait([staleLoad, latestLoad]);

      final state = cubit.state as UpcomingMaintenanceLoaded;
      expect(state.allPredictions.single.planItem.itemName, 'Latest oil');
      expect(gateway.events, ['cancelAll']);
      await cubit.close();
    },
  );
}

UpcomingMaintenanceCubit _cubit({
  required _RecordingNotificationGateway gateway,
  required _FakePreferencesService preferences,
  required DateTime now,
}) {
  return _buildCubit(
    _FakeVehicleRepository(),
    _FakeMaintenanceRepository(),
    gateway,
    preferences,
    now,
  );
}

UpcomingMaintenanceCubit _buildCubit(
  VehicleRepository vehicleRepository,
  MaintenanceRepository maintenanceRepository,
  NotificationGateway gateway,
  PreferencesService preferences,
  DateTime now,
) {
  final clock = _FixedClock(now);
  return UpcomingMaintenanceCubit(
    LoadUpcomingMaintenance(
      vehicleRepository,
      maintenanceRepository,
      PredictionService(clock),
      clock,
    ),
    SynchronizeMaintenanceReminders(
      preferences,
      NotificationCoordinator(gateway),
      _FixedReminderSchedule(),
      clock,
    ),
  );
}

Vehicle _vehicle() {
  return Vehicle(
    id: 1,
    name: 'Vehicle',
    mileage: 1000,
    mileageLastUpdated: DateTime(2026, 7, 1),
    boughtDate: DateTime(2026, 1, 1),
  );
}

class _FakeVehicleRepository extends VehicleRepository {
  @override
  Future<List<Vehicle>> getVehicles() async => [_vehicle()];
}

class _FakeMaintenanceRepository extends MaintenanceRepository {
  @override
  Future<List<MaintenancePlanItem>> getPlanItems(int vehicleId) async {
    return const [
      MaintenancePlanItem(
        id: 1,
        vehicleId: 1,
        itemName: 'Oil',
        intervalTimeMonths: 12,
      ),
    ];
  }

  @override
  Future<List<ServiceLogWithItems>> getServiceLogs(int vehicleId) async {
    return const [];
  }

  @override
  Future<List<ServiceLogPerformedItemLink>> getPerformedItemLinksForVehicle(
    int vehicleId,
  ) async {
    return const [];
  }
}

class _FakePreferencesService extends PreferencesService {
  _FakePreferencesService({
    required this.notificationsEnabled,
    this.leadTimeDays = 7,
  });

  bool notificationsEnabled;
  int leadTimeDays;
  Completer<void>? enabledReadStarted;
  Completer<bool>? blockedEnabledRead;

  @override
  Future<bool> getNotificationsEnabled() async {
    final blocker = blockedEnabledRead;
    if (blocker != null) {
      blockedEnabledRead = null;
      enabledReadStarted?.complete();
      enabledReadStarted = null;
      return blocker.future;
    }
    return notificationsEnabled;
  }

  @override
  Future<int> getReminderLeadTimeDays() async => leadTimeDays;
}

class _BlockingMaintenanceRepository extends MaintenanceRepository {
  final firstPlanReadStarted = Completer<void>();
  final firstPlans = Completer<List<MaintenancePlanItem>>();
  int planReadCount = 0;

  @override
  Future<List<MaintenancePlanItem>> getPlanItems(int vehicleId) {
    planReadCount++;
    if (planReadCount == 1) {
      firstPlanReadStarted.complete();
      return firstPlans.future;
    }
    return Future.value(const [
      MaintenancePlanItem(
        id: 2,
        vehicleId: 1,
        itemName: 'Latest oil',
        intervalTimeMonths: 12,
      ),
    ]);
  }

  @override
  Future<List<ServiceLogWithItems>> getServiceLogs(int vehicleId) async {
    return const [];
  }

  @override
  Future<List<ServiceLogPerformedItemLink>> getPerformedItemLinksForVehicle(
    int vehicleId,
  ) async {
    return const [];
  }
}

class _TwoBlockedMaintenanceRepository extends MaintenanceRepository {
  final firstPlanReadStarted = Completer<void>();
  final secondPlanReadStarted = Completer<void>();
  final firstPlans = Completer<List<MaintenancePlanItem>>();
  final secondPlans = Completer<List<MaintenancePlanItem>>();
  int planReadCount = 0;

  @override
  Future<List<MaintenancePlanItem>> getPlanItems(int vehicleId) {
    planReadCount++;
    if (planReadCount == 1) {
      firstPlanReadStarted.complete();
      return firstPlans.future;
    }
    secondPlanReadStarted.complete();
    return secondPlans.future;
  }

  @override
  Future<List<ServiceLogWithItems>> getServiceLogs(int vehicleId) async {
    return const [];
  }

  @override
  Future<List<ServiceLogPerformedItemLink>> getPerformedItemLinksForVehicle(
    int vehicleId,
  ) async {
    return const [];
  }
}

class _RecordingNotificationGateway implements NotificationGateway {
  final List<String> events = [];
  final List<NotificationRequest> requests = [];
  bool failSchedule = false;

  @override
  Future<void> cancelAllNotifications() async {
    events.add('cancelAll');
  }

  @override
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    String? payload,
  }) async {
    events.add('schedule');
    if (failSchedule) throw StateError('platform failed');
    requests.add(
      NotificationRequest(
        id: id,
        title: title,
        body: body,
        scheduledDateTime: scheduledDateTime,
        payload: payload,
      ),
    );
  }
}

class _FixedClock implements Clock {
  const _FixedClock(this.value);

  final DateTime value;

  @override
  DateTime now() => value;
}

class _FixedReminderSchedule implements ReminderSchedulePort {
  @override
  DateTime? calculateNotificationTime({
    required DateTime predictedDueDate,
    required int leadTimeDays,
    required DateTime now,
  }) {
    final result = predictedDueDate
        .subtract(Duration(days: leadTimeDays))
        .copyWith(
          hour: 12,
          minute: 0,
          second: 0,
          millisecond: 0,
          microsecond: 0,
        );
    return result.isAfter(now) ? result : null;
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
