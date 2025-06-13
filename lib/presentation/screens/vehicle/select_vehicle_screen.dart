import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transparent_image/transparent_image.dart';

import 'package:carvita/core/constants/app_colors.dart';
import 'package:carvita/core/theme/app_theme.dart';
import 'package:carvita/core/widgets/gradient_background.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/data/repositories/maintenance_repository.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/presentation/manager/maintenance_plan/maintenance_plan_cubit.dart';
import 'package:carvita/presentation/manager/service_log/service_log_cubit.dart';
import 'package:carvita/presentation/screens/maintenance/log_maintenance_screen.dart';

class SelectVehicleScreen extends StatelessWidget {
  final List<Vehicle> vehicles;

  const SelectVehicleScreen({super.key, required this.vehicles});

  void _navigateToLogMaintenance(
    BuildContext context,
    int vehicleId,
    String vehicleName,
  ) {
    final maintenanceRepository = MaintenanceRepository();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (newRouteContext) => MultiBlocProvider(
              providers: [
                BlocProvider(
                  create:
                      (_) =>
                          MaintenancePlanCubit(maintenanceRepository, vehicleId)
                            ..fetchPlanItems(),
                ),
                BlocProvider(
                  create:
                      (_) =>
                          ServiceLogCubit(maintenanceRepository, vehicleId)
                            ..fetchServiceLogs(),
                ),
              ],
              child: LogMaintenanceScreen(
                vehicleId: vehicleId,
                vehicleName: vehicleName,
                logToEdit: null,
              ),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeExtensions = Theme.of(context).extension<AppThemeExtensions>()!;
    return GradientBackground(
      gradient: themeExtensions.primaryGradient,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.chooseVehicle),
          backgroundColor: Theme.of(
            context,
          ).colorScheme.inverseSurface.withValues(alpha: 0.1),
          elevation: 0,
        ),
        body: ListView.builder(
          itemCount: vehicles.length,
          itemBuilder: (context, index) {
            final vehicle = vehicles[index];
            return Card(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading:
                    vehicle.image != null && vehicle.image!.isNotEmpty
                        ? ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: FadeInImage(
                            placeholder: MemoryImage(kTransparentImage),
                            image: MemoryImage(vehicle.image!),
                            fadeInDuration: const Duration(milliseconds: 200),
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        )
                        : Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: const Icon(
                            Icons.directions_car,
                            size: 30,
                            color: Colors.grey,
                          ),
                        ),
                title: Text(
                  vehicle.name,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  vehicle.model ?? AppLocalizations.of(context)!.unknownModel,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                onTap: () {
                  if (vehicle.id != null) {
                    _navigateToLogMaintenance(
                      context,
                      vehicle.id!,
                      vehicle.name,
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Invalid vehicle ID."),
                        backgroundColor: AppColors.urgentReminderText,
                      ),
                    );
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
