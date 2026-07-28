import 'package:flutter_test/flutter_test.dart';

import 'package:carvita/application/ports/clock.dart';
import 'package:carvita/application/ports/notification_tap_port.dart';
import 'package:carvita/core/services/notification_service.dart';

void main() {
  test('cold-start and runtime taps enter the same payload sink', () async {
    final platform = _FakeLocalNotificationsPlatform(
      launchPayload: 'cold-start',
    );
    final taps = _RecordingNotificationTaps();
    final service = NotificationService(
      _FixedClock(DateTime(2026, 7, 27)),
      taps,
      platform: platform,
    );

    await service.initialize();
    platform.emitTap('runtime-resume');

    expect(taps.payloads, ['cold-start', 'runtime-resume']);
  });

  test('a normal launch does not enqueue an empty payload', () async {
    final platform = _FakeLocalNotificationsPlatform();
    final taps = _RecordingNotificationTaps();
    final service = NotificationService(
      _FixedClock(DateTime(2026, 7, 27)),
      taps,
      platform: platform,
    );

    await service.initialize();

    expect(taps.payloads, isEmpty);
  });

  test('past notifications are skipped before reaching the platform', () async {
    final platform = _FakeLocalNotificationsPlatform();
    final service = NotificationService(
      _FixedClock(DateTime(2026, 7, 27, 13)),
      _RecordingNotificationTaps(),
      platform: platform,
    );

    await service.scheduleNotification(
      id: 1,
      title: 'Title',
      body: 'Body',
      scheduledDateTime: DateTime(2026, 7, 27, 12),
    );
    await service.scheduleNotification(
      id: 2,
      title: 'Title',
      body: 'Body',
      scheduledDateTime: DateTime(2026, 7, 28, 12),
      payload: 'payload',
    );

    expect(platform.scheduledIds, [2]);
    expect(platform.scheduledPayloads, ['payload']);
  });
}

class _FixedClock implements Clock {
  const _FixedClock(this.value);

  final DateTime value;

  @override
  DateTime now() => value;
}

class _RecordingNotificationTaps implements NotificationTapPort {
  final List<String?> payloads = [];

  @override
  void enqueuePayload(String? payload) {
    payloads.add(payload);
  }

  @override
  void navigatorReady() {}
}

class _FakeLocalNotificationsPlatform implements LocalNotificationsPlatform {
  _FakeLocalNotificationsPlatform({this.launchPayload});

  final String? launchPayload;
  NotificationPayloadCallback? _onTap;
  final List<int> scheduledIds = [];
  final List<String?> scheduledPayloads = [];

  void emitTap(String? payload) {
    _onTap?.call(payload);
  }

  @override
  Future<void> initialize(NotificationPayloadCallback onNotificationTap) async {
    _onTap = onNotificationTap;
  }

  @override
  Future<String?> getLaunchPayload() async => launchPayload;

  @override
  Future<bool> checkPermissions() async => true;

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> cancelAllNotifications() async {}

  @override
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    String? payload,
  }) async {
    scheduledIds.add(id);
    scheduledPayloads.add(payload);
  }
}
