import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:carvita/core/constants/app_colors.dart';
import 'package:carvita/core/theme/app_theme.dart';
import 'package:carvita/core/widgets/gradient_background.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/presentation/manager/locale_provider.dart';
import 'package:carvita/presentation/manager/upcoming_maintenance/upcoming_maintenance_cubit.dart';
import 'package:carvita/presentation/manager/vehicle_list/vehicle_cubit.dart';
import 'package:carvita/presentation/manager/vehicle_list/vehicle_state.dart';

class AddEditVehicleScreen extends StatefulWidget {
  final Vehicle? vehicle;

  const AddEditVehicleScreen({super.key, this.vehicle});

  @override
  State<AddEditVehicleScreen> createState() => _AddEditVehicleScreenState();
}

class _AddEditVehicleScreenState extends State<AddEditVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _mileageController;
  late TextEditingController _boughtDateController;
  late TextEditingController _modelController;
  late TextEditingController _plateNumberController;
  late TextEditingController _vinController;
  late TextEditingController _engineNumberController;

  Uint8List? _selectedImageBytes;
  DateTime? _selectedBoughtDate;

  bool get _isEditing => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _nameController = TextEditingController(text: v?.name ?? '');
    _mileageController = TextEditingController(
      text: v?.mileage.toString() ?? '',
    );
    _selectedBoughtDate = v?.boughtDate;
    _boughtDateController = TextEditingController(
      text: v != null ? DateFormat.yMMMd().format(v.boughtDate) : '',
    );
    _modelController = TextEditingController(text: v?.model ?? '');
    _plateNumberController = TextEditingController(text: v?.plateNumber ?? '');
    _vinController = TextEditingController(text: v?.vin ?? '');
    _engineNumberController = TextEditingController(
      text: v?.engineNumber ?? '',
    );
    _selectedImageBytes = v?.image;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mileageController.dispose();
    _boughtDateController.dispose();
    _modelController.dispose();
    _plateNumberController.dispose();
    _vinController.dispose();
    _engineNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? imageFile = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 800,
    );

    if (imageFile != null) {
      final bytes = await imageFile.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
      });
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(
                  Icons.photo_library,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  AppLocalizations.of(context)!.chooseFromGallery,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                onTap: () {
                  _pickImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_camera,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  AppLocalizations.of(context)!.takePhoto,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                onTap: () {
                  _pickImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
              if (_selectedImageBytes != null)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: AppColors.urgentReminderText,
                  ),
                  title: Text(
                    AppLocalizations.of(context)!.removePhoto,
                    style: TextStyle(color: AppColors.urgentReminderText),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedImageBytes = null;
                    });
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectBoughtDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBoughtDate ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(
        const Duration(days: 1),
      ), // Cannot be in future
      builder: (_, child) => child!,
    );
    if (picked != null && picked != _selectedBoughtDate) {
      setState(() {
        _selectedBoughtDate = picked;
        _boughtDateController.text = DateFormat.yMMMd(
          Localizations.localeOf(context).toLanguageTag(),
        ).format(picked);
      });
    }
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      if (_selectedBoughtDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              )!.invalidEmptyEntry(AppLocalizations.of(context)!.boughtDate),
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
            backgroundColor: AppColors.urgentReminderText,
          ),
        );
        return;
      }

      final mileageFilled =
          double.tryParse(_mileageController.text.trim()) ?? 0;
      var mileageLastUpdated = DateTime.now();
      if (_isEditing && mileageFilled == widget.vehicle!.mileage) {
        mileageLastUpdated = widget.vehicle!.mileageLastUpdated;
      } else {}

      final vehicleData = Vehicle(
        id: widget.vehicle?.id,
        name: _nameController.text.trim(),
        mileage: mileageFilled,
        mileageLastUpdated: mileageLastUpdated,
        boughtDate: _selectedBoughtDate!,
        image: _selectedImageBytes,
        model:
            _modelController.text.trim().isNotEmpty
                ? _modelController.text.trim()
                : null,
        plateNumber:
            _plateNumberController.text.trim().isNotEmpty
                ? _plateNumberController.text.trim()
                : null,
        vin:
            _vinController.text.trim().isNotEmpty
                ? _vinController.text.trim()
                : null,
        engineNumber:
            _engineNumberController.text.trim().isNotEmpty
                ? _engineNumberController.text.trim()
                : null,
      );

      final cubit = context.read<VehicleCubit>();
      if (_isEditing) {
        await cubit.updateVehicle(vehicleData);
      } else {
        await cubit.addVehicle(vehicleData);
      }

      if (mounted &&
          (cubit.state is VehicleOperationSuccess ||
              cubit.state is VehicleLoaded)) {
        context.read<UpcomingMaintenanceCubit>().loadAllUpcomingMaintenance(
          AppLocalizations.of(context),
        );
      }

      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    final themeExtensions = Theme.of(context).extension<AppThemeExtensions>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onPrimary;

    Widget formField(
      TextEditingController controller,
      String label,
      String? hint, {
      TextInputType keyboardType = TextInputType.text,
      bool isRequired = false,
      String? Function(String?)? validator,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18.0),
        child: TextFormField(
          controller: controller,
          style: TextStyle(color: themeExtensions.textColorOnBackground),
          decoration: InputDecoration(labelText: label, hintText: hint),
          keyboardType: keyboardType,
          validator: (value) {
            if (isRequired && (value == null || value.trim().isEmpty)) {
              return AppLocalizations.of(context)!.invalidEmptyEntry(label);
            }
            return validator != null ? validator(value) : null;
          },
        ),
      );
    }

    return GradientBackground(
      gradient: themeExtensions.primaryGradient,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            AppLocalizations.of(
              context,
            )!.addEditVehicle(_isEditing ? 'edit' : 'add'),
          ),
          backgroundColor: Theme.of(
            context,
          ).colorScheme.inverseSurface.withValues(alpha: 0.1),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new),
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
                GestureDetector(
                  onTap: _showImagePickerOptions,
                  child: Container(
                    height: 150,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: bgColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: bgColor.withValues(alpha: 0.3)),
                    ),
                    child:
                        _selectedImageBytes != null
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: Image.memory(
                                _selectedImageBytes!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 150,
                              ),
                            )
                            : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo_outlined,
                                  size: 36,
                                  color: themeExtensions.textColorOnBackground,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "${AppLocalizations.of(context)!.uploadVehicleImage} (${AppLocalizations.of(context)!.optionalEntry})",
                                  style: TextStyle(
                                    color:
                                        themeExtensions.textColorOnBackground,
                                  ),
                                ),
                              ],
                            ),
                  ),
                ),

                formField(
                  _nameController,
                  '${AppLocalizations.of(context)!.vehicleNickname}*',
                  AppLocalizations.of(context)!.vehicleNicknameHint,
                  isRequired: true,
                ),
                formField(
                  _mileageController,
                  '${AppLocalizations.of(context)!.mileageLabelWithUnit(" (${localeProvider.mileageUnit})")}*',
                  null,
                  keyboardType: TextInputType.number,
                  isRequired: true,
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return AppLocalizations.of(context)!.invalidEmptyEntry(
                        AppLocalizations.of(context)!.mileageLabelWithUnit(""),
                      );
                    }
                    if (double.tryParse(val) == null || double.parse(val) < 0) {
                      return AppLocalizations.of(context)!.invalidOptionalEntry(
                        AppLocalizations.of(context)!.mileageLabelWithUnit(""),
                      );
                    }
                    return null;
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18.0),
                  child: TextFormField(
                    controller: _boughtDateController,
                    style: TextStyle(
                      color: themeExtensions.textColorOnBackground,
                    ),
                    decoration: InputDecoration(
                      labelText: '${AppLocalizations.of(context)!.boughtDate}*',
                      suffixIcon: Icon(
                        Icons.calendar_today,
                        color: themeExtensions.textColorOnBackground,
                      ),
                    ),
                    readOnly: true,
                    onTap: () => _selectBoughtDate(context),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!.invalidEmptyEntry(
                          AppLocalizations.of(context)!.boughtDate,
                        );
                      }
                      return null;
                    },
                  ),
                ),
                formField(
                  _modelController,
                  AppLocalizations.of(context)!.vehicleModel,
                  AppLocalizations.of(context)!.vehicleModelHint,
                ),
                formField(
                  _plateNumberController,
                  AppLocalizations.of(context)!.plateNumber,
                  null,
                ),
                formField(
                  _vinController,
                  AppLocalizations.of(context)!.vin,
                  AppLocalizations.of(context)!.vinHint,
                ),
                formField(
                  _engineNumberController,
                  AppLocalizations.of(context)!.engineNumber,
                  null,
                ),

                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _submitForm,
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
                  child: Text(
                    AppLocalizations.of(
                      context,
                    )!.addEditButtonText(_isEditing ? 'edit' : 'add'),
                    style: TextStyle(
                      color:
                          isDark
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
