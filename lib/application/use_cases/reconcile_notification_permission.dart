import 'package:carvita/application/ports/notification_permission_port.dart';
import 'package:carvita/application/ports/preferences_ports.dart';

final class ReconcileNotificationPermission {
  ReconcileNotificationPermission(this._preferences, this._notifications);

  final ReminderPreferences _preferences;
  final NotificationPermissionGateway _notifications;
  Future<bool>? _inFlight;

  /// Returns true when a stored opt-in was disabled because the operating
  /// system no longer grants notification permission.
  Future<bool> call() {
    final current = _inFlight;
    if (current != null) return current;

    late final Future<bool> operation;
    operation = _reconcile().whenComplete(() {
      if (identical(_inFlight, operation)) {
        _inFlight = null;
      }
    });
    _inFlight = operation;
    return operation;
  }

  Future<bool> _reconcile() async {
    if (!await _preferences.getNotificationsEnabled()) {
      return false;
    }
    if (await _notifications.checkPermissions()) {
      return false;
    }

    await _preferences.setNotificationsEnabled(false);
    await _notifications.cancelAllNotifications();
    return true;
  }
}
