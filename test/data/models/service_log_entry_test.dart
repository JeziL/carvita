import 'package:flutter_test/flutter_test.dart';

import 'package:carvita/data/models/service_log_entry.dart';

void main() {
  group('ServiceLogPerformedItem.fromJoinedMap', () {
    test('preserves a predefined item identity from a joined row', () {
      final item = ServiceLogPerformedItem.fromJoinedMap({
        'id': 41,
        'serviceLogId': 7,
        'maintenancePlanItemId': 13,
        'customItemName': null,
        'predefinedItemName': 'Oil change',
      });

      expect(item.id, 41);
      expect(item.serviceLogId, 7);
      expect(item.maintenancePlanItemId, 13);
      expect(item.customItemName, isNull);
      expect(item.displayName, 'Oil change');
    });

    test('preserves a custom item identity from a joined row', () {
      final item = ServiceLogPerformedItem.fromJoinedMap({
        'id': 42,
        'serviceLogId': 7,
        'maintenancePlanItemId': null,
        'customItemName': 'Oil change',
        'predefinedItemName': null,
      });

      expect(item.id, 42);
      expect(item.maintenancePlanItemId, isNull);
      expect(item.customItemName, 'Oil change');
      expect(item.displayName, 'Oil change');
    });

    test('keeps the plan id when the joined display name is unavailable', () {
      final item = ServiceLogPerformedItem.fromJoinedMap({
        'id': 43,
        'serviceLogId': 7,
        'maintenancePlanItemId': 99,
        'customItemName': null,
        'predefinedItemName': null,
      });

      expect(item.maintenancePlanItemId, 99);
      expect(item.displayName, 'Unknown Item');
    });
  });

  test('edit inputs reuse persisted identities instead of display names', () {
    const predefinedItem = ServiceLogPerformedItem(
      id: 41,
      serviceLogId: 7,
      maintenancePlanItemId: 13,
      displayName: 'Oil change',
    );
    const customItem = ServiceLogPerformedItem(
      id: 42,
      serviceLogId: 7,
      customItemName: 'Oil change',
      displayName: 'Oil change',
    );
    final log = ServiceLogWithItems(
      entry: ServiceLogEntry(
        id: 7,
        vehicleId: 2,
        serviceDate: DateTime(2026, 1, 2),
        mileageAtService: 12000,
      ),
      performedItems: const [predefinedItem, customItem],
    );

    final inputs = log.performedItems
        .map(PerformedItemInput.fromPerformedItem)
        .toList(growable: false);

    expect(log.performedItemDisplayNames, ['Oil change', 'Oil change']);
    expect(inputs, const [
      PerformedItemInput(maintenancePlanItemId: 13),
      PerformedItemInput(customItemName: 'Oil change'),
    ]);
  });
}
