import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl_standalone.dart';
import 'package:provider/provider.dart';

import 'package:carvita/core/constants/app_routes.dart';
import 'package:carvita/core/services/notification_service.dart';
import 'package:carvita/core/services/prediction_service.dart';
import 'package:carvita/core/services/preferences_service.dart';
import 'package:carvita/core/theme/app_theme.dart';
import 'package:carvita/data/repositories/maintenance_repository.dart';
import 'package:carvita/data/repositories/vehicle_repository.dart';
import 'package:carvita/data/sources/local/database_helper.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/presentation/manager/locale_provider.dart';
import 'package:carvita/presentation/manager/upcoming_maintenance/upcoming_maintenance_cubit.dart';
import 'package:carvita/presentation/manager/vehicle_list/vehicle_cubit.dart';
import 'package:carvita/presentation/navigation/app_router.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();
final appSupportedLocales = [
  Locale('en'),
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notificationService = NotificationService();
  await notificationService.initialize();
  await notificationService.requestPermissions();
  await findSystemLocale();
  runApp(const CarVitaApp());
}

class CarVitaApp extends StatelessWidget {
  const CarVitaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final databaseHelper = DatabaseHelper();
    final preferencesService = PreferencesService();
    final predictionService = PredictionService();
    final notificationService = NotificationService();
    final vehicleRepository = VehicleRepository(dbHelper: databaseHelper);
    final maintenanceRepository = MaintenanceRepository(
      dbHelper: databaseHelper,
    );

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
                databaseHelper, // or refactor link fetching
                notificationService,
                preferencesService,
              )..loadAllUpcomingMaintenance(
                AppLocalizations.of(context),
              ), // load on app start
        ),
        ChangeNotifierProvider(
          create: (_) => LocaleProvider(preferencesService),
        ),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, child) {
          return MaterialApp(
            title: "CarVita",
            theme: AppTheme.lightTheme,
            debugShowCheckedModeBanner: false,

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
            supportedLocales: appSupportedLocales,
            locale: localeProvider.appLocale,

            builder: (context, child) {
              final MediaQueryData data = MediaQuery.of(context);
              return MediaQuery(
                data: data.copyWith(
                  textScaler: data.textScaler.clamp(
                    minScaleFactor: 0.8,
                    maxScaleFactor: 1.2,
                  ), // restrict text scaling
                ),
                child: child!,
              );
            },
          );
        },
      ),
    );
  }
}
