// import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:carvita/core/constants/app_colors.dart';
import 'package:carvita/core/widgets/gradient_background.dart';
import 'package:carvita/data/models/maintenance_plan_item.dart';
import 'package:carvita/data/models/service_log_entry.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/data/repositories/vehicle_repository.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/presentation/manager/locale_provider.dart';
import 'package:carvita/presentation/manager/maintenance_plan/maintenance_plan_cubit.dart';
import 'package:carvita/presentation/manager/service_log/service_log_cubit.dart';
import 'package:carvita/presentation/manager/service_log/service_log_state.dart';
import 'package:carvita/presentation/manager/upcoming_maintenance/upcoming_maintenance_cubit.dart';
import 'package:carvita/presentation/manager/vehicle_list/vehicle_cubit.dart';

import 'package:carvita/presentation/manager/maintenance_plan/maintenance_plan_state.dart'
    as plan_state;

class LogMaintenanceScreen extends StatefulWidget {
  final int vehicleId;
  final String vehicleName;
  final ServiceLogWithItems? logToEdit; // Null if adding new

  const LogMaintenanceScreen({
    super.key,
    required this.vehicleId,
    required this.vehicleName,
    this.logToEdit,
  });

  @override
  State<LogMaintenanceScreen> createState() => _LogMaintenanceScreenState();
}

class _LogMaintenanceScreenState extends State<LogMaintenanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vehicleRepository = VehicleRepository();

  late TextEditingController _dateController;
  late TextEditingController _mileageController;
  late TextEditingController _costController;
  late TextEditingController _notesController;
  late TextEditingController _customItemNameController;

  DateTime? _selectedServiceDate;

  List<MaintenancePlanItem> _availablePlanItems = [];
  final Set<int> _selectedPredefinedItemIds = <int>{};
  final Set<String> _selectedCustomItemNames = <String>{};

  bool get _isEditing => widget.logToEdit != null;
  String get _vehicleName => widget.vehicleName;

  @override
  void initState() {
    super.initState();
    final log = widget.logToEdit?.entry;

    _selectedServiceDate = log?.serviceDate ?? DateTime.now();
    final localeProvider = context.read<LocaleProvider>();
    final String? currentLocaleTag = localeProvider.appLocale?.toLanguageTag();
    _dateController = TextEditingController(
      text: DateFormat.yMMMd(currentLocaleTag).format(_selectedServiceDate!),
    );

    _mileageController = TextEditingController(
      text: log?.mileageAtService.toString() ?? '',
    );
    _costController = TextEditingController(text: log?.cost?.toString() ?? '');
    _notesController = TextEditingController(text: log?.notes ?? '');
    _customItemNameController = TextEditingController();

    final planState = context.read<MaintenancePlanCubit>().state;
    if (planState is plan_state.MaintenancePlanLoaded) {
      _availablePlanItems = planState.planItems;
    } else {
      context.read<MaintenancePlanCubit>().fetchPlanItems();
    }

    if (_isEditing && widget.logToEdit != null) {
      for (String displayName in widget.logToEdit!.performedItemDisplayNames) {
        bool foundAsPredefined = false;
        if (planState is plan_state.MaintenancePlanLoaded) {
          for (var planItem in planState.planItems) {
            if (planItem.itemName == displayName && planItem.id != null) {
              _selectedPredefinedItemIds.add(planItem.id!);
              foundAsPredefined = true;
              break;
            }
          }
        }
        if (!foundAsPredefined) {
          _selectedCustomItemNames.add(displayName);
        }
      }
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _mileageController.dispose();
    _costController.dispose();
    _notesController.dispose();
    _customItemNameController.dispose();
    super.dispose();
  }

  Future<void> _selectServiceDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedServiceDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryBlue,
              onPrimary: AppColors.white,
              onSurface: AppColors.textBlack,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedServiceDate) {
      setState(() {
        _selectedServiceDate = picked;
        _dateController.text = DateFormat.yMMMd(
          Localizations.localeOf(context).toLanguageTag(),
        ).format(picked);
      });
    }
  }

  void _addCustomItem() {
    final customName = _customItemNameController.text.trim();
    if (customName.isNotEmpty) {
      setState(() {
        _selectedCustomItemNames.add(customName);
        _customItemNameController.clear();
      });
    }
  }

  void _submitForm() async {
    final localeProvider = context.watch<LocaleProvider>();
    if (!_formKey.currentState!.validate()) return;
    if (_selectedServiceDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            )!.invalidEmptyEntry(AppLocalizations.of(context)!.maintenanceDate),
          ),
        ),
      );
      return;
    }

    final List<PerformedItemInput> performedItems = [];
    for (int id in _selectedPredefinedItemIds) {
      performedItems.add(PerformedItemInput(maintenancePlanItemId: id));
    }
    for (String name in _selectedCustomItemNames) {
      performedItems.add(PerformedItemInput(customItemName: name));
    }

    if (performedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.invalidEmptyEntry(
              AppLocalizations.of(context)!.maintenanceItems,
            ),
          ),
        ),
      );
      return;
    }

    final newMileageAtService = double.parse(_mileageController.text.trim());
    final logEntry = ServiceLogEntry(
      id: widget.logToEdit?.entry.id,
      vehicleId: widget.vehicleId,
      serviceDate: _selectedServiceDate!,
      mileageAtService: newMileageAtService,
      cost:
          _costController.text.trim().isEmpty
              ? null
              : double.tryParse(_costController.text.trim()),
      notes:
          _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
    );

    final serviceLogCubit = context.read<ServiceLogCubit>();
    bool submissionSuccess = false;
    if (_isEditing) {
      await serviceLogCubit.updateServiceLog(logEntry, performedItems);
      if (serviceLogCubit.state is ServiceLogOperationSuccess ||
          serviceLogCubit.state is ServiceLogLoaded) {
        submissionSuccess = true;
      }
    } else {
      await serviceLogCubit.addServiceLog(logEntry, performedItems);
      if (serviceLogCubit.state is ServiceLogOperationSuccess ||
          serviceLogCubit.state is ServiceLogLoaded) {
        submissionSuccess = true;
      }
    }

    if (submissionSuccess && mounted) {
      Vehicle? currentVehicle = await _vehicleRepository.getVehicleById(
        widget.vehicleId,
      );

      if (currentVehicle != null &&
          newMileageAtService > currentVehicle.mileage &&
          mounted) {
        final bool? confirmUpdate = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              title: Text(
                AppLocalizations.of(context)!.updateMileageTitle,
                style: TextStyle(color: AppColors.textBlack, fontSize: 24),
              ),
              content: Text(
                AppLocalizations.of(context)!.updateMileageBody(
                  newMileageAtService.toStringAsFixed(0),
                  currentVehicle.mileage.toStringAsFixed(0),
                  currentVehicle.name,
                  localeProvider.mileageUnit,
                ),
                style: const TextStyle(color: AppColors.textBlack),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text(
                    AppLocalizations.of(context)!.no,
                    style: TextStyle(color: AppColors.primaryBlue),
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
                TextButton(
                  child: Text(
                    AppLocalizations.of(context)!.yes,
                    style: TextStyle(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                ),
              ],
            );
          },
        );

        if (confirmUpdate == true) {
          final updatedVehicle = currentVehicle.copyWith(
            mileage: newMileageAtService,
          );
          // ignore: use_build_context_synchronously
          await context.read<VehicleCubit>().updateVehicle(updatedVehicle);
        }
      }
      if (mounted) {
        context.read<UpcomingMaintenanceCubit>().loadAllUpcomingMaintenance(
          AppLocalizations.of(context),
        );
      }
      if (mounted) Navigator.of(context).pop();
    }
  }

  Widget _buildItemSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "${AppLocalizations.of(context)!.maintenanceItems}*",
          style: TextStyle(
            color: AppColors.textWhite.withValues(alpha: 0.9),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        BlocBuilder<MaintenancePlanCubit, plan_state.MaintenancePlanState>(
          builder: (context, state) {
            if (state is plan_state.MaintenancePlanLoaded) {
              _availablePlanItems = state.planItems;
              if (_availablePlanItems.isEmpty &&
                  _selectedCustomItemNames.isEmpty) {
                // No predefined items and no custom items yet
              }
            } else if (state is plan_state.MaintenancePlanLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.white,
                  strokeWidth: 2,
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_availablePlanItems.isNotEmpty)
                  Text(
                    "${AppLocalizations.of(context)!.chooseFromPlan}:",
                    style: TextStyle(
                      color: AppColors.textWhite.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                if (_availablePlanItems.isNotEmpty)
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children:
                        _availablePlanItems.map((item) {
                          final isSelected = _selectedPredefinedItemIds
                              .contains(item.id);
                          return Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(canvasColor: Colors.transparent),
                            child: ChoiceChip(
                              label: Text(
                                item.itemName,
                                style: TextStyle(
                                  color:
                                      isSelected
                                          ? AppColors.primaryBlue
                                          : AppColors.textWhite.withValues(
                                            alpha: 0.9,
                                          ),
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedPredefinedItemIds.add(item.id!);
                                  } else {
                                    _selectedPredefinedItemIds.remove(item.id);
                                  }
                                });
                              },
                              backgroundColor: Colors.transparent,
                              selectedColor: AppColors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color:
                                      isSelected
                                          ? AppColors.primaryBlue
                                          : AppColors.white.withValues(
                                            alpha: 0.3,
                                          ),
                                ),
                              ),
                              labelPadding: const EdgeInsets.symmetric(
                                horizontal: 6.0,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6.0,
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                if (_availablePlanItems.isNotEmpty) const SizedBox(height: 15),

                if (_selectedCustomItemNames.isNotEmpty)
                  Text(
                    "${AppLocalizations.of(context)!.customItemAdded}:",
                    style: TextStyle(
                      color: AppColors.textWhite.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                if (_selectedCustomItemNames.isNotEmpty)
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children:
                        _selectedCustomItemNames
                            .map(
                              (name) => Chip(
                                label: Text(
                                  name,
                                  style: const TextStyle(
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                                backgroundColor: AppColors.white.withValues(
                                  alpha: 0.9,
                                ),
                                deleteIconColor: AppColors.primaryBlue
                                    .withValues(alpha: 0.7),
                                onDeleted: () {
                                  setState(() {
                                    _selectedCustomItemNames.remove(name);
                                  });
                                },
                              ),
                            )
                            .toList(),
                  ),
                if (_selectedCustomItemNames.isNotEmpty)
                  const SizedBox(height: 15),

                // Input for custom items
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _customItemNameController,
                        style: const TextStyle(color: AppColors.textWhite),
                        decoration: InputDecoration(
                          hintText:
                              AppLocalizations.of(context)!.customItemAddHint,
                        ),
                        onFieldSubmitted:
                            (_) =>
                                _addCustomItem(), // Allow submitting with enter key
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: AppColors.white,
                      ),
                      onPressed: _addCustomItem,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            AppLocalizations.of(
              context,
            )!.addEditMaintenanceLog(_isEditing ? 'edit' : 'add'),
            style: const TextStyle(
              color: AppColors.textWhite,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: AppColors.statusBarColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: AppColors.textWhite,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  AppLocalizations.of(context)!.addEditMaintenanceLogForVeh(
                    _isEditing ? 'edit' : 'add',
                    _vehicleName,
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textWhite.withValues(alpha: 0.8),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                // Date
                TextFormField(
                  controller: _dateController,
                  style: const TextStyle(color: AppColors.textWhite),
                  decoration: InputDecoration(
                    labelText:
                        '${AppLocalizations.of(context)!.maintenanceDate}*',
                    suffixIcon: Icon(
                      Icons.calendar_today,
                      color: AppColors.textWhite,
                    ),
                  ),
                  readOnly: true,
                  onTap: () => _selectServiceDate(context),
                  validator:
                      (value) =>
                          (value == null || value.isEmpty)
                              ? AppLocalizations.of(context)!.invalidEmptyEntry(
                                AppLocalizations.of(context)!.maintenanceDate,
                              )
                              : null,
                ),
                const SizedBox(height: 20),

                // Mileage
                TextFormField(
                  controller: _mileageController,
                  style: const TextStyle(color: AppColors.textWhite),
                  decoration: InputDecoration(
                    labelText:
                        '${AppLocalizations.of(context)!.mileageAtService} (${localeProvider.mileageUnit})*',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,1}$'),
                    ),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return AppLocalizations.of(context)!.invalidEmptyEntry(
                        AppLocalizations.of(context)!.maintenanceDate,
                      );
                    }
                    if (double.tryParse(value.trim()) == null ||
                        double.parse(value.trim()) <= 0) {
                      return AppLocalizations.of(context)!.invalidOptionalEntry(
                        AppLocalizations.of(context)!.maintenanceDate,
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Item Selection Section
                _buildItemSelectionSection(),
                const SizedBox(height: 20),

                // Cost
                TextFormField(
                  controller: _costController,
                  style: const TextStyle(color: AppColors.textWhite),
                  decoration: InputDecoration(
                    labelText:
                        '${AppLocalizations.of(context)!.cost} (${AppLocalizations.of(context)!.optionalEntry})',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}$'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Notes
                TextFormField(
                  controller: _notesController,
                  style: const TextStyle(color: AppColors.textWhite),
                  decoration: InputDecoration(
                    labelText:
                        '${AppLocalizations.of(context)!.notes} (${AppLocalizations.of(context)!.optionalEntry})',
                    hintText: AppLocalizations.of(context)!.notesMLogHint,
                  ),
                  maxLines: 3,
                  minLines: 1,
                ),
                const SizedBox(height: 30),

                ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(
                      context,
                    )!.addEditButtonText(_isEditing ? 'edit' : 'add'),
                    style: const TextStyle(color: AppColors.primaryBlue),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
