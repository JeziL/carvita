import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:carvita/core/constants/app_colors.dart';
import 'package:carvita/core/constants/app_routes.dart';
import 'package:carvita/data/models/maintenance_plan_item.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/presentation/manager/locale_provider.dart';
import 'package:carvita/presentation/manager/maintenance_plan/maintenance_plan_cubit.dart';
import 'package:carvita/presentation/manager/maintenance_plan/maintenance_plan_state.dart';
import 'package:carvita/presentation/manager/service_log/service_log_cubit.dart';
import 'package:carvita/presentation/manager/upcoming_maintenance/upcoming_maintenance_cubit.dart';

class MaintenancePlanTab extends StatefulWidget {
  final int vehicleId;
  final String vehicleName;

  const MaintenancePlanTab({
    super.key,
    required this.vehicleId,
    required this.vehicleName,
  });

  @override
  State<MaintenancePlanTab> createState() => _MaintenancePlanTabState();
}

class _MaintenancePlanTabState extends State<MaintenancePlanTab> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> _confirmDeleteItem(
    BuildContext context,
    MaintenancePlanItem item,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          title: Text(
            AppLocalizations.of(context)!.confirmDelete,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 24,
            ),
          ),
          content: Text(
            AppLocalizations.of(context)!.deleteConfirmMPlan(item.itemName),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                AppLocalizations.of(context)!.cancel,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: Text(
                AppLocalizations.of(context)!.delete,
                style: TextStyle(color: AppColors.urgentReminderText),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true && item.id != null && context.mounted) {
      final cubit = context.read<MaintenancePlanCubit>();
      await cubit.deletePlanItem(item.id!);
      if (context.mounted &&
          (cubit.state is MaintenancePlanOperationSuccess ||
              cubit.state is MaintenancePlanLoaded)) {
        context.read<UpcomingMaintenanceCubit>().loadAllUpcomingMaintenance(
          AppLocalizations.of(context),
        );
        context.read<ServiceLogCubit>().fetchServiceLogs();
      }
    }
  }

  String _formatInterval(MaintenancePlanItem item) {
    final localeProvider = context.watch<LocaleProvider>();
    List<String> parts = [];
    if (item.intervalMileage != null) {
      parts.add(
        AppLocalizations.of(
          context,
        )!.everyNMileage(item.intervalMileage!, localeProvider.mileageUnit),
      );
    }
    if (item.intervalTimeMonths != null) {
      parts.add(
        AppLocalizations.of(context)!.everyNMonth(item.intervalTimeMonths!),
      );
    }
    if (parts.isEmpty) return ""; // should not happen
    return "${AppLocalizations.of(context)!.regularInterval}: ${parts.join(' / ')}";
  }

  @override
  Widget build(BuildContext context) {
    final maintenancePlanCubit = BlocProvider.of<MaintenancePlanCubit>(context);

    return BlocConsumer<MaintenancePlanCubit, MaintenancePlanState>(
      listener: (context, state) {
        if (state is MaintenancePlanError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              backgroundColor: AppColors.urgentReminderText,
            ),
          );
        }
      },
      builder: (context, state) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.maintenancePlan,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.addManualItemRoute,
                        arguments: {
                          'vehicleId': widget.vehicleId,
                          'vehicleName': widget.vehicleName,
                          'planItem': null, // Adding new item
                          'cubitInstance': maintenancePlanCubit,
                          'serviceLogCubit': context.read<ServiceLogCubit>(),
                        },
                      );
                    },
                    icon: Icon(
                      Icons.add,
                      size: 18,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    label: Text(
                      AppLocalizations.of(context)!.addMPlan,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(fontSize: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              if (state is MaintenancePlanLoading)
                const Center(child: CircularProgressIndicator()),
              if (state is MaintenancePlanLoaded)
                if (state.planItems.isEmpty)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 30.0),
                      child: Text(
                        AppLocalizations.of(
                          context,
                        )!.emptyMPlan(AppLocalizations.of(context)!.addMPlan),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    padding: const EdgeInsets.all(0),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.planItems.length,
                    itemBuilder: (context, index) {
                      final item = state.planItems[index];
                      final regularIntervalString = _formatInterval(item);

                      return Card(
                        color:
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerLowest,
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                            width: 0.2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.itemName,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      regularIntervalString,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.8),
                                      ),
                                    ),
                                    if (item.notes != null &&
                                        item.notes!.isNotEmpty)
                                      const SizedBox(height: 4),
                                    if (item.notes != null &&
                                        item.notes!.isNotEmpty)
                                      Text(
                                        "${AppLocalizations.of(context)!.notes}: ${item.notes}",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: Icon(
                                  Icons.more_vert,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                                onSelected: (String value) {
                                  if (value == 'edit') {
                                    Navigator.pushNamed(
                                      context,
                                      AppRoutes.addManualItemRoute,
                                      arguments: {
                                        'vehicleId': widget.vehicleId,
                                        'vehicleName': widget.vehicleName,
                                        'planItem': item,
                                        'cubitInstance': maintenancePlanCubit,
                                        'serviceLogCubit':
                                            context.read<ServiceLogCubit>(),
                                      },
                                    );
                                  } else if (value == 'delete') {
                                    _confirmDeleteItem(context, item);
                                  }
                                },
                                itemBuilder:
                                    (
                                      BuildContext context,
                                    ) => <PopupMenuEntry<String>>[
                                      PopupMenuItem<String>(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.edit_outlined,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                              size: 20,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              AppLocalizations.of(
                                                context,
                                              )!.edit,
                                              style: TextStyle(
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete_outline,
                                              color:
                                                  AppColors.urgentReminderText,
                                              size: 20,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              AppLocalizations.of(
                                                context,
                                              )!.delete,
                                              style: TextStyle(
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                // offset: Offset(0, 40),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ],
          ),
        );
      },
    );
  }
}
