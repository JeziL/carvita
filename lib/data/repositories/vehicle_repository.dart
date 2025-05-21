import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/data/sources/local/database_helper.dart';

class VehicleRepository {
  final DatabaseHelper _dbHelper;

  VehicleRepository({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper();

  Future<List<Vehicle>> getVehicles() async {
    return await _dbHelper.getAllVehicles();
  }

  Future<Vehicle?> getVehicleById(int id) async {
    return await _dbHelper.getVehicleById(id);
  }

  Future<void> addVehicle(Vehicle vehicle) async {
    await _dbHelper.insertVehicle(vehicle);
  }

  Future<void> updateVehicle(Vehicle vehicle) async {
    await _dbHelper.updateVehicle(vehicle);
  }

  Future<void> deleteVehicle(int id) async {
    await _dbHelper.deleteVehicle(id);
  }
}
