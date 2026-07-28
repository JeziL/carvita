import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android exposes the device time zone through the scoped channel', () {
    final source = File(
      'android/app/src/main/kotlin/com/wangjinli/carvita/MainActivity.kt',
    ).readAsStringSync();

    expect(source, contains('com.wangjinli.carvita/device_time_zone'));
    expect(source, contains('"getLocalTimeZoneId"'));
    expect(source, contains('TimeZone.getDefault().id'));
  });
}
