import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:carvita/application/use_cases/vehicle_use_cases.dart';
import 'package:carvita/core/failures/app_failure.dart';
import 'package:carvita/core/utils/operation_result.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'vehicle_state.dart';

class VehicleCubit extends Cubit<VehicleState> {
  final VehicleUseCases _useCases;
  int _loadRevision = 0;

  VehicleCubit(this._useCases) : super(VehicleInitial());

  Future<OperationResult> fetchVehicles() async {
    if (isClosed) {
      return OperationFailure.capture(
        AppFailureKind.load,
        StateError('VehicleCubit is closed'),
        StackTrace.current,
        context: 'VehicleCubit.fetchVehicles.closed',
      );
    }
    final revision = ++_loadRevision;
    final previousVehicles = state is VehicleLoaded
        ? (state as VehicleLoaded).vehicles
        : null;
    if (previousVehicles == null) {
      emit(VehicleLoading());
    } else {
      emit(VehicleLoaded(previousVehicles, isRefreshing: true));
    }
    try {
      final vehicles = await _useCases.getVehicles();
      if (isClosed || revision != _loadRevision) {
        return OperationSuccess();
      }
      emit(VehicleLoaded(vehicles));
      return OperationSuccess();
    } catch (error, stackTrace) {
      final failure = OperationFailure.capture(
        previousVehicles == null ? AppFailureKind.load : AppFailureKind.refresh,
        error,
        stackTrace,
        context: 'VehicleCubit.fetchVehicles',
      );
      if (!isClosed && revision == _loadRevision) {
        if (previousVehicles == null) {
          emit(VehicleError(failure.failure));
        } else {
          emit(
            VehicleLoaded(previousVehicles, refreshFailure: failure.failure),
          );
        }
      }
      return failure;
    }
  }

  Future<OperationResult> addVehicle(Vehicle vehicle) async {
    try {
      await _useCases.addVehicle(vehicle);
    } catch (error, stackTrace) {
      return OperationFailure.capture(
        AppFailureKind.save,
        error,
        stackTrace,
        context: 'VehicleCubit.addVehicle',
      );
    }
    return _successAfterRefresh();
  }

  Future<OperationResult> updateVehicle(Vehicle vehicle) async {
    try {
      await _useCases.updateVehicle(vehicle);
    } catch (error, stackTrace) {
      return OperationFailure.capture(
        AppFailureKind.save,
        error,
        stackTrace,
        context: 'VehicleCubit.updateVehicle',
      );
    }
    return _successAfterRefresh();
  }

  Future<OperationResult> deleteVehicle(int id) async {
    try {
      await _useCases.deleteVehicle(id);
    } catch (error, stackTrace) {
      return OperationFailure.capture(
        AppFailureKind.delete,
        error,
        stackTrace,
        context: 'VehicleCubit.deleteVehicle',
      );
    }
    return _successAfterRefresh();
  }

  Future<OperationResult> _successAfterRefresh() async {
    final refreshResult = await fetchVehicles();
    return OperationSuccess(
      followUpFailure: refreshResult is OperationFailure ? refreshResult : null,
    );
  }
}
