import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carvita/application/use_cases/maintenance_plan_use_cases.dart';
import 'package:carvita/application/use_cases/service_log_use_cases.dart';
import 'package:carvita/application/use_cases/vehicle_use_cases.dart';
import 'package:carvita/core/services/preferences_service.dart';
import 'package:carvita/core/theme/app_theme.dart';
import 'package:carvita/data/models/maintenance_plan_item.dart';
import 'package:carvita/data/models/service_log_entry.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/data/repositories/maintenance_repository.dart';
import 'package:carvita/data/repositories/vehicle_repository.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/presentation/manager/locale_provider.dart';
import 'package:carvita/presentation/manager/maintenance_plan/maintenance_plan_cubit.dart';
import 'package:carvita/presentation/manager/service_log/service_log_cubit.dart';
import 'package:carvita/presentation/manager/vehicle_list/vehicle_cubit.dart';
import 'package:carvita/presentation/screens/maintenance/add_edit_maintenance_plan_item_screen.dart';
import 'package:carvita/presentation/screens/maintenance/log_maintenance_screen.dart';
import 'package:carvita/presentation/screens/vehicle/add_edit_vehicle_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('vehicle form ignores a second submit while saving', (
    tester,
  ) async {
    final repository = _BlockingVehicleRepository();
    final cubit = VehicleCubit(
      VehicleUseCases(repository, PreferencesService()),
    );

    await tester.pumpWidget(
      _testApp(
        providers: [BlocProvider<VehicleCubit>.value(value: cubit)],
        child: AddEditVehicleScreen(vehicle: _vehicle()),
      ),
    );
    await tester.pumpAndSettle();

    final submit = find.widgetWithText(ElevatedButton, 'Save changes');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(repository.updateCount, 1);
    expect(find.byKey(const ValueKey('vehicle-submit-progress')), findsOne);

    await tester.pumpWidget(const SizedBox());
    await cubit.close();
    repository.updateCompleter.complete();
    await tester.pump();
  });

  testWidgets('plan form ignores a second submit while saving', (tester) async {
    final repository = _BlockingMaintenanceRepository();
    final planCubit = MaintenancePlanCubit(
      MaintenancePlanUseCases(repository),
      1,
    );
    final logCubit = ServiceLogCubit(ServiceLogUseCases(repository), 1);

    await tester.pumpWidget(
      _testApp(
        providers: [
          BlocProvider<MaintenancePlanCubit>.value(value: planCubit),
          BlocProvider<ServiceLogCubit>.value(value: logCubit),
        ],
        child: AddEditMaintenancePlanItemScreen(
          vehicleId: 1,
          vehicleName: 'Vehicle',
          planItemToEdit: _planItem(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final submit = find.widgetWithText(ElevatedButton, 'Save changes');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(repository.planUpdateCount, 1);
    expect(find.byKey(const ValueKey('plan-submit-progress')), findsOne);

    await tester.pumpWidget(const SizedBox());
    await planCubit.close();
    await logCubit.close();
    repository.planUpdateCompleter.complete();
    await tester.pump();
  });

  testWidgets('service log form ignores a second submit while saving', (
    tester,
  ) async {
    final repository = _BlockingMaintenanceRepository();
    final planCubit = MaintenancePlanCubit(
      MaintenancePlanUseCases(repository),
      1,
    );
    final logCubit = ServiceLogCubit(ServiceLogUseCases(repository), 1);

    await tester.pumpWidget(
      _testApp(
        providers: [
          BlocProvider<MaintenancePlanCubit>.value(value: planCubit),
          BlocProvider<ServiceLogCubit>.value(value: logCubit),
        ],
        child: LogMaintenanceScreen(
          vehicleId: 1,
          vehicleName: 'Vehicle',
          logToEdit: _serviceLog(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final submit = find.widgetWithText(ElevatedButton, 'Save changes');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(repository.logUpdateCount, 1);
    expect(find.byKey(const ValueKey('log-submit-progress')), findsOne);

    await tester.pumpWidget(const SizedBox());
    await planCubit.close();
    await logCubit.close();
    repository.logUpdateCompleter.complete(true);
    await tester.pump();
  });

  testWidgets('editing forms stay above the system navigation bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const systemPadding = EdgeInsets.only(bottom: 48);
    Future<void> expectFormAboveSystemNavigation(Type screenType) async {
      final formScrollView = find.descendant(
        of: find.byType(screenType),
        matching: find.byType(SingleChildScrollView),
      );
      expect(formScrollView, findsOne);
      expect(
        tester.getBottomLeft(formScrollView).dy,
        lessThanOrEqualTo(800 - systemPadding.bottom),
      );

      final submit = find.widgetWithText(ElevatedButton, 'Save changes');
      await tester.ensureVisible(submit);
      expect(
        tester.getBottomLeft(submit).dy,
        lessThanOrEqualTo(800 - systemPadding.bottom),
      );
    }

    final vehicleCubit = VehicleCubit(
      VehicleUseCases(_BlockingVehicleRepository(), PreferencesService()),
    );

    await tester.pumpWidget(
      _testApp(
        systemPadding: systemPadding,
        providers: [BlocProvider<VehicleCubit>.value(value: vehicleCubit)],
        child: AddEditVehicleScreen(vehicle: _vehicle()),
      ),
    );
    await tester.pumpAndSettle();
    await expectFormAboveSystemNavigation(AddEditVehicleScreen);

    await tester.pumpWidget(const SizedBox());
    await vehicleCubit.close();

    final repository = _BlockingMaintenanceRepository();
    final planCubit = MaintenancePlanCubit(
      MaintenancePlanUseCases(repository),
      1,
    );
    final logCubit = ServiceLogCubit(ServiceLogUseCases(repository), 1);

    await tester.pumpWidget(
      _testApp(
        systemPadding: systemPadding,
        providers: [
          BlocProvider<MaintenancePlanCubit>.value(value: planCubit),
          BlocProvider<ServiceLogCubit>.value(value: logCubit),
        ],
        child: AddEditMaintenancePlanItemScreen(
          vehicleId: 1,
          vehicleName: 'Vehicle',
          planItemToEdit: _planItem(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectFormAboveSystemNavigation(AddEditMaintenancePlanItemScreen);

    await tester.pumpWidget(
      _testApp(
        systemPadding: systemPadding,
        providers: [
          BlocProvider<MaintenancePlanCubit>.value(value: planCubit),
          BlocProvider<ServiceLogCubit>.value(value: logCubit),
        ],
        child: LogMaintenanceScreen(
          vehicleId: 1,
          vehicleName: 'Vehicle',
          logToEdit: _serviceLog(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectFormAboveSystemNavigation(LogMaintenanceScreen);

    await tester.pumpWidget(const SizedBox());
    await planCubit.close();
    await logCubit.close();
  });

  const chipThemeCases =
      <({String name, Brightness brightness, Color seedColor})>[
        (name: 'light', brightness: Brightness.light, seedColor: Colors.blue),
        (name: 'dark', brightness: Brightness.dark, seedColor: Colors.blue),
        (
          name: 'custom seed light',
          brightness: Brightness.light,
          seedColor: Colors.teal,
        ),
      ];
  for (final themeCase in chipThemeCases) {
    testWidgets(
      'unavailable plan chip matches custom item colors in ${themeCase.name} mode',
      (tester) async {
        final repository = _BlockingMaintenanceRepository();
        final planCubit = MaintenancePlanCubit(
          MaintenancePlanUseCases(repository),
          1,
        );
        final logCubit = ServiceLogCubit(ServiceLogUseCases(repository), 1);
        final logToEdit = _serviceLogWithUnavailablePlanItem();

        expect(logToEdit.performedItems.first.maintenancePlanItemId, 2);
        expect(logToEdit.performedItems.last.customItemName, 'Inspection');
        expect(_planItem().id, isNot(2));

        await tester.pumpWidget(
          _testApp(
            brightness: themeCase.brightness,
            seedColor: themeCase.seedColor,
            providers: [
              BlocProvider<MaintenancePlanCubit>.value(value: planCubit),
              BlocProvider<ServiceLogCubit>.value(value: logCubit),
            ],
            child: LogMaintenanceScreen(
              vehicleId: 1,
              vehicleName: 'Vehicle',
              logToEdit: logToEdit,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final unavailableLabelFinder = find.text('Deleted plan');
        final customLabelFinder = find.text('Inspection');
        expect(unavailableLabelFinder, findsOne);
        expect(customLabelFinder, findsOne);
        final unavailableChip = tester.widget<Chip>(
          find.ancestor(
            of: unavailableLabelFinder,
            matching: find.byType(Chip),
          ),
        );
        final customChip = tester.widget<Chip>(
          find.ancestor(of: customLabelFinder, matching: find.byType(Chip)),
        );
        final unavailableLabel = unavailableChip.label as Text;
        final customLabel = customChip.label as Text;

        expect(unavailableChip.backgroundColor, customChip.backgroundColor);
        expect(unavailableLabel.style?.color, customLabel.style?.color);
        expect(unavailableChip.deleteIconColor, customChip.deleteIconColor);

        await tester.pumpWidget(const SizedBox());
        await planCubit.close();
        await logCubit.close();
      },
    );
  }

  testWidgets('vehicle write failure keeps input and re-enables submit', (
    tester,
  ) async {
    final repository = _BlockingVehicleRepository()
      ..writeError = StateError('write failed');
    final cubit = VehicleCubit(
      VehicleUseCases(repository, PreferencesService()),
    );

    await tester.pumpWidget(
      _testApp(
        providers: [BlocProvider<VehicleCubit>.value(value: cubit)],
        child: AddEditVehicleScreen(vehicle: _vehicle()),
      ),
    );
    await tester.pumpAndSettle();

    final submit = find.widgetWithText(ElevatedButton, 'Save changes');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Vehicle'), findsWidgets);
    expect(find.text('Unable to save changes. Try again.'), findsOne);
    expect(find.textContaining('write failed'), findsNothing);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Save changes'),
          )
          .onPressed,
      isNotNull,
    );

    await cubit.close();
  });

  testWidgets('vehicle form normalizes locale digits before saving', (
    tester,
  ) async {
    final repository = _BlockingVehicleRepository();
    final cubit = VehicleCubit(
      VehicleUseCases(repository, PreferencesService()),
    );

    await tester.pumpWidget(
      _testApp(
        locale: const Locale('ar'),
        providers: [BlocProvider<VehicleCubit>.value(value: cubit)],
        child: AddEditVehicleScreen(vehicle: _vehicle()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('vehicle-mileage-field')),
      '١٢٣٫٤',
    );
    final submit = find.byType(ElevatedButton).last;
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(repository.lastUpdatedVehicle?.mileage, 123.4);

    await tester.pumpWidget(const SizedBox());
    await cubit.close();
    repository.updateCompleter.complete();
    await tester.pump();
  });

  testWidgets('purchase and completed service pickers stop at today', (
    tester,
  ) async {
    final futureDate = DateTime.now().add(const Duration(days: 1));
    final vehicleRepository = _BlockingVehicleRepository();
    final vehicleCubit = VehicleCubit(
      VehicleUseCases(vehicleRepository, PreferencesService()),
    );

    await tester.pumpWidget(
      _testApp(
        providers: [BlocProvider<VehicleCubit>.value(value: vehicleCubit)],
        child: AddEditVehicleScreen(
          vehicle: _vehicle().copyWith(boughtDate: futureDate),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vehicle-bought-date-field')));
    await tester.pumpAndSettle();

    var picker = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(DateUtils.isSameDay(picker.lastDate, DateTime.now()), isTrue);
    expect(DateUtils.isSameDay(picker.initialDate, DateTime.now()), isTrue);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await vehicleCubit.close();

    final maintenanceRepository = _BlockingMaintenanceRepository();
    final planCubit = MaintenancePlanCubit(
      MaintenancePlanUseCases(maintenanceRepository),
      1,
    );
    final logCubit = ServiceLogCubit(
      ServiceLogUseCases(maintenanceRepository),
      1,
    );
    await tester.pumpWidget(
      _testApp(
        providers: [
          BlocProvider<MaintenancePlanCubit>.value(value: planCubit),
          BlocProvider<ServiceLogCubit>.value(value: logCubit),
        ],
        child: LogMaintenanceScreen(
          vehicleId: 1,
          vehicleName: 'Vehicle',
          logToEdit: ServiceLogWithItems(
            entry: _serviceLog().entry.copyWith(serviceDate: futureDate),
            performedItems: _serviceLog().performedItems,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('log-date-field')));
    await tester.pumpAndSettle();

    picker = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(DateUtils.isSameDay(picker.lastDate, DateTime.now()), isTrue);
    expect(DateUtils.isSameDay(picker.initialDate, DateTime.now()), isTrue);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await planCubit.close();
    await logCubit.close();
  });

  testWidgets('plan form accepts locale integer digits', (tester) async {
    final repository = _BlockingMaintenanceRepository();
    final planCubit = MaintenancePlanCubit(
      MaintenancePlanUseCases(repository),
      1,
    );
    final logCubit = ServiceLogCubit(ServiceLogUseCases(repository), 1);

    await tester.pumpWidget(
      _testApp(
        locale: const Locale('ar'),
        providers: [
          BlocProvider<MaintenancePlanCubit>.value(value: planCubit),
          BlocProvider<ServiceLogCubit>.value(value: logCubit),
        ],
        child: AddEditMaintenancePlanItemScreen(
          vehicleId: 1,
          vehicleName: 'Vehicle',
          planItemToEdit: _planItem(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('plan-time-field')), '١٨');
    final submit = find.byType(ElevatedButton).last;
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(repository.lastPlanItem?.intervalTimeMonths, 18);

    await tester.pumpWidget(const SizedBox());
    await planCubit.close();
    await logCubit.close();
    repository.planUpdateCompleter.complete();
    await tester.pump();
  });

  testWidgets('service log form accepts locale decimal input', (tester) async {
    final repository = _BlockingMaintenanceRepository();
    final planCubit = MaintenancePlanCubit(
      MaintenancePlanUseCases(repository),
      1,
    );
    final logCubit = ServiceLogCubit(ServiceLogUseCases(repository), 1);

    await tester.pumpWidget(
      _testApp(
        locale: const Locale('ar'),
        providers: [
          BlocProvider<MaintenancePlanCubit>.value(value: planCubit),
          BlocProvider<ServiceLogCubit>.value(value: logCubit),
        ],
        child: LogMaintenanceScreen(
          vehicleId: 1,
          vehicleName: 'Vehicle',
          logToEdit: _serviceLog(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('log-mileage-field')),
      '١٢٣٫٤',
    );
    await tester.enterText(
      find.byKey(const ValueKey('log-cost-field')),
      '٥٠٫٢٥',
    );
    final submit = find.byType(ElevatedButton).last;
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(repository.lastLogEntry?.mileageAtService, 123.4);
    expect(repository.lastLogEntry?.cost, 50.25);

    await tester.pumpWidget(const SizedBox());
    await planCubit.close();
    await logCubit.close();
    repository.logUpdateCompleter.complete(true);
    await tester.pump();
  });

  testWidgets('vehicle form is accessible at 200 percent text scaling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cubit = VehicleCubit(
      VehicleUseCases(_BlockingVehicleRepository(), PreferencesService()),
    );

    await tester.pumpWidget(
      _testApp(
        textScaler: const TextScaler.linear(2),
        providers: [BlocProvider<VehicleCubit>.value(value: cubit)],
        child: AddEditVehicleScreen(vehicle: _vehicle()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel(RegExp('Upload vehicle image')), findsOne);
    expect(find.byTooltip('Back'), findsOne);
    await cubit.close();
  });
}

Widget _testApp({
  required List<SingleChildWidget> providers,
  required Widget child,
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
  Brightness brightness = Brightness.light,
  Color seedColor = Colors.blue,
  EdgeInsets systemPadding = EdgeInsets.zero,
}) {
  final preferences = PreferencesService();
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );
  return MultiProvider(
    providers: [
      Provider<VehicleUseCases>.value(
        value: VehicleUseCases(VehicleRepository(), preferences),
      ),
      ChangeNotifierProvider<LocaleProvider>(
        create: (_) => LocaleProvider(preferences),
      ),
      ...providers,
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.getThemeData(colorScheme, brightness),
      builder: (context, appChild) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: textScaler,
            padding: systemPadding,
            viewPadding: systemPadding,
          ),
          child: appChild!,
        );
      },
      home: child,
    ),
  );
}

Vehicle _vehicle() {
  return Vehicle(
    id: 1,
    name: 'Vehicle',
    mileage: 1000,
    mileageLastUpdated: DateTime(2026, 1, 1),
    boughtDate: DateTime(2025, 1, 1),
  );
}

MaintenancePlanItem _planItem() {
  return const MaintenancePlanItem(
    id: 1,
    vehicleId: 1,
    itemName: 'Oil',
    intervalTimeMonths: 12,
  );
}

ServiceLogWithItems _serviceLog() {
  return ServiceLogWithItems(
    entry: ServiceLogEntry(
      id: 1,
      vehicleId: 1,
      serviceDate: DateTime(2026, 1, 1),
      mileageAtService: 1000,
    ),
    performedItems: const [
      ServiceLogPerformedItem(
        id: 1,
        serviceLogId: 1,
        customItemName: 'Inspection',
        displayName: 'Inspection',
      ),
    ],
  );
}

ServiceLogWithItems _serviceLogWithUnavailablePlanItem() {
  final serviceLog = _serviceLog();
  return ServiceLogWithItems(
    entry: serviceLog.entry,
    performedItems: const [
      ServiceLogPerformedItem(
        id: 1,
        serviceLogId: 1,
        maintenancePlanItemId: 2,
        displayName: 'Deleted plan',
      ),
      ServiceLogPerformedItem(
        id: 2,
        serviceLogId: 1,
        customItemName: 'Inspection',
        displayName: 'Inspection',
      ),
    ],
  );
}

class _BlockingVehicleRepository extends VehicleRepository {
  final Completer<void> updateCompleter = Completer<void>();
  int updateCount = 0;
  Object? writeError;
  Vehicle? lastUpdatedVehicle;

  @override
  Future<void> updateVehicle(Vehicle vehicle) async {
    updateCount++;
    lastUpdatedVehicle = vehicle;
    if (writeError case final error?) throw error;
    await updateCompleter.future;
  }

  @override
  Future<List<Vehicle>> getVehicles() async => [_vehicle()];
}

class _BlockingMaintenanceRepository extends MaintenanceRepository {
  final Completer<void> planUpdateCompleter = Completer<void>();
  final Completer<bool> logUpdateCompleter = Completer<bool>();
  int planUpdateCount = 0;
  int logUpdateCount = 0;
  MaintenancePlanItem? lastPlanItem;
  ServiceLogEntry? lastLogEntry;

  @override
  Future<List<MaintenancePlanItem>> getPlanItems(int vehicleId) async => [
    _planItem(),
  ];

  @override
  Future<void> updatePlanItem(MaintenancePlanItem item) async {
    planUpdateCount++;
    lastPlanItem = item;
    await planUpdateCompleter.future;
  }

  @override
  Future<List<ServiceLogWithItems>> getServiceLogs(int vehicleId) async => [
    _serviceLog(),
  ];

  @override
  Future<bool> updateServiceLog(
    ServiceLogEntry logEntry,
    List<PerformedItemInput> performedItems,
  ) async {
    logUpdateCount++;
    lastLogEntry = logEntry;
    return logUpdateCompleter.future;
  }
}
