import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Lightweight wrapper around the Google Places Autocomplete (legacy) API.
///
/// Supply your API key via `--dart-define=GOOGLE_PLACES_API_KEY=<key>`.
class PlacesService {
  PlacesService._();
  static final PlacesService instance = PlacesService._();

  static const String _apiKey =
      String.fromEnvironment('GOOGLE_PLACES_API_KEY');

  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/place';

  /// Whether an API key is configured. If false, autocomplete won't work
  /// but the field degrades gracefully to a normal text input.
  static bool get isAvailable => _apiKey.isNotEmpty;

  // ─────────────────────── Autocomplete ──────────────────────────

  /// Returns a list of address suggestions for the given [input].
  ///
  /// Each item contains `placeId`, `description`, and `mainText` /
  /// `secondaryText` for display.
  Future<List<PlacePrediction>> autocomplete(String input) async {
    if (_apiKey.isEmpty || input.trim().length < 3) return [];

    final uri = Uri.parse('$_baseUrl/autocomplete/json').replace(
      queryParameters: {
        'input': input.trim(),
        'key': _apiKey,
        'types': 'address',
        'components': 'country:us',
      },
    );

    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) return [];

      final body = jsonDecode(resp.body);
      if (body['status'] != 'OK') return [];

      final predictions = body['predictions'] as List? ?? [];
      return predictions.map((p) => PlacePrediction.fromJson(p)).toList();
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────── Place Details ─────────────────────────

  /// Fetch structured address components for a [placeId].
  Future<PlaceDetails?> getDetails(String placeId) async {
    if (_apiKey.isEmpty || placeId.isEmpty) return null;

    final uri = Uri.parse('$_baseUrl/details/json').replace(
      queryParameters: {
        'place_id': placeId,
        'key': _apiKey,
        'fields': 'formatted_address,address_components,geometry',
      },
    );

    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) return null;

      final body = jsonDecode(resp.body);
      if (body['status'] != 'OK') return null;

      return PlaceDetails.fromJson(body['result']);
    } catch (_) {
      return null;
    }
  }
}

// ──────────────────────────── Models ──────────────────────────────

class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  const PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    final structured = json['structured_formatting'] ?? {};
    return PlacePrediction(
      placeId: (json['place_id'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      mainText: (structured['main_text'] ?? '').toString(),
      secondaryText: (structured['secondary_text'] ?? '').toString(),
    );
  }
}

class PlaceDetails {
  final String formattedAddress;
  final String streetNumber;
  final String route;
  final String city;
  final String state;
  final String zip;
  final double? lat;
  final double? lng;

  const PlaceDetails({
    required this.formattedAddress,
    required this.streetNumber,
    required this.route,
    required this.city,
    required this.state,
    required this.zip,
    this.lat,
    this.lng,
  });

  /// e.g. "3817 Parker Road"
  String get streetAddress {
    final parts = <String>[];
    if (streetNumber.isNotEmpty) parts.add(streetNumber);
    if (route.isNotEmpty) parts.add(route);
    return parts.join(' ');
  }

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final components = json['address_components'] as List? ?? [];
    String streetNumber = '';
    String route = '';
    String city = '';
    String state = '';
    String zip = '';

    for (final c in components) {
      final types = (c['types'] as List? ?? []).cast<String>();
      final value = (c['long_name'] ?? '').toString();
      final short = (c['short_name'] ?? '').toString();

      if (types.contains('street_number')) streetNumber = value;
      if (types.contains('route')) route = value;
      if (types.contains('locality')) city = value;
      if (types.contains('administrative_area_level_1')) state = short;
      if (types.contains('postal_code')) zip = value;
    }

    final geo = json['geometry']?['location'];

    return PlaceDetails(
      formattedAddress: (json['formatted_address'] ?? '').toString(),
      streetNumber: streetNumber,
      route: route,
      city: city,
      state: state,
      zip: zip,
      lat: geo?['lat'] is num ? (geo['lat'] as num).toDouble() : null,
      lng: geo?['lng'] is num ? (geo['lng'] as num).toDouble() : null,
    );
  }
}
