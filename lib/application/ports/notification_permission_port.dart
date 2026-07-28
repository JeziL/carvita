abstract interface class NotificationPermissionGateway {
  Future<bool> requestPermissions();

  Future<bool> checkPermissions();

  Future<void> cancelAllNotifications();
}
