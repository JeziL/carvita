import 'dart:typed_data';

enum VehicleImageSource { camera, gallery }

enum ShareFileOutcome { success, dismissed, unavailable }

final class AppPackageInfo {
  const AppPackageInfo({required this.version});

  final String version;
}

abstract interface class VehicleImagePickerPort {
  Future<Uint8List?> pickVehicleImage(VehicleImageSource source);
}

abstract interface class BackupFilePickerPort {
  Future<String?> pickBackupFile();
}

abstract interface class FileSharePort {
  Future<ShareFileOutcome> shareFile(String path);
}

abstract interface class AppPackageInfoPort {
  Future<AppPackageInfo> loadPackageInfo();
}

abstract interface class ExternalUrlPort {
  Future<void> openExternalUrl(Uri uri);
}

abstract interface class AppExitPort {
  Future<void> exitApplication();
}
