import 'package:carvita/core/constants/app_colors.dart';
import 'package:carvita/core/constants/app_routes.dart';
import 'package:carvita/data/models/predicted_maintenance.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/presentation/manager/upcoming_maintenance/upcoming_maintenance_cubit.dart';
import 'package:carvita/presentation/manager/upcoming_maintenance/upcoming_maintenance_state.dart';
import 'package:carvita/presentation/manager/vehicle_list/vehicle_cubit.dart'; // For vehicle filter
import 'package:carvita/presentation/manager/vehicle_list/vehicle_state.dart'
    as vehicle_list_state_import;
import 'package:carvita/presentation/screens/common_widgets/main_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class UpcomingMaintenanceListScreen extends StatefulWidget {
  const UpcomingMaintenanceListScreen({super.key});

  @override
  State<UpcomingMaintenanceListScreen> createState() =>
      _UpcomingMaintenanceListScreenState();
}

class _UpcomingMaintenanceListScreenState
    extends State<UpcomingMaintenanceListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Vehicle? _selectedVehicleFilter;
  final Vehicle _allVehiclesSentinel = Vehicle(
    id: -999,
    name: "All vehicles",
    mileage: 0,
    boughtDate: DateTime(0),
  );
  List<Vehicle> _allVehicles = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Get vehicles for filter
    final vehicleState = context.read<VehicleCubit>().state;
    if (vehicleState is vehicle_list_state_import.VehicleLoaded) {
      _allVehicles = vehicleState.vehicles;
    } else {
      context.read<VehicleCubit>().fetchVehicles(); // If not loaded
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<PredictedMaintenanceInfo> _filterPredictions(
    List<PredictedMaintenanceInfo> predictions,
  ) {
    List<PredictedMaintenanceInfo> filtered = List.from(
      predictions,
    ); // Create a mutable copy

    // 1. Filter by selected vehicle
    if (_selectedVehicleFilter != null) {
      filtered =
          filtered
              .where((p) => p.vehicle.id == _selectedVehicleFilter!.id)
              .toList();
    }

    // 2. Filter by date tab
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_tabController.index == 1) {
      // This Week
      final startOfWeek = today.subtract(
        Duration(days: today.weekday - 1),
      ); // Assuming Monday is first day
      final endOfWeek = startOfWeek.add(
        const Duration(days: 6, hours: 23, minutes: 59),
      );
      filtered =
          filtered
              .where(
                (p) =>
                    !p.predictedDueDate.isBefore(startOfWeek) &&
                    !p.predictedDueDate.isAfter(endOfWeek),
              )
              .toList();
    } else if (_tabController.index == 2) {
      // This Month
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(
        now.year,
        now.month + 1,
        0,
        23,
        59,
      ); // Last day of current month
      filtered =
          filtered
              .where(
                (p) =>
                    !p.predictedDueDate.isBefore(startOfMonth) &&
                    !p.predictedDueDate.isAfter(endOfMonth),
              )
              .toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          AppColors.white,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.upcomingMaintenance,
          style: TextStyle(color: AppColors.textBlack),
        ),
        backgroundColor: AppColors.white,
        elevation: 1.0,
        iconTheme: const IconThemeData(
          color: AppColors.textBlack,
        ), // Back button color
        automaticallyImplyLeading: false,
        actions: [
          BlocBuilder<VehicleCubit, vehicle_list_state_import.VehicleState>(
            builder: (context, vehicleState) {
              if (vehicleState is vehicle_list_state_import.VehicleLoaded) {
                _allVehicles = vehicleState.vehicles;
              }
              return PopupMenuButton<Vehicle?>(
                icon: Icon(
                  Icons.filter_list,
                  color: AppColors.textBlack.withValues(alpha: 0.7),
                ),
                tooltip: AppLocalizations.of(context)!.filterByVehicle,
                onSelected: (Vehicle? vehicle) {
                  setState(() {
                    if (vehicle != null &&
                        vehicle.id == _allVehiclesSentinel.id) {
                      _selectedVehicleFilter = null;
                    } else {
                      _selectedVehicleFilter = vehicle;
                    }
                  });
                },
                itemBuilder: (BuildContext context) {
                  List<PopupMenuEntry<Vehicle?>> items = [];
                  items.add(
                    PopupMenuItem<Vehicle?>(
                      value: _allVehiclesSentinel,
                      child: Text(AppLocalizations.of(context)!.allVehicles),
                    ),
                  );
                  items.addAll(
                    _allVehicles.map((Vehicle vehicle) {
                      return PopupMenuItem<Vehicle?>(
                        value: vehicle,
                        child: Text(vehicle.name),
                      );
                    }).toList(),
                  );
                  return items;
                },
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryBlue,
          unselectedLabelColor: AppColors.textBlack.withValues(alpha: 0.7),
          indicatorColor: AppColors.primaryBlue,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          onTap: (_) => setState(() {}), // Trigger rebuild to apply filter
          tabs: [
            Tab(text: AppLocalizations.of(context)!.nextYear),
            Tab(text: AppLocalizations.of(context)!.thisWeek),
            Tab(text: AppLocalizations.of(context)!.thisMonth),
          ],
        ),
      ),
      body: BlocBuilder<UpcomingMaintenanceCubit, UpcomingMaintenanceState>(
        builder: (context, state) {
          if (state is UpcomingMaintenanceLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is UpcomingMaintenanceError) {
            return Center(
              child: Text(
                state.message,
                style: const TextStyle(color: AppColors.urgentReminderText),
              ),
            );
          }
          if (state is UpcomingMaintenanceLoaded) {
            final displayedPredictions = _filterPredictions(
              state.allPredictions,
            );

            if (displayedPredictions.isEmpty) {
              return Center(
                child: Text(
                  _selectedVehicleFilter == null && _tabController.index == 0
                      ? AppLocalizations.of(context)!.maintenanceListEmpty
                      : AppLocalizations.of(
                        context,
                      )!.maintenanceListEmptyAfterFilter,
                  style: TextStyle(
                    color: AppColors.textBlack.withValues(alpha: 0.7),
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: displayedPredictions.length,
              itemBuilder: (context, index) {
                final prediction = displayedPredictions[index];
                final vehicleName = prediction.vehicle.name;
                final itemName = prediction.planItem.itemName;
                final dueDate = DateFormat.yMMMd(
                  Localizations.localeOf(context).toLanguageTag(),
                ).format(prediction.predictedDueDate);
                final daysRemaining =
                    prediction.predictedDueDate
                        .difference(DateTime.now())
                        .inDays;
                String dueText =
                    daysRemaining >= 0
                        ? AppLocalizations.of(context)!.daysLater(daysRemaining)
                        : AppLocalizations.of(
                          context,
                        )!.daysOverdue(-daysRemaining);

                return Card(
                  elevation: 1.5,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    title: Text(
                      itemName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppColors.textBlack,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicleName,
                          style: TextStyle(
                            color: AppColors.textBlack.withValues(alpha: 0.8),
                          ),
                        ),
                        Text(
                          "${AppLocalizations.of(context)!.status}: $dueText",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color:
                                daysRemaining <= 30
                                    ? AppColors.urgentReminderText
                                    : AppColors.primaryBlue,
                          ),
                        ),
                        Text(
                          "${AppLocalizations.of(context)!.estimated}: $dueDate ${prediction.predictedAtMileage != null ? '/ ${prediction.predictedAtMileage!.toStringAsFixed(0)} km' : ''}",
                          style: TextStyle(
                            color: AppColors.textBlack.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.vehicleDetailsRoute,
                        arguments: prediction.vehicle.id,
                      );
                    },
                  ),
                );
              },
            );
          }
          return Center(
            child: Text(
              AppLocalizations.of(context)!.loading,
              style: TextStyle(color: AppColors.textBlack),
            ),
          );
        },
      ),
      bottomNavigationBar: const MainBottomNavigationBar(
        currentIndex: 2,
      ), // Index for Upcoming Maintenance
    );
  }
}
