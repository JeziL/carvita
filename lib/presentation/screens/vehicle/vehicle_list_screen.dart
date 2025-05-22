import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:carvita/core/constants/app_colors.dart';
import 'package:carvita/core/constants/app_routes.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/presentation/manager/upcoming_maintenance/upcoming_maintenance_cubit.dart';
import 'package:carvita/presentation/manager/vehicle_list/vehicle_cubit.dart';
import 'package:carvita/presentation/manager/vehicle_list/vehicle_state.dart';
import 'package:carvita/presentation/screens/common_widgets/main_bottom_navigation_bar.dart';

class VehicleListScreen extends StatefulWidget {
  const VehicleListScreen({super.key});

  @override
  State<VehicleListScreen> createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends State<VehicleListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VehicleCubit>().fetchVehicles();
    });
  }

  Future<void> _confirmDelete(BuildContext context, Vehicle vehicle) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: Text(
            AppLocalizations.of(context)!.confirmDelete,
            style: TextStyle(color: AppColors.textBlack, fontSize: 24),
          ),
          content: Text(
            AppLocalizations.of(context)!.deleteConfirmVeh(vehicle.name),
            style: const TextStyle(color: AppColors.textBlack),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                AppLocalizations.of(context)!.cancel,
                style: TextStyle(color: AppColors.primaryBlue),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              child: Text(
                AppLocalizations.of(context)!.delete,
                style: TextStyle(color: AppColors.urgentReminderText),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmed == true && vehicle.id != null && context.mounted) {
      final cubit = context.read<VehicleCubit>();
      await cubit.deleteVehicle(vehicle.id!);
      if (context.mounted &&
          (cubit.state is VehicleOperationSuccess ||
              cubit.state is VehicleLoaded)) {
        context.read<UpcomingMaintenanceCubit>().loadAllUpcomingMaintenance(
          AppLocalizations.of(context),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.myVehicles,
          style: TextStyle(
            color: AppColors.textBlack,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.7),
      ),
      body: BlocConsumer<VehicleCubit, VehicleState>(
        listener: (context, state) {
          if (state is VehicleError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.message,
                  style: const TextStyle(color: AppColors.textWhite),
                ),
                backgroundColor: AppColors.urgentReminderText,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is VehicleLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.white),
            );
          } else if (state is VehicleLoaded) {
            if (state.vehicles.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.no_transfer_rounded,
                      size: 60,
                      color: AppColors.textBlack,
                    ),
                    SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.emptyVehicle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textBlack,
                      ),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: state.vehicles.length,
              itemBuilder: (context, index) {
                final vehicle = state.vehicles[index];
                return Card(
                  color: AppColors.cardBackground,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 1,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    leading:
                        vehicle.image != null && vehicle.image!.isNotEmpty
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: Image.memory(
                                vehicle.image!,
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) => Container(
                                      width: 70,
                                      height: 70,
                                      color: Colors.grey[200],
                                      child: const Icon(
                                        Icons.directions_car,
                                        size: 30,
                                        color: Colors.grey,
                                      ),
                                    ),
                              ),
                            )
                            : Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: const Icon(
                                Icons.directions_car,
                                size: 35,
                                color: Colors.grey,
                              ),
                            ),
                    title: Text(
                      vehicle.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppColors.textBlack,
                        fontSize: 17,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        (vehicle.model != null && vehicle.model!.isNotEmpty)
                            ? Text(
                              "${AppLocalizations.of(context)!.vehicleModel}: ${vehicle.model!}",
                              style: TextStyle(
                                color: AppColors.textBlack.withValues(
                                  alpha: 0.7,
                                ),
                                fontSize: 13,
                              ),
                            )
                            : Text(
                              AppLocalizations.of(context)!.unknownModel,
                              style: TextStyle(
                                color: AppColors.textBlack.withValues(
                                  alpha: 0.7,
                                ),
                                fontSize: 13,
                              ),
                            ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: AppColors.primaryBlue,
                          ),
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.addVehicleRoute,
                              arguments: vehicle,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.urgentReminderText,
                          ),
                          onPressed: () => _confirmDelete(context, vehicle),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.vehicleDetailsRoute,
                        arguments: vehicle.id,
                      );
                    },
                  ),
                );
              },
            );
          } else if (state is VehicleError) {
            return Center(
              child: Text(
                state.message,
                style: const TextStyle(color: AppColors.urgentReminderText),
              ),
            );
          }
          return Center(
            child: Text(
              AppLocalizations.of(context)!.loading,
              style: TextStyle(color: AppColors.textWhite),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.addVehicleRoute);
        },
        backgroundColor: AppColors.primaryBlue,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: AppColors.white),
      ),
      bottomNavigationBar: const MainBottomNavigationBar(
        currentIndex: 1,
      ), // Index for 'Vehicles'
    );
  }
}
