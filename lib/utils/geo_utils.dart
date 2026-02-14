import 'dart:math';

import 'zip_locations.dart';
import '../services/zip_lookup_service.dart';

const double _earthRadiusMiles = 3958.8;

Map<String, double>? _latLngForZip(String zip) {
  final key = zip.trim();
  if (key.isEmpty) return null;
  // Try runtime cache first (includes geocoded results), then hardcoded map
  final loc = ZipLookupService.instance.lookupCached(key) ?? zipLocations[key];
  if (loc == null) return null;
  final lat = loc['lat'];
  final lng = loc['lng'];
  if (lat == null || lng == null) return null;
  return {'lat': lat, 'lng': lng};
}

String? extractZip(Map<String, dynamic> data) {
  final candidates = [
    data['zip'],
    data['zipcode'],
    data['jobZip'],
    data['serviceZip'],
    data['postalCode'],
  ];

  for (final c in candidates) {
    final v = (c ?? '').toString().trim();
    if (v.isNotEmpty) return v;
  }
  return null;
}

String? extractZipFromString(String? raw) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) return null;
  final match = RegExp(r'(\d{5})').firstMatch(text);
  return match?.group(1);
}

double? distanceMilesBetweenZips(String zipA, String zipB) {
  final a = _latLngForZip(zipA);
  final b = _latLngForZip(zipB);
  if (a == null || b == null) return null;

  final lat1 = _degToRad(a['lat']!);
  final lon1 = _degToRad(a['lng']!);
  final lat2 = _degToRad(b['lat']!);
  final lon2 = _degToRad(b['lng']!);

  final dLat = lat2 - lat1;
  final dLon = lon2 - lon1;

  final sinDLat = sin(dLat / 2);
  final sinDLon = sin(dLon / 2);

  final aVal = sinDLat * sinDLat + cos(lat1) * cos(lat2) * sinDLon * sinDLon;
  final cVal = 2 * atan2(sqrt(aVal), sqrt(1 - aVal));

  return _earthRadiusMiles * cVal;
}

String formatDistance(double miles) {
  if (miles < 1) return '< 1 mi';
  return '${miles.toStringAsFixed(1)} mi';
}

double _degToRad(double deg) => deg * (pi / 180.0);
