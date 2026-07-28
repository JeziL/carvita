import 'dart:typed_data';

import 'package:carvita/application/ports/preferences_ports.dart';
import 'package:carvita/application/ports/vehicle_repository_port.dart';
import 'package:carvita/data/models/vehicle.dart';

final class VehicleUseCases {
  const VehicleUseCases(this._repository, this._preferences);

  final VehicleRepositoryPort _repository;
  final DefaultVehiclePreferences _preferences;

  Future<List<Vehicle>> getVehicles() => _repository.getVehicles();

  Future<Vehicle?> getVehicleById(int id) => _repository.getVehicleById(id);

  Future<Uint8List?> getVehicleImage(int id) => _repository.getVehicleImage(id);

  Future<void> addVehicle(Vehicle vehicle) {
    return _repository.addVehicle(vehicle);
  }

  Future<void> updateVehicle(Vehicle vehicle) {
    return _repository.updateVehicle(vehicle);
  }

  Future<void> deleteVehicle(int id) async {
    await _repository.deleteVehicle(id);
    final defaultVehicleId = await _preferences.getDefaultVehicleId();
    if (defaultVehicleId == id) {
      await _preferences.setDefaultVehicleId(null);
    }
  }
}
