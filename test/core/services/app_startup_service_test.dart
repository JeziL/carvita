import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:carvita/application/ports/app_startup_port.dart';
import 'package:carvita/core/services/app_startup_service.dart';

void main() {
  test('continues after a recoverable operation failure', () async {
    final completed = <AppStartupStep>[];
    final service = AppStartupService(
      refreshReminderSchedule: () {
        completed.add(AppStartupStep.reminderSchedule);
      },
      initializeNotifications: () {
        throw StateError('notification plugin unavailable');
      },
      initializeSystemLocale: () {
        completed.add(AppStartupStep.systemLocale);
      },
      initializeQuickActions: () {
        completed.add(AppStartupStep.quickActions);
      },
    );

    final result = await service.initialize();

    expect(completed, [
      AppStartupStep.reminderSchedule,
      AppStartupStep.systemLocale,
      AppStartupStep.quickActions,
    ]);
    expect(result.failures, hasLength(1));
    expect(result.failures.single.step, AppStartupStep.notifications);
  });

  test('concurrent callers share one initialization run', () async {
    final gate = Completer<void>();
    var notificationInitializationCount = 0;
    final service = AppStartupService(
      refreshReminderSchedule: () {},
      initializeNotifications: () async {
        notificationInitializationCount++;
        await gate.future;
      },
      initializeSystemLocale: () {},
      initializeQuickActions: () {},
    );

    final first = service.initialize();
    final second = service.initialize();
    gate.complete();

    expect(await first, same(await second));
    expect(notificationInitializationCount, 1);
  });
}
