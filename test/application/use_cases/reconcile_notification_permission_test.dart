import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:carvita/application/ports/notification_permission_port.dart';
import 'package:carvita/application/ports/preferences_ports.dart';
import 'package:carvita/application/use_cases/reconcile_notification_permission.dart';

void main() {
  test(
    'does not inspect or request permission when reminders are off',
    () async {
      final preferences = _ReminderPreferences(enabled: false);
      final notifications = _NotificationPermissions(granted: false);
      final reconcile = ReconcileNotificationPermission(
        preferences,
        notifications,
      );

      expect(await reconcile(), isFalse);
      expect(notifications.checkCount, 0);
      expect(notifications.requestCount, 0);
      expect(notifications.cancelCount, 0);
      expect(preferences.setCount, 0);
    },
  );

  test('keeps the opt-in when system permission is granted', () async {
    final preferences = _ReminderPreferences(enabled: true);
    final notifications = _NotificationPermissions(granted: true);
    final reconcile = ReconcileNotificationPermission(
      preferences,
      notifications,
    );

    expect(await reconcile(), isFalse);
    expect(preferences.enabled, isTrue);
    expect(preferences.setCount, 0);
    expect(notifications.requestCount, 0);
    expect(notifications.cancelCount, 0);
  });

  test('turns reminders off without requesting missing permission', () async {
    final preferences = _ReminderPreferences(enabled: true);
    final notifications = _NotificationPermissions(granted: false);
    final reconcile = ReconcileNotificationPermission(
      preferences,
      notifications,
    );

    expect(await reconcile(), isTrue);
    expect(preferences.enabled, isFalse);
    expect(preferences.setCount, 1);
    expect(notifications.checkCount, 1);
    expect(notifications.requestCount, 0);
    expect(notifications.cancelCount, 1);
  });

  test('concurrent callers share one permission reconciliation', () async {
    final gate = Completer<void>();
    final preferences = _ReminderPreferences(enabled: true);
    final notifications = _NotificationPermissions(
      granted: false,
      checkGate: gate,
    );
    final reconcile = ReconcileNotificationPermission(
      preferences,
      notifications,
    );

    final first = reconcile();
    final second = reconcile();
    expect(first, same(second));

    gate.complete();
    expect(await first, isTrue);
    expect(notifications.checkCount, 1);
    expect(notifications.cancelCount, 1);
    expect(preferences.setCount, 1);
  });

  test(
    'keeps the saved opt-in off when notification cancellation fails',
    () async {
      final preferences = _ReminderPreferences(enabled: true);
      final notifications = _NotificationPermissions(
        granted: false,
        cancelError: StateError('platform unavailable'),
      );
      final reconcile = ReconcileNotificationPermission(
        preferences,
        notifications,
      );

      await expectLater(reconcile(), throwsStateError);
      expect(preferences.enabled, isFalse);
      expect(preferences.setCount, 1);
      expect(notifications.requestCount, 0);
    },
  );
}

final class _ReminderPreferences implements ReminderPreferences {
  _ReminderPreferences({required this.enabled});

  bool enabled;
  int setCount = 0;

  @override
  Future<bool> getNotificationsEnabled() async => enabled;

  @override
  Future<int> getReminderLeadTimeDays() async => 7;

  @override
  Future<void> setNotificationsEnabled(bool enabled) async {
    setCount++;
    this.enabled = enabled;
  }
}

final class _NotificationPermissions implements NotificationPermissionGateway {
  _NotificationPermissions({
    required this.granted,
    this.checkGate,
    this.cancelError,
  });

  bool granted;
  final Completer<void>? checkGate;
  final Object? cancelError;
  int checkCount = 0;
  int requestCount = 0;
  int cancelCount = 0;

  @override
  Future<bool> checkPermissions() async {
    checkCount++;
    await checkGate?.future;
    return granted;
  }

  @override
  Future<bool> requestPermissions() async {
    requestCount++;
    return granted;
  }

  @override
  Future<void> cancelAllNotifications() async {
    cancelCount++;
    final error = cancelError;
    if (error != null) throw error;
  }
}
