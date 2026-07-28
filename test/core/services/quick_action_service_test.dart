import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carvita/application/use_cases/maintenance_plan_use_cases.dart';
import 'package:carvita/application/use_cases/service_log_use_cases.dart';
import 'package:carvita/core/services/navigation_service.dart';
import 'package:carvita/core/services/preferences_service.dart';
import 'package:carvita/core/services/quick_action_service.dart';
import 'package:carvita/core/theme/app_theme.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/data/repositories/maintenance_repository.dart';
import 'package:carvita/data/repositories/vehicle_repository.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/presentation/manager/locale_provider.dart';
import 'package:carvita/presentation/navigation/default_quick_action_navigation.dart';
import 'package:carvita/presentation/screens/vehicle/select_vehicle_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('cold-start shortcut waits for Navigator and is consumed once', (
    tester,
  ) async {
    final platform = _FakeQuickActionPlatform();
    final service = _service(platform: platform);
    service.initializeListener();

    platform.emit(QuickActionService.upcomingMaintenanceAction);
    platform.emit(QuickActionService.upcomingMaintenanceAction);
    await tester.pumpWidget(_testApp());
    service.navigatorReady();
    await tester.pumpAndSettle();

    expect(find.text('Upcoming destination'), findsOne);
  });

  testWidgets('hot duplicate log intents run one request', (tester) async {
    final platform = _FakeQuickActionPlatform();
    final vehicleRepository = _FakeVehicleRepository();
    final blockedRead = Completer<List<Vehicle>>();
    vehicleRepository.blockedRead = blockedRead;
    final service = _service(
      platform: platform,
      vehicleRepository: vehicleRepository,
    );
    service.initializeListener();
    await tester.pumpWidget(_testApp());
    service.navigatorReady();

    platform.emit(QuickActionService.logMaintenanceAction);
    platform.emit(QuickActionService.logMaintenanceAction);
    await tester.pump();
    expect(vehicleRepository.readCount, 1);

    blockedRead.complete(const []);
    await tester.pumpAndSettle();
    expect(vehicleRepository.readCount, 1);
    expect(
      find.text('Please add a vehicle before logging maintenance.'),
      findsOne,
    );
  });

  testWidgets('invalid default is cleared before vehicle selection', (
    tester,
  ) async {
    final platform = _FakeQuickActionPlatform();
    final preferences = _FakePreferencesService(defaultVehicleId: 999);
    final vehicleRepository = _FakeVehicleRepository(
      vehicles: [_vehicle(1), _vehicle(2)],
    );
    final service = _service(
      platform: platform,
      vehicleRepository: vehicleRepository,
      preferencesService: preferences,
    );
    service.initializeListener();
    await tester.pumpWidget(_testApp());
    service.navigatorReady();

    platform.emit(QuickActionService.logMaintenanceAction);
    await tester.pumpAndSettle();

    expect(find.byType(SelectVehicleScreen), findsOne);
    expect(preferences.defaultVehicleId, isNull);
    expect(preferences.setCalls, 1);
  });
}

QuickActionService _service({
  required _FakeQuickActionPlatform platform,
  _FakeVehicleRepository? vehicleRepository,
  _FakePreferencesService? preferencesService,
}) {
  final maintenanceRepository = _FakeMaintenanceRepository();
  return QuickActionService(
    vehicleRepository: vehicleRepository ?? _FakeVehicleRepository(),
    preferencesService: preferencesService ?? _FakePreferencesService(),
    navigation: DefaultQuickActionNavigation(
      MaintenancePlanUseCases(maintenanceRepository),
      ServiceLogUseCases(maintenanceRepository),
    ),
    platform: platform,
  );
}

Widget _testApp() {
  final preferences = PreferencesService();
  return ChangeNotifierProvider(
    create: (_) => LocaleProvider(preferences),
    child: MaterialApp(
      navigatorKey: NavigationService.navigatorKey,
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.getThemeData(
        ColorScheme.fromSeed(seedColor: Colors.blue),
        Brightness.light,
      ),
      routes: {
        '/upcoming-maintenance': (_) =>
            const Scaffold(body: Text('Upcoming destination')),
      },
      home: const Scaffold(body: Text('Home')),
    ),
  );
}

Vehicle _vehicle(int id) {
  return Vehicle(
    id: id,
    name: 'Vehicle $id',
    mileage: 1000,
    mileageLastUpdated: DateTime(2026, 1, 1),
    boughtDate: DateTime(2025, 1, 1),
  );
}

class _FakeQuickActionPlatform implements QuickActionPlatform {
  ValueChanged<String>? callback;

  @override
  void initialize(ValueChanged<String> onShortcut) {
    callback = onShortcut;
  }

  void emit(String action) {
    callback!(action);
  }

  @override
  Future<void> setShortcutItems({
    required String logMaintenanceTitle,
    required String upcomingMaintenanceTitle,
  }) async {}
}

class _FakeVehicleRepository extends VehicleRepository {
  _FakeVehicleRepository({List<Vehicle> vehicles = const []})
    : vehicles = List<Vehicle>.of(vehicles);

  final List<Vehicle> vehicles;
  Completer<List<Vehicle>>? blockedRead;
  int readCount = 0;

  @override
  Future<List<Vehicle>> getVehicles() async {
    readCount++;
    if (blockedRead case final blocker?) return blocker.future;
    return List<Vehicle>.of(vehicles);
  }
}

class _FakeMaintenanceRepository extends MaintenanceRepository {}

class _FakePreferencesService extends PreferencesService {
  _FakePreferencesService({this.defaultVehicleId});

  int? defaultVehicleId;
  int setCalls = 0;

  @override
  Future<int?> getDefaultVehicleId() async => defaultVehicleId;

  @override
  Future<void> setDefaultVehicleId(int? vehicleId) async {
    setCalls++;
    defaultVehicleId = vehicleId;
  }
}
