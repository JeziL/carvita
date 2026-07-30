import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'package:carvita/application/ports/notification_permission_port.dart';
import 'package:carvita/application/ports/platform_ports.dart';
import 'package:carvita/application/use_cases/reconcile_notification_permission.dart';
import 'package:carvita/application/use_cases/vehicle_use_cases.dart';
import 'package:carvita/core/constants/app_colors.dart';
import 'package:carvita/core/constants/app_routes.dart';
import 'package:carvita/core/failures/app_failure.dart';
import 'package:carvita/core/services/preferences_service.dart';
import 'package:carvita/core/theme/app_theme.dart';
import 'package:carvita/core/utils/preference_selection.dart';
import 'package:carvita/core/widgets/gradient_background.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/main.dart';
import 'package:carvita/presentation/failures/app_failure_localizer.dart';
import 'package:carvita/presentation/formatters/preference_localizer.dart';
import 'package:carvita/presentation/manager/locale_provider.dart';
import 'package:carvita/presentation/manager/theme_provider.dart';
import 'package:carvita/presentation/manager/upcoming_maintenance/upcoming_maintenance_cubit.dart';
import 'package:carvita/presentation/manager/vehicle_list/vehicle_cubit.dart';
import 'package:carvita/presentation/screens/common_widgets/main_bottom_navigation_bar.dart';
import 'package:carvita/presentation/screens/settings/backup_settings_section.dart';
import 'package:carvita/presentation/screens/settings/preference_dialogs.dart';

import 'package:carvita/presentation/manager/vehicle_list/vehicle_state.dart'
    as vehicle_list_state_import;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  late final PreferencesService _preferencesService;
  late final VehicleUseCases _vehicleUseCases;
  late final AppPackageInfoPort _packageInfoProvider;
  late final ExternalUrlPort _externalUrl;

  String _defaultVehicleName = "";
  int? _currentDefaultVehicleId;
  bool _maintenanceRemindersEnabled = false;
  int _selectedLeadTimeDays = 7;
  late final NotificationPermissionGateway _notificationService;
  late final ReconcileNotificationPermission _reconcileNotificationPermission;
  DueReminderThresholdValue _selectedThreshold =
      DueReminderThresholdValue.halfYear;
  int _selectedReminderItemCount = 3;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _preferencesService = context.read<PreferencesService>();
    _vehicleUseCases = context.read<VehicleUseCases>();
    _notificationService = context.read<NotificationPermissionGateway>();
    _reconcileNotificationPermission = context
        .read<ReconcileNotificationPermission>();
    _packageInfoProvider = context.read<AppPackageInfoPort>();
    _externalUrl = context.read<ExternalUrlPort>();
    WidgetsBinding.instance.addObserver(this);
    _loadDefaultVehicleInfo();
    _loadReminderSettings();
    _loadNotificationSettings();
    _initPackageInfo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadNotificationSettings();
    }
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
      vehicle ??= await _vehicleUseCases.getVehicleById(defaultId);

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
    final result = await showDefaultVehicleSelectionDialog(
      context: context,
      vehicles: vehicles,
      currentVehicleId: _currentDefaultVehicleId,
    );
    if (!mounted || result == null) return;

    final newVehicleId = switch (result) {
      PreferenceSelected<int>(:final value) => value,
      PreferenceCleared<int>() => null,
    };
    if (newVehicleId != _currentDefaultVehicleId) {
      await _preferencesService.setDefaultVehicleId(newVehicleId);
      if (!mounted) return;
      await _loadDefaultVehicleInfo();
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
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerLowest,
              title: Text(
                AppLocalizations.of(context)!.chooseThreshold,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              children: DueReminderThresholdValue.values.map((threshold) {
                return SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogContext, threshold),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Text(
                      threshold.displayString(context),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
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
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          title: Text(
            AppLocalizations.of(context)!.chooseDisplayItemCount,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          children: counts.map((count) {
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, count),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Text(
                  AppLocalizations.of(context)!.itemCount(count),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
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

  Future<void> _loadNotificationSettings() async {
    try {
      await _reconcileNotificationPermission();
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to reconcile notification permission in settings: '
        '$error\n$stackTrace',
      );
    }
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
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          title: Text(
            AppLocalizations.of(context)!.chooseLeadTime,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          children: leadTimeOptions.map((days) {
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, days),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Text(
                  AppLocalizations.of(context)!.notificationLeadTime(days),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
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

  Future<void> _triggerNotificationReschedule({AppLocalizations? l10n}) async {
    if (!mounted) return;
    try {
      await context
          .read<UpcomingMaintenanceCubit>()
          .rescheduleNotificationsBasedOnNewSettings(
            l10n ?? AppLocalizations.of(context),
          );
    } catch (error, stackTrace) {
      final failure = AppFailure.capture(
        AppFailureKind.reminderUpdate,
        error,
        stackTrace,
        context: 'SettingsScreen.triggerNotificationReschedule',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failure.toLocalizedMessage(l10n ?? AppLocalizations.of(context)!),
          ),
          backgroundColor: AppColors.urgentReminderText,
        ),
      );
    }
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
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          title: Text(
            AppLocalizations.of(context)!.chooseMileageUnit,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          children: units.map((unit) {
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, unit),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Text(
                  AppLocalizations.of(context)!.mileageUnit(unit),
                  style: TextStyle(
                    color: (currentSelection == unit)
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: (currentSelection == unit)
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
      if (!mounted) return;
      await _loadDefaultVehicleInfo();
    }
  }

  Widget _buildSettingsCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
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
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
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
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.primary,
        size: 22,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: value != null
          ? Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            )
          : null,
      trailing:
          trailing ??
          (onTap != null
              ? Icon(
                  Icons.chevron_right,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
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
      ...appSupportedLocales,
    ];

    final result = await showLanguageSelectionDialog(
      context: context,
      supportedLanguages: supportedLanguages,
      currentLocale: localeProvider.appLocale,
    );
    if (!mounted || result == null) return;

    final selectedLocale = switch (result) {
      PreferenceSelected<Locale>(:final value) => value,
      PreferenceCleared<Locale>() => null,
    };
    if (selectedLocale != localeProvider.appLocale) {
      await localeProvider.setLocale(selectedLocale);
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _triggerNotificationReschedule(l10n: AppLocalizations.of(context));
          }
        });
      }
    }
  }

  Future<void> _initPackageInfo() async {
    try {
      final info = await _packageInfoProvider.loadPackageInfo();
      if (!mounted) return;
      setState(() {
        _appVersion = info.version;
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to load package information: $error\n$stackTrace');
    }
  }

  void _showColorPicker(BuildContext context, ThemeProvider themeProvider) {
    Color pickerColor =
        themeProvider.customSeedColor ?? Theme.of(context).colorScheme.primary;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            AppLocalizations.of(context)!.chooseColor,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (color) => pickerColor = color,
              enableAlpha: false, // Usually seed colors don't need alpha
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(AppLocalizations.of(context)!.cancel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(AppLocalizations.of(context)!.ok),
              onPressed: () {
                themeProvider.setCustomSeedColor(pickerColor);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSelectThemeDialog(
    BuildContext context,
    ThemeProvider themeProvider,
  ) async {
    final AppThemePreference? result = await showDialog<AppThemePreference>(
      context: context,
      builder: (BuildContext dialogContext) {
        return SimpleDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            AppLocalizations.of(context)!.chooseTheme,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          children: AppThemePreference.values.map((preference) {
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, preference),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Text(
                  preference.displayString(context),
                  style: TextStyle(
                    color: themeProvider.themePreference == preference
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: themeProvider.themePreference == preference
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

    if (result != null) {
      themeProvider.setThemePreference(result);
      if (result == AppThemePreference.custom &&
          themeProvider.customSeedColor == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showColorPicker(context, themeProvider);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleState = context.watch<VehicleCubit>().state;
    final localeProvider = context.watch<LocaleProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final themeExtensions = Theme.of(context).extension<AppThemeExtensions>()!;

    return GradientBackground(
      gradient: themeExtensions.primaryGradient,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(AppLocalizations.of(context)!.navSettings),
          backgroundColor: Theme.of(
            context,
          ).colorScheme.inverseSurface.withValues(alpha: 0.1),
          elevation: 0,
          systemOverlayStyle: AppTheme.gradientSystemOverlayStyle,
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
                        if (mounted) {
                          setState(() => _maintenanceRemindersEnabled = value);
                        }
                        await _notificationService.cancelAllNotifications();
                      } else {
                        bool notificationsEnabled = await _notificationService
                            .checkPermissions();
                        if (!notificationsEnabled) {
                          notificationsEnabled = await _notificationService
                              .requestPermissions();
                        }
                        if (!context.mounted) return;
                        if (!notificationsEnabled) {
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
                          return;
                        }
                        await _preferencesService.setNotificationsEnabled(
                          value,
                        );
                        if (!mounted) return;
                        setState(() => _maintenanceRemindersEnabled = value);
                        _triggerNotificationReschedule();
                      }
                    },
                    activeThumbColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
                _buildSettingItem(
                  icon: Icons.schedule_outlined,
                  label: AppLocalizations.of(
                    context,
                  )!.notificationLeadTimeLabel,
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
                  value: _currentDefaultVehicleId == null
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
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                          ),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context)!.loading),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
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
                  onTap: () =>
                      _showSelectLanguageDialog(context, localeProvider),
                ),
                _buildSettingItem(
                  icon: Icons.straighten_outlined,
                  label: AppLocalizations.of(context)!.mileageUnitLabel,
                  value: AppLocalizations.of(
                    context,
                  )!.mileageUnit(localeProvider.mileageUnit),
                  onTap: () =>
                      _showSelectMileageUnitDialog(context, localeProvider),
                ),
                _buildSettingItem(
                  icon: Icons.brightness_6_outlined,
                  label: AppLocalizations.of(context)!.theme,
                  value: themeProvider.themePreference.displayString(context),
                  onTap: () => _showSelectThemeDialog(context, themeProvider),
                ),
                if (themeProvider.themePreference == AppThemePreference.custom)
                  _buildSettingItem(
                    icon: Icons.color_lens_outlined,
                    label: AppLocalizations.of(context)!.themeColor,
                    trailing: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color:
                            themeProvider.customSeedColor ??
                            Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                    onTap: () => _showColorPicker(context, themeProvider),
                  ),
              ],
            ),
            const BackupSettingsSection(),
            _buildSettingsCard(
              title: AppLocalizations.of(context)!.about,
              children: [
                _buildSettingItem(
                  icon: Icons.info_outline,
                  label: AppLocalizations.of(context)!.appVersionEntry,
                  value: _appVersion,
                ),
                _buildSettingItem(
                  icon: Icons.help_outline,
                  label: AppLocalizations.of(context)!.helpAndSupport,
                  onTap: () {
                    final url = Uri.parse('https://github.com/JeziL/carvita');
                    _externalUrl.openExternalUrl(url);
                  },
                ),
                _buildSettingItem(
                  icon: Icons.shield_outlined,
                  label: AppLocalizations.of(context)!.privacyPolicy,
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.privacyRoute);
                  },
                ),
                _buildSettingItem(
                  icon: Icons.copyright_outlined,
                  label: AppLocalizations.of(context)!.openSourceLicenses,
                  onTap: () {
                    ThemeData theme = Theme.of(context);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => Theme(
                          data: theme.copyWith(
                            appBarTheme: theme.appBarTheme.copyWith(
                              titleTextStyle: theme.appBarTheme.titleTextStyle
                                  ?.copyWith(
                                    color: theme.colorScheme.onSurface,
                                  ),
                              iconTheme: IconThemeData(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          child: LicensePage(applicationVersion: _appVersion),
                        ),
                      ),
                    );
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
