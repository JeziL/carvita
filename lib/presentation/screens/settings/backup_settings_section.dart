import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:carvita/application/ports/platform_ports.dart';
import 'package:carvita/core/constants/app_colors.dart';
import 'package:carvita/core/failures/app_failure.dart';
import 'package:carvita/core/services/backup_service.dart';
import 'package:carvita/core/services/notification_service.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/presentation/failures/app_failure_localizer.dart';

class BackupSettingsSection extends StatefulWidget {
  const BackupSettingsSection({super.key});

  @override
  State<BackupSettingsSection> createState() => _BackupSettingsSectionState();
}

class _BackupSettingsSectionState extends State<BackupSettingsSection> {
  late final BackupGateway _backup;
  late final BackupFilePickerPort _filePicker;
  late final FileSharePort _fileShare;
  late final AppPackageInfoPort _packageInfo;
  late final AppExitPort _appExit;
  late final NotificationPermissionGateway _notifications;

  bool _isExporting = false;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _backup = context.read<BackupGateway>();
    _filePicker = context.read<BackupFilePickerPort>();
    _fileShare = context.read<FileSharePort>();
    _packageInfo = context.read<AppPackageInfoPort>();
    _appExit = context.read<AppExitPort>();
    _notifications = context.read<NotificationPermissionGateway>();
  }

  Future<void> _exportBackup() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    String? packagePath;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.exportPrepare)),
    );

    try {
      final packageInfo = await _packageInfo.loadPackageInfo();
      packagePath = await _backup.createExportSnapshot(
        applicationVersion: packageInfo.version,
      );
      final shareResult = await _fileShare.shareFile(packagePath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).removeCurrentSnackBar();

      switch (shareResult) {
        case ShareFileOutcome.success:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.exportSuccess),
              backgroundColor: Colors.green,
            ),
          );
        case ShareFileOutcome.dismissed:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.exportCancelled),
            ),
          );
        case ShareFileOutcome.unavailable:
          _showFailure(
            AppFailure.capture(
              AppFailureKind.export,
              StateError('Share failed with status $shareResult'),
              StackTrace.current,
              context: 'BackupSettingsSection.export.share',
            ),
          );
      }
    } on BackupSourceNotFoundException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errDBNotFound),
          backgroundColor: AppColors.urgentReminderText,
        ),
      );
    } catch (error, stackTrace) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      _showFailure(
        AppFailure.capture(
          AppFailureKind.export,
          error,
          stackTrace,
          context: 'BackupSettingsSection.export',
        ),
      );
    } finally {
      if (packagePath != null) {
        await _backup.deleteExportSnapshot(packagePath);
      }
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _restoreBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        title: Text(AppLocalizations.of(context)!.restoreWarningTitle),
        content: Text(AppLocalizations.of(context)!.restoreWarningBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              AppLocalizations.of(context)!.restoreData,
              style: const TextStyle(
                color: AppColors.urgentReminderText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || _isImporting) return;

    setState(() => _isImporting = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.chooseDBFile)),
    );

    try {
      final selectedPath = await _filePicker.pickBackupFile();
      if (!mounted) return;
      if (selectedPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.importCancelled),
          ),
        );
        return;
      }

      await _backup.restoreDatabase(selectedPath);
      try {
        await _notifications.cancelAllNotifications();
      } catch (error) {
        debugPrint(
          'Backup restore succeeded, but old notifications could not be '
          'cancelled: $error',
        );
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerLowest,
            title: Text(AppLocalizations.of(context)!.restoreSuccessTitle),
            content: Text(AppLocalizations.of(context)!.restoreSuccessBody),
            actions: [
              TextButton(
                onPressed: _appExit.exitApplication,
                child: Text(
                  AppLocalizations.of(context)!.exitButton,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (error, stackTrace) {
      if (!mounted) return;
      _showFailure(
        AppFailure.capture(
          AppFailureKind.restore,
          error,
          stackTrace,
          context: 'BackupSettingsSection.restore',
        ),
      );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showFailure(AppFailure failure) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failure.toLocalizedMessage(AppLocalizations.of(context)!),
        ),
        backgroundColor: AppColors.urgentReminderText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.surfaceContainerLowest,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.only(left: 18, right: 18, top: 5, bottom: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                AppLocalizations.of(context)!.data.toUpperCase(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            _tile(
              icon: Icons.cloud_download_outlined,
              label: AppLocalizations.of(context)!.restoreData,
              busy: _isImporting,
              onTap: _isImporting ? null : _restoreBackup,
            ),
            _tile(
              icon: Icons.ios_share_outlined,
              label: AppLocalizations.of(context)!.exportData,
              busy: _isExporting,
              onTap: _isExporting ? null : _exportBackup,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String label,
    required bool busy,
    required VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: colorScheme.primary, size: 22),
      title: Text(
        label,
        style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
      ),
      onTap: onTap,
      trailing: busy
          ? SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            )
          : Icon(
              Icons.chevron_right,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
    );
  }
}
