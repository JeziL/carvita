import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import 'package:carvita/core/constants/app_colors.dart';
import 'package:carvita/core/constants/app_routes.dart';
import 'package:carvita/core/services/notification_service.dart';
import 'package:carvita/core/services/preferences_service.dart';
import 'package:carvita/core/widgets/gradient_background.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/data/repositories/vehicle_repository.dart';
import 'package:carvita/data/sources/local/database_helper.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/main.dart';
import 'package:carvita/presentation/manager/locale_provider.dart';
import 'package:carvita/presentation/manager/upcoming_maintenance/upcoming_maintenance_cubit.dart';
import 'package:carvita/presentation/manager/vehicle_list/vehicle_cubit.dart';
import 'package:carvita/presentation/screens/common_widgets/main_bottom_navigation_bar.dart';

import 'package:carvita/presentation/manager/vehicle_list/vehicle_state.dart'
    as vehicle_list_state_import;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final PreferencesService _preferencesService = PreferencesService();
  final VehicleRepository _vehicleRepository = VehicleRepository();

  String _defaultVehicleName = "";
  int? _currentDefaultVehicleId;
  bool _maintenanceRemindersEnabled = false;
  int _selectedLeadTimeDays = 7;
  final NotificationService _notificationService = NotificationService();
  DueReminderThresholdValue _selectedThreshold =
      DueReminderThresholdValue.halfYear;
  int _selectedReminderItemCount = 3;
  bool _isExporting = false;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _loadDefaultVehicleInfo();
    _loadReminderSettings();
    _loadNotificationSettings();
  }

  Future<void> _loadDefaultVehicleInfo() async {
    final defaultId = await _preferencesService.getDefaultVehicleId();
    if (!mounted) return;

    _currentDefaultVehicleId = defaultId;
    if (defaultId != null) {
      final vehicleState = context.read<VehicleCubit>().state;
      Vehicle? vehicle;
      if (vehicleState is vehicle_list_state_import.VehicleLoaded) {
        vehicle = vehicleState.vehicles.firstWhereOrNull(
          (v) => v.id == defaultId,
        );
      }
      vehicle ??= await _vehicleRepository.getVehicleById(defaultId);

      if (vehicle != null) {
        if (mounted) setState(() => _defaultVehicleName = vehicle!.name);
      } else {
        await _preferencesService.setDefaultVehicleId(null);
        if (mounted) {
          setState(() {
            _defaultVehicleName = AppLocalizations.of(context)!.notSet;
            _currentDefaultVehicleId = null;
          });
        }
      }
    } else {
      if (mounted) {
        setState(
          () => _defaultVehicleName = AppLocalizations.of(context)!.notSet,
        );
      }
    }
  }

  Future<void> _showSelectDefaultVehicleDialog(
    BuildContext context,
    List<Vehicle> vehicles,
  ) async {
    int? newSelectedId = _currentDefaultVehicleId;

    final result = await showDialog<int?>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (stfContext, stfSetState) {
            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              title: Text(
                AppLocalizations.of(context)!.chooseDefaultVehicle,
                style: TextStyle(color: AppColors.textBlack, fontSize: 20),
              ),
              contentPadding: const EdgeInsets.only(top: 10.0, bottom: 0),
              content: SizedBox(
                width: double.maxFinite,
                child:
                    vehicles.isEmpty
                        ? Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 20.0,
                            horizontal: 24.0,
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.noVehicles,
                            style: TextStyle(color: AppColors.textBlack),
                          ),
                        )
                        : ListView.builder(
                          shrinkWrap: true,
                          itemCount: vehicles.length,
                          itemBuilder: (BuildContext context, int index) {
                            final vehicle = vehicles[index];
                            return RadioListTile<int?>(
                              title: Text(
                                vehicle.name,
                                style: const TextStyle(
                                  color: AppColors.textBlack,
                                ),
                              ),
                              value: vehicle.id,
                              groupValue: newSelectedId,
                              activeColor: AppColors.primaryBlue,
                              onChanged: (int? value) {
                                stfSetState(() {
                                  newSelectedId = value;
                                });
                                Navigator.of(dialogContext).pop(newSelectedId);
                              },
                            );
                          },
                        ),
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actionsPadding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              actions: <Widget>[
                TextButton(
                  child: Text(
                    AppLocalizations.of(context)!.clearDefault,
                    style: TextStyle(color: AppColors.urgentReminderText),
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(null);
                  },
                ),
                TextButton(
                  child: Text(
                    AppLocalizations.of(context)!.cancel,
                    style: TextStyle(color: AppColors.primaryBlue),
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(_currentDefaultVehicleId);
                  },
                ),
              ],
            );
          },
        );
      },
    );

    if (result != _currentDefaultVehicleId) {
      await _preferencesService.setDefaultVehicleId(result);
      _loadDefaultVehicleInfo();
    }
  }

  Future<void> _loadReminderSettings() async {
    final threshold = await _preferencesService.getDueReminderThreshold();
    final count = await _preferencesService.getDueReminderItemCount();
    if (mounted) {
      setState(() {
        _selectedThreshold = threshold;
        _selectedReminderItemCount = count;
      });
    }
  }

  Future<void> _showSelectReminderThresholdDialog(BuildContext context) async {
    final DueReminderThresholdValue? result =
        await showDialog<DueReminderThresholdValue>(
          context: context,
          builder: (BuildContext dialogContext) {
            return SimpleDialog(
              backgroundColor: AppColors.cardBackground,
              title: Text(
                AppLocalizations.of(context)!.chooseThreshold,
                style: TextStyle(
                  color: AppColors.textBlack,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              children:
                  DueReminderThresholdValue.values.map((threshold) {
                    return SimpleDialogOption(
                      onPressed: () => Navigator.pop(dialogContext, threshold),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(
                          threshold.displayString(context),
                          style: const TextStyle(
                            color: AppColors.textBlack,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            );
          },
        );

    if (result != null && result != _selectedThreshold) {
      await _preferencesService.setDueReminderThreshold(result);
      if (mounted) {
        setState(() => _selectedThreshold = result);
      }
    }
  }

  Future<void> _showSelectReminderItemCountDialog(BuildContext context) async {
    final List<int> counts = [1, 3, 5];
    final int? result = await showDialog<int>(
      context: context,
      builder: (BuildContext dialogContext) {
        return SimpleDialog(
          backgroundColor: AppColors.cardBackground,
          title: Text(
            AppLocalizations.of(context)!.chooseDisplayItemCount,
            style: TextStyle(
              color: AppColors.textBlack,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          children:
              counts.map((count) {
                return SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogContext, count),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Text(
                      AppLocalizations.of(context)!.itemCount(count),
                      style: const TextStyle(
                        color: AppColors.textBlack,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              }).toList(),
        );
      },
    );

    if (result != null && result != _selectedReminderItemCount) {
      await _preferencesService.setDueReminderItemCount(result);
      if (mounted) {
        setState(() => _selectedReminderItemCount = result);
      }
    }
  }

  Future<void> _exportDatabase() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.exportPrepare)),
    );

    try {
      final dbFolder = await getDatabasesPath();
      final sourceDbPath = path.join(dbFolder, DatabaseHelper.dbName);
      final sourceDbFile = File(sourceDbPath);

      if (!await sourceDbFile.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.errDBNotFound),
              backgroundColor: AppColors.urgentReminderText,
            ),
          );
        }
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final tempDbPath = path.join(
        tempDir.path,
        'carvita_backup_$timestamp.db',
      );
      final tempDbFile = await sourceDbFile.copy(tempDbPath);

      final shareResult = await SharePlus.instance.share(
        ShareParams(files: [XFile(tempDbFile.path)]),
      );

      if (shareResult.status == ShareResultStatus.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.exportSuccess),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (shareResult.status == ShareResultStatus.dismissed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.exportCancelled),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(shareResult.status.toString()),
              backgroundColor: AppColors.urgentReminderText,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.urgentReminderText,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _importDatabase() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: Text(
            AppLocalizations.of(context)!.restoreWarningTitle,
            style: TextStyle(color: AppColors.textBlack, fontSize: 20),
          ),
          content: Text(
            AppLocalizations.of(context)!.restoreWarningBody,
            style: TextStyle(color: AppColors.textBlack),
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
                AppLocalizations.of(context)!.restoreData,
                style: TextStyle(
                  color: AppColors.urgentReminderText,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    if (_isImporting) return;

    setState(() => _isImporting = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.chooseDBFile)),
      );
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.single.path != null) {
        final pickedFile = File(result.files.single.path!);

        await DatabaseHelper().close();

        final dbFolder = await getDatabasesPath();
        final appDbPath = path.join(dbFolder, DatabaseHelper.dbName);
        final appDbFile = File(appDbPath);

        if (await appDbFile.exists()) {
          await appDbFile.delete();
        }

        await pickedFile.copy(appDbPath);

        if (mounted) {
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                backgroundColor: AppColors.cardBackground,
                title: Text(
                  AppLocalizations.of(context)!.restoreSuccessTitle,
                  style: TextStyle(color: AppColors.textBlack),
                ),
                content: Text(
                  AppLocalizations.of(context)!.restoreSuccessBody,
                  style: TextStyle(color: AppColors.textBlack),
                ),
                actions: <Widget>[
                  TextButton(
                    child: Text(
                      AppLocalizations.of(context)!.exitButton,
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      SystemNavigator.pop(); // try exit the app (may not apply to all platforms)
                    },
                  ),
                ],
              );
            },
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.importCancelled),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.urgentReminderText,
          ),
        );
      }
      // Try to reopen the database connection in case the app is in an unstable state after failure
      await DatabaseHelper().database;
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _loadNotificationSettings() async {
    final enabled = await _preferencesService.getNotificationsEnabled();
    final leadTime = await _preferencesService.getReminderLeadTimeDays();
    if (mounted) {
      setState(() {
        _maintenanceRemindersEnabled = enabled;
        _selectedLeadTimeDays = leadTime;
      });
    }
  }

  Future<void> _showSelectReminderLeadTimeDialog(BuildContext context) async {
    final List<int> leadTimeOptions =
        PreferencesService.reminderLeadTimeOptionsInDays;

    final int? result = await showDialog<int>(
      context: context,
      builder: (BuildContext dialogContext) {
        return SimpleDialog(
          backgroundColor: AppColors.cardBackground,
          title: Text(
            AppLocalizations.of(context)!.chooseLeadTime,
            style: TextStyle(
              color: AppColors.textBlack,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          children:
              leadTimeOptions.map((days) {
                return SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogContext, days),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Text(
                      AppLocalizations.of(context)!.notificationLeadTime(days),
                      style: const TextStyle(
                        color: AppColors.textBlack,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              }).toList(),
        );
      },
    );

    if (result != null && result != _selectedLeadTimeDays) {
      await _preferencesService.setReminderLeadTimeDays(result);
      if (mounted) {
        setState(() => _selectedLeadTimeDays = result);
        _triggerNotificationReschedule();
      }
    }
  }

  void _triggerNotificationReschedule() {
    context
        .read<UpcomingMaintenanceCubit>()
        .rescheduleNotificationsBasedOnNewSettings();
  }

  Future<void> _showSelectMileageUnitDialog(
    BuildContext context,
    LocaleProvider localeProvider,
  ) async {
    final List<String> units = ['km', 'mi'];
    String currentSelection = localeProvider.mileageUnit;

    final String? result = await showDialog<String?>(
      context: context,
      builder: (BuildContext dialogContext) {
        return SimpleDialog(
          backgroundColor: AppColors.cardBackground,
          title: Text(
            AppLocalizations.of(context)!.chooseMileageUnit,
            style: TextStyle(
              color: AppColors.textBlack,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          children:
              units.map((unit) {
                return SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogContext, unit),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Text(
                      AppLocalizations.of(context)!.mileageUnit(unit),
                      style: TextStyle(
                        color:
                            (currentSelection == unit)
                                ? AppColors.primaryBlue
                                : AppColors.textBlack,
                        fontSize: 16,
                        fontWeight:
                            (currentSelection == unit)
                                ? FontWeight.bold
                                : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
        );
      },
    );

    if (result != localeProvider.mileageUnit && result != null) {
      await localeProvider.setMileageUnit(result);
      _loadDefaultVehicleInfo();
    }
  }

  Widget _buildSettingsCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      color: AppColors.cardBackground,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.only(
          left: 18.0,
          right: 18.0,
          top: 5.0,
          bottom: 5.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10.0, bottom: 0.0),
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textBlack.withValues(alpha: 0.6),
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String label,
    String? value,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primaryBlue, size: 22),
      title: Text(
        label,
        style: const TextStyle(fontSize: 16, color: AppColors.textBlack),
      ),
      subtitle:
          value != null
              ? Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textBlack.withValues(alpha: 0.7),
                ),
              )
              : null,
      trailing:
          trailing ??
          (onTap != null
              ? Icon(
                Icons.chevron_right,
                color: AppColors.textBlack.withValues(alpha: 0.5),
              )
              : null),
      onTap: onTap,
    );
  }

  Future<void> _showSelectLanguageDialog(
    BuildContext context,
    LocaleProvider localeProvider,
  ) async {
    final List<Map<String, dynamic>> supportedLanguages = [
      {
        'locale': null,
        'name': LocaleProvider.getLocaleDisplayString(null, context),
      },
      ...appSupportedLocales.map(
        (l) => {
          'locale': l,
          'name': LocaleProvider.getLocaleDisplayString(l, context),
        },
      ),
    ];

    Locale? currentSelection = localeProvider.appLocale;

    final Locale? result = await showDialog<Locale?>(
      context: context,
      builder: (BuildContext dialogContext) {
        return SimpleDialog(
          backgroundColor: AppColors.cardBackground,
          title: Text(
            AppLocalizations.of(context)!.chooseLanguage,
            style: TextStyle(
              color: AppColors.textBlack,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          children:
              supportedLanguages.map((lang) {
                Locale? langLocale = lang['locale'] as Locale?;
                String langName = lang['name'] as String;
                return SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogContext, langLocale),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Text(
                      langName,
                      style: TextStyle(
                        color:
                            (currentSelection?.toLanguageTag() ==
                                        langLocale?.toLanguageTag()) ||
                                    (currentSelection == null &&
                                        langLocale == null)
                                ? AppColors.primaryBlue
                                : AppColors.textBlack,
                        fontSize: 16,
                        fontWeight:
                            (currentSelection?.toLanguageTag() ==
                                        langLocale?.toLanguageTag()) ||
                                    (currentSelection == null &&
                                        langLocale == null)
                                ? FontWeight.bold
                                : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
        );
      },
    );

    if (result != localeProvider.appLocale) {
      await localeProvider.setLocale(result);
      _loadDefaultVehicleInfo();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleState = context.watch<VehicleCubit>().state;
    final localeProvider = context.watch<LocaleProvider>();

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            AppLocalizations.of(context)!.navSettings,
            style: TextStyle(
              color: AppColors.textWhite,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: AppColors.statusBarColor,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 20),
          children: [
            _buildSettingsCard(
              title: AppLocalizations.of(context)!.notification,
              children: [
                _buildSettingItem(
                  icon: Icons.notifications_active_outlined,
                  label: AppLocalizations.of(context)!.notificationEnabled,
                  trailing: Switch(
                    value: _maintenanceRemindersEnabled,
                    onChanged: (bool value) async {
                      if (!value) {
                        await _preferencesService.setNotificationsEnabled(
                          value,
                        );
                        setState(() => _maintenanceRemindersEnabled = value);
                        await _notificationService.cancelAllNotifications();
                      } else {
                        bool notificationsEnabled =
                            await _notificationService.checkPermissions();
                        if (!notificationsEnabled) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.errNotificationPermission,
                                ),
                                backgroundColor: AppColors.urgentReminderText,
                              ),
                            );
                          }
                          return;
                        }
                        await _preferencesService.setNotificationsEnabled(
                          value,
                        );
                        setState(() => _maintenanceRemindersEnabled = value);
                        _triggerNotificationReschedule();
                      }
                    },
                    activeColor: AppColors.primaryBlue,
                  ),
                ),
                _buildSettingItem(
                  icon: Icons.schedule_outlined,
                  label:
                      AppLocalizations.of(context)!.notificationLeadTimeLabel,
                  value: AppLocalizations.of(
                    context,
                  )!.notificationLeadTime(_selectedLeadTimeDays),
                  onTap: () => _showSelectReminderLeadTimeDialog(context),
                ),
              ],
            ),
            _buildSettingsCard(
              title: AppLocalizations.of(context)!.dashboardTitle,
              children: [
                _buildSettingItem(
                  icon: Icons.star_border_purple500_outlined,
                  label: AppLocalizations.of(context)!.defaultVehicle,
                  value:
                      _currentDefaultVehicleId == null
                          ? AppLocalizations.of(context)!.notSet
                          : _defaultVehicleName,
                  onTap: () {
                    if (vehicleState
                        is vehicle_list_state_import.VehicleLoaded) {
                      if (vehicleState.vehicles.isNotEmpty) {
                        _showSelectDefaultVehicleDialog(
                          context,
                          vehicleState.vehicles,
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              AppLocalizations.of(context)!.noVehicles,
                            ),
                            backgroundColor: AppColors.primaryBlue,
                          ),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context)!.loading),
                          backgroundColor: AppColors.primaryBlue,
                        ),
                      );
                      context.read<VehicleCubit>().fetchVehicles();
                    }
                  },
                ),
                _buildSettingItem(
                  icon: Icons.hourglass_bottom_outlined,
                  label: AppLocalizations.of(context)!.reminderThresholdSetting,
                  value: _selectedThreshold.displayString(context),
                  onTap: () => _showSelectReminderThresholdDialog(context),
                ),
                _buildSettingItem(
                  icon: Icons.checklist_outlined,
                  label: AppLocalizations.of(context)!.reminderDisplayItemCount,
                  value: AppLocalizations.of(
                    context,
                  )!.itemCount(_selectedReminderItemCount),
                  onTap: () => _showSelectReminderItemCountDialog(context),
                ),
              ],
            ),
            _buildSettingsCard(
              title: AppLocalizations.of(context)!.general,
              children: [
                _buildSettingItem(
                  icon: Icons.language_outlined,
                  label: AppLocalizations.of(context)!.language,
                  value: localeProvider.getCurrentLocaleDisplayString(context),
                  onTap:
                      () => _showSelectLanguageDialog(context, localeProvider),
                ),
                _buildSettingItem(
                  icon: Icons.straighten_outlined,
                  label: AppLocalizations.of(context)!.mileageUnitLabel,
                  value: AppLocalizations.of(
                    context,
                  )!.mileageUnit(localeProvider.mileageUnit),
                  onTap:
                      () =>
                          _showSelectMileageUnitDialog(context, localeProvider),
                ),
              ],
            ),
            _buildSettingsCard(
              title: AppLocalizations.of(context)!.data,
              children: [
                _buildSettingItem(
                  icon: Icons.cloud_download_outlined,
                  label: AppLocalizations.of(context)!.restoreData,
                  onTap: _isImporting ? null : _importDatabase,
                  trailing:
                      _isImporting
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryBlue,
                            ),
                          )
                          : Icon(
                            Icons.chevron_right,
                            color: AppColors.textBlack.withValues(alpha: 0.5),
                          ),
                ),
                _buildSettingItem(
                  icon: Icons.ios_share_outlined,
                  label: AppLocalizations.of(context)!.exportData,
                  onTap: _isExporting ? null : _exportDatabase,
                  trailing:
                      _isExporting
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryBlue,
                            ),
                          )
                          : Icon(
                            Icons.chevron_right,
                            color: AppColors.textBlack.withValues(alpha: 0.5),
                          ),
                ),
              ],
            ),
            _buildSettingsCard(
              title: AppLocalizations.of(context)!.about,
              children: [
                _buildSettingItem(
                  icon: Icons.info_outline,
                  label: AppLocalizations.of(context)!.appVersionEntry,
                  value: "0.9.0 (early access)",
                ),
                // _buildSettingItem(
                //   icon: Icons.help_outline,
                //   label: "Help & Support",
                //   onTap: () {
                //     /* Placeholder */
                //   },
                // ),
                _buildSettingItem(
                  icon: Icons.shield_outlined,
                  label: AppLocalizations.of(context)!.privacyPolicy,
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.privacyRoute);
                  },
                ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: const MainBottomNavigationBar(
          currentIndex: 3,
        ), // Index for Settings
      ),
    );
  }
}
