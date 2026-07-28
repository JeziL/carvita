import 'dart:async';

import 'package:carvita/application/ports/app_startup_port.dart';

typedef AppStartupOperation = FutureOr<void> Function();

final class AppStartupService implements AppStartupPort {
  AppStartupService({
    required AppStartupOperation refreshReminderSchedule,
    required AppStartupOperation initializeNotifications,
    required AppStartupOperation initializeSystemLocale,
    required AppStartupOperation initializeQuickActions,
  }) : _operations = [
         (step: AppStartupStep.reminderSchedule, run: refreshReminderSchedule),
         (step: AppStartupStep.notifications, run: initializeNotifications),
         (step: AppStartupStep.systemLocale, run: initializeSystemLocale),
         (step: AppStartupStep.quickActions, run: initializeQuickActions),
       ];

  final List<({AppStartupStep step, AppStartupOperation run})> _operations;
  Future<AppStartupResult>? _initialization;

  @override
  Future<AppStartupResult> initialize() {
    return _initialization ??= _initialize();
  }

  Future<AppStartupResult> _initialize() async {
    final failures = <AppStartupFailure>[];
    for (final operation in _operations) {
      try {
        await operation.run();
      } catch (error, stackTrace) {
        failures.add(
          AppStartupFailure(
            step: operation.step,
            error: error,
            stackTrace: stackTrace,
          ),
        );
      }
    }
    return AppStartupResult(failures);
  }
}
