import 'package:flutter_test/flutter_test.dart';

import 'package:carvita/application/reminders/maintenance_reminder_payload.dart';

void main() {
  test('versioned payload round-trips required identifiers', () {
    final payload = MaintenanceReminderPayload(
      vehicleId: 42,
      planItemId: 99,
      scheduledAt: _scheduledAt,
    );

    final decoded = MaintenanceReminderPayload.tryParse(payload.encode());

    expect(decoded, isNotNull);
    expect(decoded!.vehicleId, 42);
    expect(decoded.planItemId, 99);
    expect(decoded.scheduledAt, _scheduledAt);
    expect(decoded.action, MaintenanceReminderAction.openMaintenancePlan);
  });

  test('rejects malformed, unknown, and unsafe payloads', () {
    final oversized =
        'x' * (MaintenanceReminderPayload.maximumEncodedLength + 1);

    expect(MaintenanceReminderPayload.tryParse(null), isNull);
    expect(MaintenanceReminderPayload.tryParse(''), isNull);
    expect(MaintenanceReminderPayload.tryParse('not json'), isNull);
    expect(MaintenanceReminderPayload.tryParse('[]'), isNull);
    expect(
      MaintenanceReminderPayload.tryParse(
        '{"payloadVersion":2,"action":"openMaintenancePlan",'
        '"vehicleId":1,"planItemId":2,"scheduledAtEpochMillis":1}',
      ),
      isNull,
    );
    expect(
      MaintenanceReminderPayload.tryParse(
        '{"payloadVersion":1,"action":"deleteEverything",'
        '"vehicleId":1,"planItemId":2,"scheduledAtEpochMillis":1}',
      ),
      isNull,
    );
    expect(
      MaintenanceReminderPayload.tryParse(
        '{"payloadVersion":1,"action":"openMaintenancePlan",'
        '"vehicleId":0,"planItemId":2,"scheduledAtEpochMillis":1}',
      ),
      isNull,
    );
    expect(
      MaintenanceReminderPayload.tryParse(
        '{"payloadVersion":1,"action":"openMaintenancePlan",'
        '"vehicleId":"1","planItemId":2,"scheduledAtEpochMillis":1}',
      ),
      isNull,
    );
    expect(
      MaintenanceReminderPayload.tryParse(
        '{"payloadVersion":1,"action":"openMaintenancePlan",'
        '"vehicleId":1,"planItemId":2,'
        '"scheduledAtEpochMillis":999999999999999999}',
      ),
      isNull,
    );
    expect(MaintenanceReminderPayload.tryParse(oversized), isNull);
  });
}

final _scheduledAt = DateTime.utc(2030, 1, 2, 12);
