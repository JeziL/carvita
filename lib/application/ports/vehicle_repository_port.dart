import 'dart:typed_data';

import 'package:carvita/data/models/vehicle.dart';

abstract interface class VehicleRepositoryPort {
  Future<List<Vehicle>> getVehicles();

  Future<Vehicle?> getVehicleById(int id);

  Future<Uint8List?> getVehicleImage(int id);

  Future<void> addVehicle(Vehicle vehicle);

  Future<void> updateVehicle(Vehicle vehicle);

  Future<void> deleteVehicle(int id);
}
