import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:carvita/core/utils/operation_result.dart';
import 'package:carvita/data/models/maintenance_plan_item.dart';
import 'package:carvita/data/repositories/maintenance_repository.dart';
import 'maintenance_plan_state.dart';

class MaintenancePlanCubit extends Cubit<MaintenancePlanState> {
  final MaintenanceRepository _repository;
  final int vehicleId;
  int _loadRevision = 0;

  MaintenancePlanCubit(this._repository, this.vehicleId)
    : super(MaintenancePlanInitial());

  Future<OperationResult> fetchPlanItems() async {
    if (isClosed) {
      return OperationFailure(
        StateError('MaintenancePlanCubit is closed'),
        StackTrace.current,
      );
    }
    final revision = ++_loadRevision;
    final previousItems = state is MaintenancePlanLoaded
        ? (state as MaintenancePlanLoaded).planItems
        : null;
    if (previousItems == null) {
      emit(MaintenancePlanLoading());
    } else {
      emit(MaintenancePlanLoaded(previousItems, isRefreshing: true));
    }
    try {
      final items = await _repository.getPlanItems(vehicleId);
      if (isClosed || revision != _loadRevision) {
        return OperationSuccess();
      }
      emit(MaintenancePlanLoaded(items));
      return OperationSuccess();
    } catch (error, stackTrace) {
      if (!isClosed && revision == _loadRevision) {
        if (previousItems == null) {
          emit(MaintenancePlanError(error.toString()));
        } else {
          emit(
            MaintenancePlanLoaded(
              previousItems,
              refreshError: error.toString(),
            ),
          );
        }
      }
      return OperationFailure(error, stackTrace);
    }
  }

  Future<OperationResult> addPlanItem(MaintenancePlanItem item) async {
    if (item.vehicleId != vehicleId) {
      return OperationFailure(
        ArgumentError.value(
          item.vehicleId,
          'item.vehicleId',
          'Vehicle does not match maintenance plan',
        ),
        StackTrace.current,
      );
    }
    try {
      await _repository.addPlanItem(item);
    } catch (error, stackTrace) {
      return OperationFailure(error, stackTrace);
    }
    return _successAfterRefresh();
  }

  Future<OperationResult> updatePlanItem(MaintenancePlanItem item) async {
    if (item.vehicleId != vehicleId) {
      return OperationFailure(
        ArgumentError.value(
          item.vehicleId,
          'item.vehicleId',
          'Vehicle does not match maintenance plan',
        ),
        StackTrace.current,
      );
    }
    try {
      await _repository.updatePlanItem(item);
    } catch (error, stackTrace) {
      return OperationFailure(error, stackTrace);
    }
    return _successAfterRefresh();
  }

  Future<OperationResult> deletePlanItem(int itemId) async {
    try {
      await _repository.deletePlanItem(itemId);
    } catch (error, stackTrace) {
      return OperationFailure(error, stackTrace);
    }
    return _successAfterRefresh();
  }

  Future<OperationResult> _successAfterRefresh() async {
    final refreshResult = await fetchPlanItems();
    return OperationSuccess(
      followUpFailure: refreshResult is OperationFailure ? refreshResult : null,
    );
  }
}
