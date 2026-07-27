import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:carvita/core/utils/operation_result.dart';
import 'package:carvita/data/models/service_log_entry.dart';
import 'package:carvita/data/repositories/maintenance_repository.dart';
import 'service_log_state.dart';

class ServiceLogCubit extends Cubit<ServiceLogState> {
  final MaintenanceRepository _repository;
  final int vehicleId;
  int _loadRevision = 0;

  ServiceLogCubit(this._repository, this.vehicleId)
    : super(ServiceLogInitial());

  Future<OperationResult> fetchServiceLogs() async {
    if (isClosed) {
      return OperationFailure(
        StateError('ServiceLogCubit is closed'),
        StackTrace.current,
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
      final logs = await _repository.getServiceLogs(vehicleId);
      if (isClosed || revision != _loadRevision) {
        return OperationSuccess();
      }
      emit(ServiceLogLoaded(logs));
      return OperationSuccess();
    } catch (error, stackTrace) {
      if (!isClosed && revision == _loadRevision) {
        if (previousLogs == null) {
          emit(ServiceLogError(error.toString()));
        } else {
          emit(ServiceLogLoaded(previousLogs, refreshError: error.toString()));
        }
      }
      return OperationFailure(error, stackTrace);
    }
  }

  Future<OperationResult> addServiceLog(
    ServiceLogEntry logEntry,
    List<PerformedItemInput> performedItems,
  ) async {
    try {
      final newLog = await _repository.addServiceLog(logEntry, performedItems);
      if (newLog == null) {
        return OperationFailure(
          StateError('Adding the service log did not return a saved record'),
          StackTrace.current,
        );
      }
    } catch (error, stackTrace) {
      return OperationFailure(error, stackTrace);
    }
    return _successAfterRefresh();
  }

  Future<OperationResult> updateServiceLog(
    ServiceLogEntry logEntry,
    List<PerformedItemInput> performedItems,
  ) async {
    try {
      final success = await _repository.updateServiceLog(
        logEntry,
        performedItems,
      );
      if (!success) {
        return OperationFailure(
          StateError('Updating the service log affected no records'),
          StackTrace.current,
        );
      }
    } catch (error, stackTrace) {
      return OperationFailure(error, stackTrace);
    }
    return _successAfterRefresh();
  }

  Future<OperationResult> deleteServiceLog(int logId) async {
    try {
      final success = await _repository.deleteServiceLog(logId);
      if (!success) {
        return OperationFailure(
          StateError('Deleting the service log affected no records'),
          StackTrace.current,
        );
      }
    } catch (error, stackTrace) {
      return OperationFailure(error, stackTrace);
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
