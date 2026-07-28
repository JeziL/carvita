import 'package:flutter/services.dart';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:carvita/application/ports/platform_ports.dart';

final class PluginPlatformService
    implements
        VehicleImagePickerPort,
        BackupFilePickerPort,
        FileSharePort,
        AppPackageInfoPort,
        ExternalUrlPort,
        AppExitPort {
  const PluginPlatformService();

  @override
  Future<Uint8List?> pickVehicleImage(VehicleImageSource source) async {
    final imageFile = await ImagePicker().pickImage(
      source: switch (source) {
        VehicleImageSource.camera => ImageSource.camera,
        VehicleImageSource.gallery => ImageSource.gallery,
      },
      imageQuality: 70,
      maxWidth: 800,
    );
    return imageFile?.readAsBytes();
  }

  @override
  Future<String?> pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles();
    return result?.files.single.path;
  }

  @override
  Future<ShareFileOutcome> shareFile(String path) async {
    final result = await SharePlus.instance.share(
      ShareParams(files: [XFile(path)]),
    );
    return switch (result.status) {
      ShareResultStatus.success => ShareFileOutcome.success,
      ShareResultStatus.dismissed => ShareFileOutcome.dismissed,
      ShareResultStatus.unavailable => ShareFileOutcome.unavailable,
    };
  }

  @override
  Future<AppPackageInfo> loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    return AppPackageInfo(version: info.version);
  }

  @override
  Future<void> openExternalUrl(Uri uri) async {
    await launchUrl(uri);
  }

  @override
  Future<void> exitApplication() => SystemNavigator.pop();
}
