import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:carvita/data/models/maintenance_plan_item.dart';
import 'package:carvita/data/repositories/maintenance_repository.dart';
import 'maintenance_plan_state.dart';

class MaintenancePlanCubit extends Cubit<MaintenancePlanState> {
  final MaintenanceRepository _repository;
  final int vehicleId;

  MaintenancePlanCubit(this._repository, this.vehicleId)
    : super(MaintenancePlanInitial()) {
    fetchPlanItems();
  }

  Future<void> fetchPlanItems() async {
    emit(MaintenancePlanLoading());
    try {
      final items = await _repository.getPlanItems(vehicleId);
      emit(MaintenancePlanLoaded(items));
    } catch (e) {
      emit(MaintenancePlanError(e.toString()));
    }
  }

  Future<void> addPlanItem(MaintenancePlanItem item) async {
    try {
      if (item.vehicleId != vehicleId) {
        emit(MaintenancePlanError("Vehicle does not match maintenance plan"));
        return;
      }
      await _repository.addPlanItem(item);
      fetchPlanItems();
      emit(MaintenancePlanOperationSuccess(""));
    } catch (e) {
      emit(MaintenancePlanError(e.toString()));
    }
  }

  Future<void> updatePlanItem(MaintenancePlanItem item) async {
    try {
      if (item.vehicleId != vehicleId) {
        emit(MaintenancePlanError("Vehicle does not match maintenance plan"));
        return;
      }
      await _repository.updatePlanItem(item);
      fetchPlanItems();
      emit(MaintenancePlanOperationSuccess(""));
    } catch (e) {
      emit(MaintenancePlanError(e.toString()));
    }
  }

  Future<void> deletePlanItem(int itemId) async {
    try {
      await _repository.deletePlanItem(itemId);
      fetchPlanItems();
      emit(MaintenancePlanOperationSuccess(""));
    } catch (e) {
      emit(MaintenancePlanError(e.toString()));
    }
  }
}
