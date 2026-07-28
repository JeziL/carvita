import 'package:carvita/core/failures/app_failure.dart';

sealed class OperationResult {
  const OperationResult();

  bool get isSuccess => this is OperationSuccess;
}

final class OperationSuccess extends OperationResult {
  final OperationFailure? followUpFailure;

  const OperationSuccess({this.followUpFailure});
}

final class OperationFailure extends OperationResult {
  final AppFailure failure;
  final Object error;
  final StackTrace stackTrace;

  OperationFailure.capture(
    AppFailureKind kind,
    this.error,
    this.stackTrace, {
    required String context,
  }) : failure = AppFailure.capture(kind, error, stackTrace, context: context);
}
