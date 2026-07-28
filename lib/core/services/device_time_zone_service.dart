import 'package:flutter/services.dart';

import 'package:carvita/application/ports/reminder_schedule_port.dart';

class MethodChannelDeviceTimeZone implements DeviceTimeZonePort {
  const MethodChannelDeviceTimeZone();

  static const MethodChannel _channel = MethodChannel(
    'com.wangjinli.carvita/device_time_zone',
  );

  @override
  Future<String> getLocalTimeZoneId() async {
    final timeZoneId = await _channel.invokeMethod<String>(
      'getLocalTimeZoneId',
    );
    if (timeZoneId == null || timeZoneId.trim().isEmpty) {
      throw StateError('Device returned an empty time zone identifier');
    }
    return timeZoneId;
  }
}
