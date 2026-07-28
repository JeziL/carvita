import 'dart:typed_data';

import 'package:carvita/application/ports/vehicle_repository_port.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/data/sources/local/database_helper.dart';

class VehicleRepository implements VehicleRepositoryPort {
  final DatabaseHelper _dbHelper;

  VehicleRepository({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper();

  @override
  Future<List<Vehicle>> getVehicles() async {
    return await _dbHelper.getAllVehicles();
  }

  @override
  Future<Vehicle?> getVehicleById(int id) async {
    return await _dbHelper.getVehicleById(id);
  }

  @override
  Future<Uint8List?> getVehicleImage(int id) {
    return _dbHelper.getVehicleImage(id);
  }

  @override
  Future<void> addVehicle(Vehicle vehicle) async {
    await _dbHelper.insertVehicle(vehicle);
  }

  @override
  Future<void> updateVehicle(Vehicle vehicle) async {
    await _dbHelper.updateVehicle(vehicle);
  }

  @override
  Future<void> deleteVehicle(int id) async {
    await _dbHelper.deleteVehicle(id);
  }
}
