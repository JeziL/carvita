import 'package:carvita/core/constants/app_routes.dart';
import 'package:carvita/core/services/notification_service.dart';
import 'package:carvita/core/services/prediction_service.dart';
import 'package:carvita/core/services/preferences_service.dart';
import 'package:carvita/data/repositories/maintenance_repository.dart';
import 'package:carvita/data/sources/local/database_helper.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/presentation/manager/upcoming_maintenance/upcoming_maintenance_cubit.dart';
import 'package:flutter/material.dart';
import 'package:carvita/core/theme/app_theme.dart';
import 'package:carvita/presentation/navigation/app_router.dart';
import 'package:carvita/data/repositories/vehicle_repository.dart';
import 'package:carvita/presentation/manager/vehicle_list/vehicle_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final NotificationService notificationService = NotificationService();
  await notificationService.initialize();
  await notificationService.requestPermissions();
  runApp(const CarVitaApp());
}

class CarVitaApp extends StatelessWidget {
  const CarVitaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final vehicleRepository = VehicleRepository();

    return MultiBlocProvider(
      providers: [
        BlocProvider<VehicleCubit>(
          create: (context) => VehicleCubit(vehicleRepository, preferencesService: PreferencesService())..fetchVehicles(),
        ),
        BlocProvider<UpcomingMaintenanceCubit>(
          create: (context) => UpcomingMaintenanceCubit(
            VehicleRepository(),
            MaintenanceRepository(),
            PredictionService(),
            DatabaseHelper(),      // or refactor link fetching
            context.read<VehicleCubit>(),
            NotificationService(),
            PreferencesService(),
            context,
          )..loadAllUpcomingMaintenance(), // load on app start
        ),
      ],
      child: MaterialApp(
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
        supportedLocales: const [
          Locale('en'),
          Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
        ],
        // locale: const Locale('en'), // Debug: Force a specific locale for testing
      
        builder: (context, child) {
          final MediaQueryData data = MediaQuery.of(context);
          return MediaQuery(
            data: data.copyWith(
              textScaler: data.textScaler.clamp(minScaleFactor: 0.8, maxScaleFactor: 1.2), // restrict text scaling
            ),
            child: child!,
          );
        },
      ),
    );
  }
}
