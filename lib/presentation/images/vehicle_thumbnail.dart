import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:carvita/data/models/vehicle.dart';
import 'package:carvita/presentation/images/vehicle_image_cache.dart';

class VehicleThumbnail extends StatelessWidget {
  const VehicleThumbnail({
    super.key,
    required this.vehicle,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.iconSize = 32,
  });

  final Vehicle vehicle;
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final directImage = vehicle.imageLoaded ? vehicle.image : null;
    if (directImage != null && directImage.isNotEmpty) {
      return _image(context, directImage);
    }
    final vehicleId = vehicle.id;
    if (vehicle.imageLoaded || vehicleId == null) {
      return _placeholder(context);
    }

    return FutureBuilder<Uint8List?>(
      future: context.read<VehicleImageCache>().load(vehicleId),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return _placeholder(context);
        }
        return _image(context, bytes);
      },
    );
  }

  Widget _image(BuildContext context, Uint8List bytes) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.memory(
        bytes,
        width: width,
        height: height,
        fit: BoxFit.cover,
        cacheWidth: (width * devicePixelRatio).round(),
        cacheHeight: (height * devicePixelRatio).round(),
        errorBuilder: (_, _, _) => _placeholder(context),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: borderRadius,
      ),
      child: Icon(
        Icons.directions_car,
        size: iconSize,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
