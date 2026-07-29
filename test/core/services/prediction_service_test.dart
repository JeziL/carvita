import 'package:flutter_test/flutter_test.dart';

import 'package:carvita/application/ports/clock.dart';
import 'package:carvita/core/services/prediction_service.dart';
import 'package:carvita/data/models/maintenance_plan_item.dart';
import 'package:carvita/data/models/predicted_maintenance.dart';
import 'package:carvita/data/models/service_log_entry.dart';
import 'package:carvita/data/models/service_log_performed_item_link.dart';
import 'package:carvita/data/models/vehicle.dart';

void main() {
  final service = PredictionService(_FixedClock(DateTime(2026, 7, 29)));

  test('new plan time interval starts from its persisted baseline', () {
    final prediction = service.calculateNextServiceForItem(
      vehicle: _vehicle(boughtDate: DateTime(2018, 1, 1)),
      planItem: _plan(
        intervalTimeMonths: 6,
        baselineDate: DateTime(2026, 1, 31),
        baselineMileage: 82000,
      ),
      allLogsForVehicle: const [],
      allPerformedItemsForVehicle: const [],
    );

    expect(prediction?.predictedDueDate, DateTime(2026, 7, 31));
    expect(prediction?.basis, PredictionBasis.time);
    expect(prediction?.isFirstOccurrence, isTrue);
  });

  test('month-end and leap-year baselines clamp to the target month', () {
    final monthEnd = service.calculateNextServiceForItem(
      vehicle: _vehicle(),
      planItem: _plan(
        intervalTimeMonths: 1,
        baselineDate: DateTime(2026, 1, 31),
        baselineMileage: 0,
      ),
      allLogsForVehicle: const [],
      allPerformedItemsForVehicle: const [],
    );
    final leapYear = service.calculateNextServiceForItem(
      vehicle: _vehicle(),
      planItem: _plan(
        intervalTimeMonths: 12,
        baselineDate: DateTime(2023, 2, 28),
        baselineMileage: 0,
      ),
      allLogsForVehicle: const [],
      allPerformedItemsForVehicle: const [],
    );

    expect(monthEnd?.predictedDueDate, DateTime(2026, 2, 28));
    expect(leapYear?.predictedDueDate, DateTime(2024, 2, 28));
  });

  test(
    'new plan mileage target stays anchored when vehicle mileage changes',
    () {
      final plan = _plan(
        intervalMileage: 10000,
        baselineDate: DateTime(2026, 1, 1),
        baselineMileage: 80000,
      );

      final beforeUpdate = service.calculateNextServiceForItem(
        vehicle: _vehicle(mileage: 82000),
        planItem: plan,
        allLogsForVehicle: const [],
        allPerformedItemsForVehicle: const [],
        currentDateOverride: DateTime(2026, 2, 1),
      );
      final afterUpdate = service.calculateNextServiceForItem(
        vehicle: _vehicle(
          mileage: 87000,
          mileageLastUpdated: DateTime(2026, 5, 1),
        ),
        planItem: plan,
        allLogsForVehicle: const [],
        allPerformedItemsForVehicle: const [],
        currentDateOverride: DateTime(2026, 5, 1),
      );

      expect(beforeUpdate?.predictedAtMileage, 90000);
      expect(afterUpdate?.predictedAtMileage, 90000);
    },
  );

  test('legacy first interval fields use the independent plan baseline', () {
    final prediction = service.calculateNextServiceForItem(
      vehicle: _vehicle(boughtDate: DateTime(2015, 1, 1)),
      planItem: _plan(
        intervalTimeMonths: 12,
        intervalMileage: 20000,
        firstIntervalTimeMonths: 3,
        firstIntervalMileage: 5000,
        baselineDate: DateTime(2026, 4, 30),
        baselineMileage: 40000,
      ),
      allLogsForVehicle: const [],
      allPerformedItemsForVehicle: const [],
      currentDateOverride: DateTime(2026, 4, 30),
    );

    expect(prediction?.predictedDueDate, DateTime(2026, 7, 30));
    expect(prediction?.predictedAtMileage, 45000);
    expect(prediction?.basis, PredictionBasis.timeAndMileageCombined);
    expect(prediction?.isFirstOccurrence, isTrue);
  });

  test('latest linked service overrides the plan baseline', () {
    final prediction = service.calculateNextServiceForItem(
      vehicle: _vehicle(mileage: 26000),
      planItem: _plan(
        intervalTimeMonths: 12,
        intervalMileage: 100000,
        baselineDate: DateTime(2020, 1, 1),
        baselineMileage: 0,
      ),
      allLogsForVehicle: [
        _log(id: 10, date: DateTime(2025, 1, 1), mileage: 10000),
        _log(id: 11, date: DateTime(2026, 2, 1), mileage: 25000),
        _log(id: 12, date: DateTime(2026, 3, 1), mileage: 30000),
      ],
      allPerformedItemsForVehicle: const [
        ServiceLogPerformedItemLink(serviceLogId: 10, maintenancePlanItemId: 1),
        ServiceLogPerformedItemLink(serviceLogId: 11, maintenancePlanItemId: 1),
        ServiceLogPerformedItemLink(
          serviceLogId: 12,
          maintenancePlanItemId: 99,
        ),
      ],
      currentDateOverride: DateTime(2026, 3, 1),
    );

    expect(prediction?.predictedDueDate, DateTime(2027, 2, 1));
    expect(prediction?.predictedAtMileage, 125000);
    expect(prediction?.isFirstOccurrence, isFalse);
  });

  test('same-day linked services use the greatest log id', () {
    final prediction = service.calculateNextServiceForItem(
      vehicle: _vehicle(mileage: 20000),
      planItem: _plan(
        intervalMileage: 5000,
        baselineDate: DateTime(2020, 1, 1),
        baselineMileage: 0,
      ),
      allLogsForVehicle: [
        _log(id: 20, date: DateTime(2026, 1, 1), mileage: 10000),
        _log(id: 21, date: DateTime(2026, 1, 1), mileage: 15000),
      ],
      allPerformedItemsForVehicle: const [
        ServiceLogPerformedItemLink(serviceLogId: 20, maintenancePlanItemId: 1),
        ServiceLogPerformedItemLink(serviceLogId: 21, maintenancePlanItemId: 1),
      ],
      currentDateOverride: DateTime(2026, 1, 1),
    );

    expect(prediction?.predictedAtMileage, 20000);
  });

  test('deleting linked services falls back through history to baseline', () {
    final plan = _plan(
      intervalTimeMonths: 6,
      baselineDate: DateTime(2025, 1, 15),
      baselineMileage: 1000,
    );
    final logs = [
      _log(id: 1, date: DateTime(2025, 6, 1), mileage: 5000),
      _log(id: 2, date: DateTime(2026, 1, 1), mileage: 10000),
    ];

    final previousLinked = service.calculateNextServiceForItem(
      vehicle: _vehicle(),
      planItem: plan,
      allLogsForVehicle: logs,
      allPerformedItemsForVehicle: const [
        ServiceLogPerformedItemLink(serviceLogId: 1, maintenancePlanItemId: 1),
      ],
    );
    final baseline = service.calculateNextServiceForItem(
      vehicle: _vehicle(),
      planItem: plan,
      allLogsForVehicle: logs,
      allPerformedItemsForVehicle: const [],
    );

    expect(previousLinked?.predictedDueDate, DateTime(2025, 12, 1));
    expect(baseline?.predictedDueDate, DateTime(2025, 7, 15));
  });

  test('combined interval returns the earlier due basis but both metadata', () {
    final prediction = service.calculateNextServiceForItem(
      vehicle: _vehicle(
        mileage: 1000,
        mileageLastUpdated: DateTime(2026, 1, 1),
      ),
      planItem: _plan(
        intervalTimeMonths: 1,
        intervalMileage: 50000,
        baselineDate: DateTime(2026, 1, 1),
        baselineMileage: 1000,
      ),
      allLogsForVehicle: const [],
      allPerformedItemsForVehicle: const [],
      currentDateOverride: DateTime(2026, 1, 1),
    );

    expect(prediction?.predictedDueDate, DateTime(2026, 2, 1));
    expect(prediction?.predictedAtMileage, 51000);
    expect(prediction?.basis, PredictionBasis.timeAndMileageCombined);
  });
}

MaintenancePlanItem _plan({
  int? intervalTimeMonths,
  int? intervalMileage,
  int? firstIntervalTimeMonths,
  int? firstIntervalMileage,
  required DateTime baselineDate,
  required double baselineMileage,
}) {
  return MaintenancePlanItem(
    id: 1,
    vehicleId: 1,
    itemName: 'Oil',
    intervalTimeMonths: intervalTimeMonths,
    intervalMileage: intervalMileage,
    firstIntervalTimeMonths: firstIntervalTimeMonths,
    firstIntervalMileage: firstIntervalMileage,
    baselineDate: baselineDate,
    baselineMileage: baselineMileage,
  );
}

Vehicle _vehicle({
  double mileage = 1000,
  DateTime? mileageLastUpdated,
  DateTime? boughtDate,
}) {
  return Vehicle(
    id: 1,
    name: 'Vehicle',
    mileage: mileage,
    mileageLastUpdated: mileageLastUpdated ?? DateTime(2026, 1, 1),
    boughtDate: boughtDate ?? DateTime(2020, 1, 1),
  );
}

ServiceLogEntry _log({
  required int id,
  required DateTime date,
  required double mileage,
}) {
  return ServiceLogEntry(
    id: id,
    vehicleId: 1,
    serviceDate: date,
    mileageAtService: mileage,
  );
}

final class _FixedClock implements Clock {
  const _FixedClock(this.value);

  final DateTime value;

  @override
  DateTime now() => value;
}
