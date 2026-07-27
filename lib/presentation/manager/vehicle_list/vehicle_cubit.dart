import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:carvita/core/services/preferences_service.dart';
import 'package:carvita/core/utils/operation_result.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/data/repositories/vehicle_repository.dart';
import 'vehicle_state.dart';

class VehicleCubit extends Cubit<VehicleState> {
  final VehicleRepository _vehicleRepository;
  final PreferencesService _preferencesService;
  int _loadRevision = 0;

  VehicleCubit(
    this._vehicleRepository, {
    PreferencesService? preferencesService,
  }) : _preferencesService = preferencesService ?? PreferencesService(),
       super(VehicleInitial());

  Future<OperationResult> fetchVehicles() async {
    if (isClosed) {
      return OperationFailure(
        StateError('VehicleCubit is closed'),
        StackTrace.current,
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
      final vehicles = await _vehicleRepository.getVehicles();
      if (isClosed || revision != _loadRevision) {
        return OperationSuccess();
      }
      emit(VehicleLoaded(vehicles));
      return OperationSuccess();
    } catch (error, stackTrace) {
      if (!isClosed && revision == _loadRevision) {
        if (previousVehicles == null) {
          emit(VehicleError(error.toString()));
        } else {
          emit(VehicleLoaded(previousVehicles, refreshError: error.toString()));
        }
      }
      return OperationFailure(error, stackTrace);
    }
  }

  Future<OperationResult> addVehicle(Vehicle vehicle) async {
    try {
      await _vehicleRepository.addVehicle(vehicle);
    } catch (error, stackTrace) {
      return OperationFailure(error, stackTrace);
    }
    return _successAfterRefresh();
  }

  Future<OperationResult> updateVehicle(Vehicle vehicle) async {
    try {
      await _vehicleRepository.updateVehicle(vehicle);
    } catch (error, stackTrace) {
      return OperationFailure(error, stackTrace);
    }
    return _successAfterRefresh();
  }

  Future<OperationResult> deleteVehicle(int id) async {
    try {
      await _vehicleRepository.deleteVehicle(id);
      final defaultVehicleId = await _preferencesService.getDefaultVehicleId();
      if (defaultVehicleId == id) {
        await _preferencesService.setDefaultVehicleId(null);
      }
    } catch (error, stackTrace) {
      return OperationFailure(error, stackTrace);
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
