import 'package:equatable/equatable.dart';

class ServiceLogEntry extends Equatable {
  final int? id;
  final int vehicleId;
  final DateTime serviceDate;
  final double mileageAtService;
  final double? cost;
  final String? notes;

  const ServiceLogEntry({
    this.id,
    required this.vehicleId,
    required this.serviceDate,
    required this.mileageAtService,
    this.cost,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicleId': vehicleId,
      'serviceDate': serviceDate.toIso8601String(),
      'mileageAtService': mileageAtService,
      'cost': cost,
      'notes': notes,
    };
  }

  factory ServiceLogEntry.fromMap(Map<String, dynamic> map) {
    return ServiceLogEntry(
      id: map['id'] as int?,
      vehicleId: map['vehicleId'] as int,
      serviceDate: DateTime.parse(map['serviceDate'] as String),
      mileageAtService: map['mileageAtService'] as double,
      cost: map['cost'] as double?,
      notes: map['notes'] as String?,
    );
  }

  ServiceLogEntry copyWith({
    int? id,
    int? vehicleId,
    DateTime? serviceDate,
    double? mileageAtService,
    double? cost,
    String? notes,
    bool setCostToNull = false,
    bool setNotesToNull = false,
  }) {
    return ServiceLogEntry(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      serviceDate: serviceDate ?? this.serviceDate,
      mileageAtService: mileageAtService ?? this.mileageAtService,
      cost: setCostToNull ? null : (cost ?? this.cost),
      notes: setNotesToNull ? null : (notes ?? this.notes),
    );
  }

  @override
  List<Object?> get props => [
    id,
    vehicleId,
    serviceDate,
    mileageAtService,
    cost,
    notes,
  ];
}

class ServiceLogPerformedItem extends Equatable {
  final int? id; // ID in service_log_performed_items
  final int serviceLogId;
  final int? maintenancePlanItemId; // FK to maintenance_plan_items
  final String? customItemName; // Name if it's a custom item for this log

  final String displayName;

  const ServiceLogPerformedItem({
    this.id,
    required this.serviceLogId,
    this.maintenancePlanItemId,
    this.customItemName,
    required this.displayName,
  }) : assert(
         maintenancePlanItemId != null || customItemName != null,
         'Either maintenancePlanItemId or customItemName must be provided.',
       );

  factory ServiceLogPerformedItem.fromJoinedMap(Map<String, dynamic> map) {
    final customItemName = map['customItemName'] as String?;
    final predefinedItemName = map['predefinedItemName'] as String?;

    return ServiceLogPerformedItem(
      id: map['id'] as int?,
      serviceLogId: map['serviceLogId'] as int,
      maintenancePlanItemId: map['maintenancePlanItemId'] as int?,
      customItemName: customItemName,
      displayName: customItemName ?? predefinedItemName ?? 'Unknown Item',
    );
  }

  Map<String, dynamic> toMapForDb() {
    return {
      'id': id,
      'serviceLogId': serviceLogId,
      'maintenancePlanItemId': maintenancePlanItemId,
      'customItemName': customItemName,
    };
  }

  @override
  List<Object?> get props => [
    id,
    serviceLogId,
    maintenancePlanItemId,
    customItemName,
    displayName,
  ];
}

// Class to hold a service log entry along with its performed items (for UI)
class ServiceLogWithItems extends Equatable {
  final ServiceLogEntry entry;
  final List<ServiceLogPerformedItem> performedItems;

  const ServiceLogWithItems({
    required this.entry,
    required this.performedItems,
  });

  List<String> get performedItemDisplayNames =>
      performedItems.map((item) => item.displayName).toList(growable: false);

  @override
  List<Object?> get props => [entry, performedItems];
}

// Helper class for input when adding/updating a service log
class PerformedItemInput extends Equatable {
  final int? maintenancePlanItemId; // ID if it's a pre-defined plan item
  final String? customItemName; // Name if it's a new custom item for this log

  const PerformedItemInput({this.maintenancePlanItemId, this.customItemName})
    : assert(
        maintenancePlanItemId != null || customItemName != null,
        'Either maintenancePlanItemId or a non-empty customItemName must be provided.',
      );

  factory PerformedItemInput.fromPerformedItem(
    ServiceLogPerformedItem performedItem,
  ) {
    return PerformedItemInput(
      maintenancePlanItemId: performedItem.maintenancePlanItemId,
      customItemName: performedItem.customItemName,
    );
  }

  @override
  List<Object?> get props => [maintenancePlanItemId, customItemName];
}
