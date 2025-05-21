import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:carvita/core/services/preferences_service.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/data/repositories/vehicle_repository.dart';
import 'vehicle_state.dart';

class VehicleCubit extends Cubit<VehicleState> {
  final VehicleRepository _vehicleRepository;
  final PreferencesService _preferencesService;

  VehicleCubit(
    this._vehicleRepository, {
    PreferencesService? preferencesService,
  }) : _preferencesService = preferencesService ?? PreferencesService(),
       super(VehicleInitial());

  Future<void> fetchVehicles() async {
    emit(VehicleLoading());
    try {
      final vehicles = await _vehicleRepository.getVehicles();
      emit(VehicleLoaded(vehicles));
    } catch (e) {
      emit(VehicleError(e.toString()));
    }
  }

  Future<void> addVehicle(Vehicle vehicle) async {
    try {
      await _vehicleRepository.addVehicle(vehicle);
      fetchVehicles();
      emit(VehicleOperationSuccess(""));
    } catch (e) {
      emit(VehicleError(e.toString()));
      // Re-fetch vehicles even on error to ensure UI consistency
      fetchVehicles();
    }
  }

  Future<void> updateVehicle(Vehicle vehicle) async {
    try {
      await _vehicleRepository.updateVehicle(vehicle);
      fetchVehicles();
      emit(VehicleOperationSuccess(""));
    } catch (e) {
      emit(VehicleError(e.toString()));
      fetchVehicles();
    }
  }

  Future<void> deleteVehicle(int id) async {
    try {
      await _vehicleRepository.deleteVehicle(id);
      // Check if the deleted vehicle was the default vehicle
      final defaultVehicleId = await _preferencesService.getDefaultVehicleId();
      if (defaultVehicleId == id) {
        await _preferencesService.setDefaultVehicleId(null); // Clear default
      }
      // After deleting, refresh the list
      fetchVehicles();
      emit(VehicleOperationSuccess(""));
    } catch (e) {
      emit(VehicleError(e.toString()));
      fetchVehicles();
    }
  }
}
