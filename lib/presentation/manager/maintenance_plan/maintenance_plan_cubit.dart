import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:carvita/application/use_cases/maintenance_plan_use_cases.dart';
import 'package:carvita/core/failures/app_failure.dart';
import 'package:carvita/core/utils/operation_result.dart';
import 'package:carvita/data/models/maintenance_plan_item.dart';
import 'maintenance_plan_state.dart';

class MaintenancePlanCubit extends Cubit<MaintenancePlanState> {
  final MaintenancePlanUseCases _useCases;
  final int vehicleId;
  int _loadRevision = 0;

  MaintenancePlanCubit(this._useCases, this.vehicleId)
    : super(MaintenancePlanInitial());

  Future<OperationResult> fetchPlanItems() async {
    if (isClosed) {
      return OperationFailure.capture(
        AppFailureKind.load,
        StateError('MaintenancePlanCubit is closed'),
        StackTrace.current,
        context: 'MaintenancePlanCubit.fetchPlanItems.closed',
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
      final items = await _useCases.getPlanItems(vehicleId);
      if (isClosed || revision != _loadRevision) {
        return OperationSuccess();
      }
      emit(MaintenancePlanLoaded(items));
      return OperationSuccess();
    } catch (error, stackTrace) {
      final failure = OperationFailure.capture(
        previousItems == null ? AppFailureKind.load : AppFailureKind.refresh,
        error,
        stackTrace,
        context: 'MaintenancePlanCubit.fetchPlanItems',
      );
      if (!isClosed && revision == _loadRevision) {
        if (previousItems == null) {
          emit(MaintenancePlanError(failure.failure));
        } else {
          emit(
            MaintenancePlanLoaded(
              previousItems,
              refreshFailure: failure.failure,
            ),
          );
        }
      }
      return failure;
    }
  }

  Future<OperationResult> addPlanItem(MaintenancePlanItem item) async {
    try {
      await _useCases.addPlanItem(vehicleId: vehicleId, item: item);
    } catch (error, stackTrace) {
      return OperationFailure.capture(
        AppFailureKind.save,
        error,
        stackTrace,
        context: 'MaintenancePlanCubit.addPlanItem',
      );
    }
    return _successAfterRefresh();
  }

  Future<OperationResult> updatePlanItem(MaintenancePlanItem item) async {
    try {
      await _useCases.updatePlanItem(vehicleId: vehicleId, item: item);
    } catch (error, stackTrace) {
      return OperationFailure.capture(
        AppFailureKind.save,
        error,
        stackTrace,
        context: 'MaintenancePlanCubit.updatePlanItem',
      );
    }
    return _successAfterRefresh();
  }

  Future<OperationResult> deletePlanItem(int itemId) async {
    try {
      await _useCases.deletePlanItem(itemId);
    } catch (error, stackTrace) {
      return OperationFailure.capture(
        AppFailureKind.delete,
        error,
        stackTrace,
        context: 'MaintenancePlanCubit.deletePlanItem',
      );
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
