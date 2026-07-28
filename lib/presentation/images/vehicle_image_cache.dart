import 'dart:collection';
import 'dart:typed_data';

import 'package:carvita/application/use_cases/vehicle_use_cases.dart';

/// Bounded LRU cache for vehicle image bytes loaded separately from list
/// summaries.
final class VehicleImageCache {
  VehicleImageCache(
    this._vehicleUseCases, {
    this.maximumEntries = 24,
    this.maximumBytes = 16 * 1024 * 1024,
  }) : assert(maximumEntries > 0),
       assert(maximumBytes > 0);

  final VehicleUseCases _vehicleUseCases;
  final int maximumEntries;
  final int maximumBytes;
  final LinkedHashMap<int, Future<Uint8List?>> _entries =
      LinkedHashMap<int, Future<Uint8List?>>();
  final Map<int, int> _entryByteLengths = {};
  int _cachedByteCount = 0;

  int get cachedEntryCount => _entries.length;
  int get cachedByteCount => _cachedByteCount;

  Future<Uint8List?> load(int vehicleId) {
    final cached = _entries.remove(vehicleId);
    if (cached != null) {
      _entries[vehicleId] = cached;
      return cached;
    }

    final pending = _vehicleUseCases.getVehicleImage(vehicleId);
    _entries[vehicleId] = pending;
    _entryByteLengths[vehicleId] = 0;
    pending.then(
      (bytes) {
        if (!identical(_entries[vehicleId], pending)) return;
        final previousLength = _entryByteLengths[vehicleId] ?? 0;
        final nextLength = bytes?.length ?? 0;
        _entryByteLengths[vehicleId] = nextLength;
        _cachedByteCount += nextLength - previousLength;
        _evictOverflow();
      },
      onError: (Object _, StackTrace _) {
        if (identical(_entries[vehicleId], pending)) {
          _remove(vehicleId);
        }
      },
    );
    _evictOverflow();
    return pending;
  }

  void invalidate(int vehicleId) {
    _remove(vehicleId);
  }

  void clear() {
    _entries.clear();
    _entryByteLengths.clear();
    _cachedByteCount = 0;
  }

  void _remove(int vehicleId) {
    _entries.remove(vehicleId);
    _cachedByteCount -= _entryByteLengths.remove(vehicleId) ?? 0;
  }

  void _evictOverflow() {
    while (_entries.isNotEmpty &&
        (_entries.length > maximumEntries || _cachedByteCount > maximumBytes)) {
      _remove(_entries.keys.first);
    }
  }
}
