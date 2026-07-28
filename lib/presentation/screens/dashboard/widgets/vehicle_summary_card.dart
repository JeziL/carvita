import 'package:flutter/material.dart';

import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/presentation/images/vehicle_thumbnail.dart';

class VehicleSummaryCard extends StatelessWidget {
  final Vehicle vehicle;
  final String nextMaintenanceInfo;
  final VoidCallback onTap;

  const VehicleSummaryCard({
    super.key,
    required this.vehicle,
    required this.nextMaintenanceInfo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Row(
            children: [
              VehicleThumbnail(
                vehicle: vehicle,
                width: 60,
                height: 60,
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.name,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      nextMaintenanceInfo,
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
