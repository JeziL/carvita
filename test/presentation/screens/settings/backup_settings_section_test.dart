import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:provider/provider.dart';

import 'package:carvita/application/ports/notification_permission_port.dart';
import 'package:carvita/application/ports/platform_ports.dart';
import 'package:carvita/core/services/backup_service.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/presentation/screens/settings/backup_settings_section.dart';

void main() {
  testWidgets('export creates, shares, and cleans a versioned package', (
    tester,
  ) async {
    final backup = _BackupGateway();
    final share = _SharePort();
    await tester.pumpWidget(_testApp(backup: backup, share: share));

    await tester.tap(find.text('Export data'));
    await tester.pump();
    await tester.pump();

    expect(backup.applicationVersion, '1.1.0+8');
    expect(share.sharedPath, 'test.cvbackup');
    expect(backup.deletedPath, 'test.cvbackup');
    expect(find.text('Export successful'), findsOneWidget);
  });

  testWidgets('data section matches the surrounding settings card style', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());

    final context = tester.element(find.byType(BackupSettingsSection));
    final colorScheme = Theme.of(context).colorScheme;
    final card = tester.widget<Card>(find.byType(Card));
    expect(card.color, colorScheme.surfaceContainerLowest);
    expect(
      card.margin,
      const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
    );
    expect(card.elevation, 2);
    expect(find.text('DATA'), findsOneWidget);
  });

  testWidgets('restore confirmation keeps the concise warning', (tester) async {
    await tester.pumpWidget(_testApp());

    await tester.tap(find.text('Restore data'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This will overwrite all current app data with the selected file and '
        'cannot be undone.\n\nIt is strongly recommended that you export your '
        'current data as a backup before proceeding.\n\nAre you sure you want '
        'to continue?',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('legacy .db'), findsNothing);
    expect(find.textContaining('included settings'), findsNothing);
  });
}

Widget _testApp({_BackupGateway? backup, _SharePort? share}) {
  return MultiProvider(
    providers: [
      Provider<BackupGateway>.value(value: backup ?? _BackupGateway()),
      Provider<BackupFilePickerPort>.value(value: _FilePicker()),
      Provider<FileSharePort>.value(value: share ?? _SharePort()),
      Provider<AppPackageInfoPort>.value(value: _PackageInfo()),
      Provider<AppExitPort>.value(value: _AppExit()),
      Provider<NotificationPermissionGateway>.value(value: _Notifications()),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: const Scaffold(body: BackupSettingsSection()),
    ),
  );
}

final class _BackupGateway implements BackupGateway {
  String? applicationVersion;
  String? deletedPath;

  @override
  Future<String> createExportSnapshot({
    String applicationVersion = 'unknown',
  }) async {
    this.applicationVersion = applicationVersion;
    return 'test.cvbackup';
  }

  @override
  Future<void> deleteExportSnapshot(String snapshotPath) async {
    deletedPath = snapshotPath;
  }

  @override
  Future<void> restoreDatabase(String selectedPath) async {}
}

final class _FilePicker implements BackupFilePickerPort {
  @override
  Future<String?> pickBackupFile() async => null;
}

final class _SharePort implements FileSharePort {
  String? sharedPath;

  @override
  Future<ShareFileOutcome> shareFile(String path) async {
    sharedPath = path;
    return ShareFileOutcome.success;
  }
}

final class _PackageInfo implements AppPackageInfoPort {
  @override
  Future<AppPackageInfo> loadPackageInfo() async {
    return const AppPackageInfo(version: '1.1.0+8');
  }
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
