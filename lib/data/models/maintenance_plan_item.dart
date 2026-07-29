import 'package:equatable/equatable.dart';

class MaintenancePlanItem extends Equatable {
  final int? id;
  final int vehicleId; // Foreign key to link with a Vehicle
  final String itemName;
  final int? intervalTimeMonths;
  final int? intervalMileage;
  final int? firstIntervalTimeMonths;
  final int? firstIntervalMileage;
  final String? notes;
  final bool isActive;
  final DateTime? baselineDate;
  final double? baselineMileage;

  const MaintenancePlanItem({
    this.id,
    required this.vehicleId,
    required this.itemName,
    this.intervalTimeMonths,
    this.intervalMileage,
    this.firstIntervalTimeMonths,
    this.firstIntervalMileage,
    this.notes,
    this.isActive = true,
    this.baselineDate,
    this.baselineMileage,
  });

  bool get hasFirstInterval =>
      firstIntervalTimeMonths != null || firstIntervalMileage != null;

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'vehicleId': vehicleId,
      'itemName': itemName,
      'intervalTimeMonths': intervalTimeMonths,
      'intervalMileage': intervalMileage,
      'firstIntervalTimeMonths': firstIntervalTimeMonths,
      'firstIntervalMileage': firstIntervalMileage,
      'notes': notes,
      'isActive': isActive ? 1 : 0,
    };
    final baselineDate = this.baselineDate;
    final baselineMileage = this.baselineMileage;
    if (baselineDate != null) {
      map['baselineDate'] = baselineDate.toIso8601String();
    }
    if (baselineMileage != null) {
      map['baselineMileage'] = baselineMileage;
    }
    return map;
  }

  factory MaintenancePlanItem.fromMap(Map<String, dynamic> map) {
    return MaintenancePlanItem(
      id: map['id'] as int?,
      vehicleId: map['vehicleId'] as int,
      itemName: map['itemName'] as String,
      intervalTimeMonths: map['intervalTimeMonths'] as int?,
      intervalMileage: map['intervalMileage'] as int?,
      firstIntervalTimeMonths: map['firstIntervalTimeMonths'] as int?,
      firstIntervalMileage: map['firstIntervalMileage'] as int?,
      notes: map['notes'] as String?,
      isActive: (map['isActive'] as int? ?? 1) == 1,
      baselineDate: switch (map['baselineDate']) {
        final String value => DateTime.tryParse(value),
        _ => null,
      },
      baselineMileage: (map['baselineMileage'] as num?)?.toDouble(),
    );
  }

  MaintenancePlanItem copyWith({
    int? id,
    int? vehicleId,
    String? itemName,
    int? intervalTimeMonths,
    int? intervalMileage,
    int? firstIntervalTimeMonths,
    int? firstIntervalMileage,
    String? notes,
    bool? isActive,
    DateTime? baselineDate,
    double? baselineMileage,
    bool setNotesToNull = false, // For explicitly setting notes to null
    bool setIntervalTimeMonthsToNull = false,
    bool setIntervalMileageToNull = false,
    bool setFirstIntervalTimeMonthsToNull = false,
    bool setFirstIntervalMileageToNull = false,
  }) {
    return MaintenancePlanItem(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      itemName: itemName ?? this.itemName,
      intervalTimeMonths: setIntervalTimeMonthsToNull
          ? null
          : (intervalTimeMonths ?? this.intervalTimeMonths),
      intervalMileage: setIntervalMileageToNull
          ? null
          : (intervalMileage ?? this.intervalMileage),
      firstIntervalTimeMonths: setFirstIntervalTimeMonthsToNull
          ? null
          : (firstIntervalTimeMonths ?? this.firstIntervalTimeMonths),
      firstIntervalMileage: setFirstIntervalMileageToNull
          ? null
          : (firstIntervalMileage ?? this.firstIntervalMileage),
      notes: setNotesToNull ? null : (notes ?? this.notes),
      isActive: isActive ?? this.isActive,
      baselineDate: baselineDate ?? this.baselineDate,
      baselineMileage: baselineMileage ?? this.baselineMileage,
    );
  }

  @override
  List<Object?> get props => [
    id,
    vehicleId,
    itemName,
    intervalTimeMonths,
    intervalMileage,
    firstIntervalTimeMonths,
    firstIntervalMileage,
    notes,
    isActive,
    baselineDate,
    baselineMileage,
  ];

  @override
  String toString() {
    return 'MaintenancePlanItem{id: $id, itemName: $itemName, isActive: $isActive}';
  }
}
