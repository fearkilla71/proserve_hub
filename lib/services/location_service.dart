import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationResult {
  const LocationResult({required this.zip, required this.city, required this.state});

  final String zip;
  final String city;
  final String state;

  String formatCityState() {
    final parts = [city.trim(), state.trim()].where((p) => p.isNotEmpty).toList();
    return parts.join(', ');
  }
}

class LocationService {
  Future<LocationResult?> getCurrentZipAndCity() async {
    if (kIsWeb) return null;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    const settings = LocationSettings(accuracy: LocationAccuracy.low);
    final position = await Geolocator.getCurrentPosition(
      locationSettings: settings,
    );

    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (placemarks.isEmpty) return null;

    final place = placemarks.first;
    final zip = (place.postalCode ?? '').trim();
    final city = (place.locality ?? place.subLocality ?? '').trim();
    final state = (place.administrativeArea ?? '').trim();

    if (zip.isEmpty && city.isEmpty && state.isEmpty) return null;

    return LocationResult(zip: zip, city: city, state: state);
  }
}
