import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:transparent_image/transparent_image.dart';

import 'package:carvita/application/use_cases/maintenance_plan_use_cases.dart';
import 'package:carvita/application/use_cases/service_log_use_cases.dart';
import 'package:carvita/application/use_cases/vehicle_use_cases.dart';
import 'package:carvita/core/constants/app_colors.dart';
import 'package:carvita/core/constants/app_routes.dart';
import 'package:carvita/core/failures/app_failure.dart';
import 'package:carvita/core/theme/app_theme.dart';
import 'package:carvita/core/widgets/gradient_background.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/presentation/failures/app_failure_localizer.dart';
import 'package:carvita/presentation/manager/maintenance_plan/maintenance_plan_cubit.dart';
import 'package:carvita/presentation/manager/service_log/service_log_cubit.dart';
import 'package:carvita/presentation/manager/vehicle_list/vehicle_cubit.dart';
import 'package:carvita/presentation/navigation/app_route_arguments.dart';
import 'package:carvita/presentation/screens/vehicle/tabs/maintenance_plan_tab.dart';
import 'package:carvita/presentation/screens/vehicle/tabs/overview_tab.dart';
import 'package:carvita/presentation/screens/vehicle/tabs/service_history_tab.dart';

import 'package:carvita/presentation/manager/vehicle_list/vehicle_state.dart'
    as vehicle_list_state_import;

class VehicleDetailsScreen extends StatefulWidget {
  final int vehicleId;
  final VehicleDetailsTab initialTab;
  final VehicleUseCases? vehicleUseCases;
  final MaintenancePlanUseCases? maintenancePlanUseCases;
  final ServiceLogUseCases? serviceLogUseCases;

  const VehicleDetailsScreen({
    super.key,
    required this.vehicleId,
    this.initialTab = VehicleDetailsTab.overview,
    this.vehicleUseCases,
    this.maintenancePlanUseCases,
    this.serviceLogUseCases,
  });

  @override
  State<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Vehicle? _vehicle;
  bool _isLoading = true;
  AppFailure? _failure;

  late final VehicleUseCases _vehicleUseCases;
  late final MaintenancePlanUseCases _maintenancePlanUseCases;
  late final ServiceLogUseCases _serviceLogUseCases;

  @override
  void initState() {
    super.initState();
    _vehicleUseCases =
        widget.vehicleUseCases ?? context.read<VehicleUseCases>();
    _maintenancePlanUseCases =
        widget.maintenancePlanUseCases ??
        context.read<MaintenancePlanUseCases>();
    _serviceLogUseCases =
        widget.serviceLogUseCases ?? context.read<ServiceLogUseCases>();
    _tabController = TabController(
      length: 3,
      initialIndex: widget.initialTab.index,
      vsync: this,
    );
    _fetchVehicleDetails();
  }

  Future<void> _fetchVehicleDetails() async {
    setState(() {
      _isLoading = true;
      _failure = null;
    });
    try {
      final vehicle = await _vehicleUseCases.getVehicleById(widget.vehicleId);
      if (mounted) {
        setState(() {
          _vehicle = vehicle;
          _isLoading = false;
        });
      }
    } catch (error, stackTrace) {
      if (mounted) {
        setState(() {
          _failure = AppFailure.capture(
            AppFailureKind.load,
            error,
            stackTrace,
            context: 'VehicleDetailsScreen.fetchVehicleDetails',
          );
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildVehicleHeader(BuildContext context, Vehicle vehicle) {
    final themeExtensions = Theme.of(context).extension<AppThemeExtensions>()!;
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: themeExtensions.textColorOnBackground,
                size: 24,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(height: 0),
          if (vehicle.image != null && vehicle.image!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: FadeInImage(
                placeholder: MemoryImage(kTransparentImage),
                image: MemoryImage(vehicle.image!),
                fadeInDuration: const Duration(milliseconds: 200),
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                imageErrorBuilder: (context, error, stackTrace) => Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: themeExtensions.textColorOnBackground.withValues(
                      alpha: 0.2,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: themeExtensions.textColorOnBackground.withValues(
                        alpha: 0.5,
                      ),
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    Icons.directions_car,
                    size: 50,
                    color: themeExtensions.textColorOnBackground,
                  ),
                ),
              ),
            )
          else
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: themeExtensions.textColorOnBackground.withValues(
                  alpha: 0.2,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: themeExtensions.textColorOnBackground.withValues(
                    alpha: 0.5,
                  ),
                  width: 3,
                ),
              ),
              child: Icon(
                Icons.directions_car,
                size: 50,
                color: themeExtensions.textColorOnBackground,
              ),
            ),
          const SizedBox(height: 10),
          Text(
            vehicle.name,
            style: TextStyle(
              color: themeExtensions.textColorOnBackground,
              fontSize: 22,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          Text(
            "${vehicle.model != null ? '${vehicle.model} - ' : ''}${DateFormat.y((Localizations.localeOf(context).toLanguageTag())).format(vehicle.boughtDate)}",
            style: TextStyle(
              color: themeExtensions.textColorOnBackground.withValues(
                alpha: 0.85,
              ),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final themeExtensions = Theme.of(context).extension<AppThemeExtensions>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : Theme.of(context).colorScheme.onPrimary;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: themeExtensions.primaryGradient.colors[0],
        unselectedLabelColor: themeExtensions.textColorOnBackground,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: themeExtensions.textColorOnBackground,
        ),
        indicatorWeight: 0,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        tabs: [
          Tab(text: AppLocalizations.of(context)!.overview),
          Tab(text: AppLocalizations.of(context)!.maintenancePlanShort),
          Tab(text: AppLocalizations.of(context)!.maintenanceLogShort),
        ],
      ),
    );
  }

  Widget _buildUnavailableState({
    required BuildContext context,
    required String message,
  }) {
    final themeExtensions = Theme.of(context).extension<AppThemeExtensions>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: TextStyle(color: themeExtensions.textColorOnBackground),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                  label: Text(AppLocalizations.of(context)!.back),
                ),
                FilledButton.icon(
                  onPressed: _fetchVehicleDetails,
                  icon: const Icon(Icons.refresh),
                  label: Text(AppLocalizations.of(context)!.retry),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadyPage(
    BuildContext context,
    AppThemeExtensions themeExtensions,
  ) {
    final vehicle = _vehicle!;
    return MultiBlocProvider(
      providers: [
        BlocProvider<MaintenancePlanCubit>(
          create: (_) =>
              MaintenancePlanCubit(_maintenancePlanUseCases, vehicle.id!)
                ..fetchPlanItems(),
        ),
        BlocProvider<ServiceLogCubit>(
          create: (_) =>
              ServiceLogCubit(_serviceLogUseCases, vehicle.id!)
                ..fetchServiceLogs(),
        ),
      ],
      child: Builder(
        builder: (builderContext) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Column(
              children: [
                _buildVehicleHeader(builderContext, vehicle),
                _buildTabBar(),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLowest,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        OverviewTab(vehicle: vehicle),
                        MaintenancePlanTab(
                          vehicleId: vehicle.id!,
                          vehicleName: vehicle.name,
                        ),
                        ServiceHistoryTab(
                          vehicleId: vehicle.id!,
                          vehicleName: vehicle.name,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                Navigator.pushNamed(
                  builderContext,
                  AppRoutes.logMaintenanceRoute,
                  arguments: LogMaintenanceRouteArguments(
                    vehicleId: vehicle.id!,
                    vehicleName: vehicle.name,
                    serviceLogCubit: builderContext.read<ServiceLogCubit>(),
                    maintenancePlanCubit: builderContext
                        .read<MaintenancePlanCubit>(),
                  ),
                );
              },
              backgroundColor: Theme.of(context).colorScheme.primary,
              shape: const CircleBorder(),
              child: Icon(
                Icons.edit_calendar_outlined,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          );
        },
      ),
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

    return BlocListener<VehicleCubit, vehicle_list_state_import.VehicleState>(
      listener: (BuildContext context, vehicleListState) {
        if (vehicleListState is vehicle_list_state_import.VehicleLoaded &&
            _vehicle != null) {
          final updatedVehicleInList = vehicleListState.vehicles
              .firstWhereOrNull((v) => v.id == _vehicle!.id);

          if (updatedVehicleInList != null) {
            if (!updatedVehicleInList.isIdentical(_vehicle!)) {
              _fetchVehicleDetails();
            }
          } else {
            if (mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context)!.errVehDeleted),
                  backgroundColor: AppColors.urgentReminderText,
                ),
              );
            }
          }
        }
      },
      child: GradientBackground(
        gradient: themeExtensions.primaryGradient,
        child: _isLoading
            ? Scaffold(
                backgroundColor: Colors.transparent,
                body: Center(
                  child: CircularProgressIndicator(
                    color: themeExtensions.textColorOnBackground,
                  ),
                ),
              )
            : _failure != null
            ? Scaffold(
                backgroundColor: Colors.transparent,
                body: _buildUnavailableState(
                  context: context,
                  message: _failure!.toLocalizedMessage(
                    AppLocalizations.of(context)!,
                  ),
                ),
              )
            : _vehicle?.id == null
            ? Scaffold(
                backgroundColor: Colors.transparent,
                body: _buildUnavailableState(
                  context: context,
                  message: AppLocalizations.of(context)!.errVehDeleted,
                ),
              )
            : _buildReadyPage(context, themeExtensions),
      ),
    );
  }
}
