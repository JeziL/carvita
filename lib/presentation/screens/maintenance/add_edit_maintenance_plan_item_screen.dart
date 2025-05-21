import 'package:carvita/core/constants/app_colors.dart';
import 'package:carvita/core/widgets/gradient_background.dart';
import 'package:carvita/data/models/maintenance_plan_item.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/presentation/manager/maintenance_plan/maintenance_plan_cubit.dart';
import 'package:carvita/presentation/manager/maintenance_plan/maintenance_plan_state.dart';
import 'package:carvita/presentation/manager/upcoming_maintenance/upcoming_maintenance_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AddEditMaintenancePlanItemScreen extends StatefulWidget {
  final int vehicleId;
  final String vehicleName;
  final MaintenancePlanItem? planItemToEdit;

  const AddEditMaintenancePlanItemScreen({
    super.key,
    required this.vehicleId,
    required this.vehicleName,
    this.planItemToEdit,
  });

  @override
  State<AddEditMaintenancePlanItemScreen> createState() =>
      _AddEditMaintenancePlanItemScreenState();
}

class _AddEditMaintenancePlanItemScreenState
    extends State<AddEditMaintenancePlanItemScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _itemNameController;
  late TextEditingController _intervalTimeMonthsController;
  late TextEditingController _intervalMileageController;
  late TextEditingController _firstIntervalTimeMonthsController;
  late TextEditingController _firstIntervalMileageController;
  late TextEditingController _notesController;

  bool get _isEditing => widget.planItemToEdit != null;
  String get _vehicleName => widget.vehicleName;

  @override
  void initState() {
    super.initState();
    final item = widget.planItemToEdit;
    _itemNameController = TextEditingController(text: item?.itemName ?? '');
    _intervalTimeMonthsController = TextEditingController(
      text: item?.intervalTimeMonths?.toString() ?? '',
    );
    _intervalMileageController = TextEditingController(
      text: item?.intervalMileage?.toString() ?? '',
    );
    _firstIntervalTimeMonthsController = TextEditingController(
      text: item?.firstIntervalTimeMonths?.toString() ?? '',
    );
    _firstIntervalMileageController = TextEditingController(
      text: item?.firstIntervalMileage?.toString() ?? '',
    );
    _notesController = TextEditingController(text: item?.notes ?? '');
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _intervalTimeMonthsController.dispose();
    _intervalMileageController.dispose();
    _firstIntervalTimeMonthsController.dispose();
    _firstIntervalMileageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final itemName = _itemNameController.text.trim();

      final String regularTimeText = _intervalTimeMonthsController.text.trim();
      final String regularMileageText = _intervalMileageController.text.trim();
      final int? intervalTimeMonths = int.tryParse(regularTimeText);
      final int? intervalMileage = int.tryParse(regularMileageText);

      final String firstTimeText =
          _firstIntervalTimeMonthsController.text.trim();
      final String firstMileageText =
          _firstIntervalMileageController.text.trim();
      final int? firstIntervalTimeMonths = int.tryParse(firstTimeText);
      final int? firstIntervalMileage = int.tryParse(firstMileageText);

      final String notes = _notesController.text.trim();

      bool isValidRegularIntervalSet =
          (intervalTimeMonths != null && intervalTimeMonths > 0) ||
          (intervalMileage != null && intervalMileage > 0);

      if (!isValidRegularIntervalSet) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.invalidRegularInterval,
              style: TextStyle(color: AppColors.textWhite),
            ),
            backgroundColor: AppColors.urgentReminderText,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      if (regularTimeText.isNotEmpty &&
          (intervalTimeMonths == null || intervalTimeMonths <= 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.invalidOptionalEntry(
                AppLocalizations.of(context)!.regularInterval,
              ),
              style: TextStyle(color: AppColors.textWhite),
            ),
            backgroundColor: AppColors.urgentReminderText,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      if (regularMileageText.isNotEmpty &&
          (intervalMileage == null || intervalMileage <= 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.invalidOptionalEntry(
                AppLocalizations.of(context)!.regularInterval,
              ),
              style: TextStyle(color: AppColors.textWhite),
            ),
            backgroundColor: AppColors.urgentReminderText,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      bool userAttemptedFirstIntervalTime = firstTimeText.isNotEmpty;
      if (userAttemptedFirstIntervalTime &&
          (firstIntervalTimeMonths == null || firstIntervalTimeMonths <= 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.invalidOptionalEntry(
                AppLocalizations.of(context)!.initialInterval,
              ),
              style: TextStyle(color: AppColors.textWhite),
            ),
            backgroundColor: AppColors.urgentReminderText,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      bool userAttemptedFirstIntervalMileage = firstMileageText.isNotEmpty;
      if (userAttemptedFirstIntervalMileage &&
          (firstIntervalMileage == null || firstIntervalMileage <= 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.invalidOptionalEntry(
                AppLocalizations.of(context)!.initialInterval,
              ),
              style: TextStyle(color: AppColors.textWhite),
            ),
            backgroundColor: AppColors.urgentReminderText,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      final planItem = MaintenancePlanItem(
        id: widget.planItemToEdit?.id, // Keep ID if editing
        vehicleId: widget.vehicleId,
        itemName: itemName,
        intervalTimeMonths: intervalTimeMonths,
        intervalMileage: intervalMileage,
        firstIntervalTimeMonths: firstIntervalTimeMonths,
        firstIntervalMileage: firstIntervalMileage,
        notes: notes.isNotEmpty ? notes : null,
      );

      final cubit = context.read<MaintenancePlanCubit>();
      if (_isEditing) {
        await cubit.updatePlanItem(planItem);
      } else {
        await cubit.addPlanItem(planItem);
      }

      if (mounted &&
          (cubit.state is MaintenancePlanOperationSuccess ||
              cubit.state is MaintenancePlanLoaded)) {
        context.read<UpcomingMaintenanceCubit>().loadAllUpcomingMaintenance();
      }

      if (mounted) Navigator.of(context).pop();
    }
  }

  Widget _buildIntervalGroup({
    required String title,
    required TextEditingController timeController,
    required TextEditingController mileageController,
    required String timeHint,
    required String mileageHint,
  }) {
    // final inputDecorationTheme = Theme.of(context).inputDecorationTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textWhite.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: timeController,
                style: const TextStyle(color: AppColors.textWhite),
                decoration: InputDecoration(hintText: timeHint),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: TextFormField(
                controller: mileageController,
                style: const TextStyle(color: AppColors.textWhite),
                decoration: InputDecoration(hintText: mileageHint),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          AppLocalizations.of(context)!.hintComesFirst,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textWhite.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            AppLocalizations.of(
              context,
            )!.addEditMaintenanceItem(_isEditing ? 'edit' : 'add'),
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
                  AppLocalizations.of(context)!.addEditMaintenanceItemForVeh(
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

                TextFormField(
                  controller: _itemNameController,
                  style: const TextStyle(color: AppColors.textWhite),
                  decoration: InputDecoration(
                    labelText: '${AppLocalizations.of(context)!.itemName}*',
                    hintText: AppLocalizations.of(context)!.itemNameHint,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return AppLocalizations.of(context)!.invalidEmptyEntry(
                        AppLocalizations.of(context)!.itemName,
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _buildIntervalGroup(
                  title: AppLocalizations.of(context)!.regularInterval,
                  timeController: _intervalTimeMonthsController,
                  mileageController: _intervalMileageController,
                  timeHint: AppLocalizations.of(context)!.timeHint,
                  mileageHint: AppLocalizations.of(context)!.mileageHint,
                ),
                const SizedBox(height: 20),
                _buildIntervalGroup(
                  title:
                      "${AppLocalizations.of(context)!.initialInterval} (${AppLocalizations.of(context)!.optionalEntry})",
                  timeController: _firstIntervalTimeMonthsController,
                  mileageController: _firstIntervalMileageController,
                  timeHint: AppLocalizations.of(context)!.firstTimeHint,
                  mileageHint: AppLocalizations.of(context)!.firstMileageHint,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _notesController,
                  style: const TextStyle(color: AppColors.textWhite),
                  decoration: InputDecoration(
                    labelText: "${AppLocalizations.of(context)!.notes} (${AppLocalizations.of(context)!.optionalEntry})",
                    hintText: AppLocalizations.of(context)!.noteMaintenanceItemHint,
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
                    AppLocalizations.of(context)!.addEditButtonText(_isEditing ? 'edit' : 'add'),
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
