import 'dart:developer' as developer;

enum AppFailureKind {
  load,
  save,
  delete,
  refresh,
  reminderUpdate,
  export,
  restore,
}

final class AppFailure {
  final AppFailureKind kind;

  AppFailure._(this.kind);

  factory AppFailure.capture(
    AppFailureKind kind,
    Object error,
    StackTrace stackTrace, {
    required String context,
  }) {
    assert(() {
      developer.log(
        'Operation failed',
        name: 'carvita.$context',
        error: error,
        stackTrace: stackTrace,
      );
      return true;
    }());
    return AppFailure._(kind);
  }
}
