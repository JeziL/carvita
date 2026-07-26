import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:carvita/core/services/notification_coordinator.dart';
import 'package:carvita/core/services/notification_service.dart';

void main() {
  test('maintenance notification ids are stable across app runs', () {
    expect(maintenanceNotificationId(vehicleId: 1, planItemId: 1), 309261797);
    expect(
      maintenanceNotificationId(vehicleId: 42, planItemId: 99),
      1008498220,
    );
  });

  group('NotificationCoordinator', () {
    test('replaces the platform schedule in request order', () async {
      final gateway = _FakeNotificationGateway();
      final coordinator = NotificationCoordinator(gateway);
      final request = _request(id: 1);

      await coordinator.replaceAll([request]);

      expect(gateway.events, ['cancelAll', 'schedule:1']);
      expect(gateway.scheduledRequests.single.id, request.id);
      expect(gateway.scheduledRequests.single.title, request.title);
      expect(
        gateway.scheduledRequests.single.scheduledDateTime,
        request.scheduledDateTime,
      );
    });

    test('a newer replacement supersedes an in-flight replacement', () async {
      final blockedCancel = Completer<void>();
      final gateway = _FakeNotificationGateway()..blockedCancel = blockedCancel;
      final coordinator = NotificationCoordinator(gateway);

      final firstReplacement = coordinator.replaceAll([_request(id: 1)]);
      await gateway.firstCancelStarted.future;

      final latestReplacement = coordinator.replaceAll([_request(id: 2)]);
      blockedCancel.complete();

      await Future.wait([firstReplacement, latestReplacement]);

      expect(gateway.events, ['cancelAll', 'cancelAll', 'schedule:2']);
      expect(gateway.scheduledRequests.map((request) => request.id), [2]);
    });

    test('coalesces queued replacements and completes every caller', () async {
      final blockedCancel = Completer<void>();
      final gateway = _FakeNotificationGateway()..blockedCancel = blockedCancel;
      final coordinator = NotificationCoordinator(gateway);

      final firstReplacement = coordinator.replaceAll([_request(id: 1)]);
      await gateway.firstCancelStarted.future;
      final secondReplacement = coordinator.replaceAll([_request(id: 2)]);
      final latestReplacement = coordinator.replaceAll([_request(id: 3)]);

      blockedCancel.complete();
      await Future.wait([
        firstReplacement,
        secondReplacement,
        latestReplacement,
      ]);

      expect(gateway.events, ['cancelAll', 'cancelAll', 'schedule:3']);
      expect(gateway.scheduledRequests.map((request) => request.id), [3]);
    });

    test('a failed replacement does not prevent a later repair', () async {
      final gateway = _FakeNotificationGateway()..failNextSchedule = true;
      final coordinator = NotificationCoordinator(gateway);

      await expectLater(
        coordinator.replaceAll([_request(id: 1)]),
        throwsStateError,
      );
      await coordinator.replaceAll([_request(id: 2)]);

      expect(gateway.events, [
        'cancelAll',
        'schedule:1',
        'cancelAll',
        'cancelAll',
        'schedule:2',
      ]);
      expect(gateway.scheduledRequests.map((request) => request.id), [2]);
    });
  });
}

NotificationRequest _request({required int id}) {
  return NotificationRequest(
    id: id,
    title: 'title $id',
    body: 'body $id',
    scheduledDateTime: DateTime(2030, 1, id, 12),
    payload: 'payload $id',
  );
}

class _FakeNotificationGateway implements NotificationGateway {
  final List<String> events = [];
  final List<NotificationRequest> scheduledRequests = [];
  final Completer<void> firstCancelStarted = Completer<void>();
  Completer<void>? blockedCancel;
  bool failNextSchedule = false;

  @override
  Future<void> cancelAllNotifications() async {
    events.add('cancelAll');
    if (!firstCancelStarted.isCompleted) {
      firstCancelStarted.complete();
    }
    final blocker = blockedCancel;
    blockedCancel = null;
    if (blocker != null) {
      await blocker.future;
    }
  }

  @override
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    String? payload,
  }) async {
    events.add('schedule:$id');
    if (failNextSchedule) {
      failNextSchedule = false;
      throw StateError('platform scheduling failed');
    }
    scheduledRequests.add(
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
