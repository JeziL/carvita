import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:carvita/application/use_cases/vehicle_use_cases.dart';
import 'package:carvita/core/constants/app_colors.dart';
import 'package:carvita/core/theme/app_theme.dart';
import 'package:carvita/core/utils/calendar_day.dart';
import 'package:carvita/core/utils/operation_result.dart';
import 'package:carvita/core/widgets/gradient_background.dart';
import 'package:carvita/data/models/maintenance_plan_item.dart';
import 'package:carvita/data/models/service_log_entry.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/presentation/failures/app_failure_localizer.dart';
import 'package:carvita/presentation/formatters/localized_number_input.dart';
import 'package:carvita/presentation/manager/locale_provider.dart';
import 'package:carvita/presentation/manager/maintenance_plan/maintenance_plan_cubit.dart';
import 'package:carvita/presentation/manager/service_log/service_log_cubit.dart';
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
  late final VehicleUseCases _vehicleUseCases;

  late TextEditingController _dateController;
  late TextEditingController _mileageController;
  late TextEditingController _costController;
  late TextEditingController _notesController;
  late TextEditingController _customItemNameController;

  DateTime? _selectedServiceDate;

  List<MaintenancePlanItem> _availablePlanItems = [];
  final Set<int> _selectedPredefinedItemIds = <int>{};
  final Set<String> _selectedCustomItemNames = <String>{};
  bool _isSubmitting = false;

  bool get _isEditing => widget.logToEdit != null;
  String get _vehicleName => widget.vehicleName;

  @override
  void initState() {
    super.initState();
    _vehicleUseCases = context.read<VehicleUseCases>();
    final log = widget.logToEdit?.entry;

    _selectedServiceDate = CalendarDay.clampToToday(
      log?.serviceDate ?? DateTime.now(),
    );
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
      for (final performedItem in widget.logToEdit!.performedItems) {
        final input = PerformedItemInput.fromPerformedItem(performedItem);
        if (input.maintenancePlanItemId != null) {
          _selectedPredefinedItemIds.add(input.maintenancePlanItemId!);
        } else if (input.customItemName != null) {
          _selectedCustomItemNames.add(input.customItemName!);
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
    final today = CalendarDay.dateOnly(DateTime.now());
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: CalendarDay.clampToToday(
        _selectedServiceDate ?? today,
        today: today,
      ),
      firstDate: DateTime(1900),
      lastDate: today,
      builder: (_, child) => child!,
    );
    if (!context.mounted) return;
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.customItemAddHint),
        ),
      );
    }
  }

  void _submitForm() async {
    if (_isSubmitting) return;
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final inputLocale = Localizations.localeOf(context);
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

    final newMileageAtService = LocalizedNumberInput.parseDouble(
      _mileageController.text,
      inputLocale,
    )!;
    final logEntry = ServiceLogEntry(
      id: widget.logToEdit?.entry.id,
      vehicleId: widget.vehicleId,
      serviceDate: _selectedServiceDate!,
      mileageAtService: newMileageAtService,
      cost: _costController.text.trim().isEmpty
          ? null
          : LocalizedNumberInput.parseDouble(_costController.text, inputLocale),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    setState(() {
      _isSubmitting = true;
    });
    final serviceLogCubit = context.read<ServiceLogCubit>();
    final OperationResult result = _isEditing
        ? await serviceLogCubit.updateServiceLog(logEntry, performedItems)
        : await serviceLogCubit.addServiceLog(logEntry, performedItems);
    if (!mounted) return;
    if (result is OperationFailure) {
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.failure.toLocalizedMessage(AppLocalizations.of(context)!),
          ),
          backgroundColor: AppColors.urgentReminderText,
        ),
      );
      return;
    }

    if (result is OperationSuccess) {
      if (result.followUpFailure case final failure?) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failure.failure.toLocalizedMessage(AppLocalizations.of(context)!),
            ),
            backgroundColor: AppColors.urgentReminderText,
          ),
        );
      }
      Vehicle? currentVehicle = await _vehicleUseCases.getVehicleById(
        widget.vehicleId,
      );
      if (!mounted) return;

      if (currentVehicle != null &&
          newMileageAtService > currentVehicle.mileage) {
        final bool? confirmUpdate = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerLowest,
              title: Text(
                AppLocalizations.of(context)!.updateMileageTitle,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 24,
                ),
              ),
              content: Text(
                AppLocalizations.of(context)!.updateMileageBody(
                  newMileageAtService.toStringAsFixed(0),
                  currentVehicle.mileage.toStringAsFixed(0),
                  currentVehicle.name,
                  localeProvider.mileageUnit,
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text(
                    AppLocalizations.of(context)!.no,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
                TextButton(
                  child: Text(
                    AppLocalizations.of(context)!.yes,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                ),
              ],
            );
          },
        );
        if (!mounted) return;

        if (confirmUpdate == true) {
          final updatedVehicle = currentVehicle.copyWith(
            mileage: newMileageAtService,
            mileageLastUpdated: _selectedServiceDate!,
          );
          await context.read<VehicleCubit>().updateVehicle(updatedVehicle);
          if (!mounted) return;
        }
      }
      await context.read<UpcomingMaintenanceCubit>().loadAllUpcomingMaintenance(
        AppLocalizations.of(context),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  Widget _buildItemSelectionSection() {
    final themeExtensions = Theme.of(context).extension<AppThemeExtensions>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : Theme.of(context).colorScheme.onPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(
            context,
          )!.requiredFieldLabel(AppLocalizations.of(context)!.maintenanceItems),
          style: TextStyle(
            color: themeExtensions.textColorOnBackground.withValues(alpha: 0.9),
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
              return Center(
                child: CircularProgressIndicator(
                  color: themeExtensions.textColorOnBackground,
                  strokeWidth: 2,
                ),
              );
            }
            final activePlanItemIds = _availablePlanItems
                .map((item) => item.id)
                .whereType<int>()
                .toSet();
            final unavailableSelectedItems =
                widget.logToEdit?.performedItems
                    .where(
                      (item) =>
                          item.maintenancePlanItemId != null &&
                          _selectedPredefinedItemIds.contains(
                            item.maintenancePlanItemId,
                          ) &&
                          !activePlanItemIds.contains(
                            item.maintenancePlanItemId,
                          ),
                    )
                    .toList(growable: false) ??
                const <ServiceLogPerformedItem>[];
            final hasPlanSelections =
                _availablePlanItems.isNotEmpty ||
                unavailableSelectedItems.isNotEmpty;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasPlanSelections)
                  Text(
                    AppLocalizations.of(context)!.sectionHeading(
                      AppLocalizations.of(context)!.chooseFromPlan,
                    ),
                    style: TextStyle(
                      color: themeExtensions.textColorOnBackground.withValues(
                        alpha: 0.8,
                      ),
                      fontSize: 13,
                    ),
                  ),
                if (hasPlanSelections)
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: [
                      ..._availablePlanItems.map((item) {
                        final isSelected = _selectedPredefinedItemIds.contains(
                          item.id,
                        );
                        return Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(canvasColor: Colors.transparent),
                          child: ChoiceChip(
                            label: Text(
                              item.itemName,
                              style: TextStyle(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : themeExtensions.textColorOnBackground
                                          .withValues(alpha: 0.9),
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
                            selectedColor: Theme.of(
                              context,
                            ).colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : themeExtensions.textColorOnBackground
                                          .withValues(alpha: 0.3),
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
                      }),
                      ...unavailableSelectedItems.map(
                        (item) => Chip(
                          label: Text(
                            item.displayName,
                            style: TextStyle(
                              color: themeExtensions.textColorOnBackground
                                  .withValues(alpha: 0.9),
                            ),
                          ),
                          deleteIconColor:
                              themeExtensions.textColorOnBackground,
                          onDeleted: () {
                            setState(() {
                              _selectedPredefinedItemIds.remove(
                                item.maintenancePlanItemId,
                              );
                            });
                          },
                          backgroundColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: themeExtensions.textColorOnBackground
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                if (hasPlanSelections) const SizedBox(height: 15),

                if (_selectedCustomItemNames.isNotEmpty)
                  Text(
                    AppLocalizations.of(context)!.sectionHeading(
                      AppLocalizations.of(context)!.customItemAdded,
                    ),
                    style: TextStyle(
                      color: themeExtensions.textColorOnBackground.withValues(
                        alpha: 0.8,
                      ),
                      fontSize: 13,
                    ),
                  ),
                if (_selectedCustomItemNames.isNotEmpty)
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: _selectedCustomItemNames
                        .map(
                          (name) => Chip(
                            label: Text(
                              name,
                              style: TextStyle(
                                color:
                                    themeExtensions.primaryGradient.colors[0],
                              ),
                            ),
                            backgroundColor: bgColor.withValues(alpha: 0.9),
                            deleteIconColor: themeExtensions
                                .primaryGradient
                                .colors[0]
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
                        style: TextStyle(
                          color: themeExtensions.textColorOnBackground,
                        ),
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(
                            context,
                          )!.customItemAddHint,
                        ),
                        onFieldSubmitted: (_) =>
                            _addCustomItem(), // Allow submitting with enter key
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: themeExtensions.textColorOnBackground,
                      ),
                      tooltip: AppLocalizations.of(context)!.customItemAddHint,
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
    final inputLocale = Localizations.localeOf(context);
    final themeExtensions = Theme.of(context).extension<AppThemeExtensions>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : Theme.of(context).colorScheme.onPrimary;

    return GradientBackground(
      gradient: themeExtensions.primaryGradient,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            AppLocalizations.of(
              context,
            )!.addEditMaintenanceLog(_isEditing ? 'edit' : 'add'),
          ),
          backgroundColor: Theme.of(
            context,
          ).colorScheme.inverseSurface.withValues(alpha: 0.1),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new),
            tooltip: AppLocalizations.of(context)!.back,
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
                    color: themeExtensions.textColorOnBackground.withValues(
                      alpha: 0.8,
                    ),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                // Date
                TextFormField(
                  key: const ValueKey('log-date-field'),
                  controller: _dateController,
                  style: TextStyle(
                    color: themeExtensions.textColorOnBackground,
                  ),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.requiredFieldLabel(
                      AppLocalizations.of(context)!.maintenanceDate,
                    ),
                    suffixIcon: Icon(
                      Icons.calendar_today,
                      color: themeExtensions.textColorOnBackground,
                    ),
                  ),
                  readOnly: true,
                  onTap: () => _selectServiceDate(context),
                  validator: (value) => (value == null || value.isEmpty)
                      ? AppLocalizations.of(context)!.invalidEmptyEntry(
                          AppLocalizations.of(context)!.maintenanceDate,
                        )
                      : null,
                ),
                const SizedBox(height: 20),

                // Mileage
                TextFormField(
                  key: const ValueKey('log-mileage-field'),
                  controller: _mileageController,
                  style: TextStyle(
                    color: themeExtensions.textColorOnBackground,
                  ),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!
                        .requiredFieldWithUnit(
                          AppLocalizations.of(context)!.mileageAtService,
                          localeProvider.mileageUnit,
                        ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    LocalizedNumberTextInputFormatter.decimal(
                      inputLocale,
                      maxFractionDigits: 1,
                    ),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return AppLocalizations.of(context)!.invalidEmptyEntry(
                        AppLocalizations.of(context)!.maintenanceDate,
                      );
                    }
                    final mileage = LocalizedNumberInput.parseDouble(
                      value,
                      inputLocale,
                    );
                    if (mileage == null || mileage <= 0) {
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
                  key: const ValueKey('log-cost-field'),
                  controller: _costController,
                  style: TextStyle(
                    color: themeExtensions.textColorOnBackground,
                  ),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.optionalFieldLabel(
                      AppLocalizations.of(context)!.cost,
                      AppLocalizations.of(context)!.optionalEntry,
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    LocalizedNumberTextInputFormatter.decimal(
                      inputLocale,
                      maxFractionDigits: 2,
                    ),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final cost = LocalizedNumberInput.parseDouble(
                      value,
                      inputLocale,
                    );
                    return cost == null || cost < 0
                        ? AppLocalizations.of(context)!.invalidOptionalEntry(
                            AppLocalizations.of(context)!.cost,
                          )
                        : null;
                  },
                ),
                const SizedBox(height: 20),

                // Notes
                TextFormField(
                  controller: _notesController,
                  style: TextStyle(
                    color: themeExtensions.textColorOnBackground,
                  ),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.optionalFieldLabel(
                      AppLocalizations.of(context)!.notes,
                      AppLocalizations.of(context)!.optionalEntry,
                    ),
                    hintText: AppLocalizations.of(context)!.notesMLogHint,
                  ),
                  maxLines: 3,
                  minLines: 1,
                ),
                const SizedBox(height: 30),

                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: bgColor,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  child: _isSubmitting
                      ? SizedBox.square(
                          key: const ValueKey('log-submit-progress'),
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : Text(
                          AppLocalizations.of(
                            context,
                          )!.addEditButtonText(_isEditing ? 'edit' : 'add'),
                          style: TextStyle(
                            color: isDark
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.primary,
                          ),
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
