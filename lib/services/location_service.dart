import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  static Future<LatLng?> getCurrentLocation() async {
    try {
      // isLocationServiceEnabled is unreliable on web — skip it there.
      if (!kIsWeb) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      // timeLimit inside LocationSettings is NOT supported on web.
      // Use .timeout() on the Future instead.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: kIsWeb ? LocationAccuracy.low : LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 15));

      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('LocationService: $e');
      return null;
    }
  }

  static Stream<LatLng> positionStream() {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: kIsWeb ? LocationAccuracy.low : LocationAccuracy.medium,
        distanceFilter: 20,
      ),
    ).map((p) => LatLng(p.latitude, p.longitude)).handleError((dynamic e) {
      debugPrint('LocationService stream: $e');
    });
  }

  static double distanceBetween(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(
      a.latitude, a.longitude,
      b.latitude, b.longitude,
    );
  }
}
