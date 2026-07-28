import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:provider/provider.dart';

import 'package:carvita/application/ports/preferences_ports.dart';
import 'package:carvita/application/ports/vehicle_repository_port.dart';
import 'package:carvita/application/use_cases/vehicle_use_cases.dart';
import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/presentation/images/vehicle_image_cache.dart';
import 'package:carvita/presentation/images/vehicle_thumbnail.dart';

void main() {
  test('cache reuses reads and evicts the least recently used image', () async {
    final repository = _ImageRepository();
    final cache = VehicleImageCache(
      VehicleUseCases(repository, _DefaultVehiclePreferences()),
      maximumEntries: 2,
    );

    await cache.load(1);
    await cache.load(2);
    await cache.load(1);
    await cache.load(3);
    await cache.load(2);

    expect(repository.reads, {1: 1, 2: 2, 3: 1});
    expect(cache.cachedEntryCount, 2);
    expect(cache.cachedByteCount, 2);
  });

  test('invalidate forces the next image read', () async {
    final repository = _ImageRepository();
    final cache = VehicleImageCache(
      VehicleUseCases(repository, _DefaultVehiclePreferences()),
    );

    await cache.load(7);
    cache.invalidate(7);
    await cache.load(7);

    expect(repository.reads[7], 2);
  });

  test(
    'cache evicts least recently used bytes above its memory budget',
    () async {
      final repository = _ImageRepository(
        bytesById: {
          1: Uint8List.fromList([1, 1]),
          2: Uint8List.fromList([2, 2]),
        },
      );
      final cache = VehicleImageCache(
        VehicleUseCases(repository, _DefaultVehiclePreferences()),
        maximumBytes: 2,
      );

      await cache.load(1);
      await cache.load(2);

      expect(cache.cachedEntryCount, 1);
      expect(cache.cachedByteCount, 2);
      await cache.load(1);
      expect(repository.reads[1], 2);
    },
  );

  testWidgets('thumbnail requests a display-size decode', (tester) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: VehicleThumbnail(
          vehicle: Vehicle(
            id: 1,
            name: 'Vehicle',
            mileage: 100,
            mileageLastUpdated: DateTime(2026, 1, 1),
            boughtDate: DateTime(2025, 1, 1),
            image: Uint8List.fromList([1, 2, 3]),
          ),
          width: 70,
          height: 50,
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final resized = image.image as ResizeImage;
    expect(resized.width, 140);
    expect(resized.height, 100);
  });

  testWidgets('large lists load visible images into a bounded cache', (
    tester,
  ) async {
    final repository = _ImageRepository();
    final cache = VehicleImageCache(
      VehicleUseCases(repository, _DefaultVehiclePreferences()),
      maximumEntries: 8,
    );

    await tester.pumpWidget(
      Provider<VehicleImageCache>.value(
        value: cache,
        child: MaterialApp(
          home: ListView.builder(
            itemExtent: 72,
            itemCount: 100,
            itemBuilder: (_, index) => VehicleThumbnail(
              vehicle: Vehicle(
                id: index + 1,
                name: 'Vehicle $index',
                mileage: 100,
                mileageLastUpdated: DateTime(2026, 1, 1),
                boughtDate: DateTime(2025, 1, 1),
                imageLoaded: false,
              ),
              width: 60,
              height: 60,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.reads.length, lessThan(100));
    await tester.fling(find.byType(ListView), const Offset(0, -2500), 3000);
    await tester.pumpAndSettle();

    expect(cache.cachedEntryCount, lessThanOrEqualTo(8));
    expect(cache.cachedByteCount, lessThanOrEqualTo(8));
    expect(repository.reads.length, lessThan(100));
  });
}

final class _ImageRepository implements VehicleRepositoryPort {
  _ImageRepository({this.bytesById = const {}});

  final Map<int, Uint8List> bytesById;
  final Map<int, int> reads = {};

  @override
  Future<Uint8List?> getVehicleImage(int id) async {
    reads.update(id, (count) => count + 1, ifAbsent: () => 1);
    return bytesById[id] ?? Uint8List.fromList([id]);
  }

  @override
  Future<List<Vehicle>> getVehicles() async => const [];

  @override
  Future<Vehicle?> getVehicleById(int id) async => null;

  @override
  Future<void> addVehicle(Vehicle vehicle) async {}

  @override
  Future<void> updateVehicle(Vehicle vehicle) async {}

  @override
  Future<void> deleteVehicle(int id) async {}
}

final class _DefaultVehiclePreferences implements DefaultVehiclePreferences {
  @override
  Future<int?> getDefaultVehicleId() async => null;

  @override
  Future<void> setDefaultVehicleId(int? vehicleId) async {}
}
