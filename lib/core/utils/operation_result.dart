sealed class OperationResult {
  const OperationResult();

  bool get isSuccess => this is OperationSuccess;
}

final class OperationSuccess extends OperationResult {
  final OperationFailure? followUpFailure;

  const OperationSuccess({this.followUpFailure});
}

final class OperationFailure extends OperationResult {
  final Object error;
  final StackTrace stackTrace;

  const OperationFailure(this.error, this.stackTrace);
}
