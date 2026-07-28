import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl_standalone.dart';
import 'package:provider/provider.dart';

import 'package:carvita/application/ports/app_startup_port.dart';
import 'package:carvita/application/ports/clock.dart';
import 'package:carvita/application/ports/notification_tap_port.dart';
import 'package:carvita/application/ports/platform_ports.dart';
import 'package:carvita/application/ports/reminder_schedule_port.dart';
import 'package:carvita/application/use_cases/load_upcoming_maintenance.dart';
import 'package:carvita/application/use_cases/maintenance_plan_use_cases.dart';
import 'package:carvita/application/use_cases/service_log_use_cases.dart';
import 'package:carvita/application/use_cases/synchronize_maintenance_reminders.dart';
import 'package:carvita/application/use_cases/vehicle_use_cases.dart';
import 'package:carvita/core/constants/app_colors.dart';
import 'package:carvita/core/constants/app_routes.dart';
import 'package:carvita/core/services/app_startup_service.dart';
import 'package:carvita/core/services/backup_service.dart';
import 'package:carvita/core/services/device_time_zone_service.dart';
import 'package:carvita/core/services/maintenance_reminder_tap_service.dart';
import 'package:carvita/core/services/navigation_service.dart';
import 'package:carvita/core/services/notification_coordinator.dart';
import 'package:carvita/core/services/notification_service.dart';
import 'package:carvita/core/services/plugin_platform_service.dart';
import 'package:carvita/core/services/prediction_service.dart';
import 'package:carvita/core/services/preferences_service.dart';
import 'package:carvita/core/services/quick_action_service.dart';
import 'package:carvita/core/services/reminder_schedule_service.dart';
import 'package:carvita/core/theme/app_theme.dart';
import 'package:carvita/data/repositories/maintenance_repository.dart';
import 'package:carvita/data/repositories/vehicle_repository.dart';
import 'package:carvita/data/sources/local/database_helper.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/presentation/manager/locale_provider.dart';
import 'package:carvita/presentation/manager/theme_provider.dart';
import 'package:carvita/presentation/manager/upcoming_maintenance/upcoming_maintenance_cubit.dart';
import 'package:carvita/presentation/manager/vehicle_list/vehicle_cubit.dart';
import 'package:carvita/presentation/images/vehicle_image_cache.dart';
import 'package:carvita/presentation/navigation/app_router.dart';
import 'package:carvita/presentation/navigation/default_maintenance_reminder_navigation.dart';
import 'package:carvita/presentation/navigation/default_quick_action_navigation.dart';
import 'package:carvita/presentation/navigation/main_navigation_controller.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();
final appSupportedLocales = [
  {'name': 'English', 'locale': Locale('en')},
  {'name': 'العربية', 'locale': Locale('ar')},
  {'name': 'Deutsch', 'locale': Locale('de')},
  {'name': 'Español', 'locale': Locale('es')},
  {'name': 'Français', 'locale': Locale('fr')},
  {'name': 'Italiano', 'locale': Locale('it')},
  {'name': '日本語', 'locale': Locale('ja')},
  {'name': '한국어', 'locale': Locale('ko')},
  {'name': 'Português', 'locale': Locale('pt')},
  {'name': 'Русский', 'locale': Locale('ru')},
  {
    'name': '简体中文',
    'locale': Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
  },
  {
    'name': '繁體中文',
    'locale': Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  },
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const clock = SystemClock();
  final preferencesService = PreferencesService();
  final databaseHelper = DatabaseHelper();
  final vehicleRepository = VehicleRepository(dbHelper: databaseHelper);
  final maintenanceRepository = MaintenanceRepository(dbHelper: databaseHelper);
  final predictionService = PredictionService(clock);
  final vehicleUseCases = VehicleUseCases(
    vehicleRepository,
    preferencesService,
  );
  final vehicleImageCache = VehicleImageCache(vehicleUseCases);
  final maintenancePlanUseCases = MaintenancePlanUseCases(
    maintenanceRepository,
  );
  final mainNavigationController = MainNavigationController();
  final serviceLogUseCases = ServiceLogUseCases(maintenanceRepository);
  final maintenanceReminderTaps = MaintenanceReminderTapService(
    vehicleRepository,
    maintenanceRepository,
    DefaultMaintenanceReminderNavigation(mainNavigationController),
  );
  final reminderSchedule = ReminderScheduleService(
    const MethodChannelDeviceTimeZone(),
    clock,
  );
  final notificationService = NotificationService(
    clock,
    maintenanceReminderTaps,
  );
  final notificationCoordinator = NotificationCoordinator(notificationService);
  final backupService = BackupService(
    preferences: preferencesService,
    clock: clock.now,
  );
  const pluginPlatformService = PluginPlatformService();
  final loadUpcomingMaintenance = LoadUpcomingMaintenance(
    maintenanceRepository,
    predictionService,
    clock,
  );
  final synchronizeMaintenanceReminders = SynchronizeMaintenanceReminders(
    preferencesService,
    notificationCoordinator,
    reminderSchedule,
    clock,
  );
  final quickActionNavigation = DefaultQuickActionNavigation(
    maintenancePlanUseCases,
    serviceLogUseCases,
    mainNavigationController,
  );

  final quickActionService = QuickActionService(
    vehicleRepository: vehicleRepository,
    preferencesService: preferencesService,
    navigation: quickActionNavigation,
    platform: const PluginQuickActionPlatform(),
  );
  final appStartup = AppStartupService(
    refreshReminderSchedule: reminderSchedule.refreshTimeZone,
    initializeNotifications: notificationService.initialize,
    initializeSystemLocale: () async {
      await findSystemLocale();
    },
    initializeQuickActions: quickActionService.initializeListener,
  );
  runApp(
    MultiProvider(
      providers: [
        Provider<AppStartupPort>.value(value: appStartup),
        Provider<QuickActionService>.value(value: quickActionService),
        ChangeNotifierProvider<MainNavigationController>.value(
          value: mainNavigationController,
        ),
        Provider<NotificationTapPort>.value(value: maintenanceReminderTaps),
        Provider<ReminderSchedulePort>.value(value: reminderSchedule),
        Provider<PreferencesService>.value(value: preferencesService),
        Provider<VehicleUseCases>.value(value: vehicleUseCases),
        Provider<VehicleImageCache>.value(value: vehicleImageCache),
        Provider<MaintenancePlanUseCases>.value(value: maintenancePlanUseCases),
        Provider<ServiceLogUseCases>.value(value: serviceLogUseCases),
        Provider<NotificationPermissionGateway>.value(
          value: notificationService,
        ),
        Provider<BackupGateway>.value(value: backupService),
        Provider<VehicleImagePickerPort>.value(value: pluginPlatformService),
        Provider<BackupFilePickerPort>.value(value: pluginPlatformService),
        Provider<FileSharePort>.value(value: pluginPlatformService),
        Provider<AppPackageInfoPort>.value(value: pluginPlatformService),
        Provider<ExternalUrlPort>.value(value: pluginPlatformService),
        Provider<AppExitPort>.value(value: pluginPlatformService),
        ChangeNotifierProvider(
          create: (_) => LocaleProvider(preferencesService),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(preferencesService),
        ),
      ],
      child: CarVitaApp(
        preferencesService: preferencesService,
        vehicleUseCases: vehicleUseCases,
        loadUpcomingMaintenance: loadUpcomingMaintenance,
        synchronizeMaintenanceReminders: synchronizeMaintenanceReminders,
      ),
    ),
  );
}

class CarVitaApp extends StatelessWidget {
  final PreferencesService preferencesService;
  final VehicleUseCases vehicleUseCases;
  final LoadUpcomingMaintenance loadUpcomingMaintenance;
  final SynchronizeMaintenanceReminders synchronizeMaintenanceReminders;
  const CarVitaApp({
    super.key,
    required this.preferencesService,
    required this.vehicleUseCases,
    required this.loadUpcomingMaintenance,
    required this.synchronizeMaintenanceReminders,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<VehicleCubit>(
          create: (context) => VehicleCubit(vehicleUseCases)..fetchVehicles(),
        ),
        BlocProvider<UpcomingMaintenanceCubit>(
          create: (context) => UpcomingMaintenanceCubit(
            loadUpcomingMaintenance,
            synchronizeMaintenanceReminders,
          ),
        ),
      ],
      child: Consumer2<LocaleProvider, ThemeProvider>(
        builder: (context, localeProvider, themeProvider, child) {
          ColorScheme lightColorScheme;
          ColorScheme darkColorScheme;
          if (themeProvider.themePreference == AppThemePreference.custom &&
              themeProvider.customSeedColor != null) {
            lightColorScheme = ColorScheme.fromSeed(
              seedColor: themeProvider.customSeedColor!,
              brightness: Brightness.light,
            );
            darkColorScheme = ColorScheme.fromSeed(
              seedColor: themeProvider.customSeedColor!,
              brightness: Brightness.dark,
            );
          } else {
            lightColorScheme = ColorScheme.fromSeed(
              seedColor: AppColors.primaryBlue,
              brightness: Brightness.light,
              primary: AppColors.primaryBlue,
              secondary: AppColors.secondaryBlue,
            );
            darkColorScheme = ColorScheme.fromSeed(
              seedColor: AppColors.primaryBlue,
              brightness: Brightness.dark,
            );
          }
          final lightThemeData = AppTheme.getThemeData(
            lightColorScheme,
            Brightness.light,
          );
          final darkThemeData = AppTheme.getThemeData(
            darkColorScheme,
            Brightness.dark,
          );
          return MaterialApp(
            title: "CarVita",
            theme: lightThemeData,
            darkTheme: darkThemeData,
            themeMode: themeProvider.themeMode,
            debugShowCheckedModeBanner: false,

            navigatorKey: NavigationService.navigatorKey,

            // router
            onGenerateRoute: AppRouter.generateRoute,
            initialRoute: AppRoutes.dashboardRoute,
            navigatorObservers: [routeObserver],

            // i18n
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: appSupportedLocales.map(
              (lang) => lang['locale'] as Locale,
            ),
            locale: localeProvider.appLocale,

            builder: (context, child) {
              return ShortcutLocalizationWrapper(child: child!);
            },
          );
        },
      ),
    );
  }
}

class ShortcutLocalizationWrapper extends StatefulWidget {
  final Widget child;

  const ShortcutLocalizationWrapper({super.key, required this.child});

  @override
  State<ShortcutLocalizationWrapper> createState() =>
      _ShortcutLocalizationWrapperState();
}

class _ShortcutLocalizationWrapperState
    extends State<ShortcutLocalizationWrapper>
    with WidgetsBindingObserver {
  Locale? _lastResolvedLocale;
  bool _initialRefreshScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshReminderContextAfterResume();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Locale resolvedLocale = Localizations.localeOf(context);
    if (!_initialRefreshScheduled) {
      _initialRefreshScheduled = true;
      _lastResolvedLocale = resolvedLocale;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshLocalizedServices(loadPredictions: true);
      });
    } else if (_lastResolvedLocale != resolvedLocale) {
      _lastResolvedLocale = resolvedLocale;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshLocalizedServices(loadPredictions: false);
      });
    }
  }

  Future<void> _refreshLocalizedServices({
    required bool loadPredictions,
  }) async {
    if (!mounted) return;
    final AppLocalizations? l10n = AppLocalizations.of(context);
    if (l10n == null) return;

    final quickActionService = context.read<QuickActionService>();
    context.read<NotificationTapPort>().navigatorReady();
    quickActionService.navigatorReady();
    if (loadPredictions) {
      try {
        final result = await context.read<AppStartupPort>().initialize();
        assert(() {
          for (final failure in result.failures) {
            debugPrint(
              'Recoverable startup failure in ${failure.step.name}: '
              '${failure.error}\n${failure.stackTrace}',
            );
          }
          return true;
        }());
      } catch (error, stackTrace) {
        debugPrint(
          'Unexpected startup initialization failure: $error\n$stackTrace',
        );
      }
      if (!mounted) return;
    }
    try {
      await quickActionService.updateShortcutItems(
        logMaintenanceTitle: l10n.logMaintenance,
        upcomingMaintenanceTitle: l10n.upcomingMaintenance,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to update localized quick actions: $error\n$stackTrace',
      );
    }
    if (!mounted) return;

    try {
      final upcomingMaintenanceCubit = context.read<UpcomingMaintenanceCubit>();
      if (loadPredictions) {
        await upcomingMaintenanceCubit.loadAllUpcomingMaintenance(l10n);
      } else {
        await upcomingMaintenanceCubit
            .rescheduleNotificationsBasedOnNewSettings(l10n);
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to refresh localized maintenance services: '
        '$error\n$stackTrace',
      );
    }
  }

  Future<void> _refreshReminderContextAfterResume() async {
    if (!mounted) return;
    try {
      final refresh = await context
          .read<ReminderSchedulePort>()
          .refreshTimeZone();
      if (!refresh.contextChanged || !mounted) return;

      final l10n = AppLocalizations.of(context);
      if (l10n == null) return;
      await context.read<UpcomingMaintenanceCubit>().loadAllUpcomingMaintenance(
        l10n,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to refresh reminders after resume: $error\n$stackTrace',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
