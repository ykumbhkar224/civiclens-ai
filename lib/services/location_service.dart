import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class GeocodedAddress {
  final String displayAddress;
  final String city;
  final String ward;
  final String pincode;
  final String state;
  final String district;

  const GeocodedAddress({
    required this.displayAddress,
    required this.city,
    required this.ward,
    this.pincode = '',
    this.state = '',
    this.district = '',
  });
}

class LocationService {
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'User-Agent': 'CivicLensApp/1.0 (civic-accountability)'},
  ));

  // ── Get device GPS position ───────────────────────────────────────────────
  static Future<LatLng?> getCurrentLocation() async {
    try {
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

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: kIsWeb ? LocationAccuracy.low : LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 15));

      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('LocationService.getCurrentLocation: $e');
      return null;
    }
  }

  // ── Reverse geocode lat/lng → human-readable address ─────────────────────
  // Uses OpenStreetMap Nominatim API (free, no API key required).
  static Future<GeocodedAddress?> reverseGeocode(double lat, double lng) async {
    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': lat.toString(),
          'lon': lng.toString(),
          'format': 'json',
          'addressdetails': '1',
          'zoom': '16',
        },
      );

      final data = response.data as Map<String, dynamic>;
      final addr = (data['address'] as Map<String, dynamic>?) ?? {};

      // Extract city (multiple fallbacks for Indian cities)
      final rawCity = (addr['city'] ??
              addr['town'] ??
              addr['municipality'] ??
              addr['county'] ??
              addr['state_district'] ??
              addr['village'] ??
              '')
          .toString()
          .trim();
      // Strip Indian admin suffixes that Nominatim adds (e.g. "Mulshi Subdistrict" → "Mulshi")
      final city = rawCity
          .replaceAll(RegExp(r'\s+Subdistrict$', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+District$', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+Taluka$', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+Block$', caseSensitive: false), '')
          .trim();

      // Extract ward/area (neighbourhood, suburb, etc.)
      final ward = (addr['suburb'] ??
              addr['neighbourhood'] ??
              addr['quarter'] ??
              addr['residential'] ??
              addr['village'] ??
              '')
          .toString()
          .trim();

      // Build concise display address: Road, Area, City
      final parts = <String>[
        if (addr['road'] != null) addr['road'].toString(),
        if (ward.isNotEmpty) ward,
        if (city.isNotEmpty) city,
      ];
      final displayAddress = parts.isNotEmpty
          ? parts.join(', ')
          : (data['display_name'] as String? ?? '').split(',').take(3).join(',');

      final pincode = (addr['postcode'] ?? '').toString().trim();
      final state = (addr['state'] ?? '').toString().trim();
      final district = (addr['county'] ??
              addr['state_district'] ??
              addr['district'] ??
              '')
          .toString()
          .trim();

      return GeocodedAddress(
        displayAddress: displayAddress,
        city: city.isNotEmpty ? city : 'Unknown',
        ward: ward,
        pincode: pincode,
        state: state,
        district: district,
      );
    } catch (e) {
      debugPrint('LocationService.reverseGeocode: $e');
      return null;
    }
  }

  // ── Combine: get GPS + auto-geocode ──────────────────────────────────────
  static Future<({LatLng location, GeocodedAddress? address})?> getLocationWithAddress() async {
    final loc = await getCurrentLocation();
    if (loc == null) return null;
    final address = await reverseGeocode(loc.latitude, loc.longitude);
    return (location: loc, address: address);
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
        a.latitude, a.longitude, b.latitude, b.longitude);
  }
}
