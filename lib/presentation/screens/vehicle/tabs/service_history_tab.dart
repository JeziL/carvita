import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:carvita/core/constants/app_colors.dart';
import 'package:carvita/core/constants/app_routes.dart';
import 'package:carvita/data/models/service_log_entry.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/presentation/manager/locale_provider.dart';
import 'package:carvita/presentation/manager/maintenance_plan/maintenance_plan_cubit.dart';
import 'package:carvita/presentation/manager/service_log/service_log_cubit.dart';
import 'package:carvita/presentation/manager/service_log/service_log_state.dart';
import 'package:carvita/presentation/manager/upcoming_maintenance/upcoming_maintenance_cubit.dart';

class ServiceHistoryTab extends StatefulWidget {
  final int vehicleId;
  final String vehicleName;

  const ServiceHistoryTab({
    super.key,
    required this.vehicleId,
    required this.vehicleName,
  });

  @override
  State<ServiceHistoryTab> createState() => _ServiceHistoryTabState();
}

class _ServiceHistoryTabState extends State<ServiceHistoryTab> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> _confirmDeleteLog(
    BuildContext context,
    ServiceLogWithItems logWithItems,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: Text(
            AppLocalizations.of(context)!.confirmDelete,
            style: TextStyle(color: AppColors.textBlack),
          ),
          content: Text(
            AppLocalizations.of(
              context,
            )!.deleteConfirmMLog(logWithItems.entry.serviceDate),
            style: const TextStyle(color: AppColors.textBlack),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                AppLocalizations.of(context)!.cancel,
                style: TextStyle(color: AppColors.primaryBlue),
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

    if (confirmed == true && logWithItems.entry.id != null && context.mounted) {
      final cubit = context.read<ServiceLogCubit>();
      await cubit.deleteServiceLog(logWithItems.entry.id!);
      if (context.mounted &&
          (cubit.state is ServiceLogOperationSuccess ||
              cubit.state is ServiceLogLoaded)) {
        context.read<UpcomingMaintenanceCubit>().loadAllUpcomingMaintenance();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final serviceLogCubit = BlocProvider.of<ServiceLogCubit>(context);
    final maintenancePlanCubit = BlocProvider.of<MaintenancePlanCubit>(context);
    final localeProvider = context.watch<LocaleProvider>();

    return BlocConsumer<ServiceLogCubit, ServiceLogState>(
      listener: (context, state) {
        if (state is ServiceLogError) {
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
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)!.maintenanceLog,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textBlack,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.logMaintenanceRoute,
                        arguments: {
                          'vehicleId': widget.vehicleId,
                          'vehicleName': widget.vehicleName,
                          'logToEdit': null,
                          'serviceLogCubit': serviceLogCubit,
                          'maintenancePlanCubit': maintenancePlanCubit,
                        },
                      );
                    },
                    icon: const Icon(
                      Icons.add,
                      size: 18,
                      color: AppColors.white,
                    ),
                    label: Text(
                      AppLocalizations.of(context)!.addMLog,
                      style: TextStyle(color: AppColors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
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
              if (state is ServiceLogLoading)
                const Center(child: CircularProgressIndicator()),
              if (state is ServiceLogLoaded)
                if (state.serviceLogs.isEmpty)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 30.0),
                      child: Text(
                        AppLocalizations.of(
                          context,
                        )!.emptyMLog(AppLocalizations.of(context)!.addMLog),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textBlack,
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
                    itemCount: state.serviceLogs.length,
                    itemBuilder: (context, index) {
                      final logWithItems = state.serviceLogs[index];
                      final entry = logWithItems.entry;

                      return Card(
                        color: AppColors.cardBackground,
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.grey[200]!,
                            width: 0.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 15.0,
                            right: 8.0,
                            top: 15.0,
                            bottom: 15.0,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(entry.serviceDate)} @ ${AppLocalizations.of(context)!.nMileage(entry.mileageAtService.round(), localeProvider.mileageUnit)}",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textBlack,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (logWithItems
                                        .performedItemDisplayNames
                                        .isNotEmpty)
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "${AppLocalizations.of(context)!.serviceItemLabel}: ${logWithItems.performedItemDisplayNames.join(AppLocalizations.of(context)!.seperator)}",
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textBlack
                                                  .withValues(alpha: 0.7),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                        ],
                                      ),
                                    if (entry.cost != null)
                                      Text(
                                        AppLocalizations.of(
                                          context,
                                        )!.costWithSign(entry.cost!),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textBlack.withValues(
                                            alpha: 0.8,
                                          ),
                                        ),
                                      ),
                                    if (entry.notes != null &&
                                        entry.notes!.isNotEmpty)
                                      const SizedBox(height: 4),
                                    if (entry.notes != null &&
                                        entry.notes!.isNotEmpty)
                                      Text(
                                        "${AppLocalizations.of(context)!.notes}: ${entry.notes}",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textBlack.withValues(
                                            alpha: 0.7,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: Icon(
                                  Icons.more_vert,
                                  color: AppColors.textBlack.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                                onSelected: (String value) {
                                  if (value == 'edit') {
                                    Navigator.pushNamed(
                                      context,
                                      AppRoutes.logMaintenanceRoute,
                                      arguments: {
                                        'vehicleId': widget.vehicleId,
                                        'vehicleName': widget.vehicleName,
                                        'logToEdit': logWithItems,
                                        'serviceLogCubit': serviceLogCubit,
                                        'maintenancePlanCubit':
                                            maintenancePlanCubit,
                                      },
                                    );
                                  } else if (value == 'delete') {
                                    _confirmDeleteLog(context, logWithItems);
                                  }
                                },
                                itemBuilder:
                                    (
                                      BuildContext bc,
                                    ) => <PopupMenuEntry<String>>[
                                      PopupMenuItem<String>(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.edit_outlined,
                                              color: AppColors.primaryBlue,
                                              size: 20,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              AppLocalizations.of(
                                                context,
                                              )!.edit,
                                              style: TextStyle(
                                                color: AppColors.textBlack,
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
                                                color: AppColors.textBlack,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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
