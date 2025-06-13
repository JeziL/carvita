import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl_standalone.dart';
import 'package:provider/provider.dart';

import 'package:carvita/core/constants/app_colors.dart';
import 'package:carvita/core/constants/app_routes.dart';
import 'package:carvita/core/services/navigation_service.dart';
import 'package:carvita/core/services/notification_service.dart';
import 'package:carvita/core/services/prediction_service.dart';
import 'package:carvita/core/services/preferences_service.dart';
import 'package:carvita/core/services/quick_action_service.dart';
import 'package:carvita/core/theme/app_theme.dart';
import 'package:carvita/data/repositories/maintenance_repository.dart';
import 'package:carvita/data/repositories/vehicle_repository.dart';
import 'package:carvita/data/sources/local/database_helper.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/presentation/manager/locale_provider.dart';
import 'package:carvita/presentation/manager/theme_provider.dart';
import 'package:carvita/presentation/manager/upcoming_maintenance/upcoming_maintenance_cubit.dart';
import 'package:carvita/presentation/manager/vehicle_list/vehicle_cubit.dart';
import 'package:carvita/presentation/navigation/app_router.dart';

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
  final notificationService = NotificationService();
  await notificationService.initialize();
  await notificationService.requestPermissions();
  await findSystemLocale();
  final preferencesService = PreferencesService();
  final databaseHelper = DatabaseHelper();
  final vehicleRepository = VehicleRepository(dbHelper: databaseHelper);
  final maintenanceRepository = MaintenanceRepository(dbHelper: databaseHelper);
  final predictionService = PredictionService();

  final quickActionService = QuickActionService(
    vehicleRepository: vehicleRepository,
    maintenanceRepository: maintenanceRepository,
    preferencesService: preferencesService,
  );
  quickActionService.initializeListener();
  runApp(
    MultiProvider(
      providers: [
        Provider<QuickActionService>.value(value: quickActionService),
        ChangeNotifierProvider(
          create: (_) => LocaleProvider(preferencesService),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(preferencesService),
        ),
      ],
      child: CarVitaApp(
        preferencesService: preferencesService,
        vehicleRepository: vehicleRepository,
        maintenanceRepository: maintenanceRepository,
        predictionService: predictionService,
        notificationService: notificationService,
      ),
    ),
  );
}

class CarVitaApp extends StatelessWidget {
  final PreferencesService preferencesService;
  final VehicleRepository vehicleRepository;
  final MaintenanceRepository maintenanceRepository;
  final PredictionService predictionService;
  final NotificationService notificationService;
  const CarVitaApp({
    super.key,
    required this.preferencesService,
    required this.vehicleRepository,
    required this.maintenanceRepository,
    required this.predictionService,
    required this.notificationService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<VehicleCubit>(
          create:
              (context) => VehicleCubit(
                vehicleRepository,
                preferencesService: preferencesService,
              )..fetchVehicles(),
        ),
        BlocProvider<UpcomingMaintenanceCubit>(
          create:
              (context) => UpcomingMaintenanceCubit(
                vehicleRepository,
                maintenanceRepository,
                predictionService,
                notificationService,
                preferencesService,
              )..loadAllUpcomingMaintenance(
                AppLocalizations.of(context),
              ), // load on app start
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
              final MediaQueryData data = MediaQuery.of(context);
              return ShortcutLocalizationWrapper(
                locale: localeProvider.appLocale,
                child: MediaQuery(
                  data: data.copyWith(
                    textScaler: data.textScaler.clamp(
                      minScaleFactor: 0.8,
                      maxScaleFactor: 1.2,
                    ), // restrict text scaling
                  ),
                  child: child!,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ShortcutLocalizationWrapper extends StatefulWidget {
  final Widget child;
  final Locale? locale;

  const ShortcutLocalizationWrapper({
    super.key,
    required this.child,
    required this.locale,
  });

  @override
  State<ShortcutLocalizationWrapper> createState() =>
      _ShortcutLocalizationWrapperState();
}

class _ShortcutLocalizationWrapperState
    extends State<ShortcutLocalizationWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateShortcuts();
    });
  }

  @override
  void didUpdateWidget(covariant ShortcutLocalizationWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.locale != oldWidget.locale) {
      _updateShortcuts();
    }
  }

  void _updateShortcuts() {
    if (mounted) {
      context.read<QuickActionService>().updateShortcutItems(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
