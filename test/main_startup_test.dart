import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carvita/core/services/notification_coordinator.dart';
import 'package:carvita/core/services/notification_service.dart';
import 'package:carvita/core/services/prediction_service.dart';
import 'package:carvita/core/services/preferences_service.dart';
import 'package:carvita/core/services/quick_action_service.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/data/repositories/maintenance_repository.dart';
import 'package:carvita/data/repositories/vehicle_repository.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/main.dart';
import 'package:carvita/presentation/manager/upcoming_maintenance/upcoming_maintenance_cubit.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('localized startup loads predictions and shortcuts once', (
    tester,
  ) async {
    final vehicleRepository = _CountingVehicleRepository();
    final maintenanceRepository = _FakeMaintenanceRepository();
    final preferences = _FakePreferencesService();
    final platform = _CountingQuickActionPlatform();
    final quickActionService = QuickActionService(
      vehicleRepository: vehicleRepository,
      maintenanceRepository: maintenanceRepository,
      preferencesService: preferences,
      platform: platform,
      navigatorContextProvider: () => null,
    );
    final upcomingCubit = UpcomingMaintenanceCubit(
      vehicleRepository,
      maintenanceRepository,
      PredictionService(),
      NotificationCoordinator(_NoopNotificationGateway()),
      preferences,
      now: () => DateTime(2026, 7, 27),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<QuickActionService>.value(value: quickActionService),
          BlocProvider<UpcomingMaintenanceCubit>.value(value: upcomingCubit),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ShortcutLocalizationWrapper(child: SizedBox()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pump();

    expect(vehicleRepository.readCount, 1);
    expect(platform.setItemsCount, 1);
    await upcomingCubit.close();
  });

  testWidgets('shortcut update failure does not skip startup predictions', (
    tester,
  ) async {
    final vehicleRepository = _CountingVehicleRepository();
    final maintenanceRepository = _FakeMaintenanceRepository();
    final preferences = _FakePreferencesService();
    final platform = _CountingQuickActionPlatform(failSetItems: true);
    final quickActionService = QuickActionService(
      vehicleRepository: vehicleRepository,
      maintenanceRepository: maintenanceRepository,
      preferencesService: preferences,
      platform: platform,
      navigatorContextProvider: () => null,
    );
    final upcomingCubit = UpcomingMaintenanceCubit(
      vehicleRepository,
      maintenanceRepository,
      PredictionService(),
      NotificationCoordinator(_NoopNotificationGateway()),
      preferences,
      now: () => DateTime(2026, 7, 27),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<QuickActionService>.value(value: quickActionService),
          BlocProvider<UpcomingMaintenanceCubit>.value(value: upcomingCubit),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ShortcutLocalizationWrapper(child: SizedBox()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(platform.setItemsCount, 1);
    expect(vehicleRepository.readCount, 1);
    expect(tester.takeException(), isNull);
    await upcomingCubit.close();
  });
}

class _CountingVehicleRepository extends VehicleRepository {
  int readCount = 0;

  @override
  Future<List<Vehicle>> getVehicles() async {
    readCount++;
    return const [];
  }
}

class _FakeMaintenanceRepository extends MaintenanceRepository {}

class _FakePreferencesService extends PreferencesService {
  @override
  Future<bool> getNotificationsEnabled() async => false;
}

class _CountingQuickActionPlatform implements QuickActionPlatform {
  _CountingQuickActionPlatform({this.failSetItems = false});

  final bool failSetItems;
  int setItemsCount = 0;

  @override
  void initialize(ValueChanged<String> onShortcut) {}

  @override
  Future<void> setShortcutItems({
    required String logMaintenanceTitle,
    required String upcomingMaintenanceTitle,
  }) async {
    setItemsCount++;
    if (failSetItems) throw StateError('shortcut platform failed');
  }
}

class _NoopNotificationGateway implements NotificationGateway {
  @override
  Future<void> cancelAllNotifications() async {}

  @override
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    String? payload,
  }) async {}
}
