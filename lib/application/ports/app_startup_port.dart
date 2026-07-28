enum AppStartupStep {
  reminderSchedule,
  notifications,
  systemLocale,
  quickActions,
}

final class AppStartupFailure {
  const AppStartupFailure({
    required this.step,
    required this.error,
    required this.stackTrace,
  });

  final AppStartupStep step;
  final Object error;
  final StackTrace stackTrace;
}

final class AppStartupResult {
  AppStartupResult(Iterable<AppStartupFailure> failures)
    : failures = List<AppStartupFailure>.unmodifiable(failures);

  final List<AppStartupFailure> failures;

  bool get isSuccess => failures.isEmpty;
}

abstract interface class AppStartupPort {
  Future<AppStartupResult> initialize();
}
