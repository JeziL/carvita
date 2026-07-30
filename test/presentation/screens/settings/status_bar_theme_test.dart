import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carvita/application/ports/notification_permission_port.dart';
import 'package:carvita/application/ports/platform_ports.dart';
import 'package:carvita/application/use_cases/reconcile_notification_permission.dart';
import 'package:carvita/application/use_cases/vehicle_use_cases.dart';
import 'package:carvita/core/services/backup_service.dart';
import 'package:carvita/core/services/preferences_service.dart';
import 'package:carvita/core/theme/app_theme.dart';
import 'package:carvita/data/repositories/vehicle_repository.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/presentation/manager/locale_provider.dart';
import 'package:carvita/presentation/manager/theme_provider.dart';
import 'package:carvita/presentation/manager/vehicle_list/vehicle_cubit.dart';
import 'package:carvita/presentation/screens/settings/privacy_screen.dart';
import 'package:carvita/presentation/screens/settings/settings_screen.dart';
import 'package:carvita/presentation/screens/vehicle/select_vehicle_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('settings gradient uses light status bar icons', (tester) async {
    await tester.pumpWidget(_settingsApp());
    await tester.pumpAndSettle();

    _expectLightStatusBar(tester);
  });

  testWidgets('settings-related gradient routes use light status bar icons', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp(child: const PrivacyScreen()));
    await tester.pumpAndSettle();
    _expectLightStatusBar(tester);

    await tester.pumpWidget(
      _testApp(child: const SelectVehicleScreen(vehicles: [])),
    );
    await tester.pumpAndSettle();
    _expectLightStatusBar(tester);
  });
}

void _expectLightStatusBar(WidgetTester tester) {
  final appBar = tester.widget<AppBar>(find.byType(AppBar));
  expect(appBar.systemOverlayStyle?.statusBarIconBrightness, Brightness.light);
  expect(appBar.systemOverlayStyle?.statusBarBrightness, Brightness.dark);
}

Widget _settingsApp() {
  final preferences = PreferencesService();
  final notifications = _Notifications();
  final vehicleUseCases = VehicleUseCases(VehicleRepository(), preferences);

  return MultiProvider(
    providers: [
      Provider<PreferencesService>.value(value: preferences),
      Provider<VehicleUseCases>.value(value: vehicleUseCases),
      Provider<NotificationPermissionGateway>.value(value: notifications),
      Provider<ReconcileNotificationPermission>.value(
        value: ReconcileNotificationPermission(preferences, notifications),
      ),
      Provider<BackupGateway>.value(value: _BackupGateway()),
      Provider<BackupFilePickerPort>.value(value: _FilePicker()),
      Provider<FileSharePort>.value(value: _SharePort()),
      Provider<AppPackageInfoPort>.value(value: _PackageInfo()),
      Provider<ExternalUrlPort>.value(value: _ExternalUrl()),
      Provider<AppExitPort>.value(value: _AppExit()),
      ChangeNotifierProvider<LocaleProvider>(
        create: (_) => LocaleProvider(preferences),
      ),
      ChangeNotifierProvider<ThemeProvider>(
        create: (_) => ThemeProvider(preferences),
      ),
      BlocProvider<VehicleCubit>(create: (_) => VehicleCubit(vehicleUseCases)),
    ],
    child: _testApp(child: const SettingsScreen()),
  );
}

Widget _testApp({required Widget child}) {
  const brightness = Brightness.light;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: brightness,
  );

  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.getThemeData(colorScheme, brightness),
    home: child,
  );
}

final class _BackupGateway implements BackupGateway {
  @override
  Future<String> createExportSnapshot({
    String applicationVersion = 'unknown',
  }) async {
    return 'test.cvbackup';
  }

  @override
  Future<void> deleteExportSnapshot(String snapshotPath) async {}

  @override
  Future<void> restoreDatabase(String selectedPath) async {}
}

final class _FilePicker implements BackupFilePickerPort {
  @override
  Future<String?> pickBackupFile() async => null;
}

final class _SharePort implements FileSharePort {
  @override
  Future<ShareFileOutcome> shareFile(String path) async {
    return ShareFileOutcome.success;
  }
}

final class _PackageInfo implements AppPackageInfoPort {
  @override
  Future<AppPackageInfo> loadPackageInfo() async {
    return const AppPackageInfo(version: 'test');
  }
}

final class _ExternalUrl implements ExternalUrlPort {
  @override
  Future<void> openExternalUrl(Uri uri) async {}
}

final class _AppExit implements AppExitPort {
  @override
  Future<void> exitApplication() async {}
}

final class _Notifications implements NotificationPermissionGateway {
  @override
  Future<void> cancelAllNotifications() async {}

  @override
  Future<bool> checkPermissions() async => true;

  @override
  Future<bool> requestPermissions() async => true;
}
