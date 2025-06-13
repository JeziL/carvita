import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:carvita/core/constants/app_colors.dart';
import 'package:carvita/core/constants/app_routes.dart';
import 'package:carvita/core/services/preferences_service.dart';
import 'package:carvita/core/services/quick_action_service.dart';
import 'package:carvita/core/theme/app_theme.dart';
import 'package:carvita/core/widgets/gradient_background.dart';
import 'package:carvita/data/models/predicted_maintenance.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/main.dart';
import 'package:carvita/presentation/manager/upcoming_maintenance/upcoming_maintenance_cubit.dart';
import 'package:carvita/presentation/manager/upcoming_maintenance/upcoming_maintenance_state.dart';
import 'package:carvita/presentation/manager/vehicle_list/vehicle_cubit.dart';
import 'package:carvita/presentation/manager/vehicle_list/vehicle_state.dart';
import 'package:carvita/presentation/screens/common_widgets/main_bottom_navigation_bar.dart';
import 'package:carvita/presentation/screens/dashboard/widgets/quick_action_button.dart';
import 'package:carvita/presentation/screens/dashboard/widgets/vehicle_summary_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver, RouteAware {
  final PreferencesService _preferencesService = PreferencesService();
  DueReminderThresholdValue _dashboardThreshold =
      DueReminderThresholdValue.month;
  int _dashboardItemCount = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDashboardFilterSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _loadDashboardFilterSettings();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute? route = ModalRoute.of(context);
    if (route != null && route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    _loadDashboardFilterSettings();
  }

  @override
  void didPush() {
    _loadDashboardFilterSettings();
  }

  Future<void> _loadDashboardFilterSettings() async {
    final threshold = await _preferencesService.getDueReminderThreshold();
    final count = await _preferencesService.getDueReminderItemCount();
    if (mounted) {
      if (threshold != _dashboardThreshold || count != _dashboardItemCount) {
        setState(() {
          _dashboardThreshold = threshold;
          _dashboardItemCount = count;
        });
      }
    }
  }

  Widget _buildDashboardUrgentReminders(
    BuildContext context,
    List<PredictedMaintenanceInfo> allPredictions,
  ) {
    final themeExtensions = Theme.of(context).extension<AppThemeExtensions>()!;
    final DueReminderThresholdValue currentThreshold = _dashboardThreshold;
    final int currentItemCount = _dashboardItemCount;

    if (allPredictions.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            AppLocalizations.of(context)!.noUpcomingMaintenance,
            style: TextStyle(color: themeExtensions.textColorOnBackground),
          ),
        ),
      );
    }
    final now = DateTime.now();
    final filteredPredictions =
        allPredictions.where((prediction) {
          final dueDate = prediction.predictedDueDate;
          return dueDate.isBefore(
            now.add(Duration(days: currentThreshold.days)),
          );
        }).toList();

    final urgentItems = filteredPredictions.take(currentItemCount).toList();

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppColors.urgentReminderText,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(
                      context,
                    )!.itemsDueSoon(filteredPredictions.length),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...urgentItems.map((prediction) {
              final vehicleName = prediction.vehicle.name;
              final itemName = prediction.planItem.itemName;
              final daysRemaining =
                  prediction.predictedDueDate.difference(DateTime.now()).inDays;
              String dueText =
                  daysRemaining >= 0
                      ? AppLocalizations.of(context)!.daysLater(daysRemaining)
                      : AppLocalizations.of(
                        context,
                      )!.daysOverdue(-daysRemaining);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            itemName,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            vehicleName,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      dueText,
                      style: TextStyle(
                        color:
                            daysRemaining <= 30
                                ? AppColors.urgentReminderText
                                : Theme.of(context).colorScheme.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (filteredPredictions.length > currentItemCount)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed:
                      () => Navigator.pushNamed(
                        context,
                        AppRoutes.upcomingMaintenanceRoute,
                      ),
                  child: Text(
                    "${AppLocalizations.of(context)!.viewAll} >>",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleSummaryCardWithPrediction(
    BuildContext context,
    Vehicle vehicle,
    List<PredictedMaintenanceInfo> allPredictions,
  ) {
    final nextServiceForThisVehicle =
        allPredictions
            .where((p) => p.vehicle.id == vehicle.id)
            .sorted((a, b) => a.predictedDueDate.compareTo(b.predictedDueDate))
            .firstOrNull;

    String nextMaintenanceDisplay =
        AppLocalizations.of(context)!.noNextMaintenance;
    if (nextServiceForThisVehicle != null) {
      nextMaintenanceDisplay = nextServiceForThisVehicle.displayInfo(context);
    }

    return VehicleSummaryCard(
      vehicle: vehicle,
      nextMaintenanceInfo: nextMaintenanceDisplay,
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.vehicleDetailsRoute,
          arguments: vehicle.id,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
    final themeExtensions = Theme.of(context).extension<AppThemeExtensions>()!;

    return GradientBackground(
      gradient: themeExtensions.primaryGradient,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            AppLocalizations.of(context)!.dashboardTitle,
            style: TextStyle(fontSize: 28),
          ),
          backgroundColor: Theme.of(
            context,
          ).colorScheme.inverseSurface.withValues(alpha: 0.1),
          elevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        ),
        body: BlocBuilder<UpcomingMaintenanceCubit, UpcomingMaintenanceState>(
          builder: (context, upcomingState) {
            List<PredictedMaintenanceInfo> allPredictions = [];
            if (upcomingState is UpcomingMaintenanceLoaded) {
              allPredictions = upcomingState.allPredictions;
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Actions
                  Row(
                    children: [
                      QuickActionButton(
                        label: AppLocalizations.of(context)!.addVehicle,
                        icon: Icons.add_circle_outline,
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.addVehicleRoute,
                          );
                        },
                      ),
                      const SizedBox(width: 15),
                      QuickActionButton(
                        label: AppLocalizations.of(context)!.logMaintenance,
                        icon: Icons.edit_calendar_outlined,
                        onPressed: () {
                          context
                              .read<QuickActionService>()
                              .handleLogMaintenanceRequest(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),

                  // Urgent Reminders
                  Text(
                    AppLocalizations.of(context)!.urgentReminders,
                    style: TextStyle(
                      color: themeExtensions.textColorOnBackground,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (upcomingState is UpcomingMaintenanceLoading)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(
                          color: themeExtensions.textColorOnBackground,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  if (upcomingState is UpcomingMaintenanceLoaded)
                    _buildDashboardUrgentReminders(context, allPredictions),
                  if (upcomingState is UpcomingMaintenanceError)
                    Text(
                      upcomingState.message,
                      style: const TextStyle(
                        color: AppColors.urgentReminderText,
                      ),
                    ),
                  const SizedBox(height: 15),

                  // My Vehicles
                  Text(
                    AppLocalizations.of(context)!.myVehicles,
                    style: TextStyle(
                      color: themeExtensions.textColorOnBackground,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  BlocBuilder<VehicleCubit, VehicleState>(
                    builder: (context, state) {
                      if (state is VehicleLoading) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: themeExtensions.textColorOnBackground,
                          ),
                        );
                      } else if (state is VehicleLoaded) {
                        if (state.vehicles.isEmpty) {
                          return Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: Text(
                                AppLocalizations.of(context)!.noVehicles,
                                style: TextStyle(
                                  color: themeExtensions.textColorOnBackground,
                                ),
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: state.vehicles.length,
                          itemBuilder: (context, index) {
                            final vehicle = state.vehicles[index];
                            return _buildVehicleSummaryCardWithPrediction(
                              context,
                              vehicle,
                              allPredictions,
                            );
                          },
                        );
                      } else if (state is VehicleError) {
                        return Center(
                          child: Text(
                            state.message,
                            style: const TextStyle(
                              color: AppColors.urgentReminderText,
                            ),
                          ),
                        );
                      }
                      return Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: Text(
                            AppLocalizations.of(context)!.noVehicles,
                            style: TextStyle(
                              color: themeExtensions.textColorOnBackground,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
        bottomNavigationBar: const MainBottomNavigationBar(currentIndex: 0),
      ),
    );
  }
}
