import 'package:flutter/foundation.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:carvita/application/ports/clock.dart';
import 'package:carvita/application/ports/notification_tap_port.dart';

typedef NotificationPayloadCallback = void Function(String? payload);

abstract interface class NotificationGateway {
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    String? payload,
  });

  Future<void> cancelAllNotifications();
}

abstract interface class NotificationPermissionGateway {
  Future<bool> requestPermissions();

  Future<bool> checkPermissions();

  Future<void> cancelAllNotifications();
}

abstract interface class LocalNotificationsPlatform {
  Future<void> initialize(NotificationPayloadCallback onNotificationTap);

  Future<String?> getLaunchPayload();

  Future<bool> requestPermissions();

  Future<bool> checkPermissions();

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    String? payload,
  });

  Future<void> cancelAllNotifications();
}

class NotificationService
    implements NotificationGateway, NotificationPermissionGateway {
  NotificationService(
    this._clock,
    this._notificationTaps, {
    LocalNotificationsPlatform? platform,
  }) : _platform = platform ?? PluginLocalNotificationsPlatform();

  final Clock _clock;
  final NotificationTapPort _notificationTaps;
  final LocalNotificationsPlatform _platform;

  Future<void> initialize() async {
    await _platform.initialize(_notificationTaps.enqueuePayload);
    final launchPayload = await _platform.getLaunchPayload();
    if (launchPayload != null) {
      _notificationTaps.enqueuePayload(launchPayload);
    }
  }

  @override
  Future<bool> requestPermissions() {
    return _platform.requestPermissions();
  }

  @override
  Future<bool> checkPermissions() {
    return _platform.checkPermissions();
  }

  @override
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    String? payload,
  }) async {
    if (!scheduledDateTime.isAfter(_clock.now())) {
      return;
    }
    await _platform.scheduleNotification(
      id: id,
      title: title,
      body: body,
      scheduledDateTime: scheduledDateTime,
      payload: payload,
    );
  }

  @override
  Future<void> cancelAllNotifications() {
    return _platform.cancelAllNotifications();
  }
}

class PluginLocalNotificationsPlatform implements LocalNotificationsPlatform {
  PluginLocalNotificationsPlatform({
    FlutterLocalNotificationsPlugin? notificationsPlugin,
  }) : _notificationsPlugin =
           notificationsPlugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _notificationsPlugin;

  @override
  Future<void> initialize(NotificationPayloadCallback onNotificationTap) async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        onNotificationTap(response.payload);
      },
      onDidReceiveBackgroundNotificationResponse:
          onDidReceiveBackgroundNotificationResponse,
    );
  }

  @override
  Future<String?> getLaunchPayload() async {
    final launchDetails = await _notificationsPlugin
        .getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp != true) return null;
    return launchDetails?.notificationResponse?.payload;
  }

  @override
  Future<bool> requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final result = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? false;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final result = await androidImplementation
          ?.requestNotificationsPermission();
      return result ?? false;
    }
    return true;
  }

  @override
  Future<bool> checkPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final result = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.checkPermissions();
      return result?.isEnabled ?? false;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final result = await androidImplementation?.areNotificationsEnabled();
      return result ?? false;
    }
    return true;
  }

  @override
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    String? payload,
  }) async {
    final tzScheduledDate = tz.TZDateTime.from(scheduledDateTime, tz.local);

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'carvita_channel_id',
          'CarVita Reminders',
          channelDescription: 'Channel for CarVita maintenance reminders.',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  @override
  Future<void> cancelAllNotifications() {
    return _notificationsPlugin.cancelAll();
  }
}

@pragma('vm:entry-point')
void onDidReceiveBackgroundNotificationResponse(
  NotificationResponse notificationResponse,
) {
  // Background isolates must not navigate. A normal notification tap is
  // delivered through the main callback or cold-start launch details.
}
