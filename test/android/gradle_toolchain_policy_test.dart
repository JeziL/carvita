import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android toolchain uses the AGP 9 built-in Kotlin baseline', () {
    final settings = File('android/settings.gradle.kts').readAsStringSync();
    final appBuild = File('android/app/build.gradle.kts').readAsStringSync();
    final gradleProperties = File('android/gradle.properties')
        .readAsStringSync();
    final wrapperProperties = File(
      'android/gradle/wrapper/gradle-wrapper.properties',
    ).readAsStringSync();

    expect(settings, contains('id("com.android.application") version "9.1.0"'));
    expect(
      settings,
      contains(
        'id("org.jetbrains.kotlin.android") version "2.4.0" apply false',
      ),
    );
    expect(wrapperProperties, contains('gradle-9.3.1-all.zip'));
    expect(gradleProperties, contains('android.builtInKotlin=true'));
    expect(gradleProperties, contains('android.newDsl=false'));
    expect(appBuild, contains('compileSdk = flutter.compileSdkVersion'));
    expect(appBuild, contains('minSdk = flutter.minSdkVersion'));
    expect(appBuild, contains('targetSdk = flutter.targetSdkVersion'));
    expect(
      appBuild,
      isNot(
        matches(
          RegExp(
            r'''id\(["'](?:kotlin-android|org\.jetbrains\.kotlin\.android)["']\)''',
          ),
        ),
      ),
    );
    expect(
      appBuild,
      contains('jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17'),
    );
  });

  test('jni native builds omit path-dependent linker build IDs', () {
    final rootBuild = File('android/build.gradle.kts').readAsStringSync();

    expect(rootBuild, contains('val isJniPlugin = name == "jni"'));
    expect(
      rootBuild,
      contains('-DCMAKE_SHARED_LINKER_FLAGS=-Wl,--build-id=none'),
    );
  });
}
