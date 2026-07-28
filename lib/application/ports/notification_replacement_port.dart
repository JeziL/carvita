int maintenanceNotificationId({
  required int vehicleId,
  required int planItemId,
}) {
  var hash = 0x811c9dc5;
  for (final value in [vehicleId, planItemId]) {
    var remaining = value;
    for (var byteIndex = 0; byteIndex < 8; byteIndex++) {
      hash ^= remaining & 0xff;
      hash = (hash * 0x01000193) & 0xffffffff;
      remaining >>= 8;
    }
  }
  return hash & 0x7fffffff;
}

class NotificationRequest {
  const NotificationRequest({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledDateTime,
    this.payload,
  });

  final int id;
  final String title;
  final String body;
  final DateTime scheduledDateTime;
  final String? payload;
}

abstract interface class NotificationReplacementPort {
  Future<void> replaceAll(List<NotificationRequest> requests);
}
