import 'package:carvita/data/models/service_log_entry.dart';
import 'package:carvita/data/repositories/maintenance_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'service_log_state.dart';

class ServiceLogCubit extends Cubit<ServiceLogState> {
  final MaintenanceRepository _repository;
  final int vehicleId;

  ServiceLogCubit(this._repository, this.vehicleId) : super(ServiceLogInitial()) {
    fetchServiceLogs();
  }

  Future<void> fetchServiceLogs() async {
    emit(ServiceLogLoading());
    try {
      final logs = await _repository.getServiceLogs(vehicleId);
      emit(ServiceLogLoaded(logs));
    } catch (e) {
      emit(ServiceLogError(e.toString()));
    }
  }

  Future<void> addServiceLog(ServiceLogEntry logEntry, List<PerformedItemInput> performedItems) async {
    try {
      final newLog = await _repository.addServiceLog(logEntry, performedItems);
      if (newLog != null) {
        fetchServiceLogs();
        emit(ServiceLogOperationSuccess(""));
      } else {
        emit(ServiceLogError("Failed to add service log: Operation was not successful"));
      }
    } catch (e) {
      emit(ServiceLogError(e.toString()));
    }
  }

  Future<void> updateServiceLog(ServiceLogEntry logEntry, List<PerformedItemInput> performedItems) async {
    try {
      final success = await _repository.updateServiceLog(logEntry, performedItems);
      if (success) {
        fetchServiceLogs();
        emit(ServiceLogOperationSuccess(""));
      } else {
        emit(ServiceLogError("Failed to update service log: Operation was not successful"));
      }
    } catch (e) {
      emit(ServiceLogError(e.toString()));
    }
  }

  Future<void> deleteServiceLog(int logId) async {
    try {
      final success = await _repository.deleteServiceLog(logId);
       if (success) {
        fetchServiceLogs();
        emit(ServiceLogOperationSuccess(""));
      } else {
        emit(ServiceLogError("Failed to delete service log: Operation was not successful"));
      }
    } catch (e) {
      emit(ServiceLogError(e.toString()));
    }
  }
}
