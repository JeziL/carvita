import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:carvita/application/use_cases/service_log_use_cases.dart';
import 'package:carvita/core/failures/app_failure.dart';
import 'package:carvita/core/utils/operation_result.dart';
import 'package:carvita/data/models/service_log_entry.dart';
import 'service_log_state.dart';

class ServiceLogCubit extends Cubit<ServiceLogState> {
  final ServiceLogUseCases _useCases;
  final int vehicleId;
  int _loadRevision = 0;

  ServiceLogCubit(this._useCases, this.vehicleId) : super(ServiceLogInitial());

  Future<OperationResult> fetchServiceLogs() async {
    if (isClosed) {
      return OperationFailure.capture(
        AppFailureKind.load,
        StateError('ServiceLogCubit is closed'),
        StackTrace.current,
        context: 'ServiceLogCubit.fetchServiceLogs.closed',
      );
    }
    final revision = ++_loadRevision;
    final previousLogs = state is ServiceLogLoaded
        ? (state as ServiceLogLoaded).serviceLogs
        : null;
    if (previousLogs == null) {
      emit(ServiceLogLoading());
    } else {
      emit(ServiceLogLoaded(previousLogs, isRefreshing: true));
    }
    try {
      final logs = await _useCases.getServiceLogs(vehicleId);
      if (isClosed || revision != _loadRevision) {
        return OperationSuccess();
      }
      emit(ServiceLogLoaded(logs));
      return OperationSuccess();
    } catch (error, stackTrace) {
      final failure = OperationFailure.capture(
        previousLogs == null ? AppFailureKind.load : AppFailureKind.refresh,
        error,
        stackTrace,
        context: 'ServiceLogCubit.fetchServiceLogs',
      );
      if (!isClosed && revision == _loadRevision) {
        if (previousLogs == null) {
          emit(ServiceLogError(failure.failure));
        } else {
          emit(ServiceLogLoaded(previousLogs, refreshFailure: failure.failure));
        }
      }
      return failure;
    }
  }

  Future<OperationResult> addServiceLog(
    ServiceLogEntry logEntry,
    List<PerformedItemInput> performedItems,
  ) async {
    try {
      await _useCases.addServiceLog(logEntry, performedItems);
    } catch (error, stackTrace) {
      return OperationFailure.capture(
        AppFailureKind.save,
        error,
        stackTrace,
        context: 'ServiceLogCubit.addServiceLog',
      );
    }
    return _successAfterRefresh();
  }

  Future<OperationResult> updateServiceLog(
    ServiceLogEntry logEntry,
    List<PerformedItemInput> performedItems,
  ) async {
    try {
      await _useCases.updateServiceLog(logEntry, performedItems);
    } catch (error, stackTrace) {
      return OperationFailure.capture(
        AppFailureKind.save,
        error,
        stackTrace,
        context: 'ServiceLogCubit.updateServiceLog',
      );
    }
    return _successAfterRefresh();
  }

  Future<OperationResult> deleteServiceLog(int logId) async {
    try {
      await _useCases.deleteServiceLog(logId);
    } catch (error, stackTrace) {
      return OperationFailure.capture(
        AppFailureKind.delete,
        error,
        stackTrace,
        context: 'ServiceLogCubit.deleteServiceLog',
      );
    }
    return _successAfterRefresh();
  }

  Future<OperationResult> _successAfterRefresh() async {
    final refreshResult = await fetchServiceLogs();
    return OperationSuccess(
      followUpFailure: refreshResult is OperationFailure ? refreshResult : null,
    );
  }
}
