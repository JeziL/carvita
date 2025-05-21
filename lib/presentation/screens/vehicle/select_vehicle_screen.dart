import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:carvita/core/constants/app_colors.dart';
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
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (newRouteContext) => MultiBlocProvider(
              providers: [
                BlocProvider(
                  create:
                      (_) => MaintenancePlanCubit(
                        MaintenanceRepository(),
                        vehicleId,
                      )..fetchPlanItems(),
                ),
                BlocProvider(
                  create:
                      (_) =>
                          ServiceLogCubit(MaintenanceRepository(), vehicleId)
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
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            AppLocalizations.of(context)!.chooseVehicle,
            style: TextStyle(color: AppColors.textWhite),
          ),
          backgroundColor: AppColors.statusBarColor,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.textWhite),
        ),
        body: ListView.builder(
          itemCount: vehicles.length,
          itemBuilder: (context, index) {
            final vehicle = vehicles[index];
            return Card(
              color: AppColors.white.withValues(alpha: 0.9),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading:
                    vehicle.image != null && vehicle.image!.isNotEmpty
                        ? ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Image.memory(
                            vehicle.image!,
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
                  style: const TextStyle(
                    color: AppColors.textBlack,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  vehicle.model ?? AppLocalizations.of(context)!.unknownModel,
                  style: TextStyle(
                    color: AppColors.textBlack.withValues(alpha: 0.7),
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
