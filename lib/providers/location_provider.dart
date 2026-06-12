import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/location_service.dart';

part 'location_provider.g.dart';

@riverpod
Future<LatLng?> currentLocation(Ref ref) async {
  return LocationService.getCurrentLocation();
}

@riverpod
Stream<LatLng> locationStream(Ref ref) {
  return LocationService.positionStream();
}
