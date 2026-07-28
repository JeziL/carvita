import 'dart:convert';

enum MaintenanceReminderAction {
  openMaintenancePlan('openMaintenancePlan');

  const MaintenanceReminderAction(this.wireValue);

  final String wireValue;
}

final class MaintenanceReminderPayload {
  const MaintenanceReminderPayload({
    required this.vehicleId,
    required this.planItemId,
    required this.scheduledAt,
    this.action = MaintenanceReminderAction.openMaintenancePlan,
  });

  static const int currentVersion = 1;
  static const int maximumEncodedLength = 1024;

  final int vehicleId;
  final int planItemId;
  final DateTime scheduledAt;
  final MaintenanceReminderAction action;

  String encode() {
    return jsonEncode({
      'payloadVersion': currentVersion,
      'action': action.wireValue,
      'vehicleId': vehicleId,
      'planItemId': planItemId,
      'scheduledAtEpochMillis': scheduledAt.toUtc().millisecondsSinceEpoch,
    });
  }

  static MaintenanceReminderPayload? tryParse(String? encoded) {
    if (encoded == null ||
        encoded.isEmpty ||
        encoded.length > maximumEncodedLength) {
      return null;
    }

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic> ||
          decoded['payloadVersion'] != currentVersion ||
          decoded['action'] !=
              MaintenanceReminderAction.openMaintenancePlan.wireValue) {
        return null;
      }

      final vehicleId = decoded['vehicleId'];
      final planItemId = decoded['planItemId'];
      final scheduledAtEpochMillis = decoded['scheduledAtEpochMillis'];
      if (vehicleId is! int ||
          planItemId is! int ||
          scheduledAtEpochMillis is! int ||
          vehicleId <= 0 ||
          planItemId <= 0 ||
          scheduledAtEpochMillis <= 0) {
        return null;
      }

      return MaintenanceReminderPayload(
        vehicleId: vehicleId,
        planItemId: planItemId,
        scheduledAt: DateTime.fromMillisecondsSinceEpoch(
          scheduledAtEpochMillis,
          isUtc: true,
        ),
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    } on RangeError {
      return null;
    }
  }

  String get deduplicationKey =>
      '${action.wireValue}:$vehicleId:$planItemId:'
      '${scheduledAt.toUtc().millisecondsSinceEpoch}';
}
