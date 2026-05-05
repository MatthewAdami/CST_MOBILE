import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/route_models.dart';
import '../config/api_config.dart';

class MapService {
  static const _headers = {
    'Accept-Language': 'en',
    'User-Agent':      'CSTMaps/1.0 (cstmaps@email.com)',
    'Accept':          'application/json',
  };

  // ── In-memory cache ───────────────────────────────────────────
  static final Map<String, String>            _reverseCache = {};
  static final Map<String, List<PlaceResult>> _searchCache  = {};

  // ── Search places (Photon — no rate limit) ────────────────────
  static Future<List<PlaceResult>> searchPlaces(String query) async {
    if (query.trim().length < 2) return [];

    if (_searchCache.containsKey(query)) {
      debugPrint('🔍 searchPlaces cache hit: $query');
      return _searchCache[query]!;
    }

    final uri = Uri.parse(ApiConfig.photonSearch).replace(queryParameters: {
      'q':     query,
      'limit': '6',
      'lang':  'en',
    });

    try {
      debugPrint('🔍 searchPlaces: $uri');
      final res = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
      debugPrint('🔍 searchPlaces status: ${res.statusCode}');
      if (res.statusCode != 200) return [];

      final data     = jsonDecode(res.body) as Map<String, dynamic>;
      final features = data['features'] as List? ?? [];

      final results = features.map((f) {
        final props  = f['properties'] as Map<String, dynamic>;
        final geo    = f['geometry']   as Map<String, dynamic>;
        final coords = geo['coordinates'] as List;

        final name    = props['name']    as String? ?? '';
        final city    = props['city']    as String? ?? '';
        final street  = props['street']  as String? ?? '';
        final country = props['country'] as String? ?? '';
        final state   = props['state']   as String? ?? '';

        final short = [
          if (name.isNotEmpty)                    name,
          if (street.isNotEmpty && name.isEmpty)  street,
          if (city.isNotEmpty)                    city,
        ].take(2).join(', ');

        final display = [
          if (name.isNotEmpty)    name,
          if (street.isNotEmpty)  street,
          if (city.isNotEmpty)    city,
          if (state.isNotEmpty)   state,
          if (country.isNotEmpty) country,
        ].join(', ');

        return PlaceResult(
          displayName: display,
          shortName:   short.isNotEmpty ? short : display,
          lat: (coords[1] as num).toDouble(),
          lon: (coords[0] as num).toDouble(),
        );
      }).toList();

      _searchCache[query] = results;
      return results;
    } catch (e) {
      debugPrint('🔍 searchPlaces error: $e');
      return [];
    }
  }

  // ── Reverse geocode (Photon + cache) ──────────────────────────
  static Future<String> reverseGeocode(double lat, double lon) async {
    final key = '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';

    if (_reverseCache.containsKey(key)) {
      debugPrint('📍 reverseGeocode cache hit: $key');
      return _reverseCache[key]!;
    }

    final uri = Uri.parse(ApiConfig.photonReverse).replace(queryParameters: {
      'lat':  lat.toString(),
      'lon':  lon.toString(),
      'lang': 'en',
    });

    try {
      debugPrint('📍 reverseGeocode: $uri');
      final res = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
      debugPrint('📍 reverseGeocode status: ${res.statusCode}');

      if (res.statusCode != 200) {
        return '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}';
      }

      final data     = jsonDecode(res.body) as Map<String, dynamic>;
      final features = data['features'] as List? ?? [];

      if (features.isEmpty) {
        return '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}';
      }

      final props  = features.first['properties'] as Map<String, dynamic>;
      final name   = props['name']   as String? ?? '';
      final street = props['street'] as String? ?? '';
      final city   = props['city']   as String? ?? '';

      final result = [
        if (name.isNotEmpty)                        name,
        if (street.isNotEmpty && name != street)    street,
        if (city.isNotEmpty)                        city,
      ].take(3).join(', ');

      final finalResult = result.isNotEmpty
          ? result
          : '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}';

      _reverseCache[key] = finalResult;
      return finalResult;
    } catch (e) {
      debugPrint('📍 reverseGeocode error: $e');
      return '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}';
    }
  }

  // ── Snap coordinate to nearest drivable road ──────────────────
  // Returns snapped [lon, lat] or null if no road within 500 m.
  static Future<List<double>?> _snapToRoad(double lon, double lat) async {
    final url = '${ApiConfig.osrmNearest}/$lon,$lat?number=1';
    try {
      final res = await http.get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;

      final data      = jsonDecode(res.body) as Map<String, dynamic>;
      final waypoints = data['waypoints'] as List<dynamic>?;
      if (waypoints == null || waypoints.isEmpty) return null;

      final wp       = waypoints.first as Map<String, dynamic>;
      final distance = (wp['distance'] as num).toDouble();

      if (distance > 500) {
        debugPrint('⚠️ snapToRoad: nearest road ${distance.round()} m away — too far');
        return null;
      }

      final loc = wp['location'] as List<dynamic>;
      return [(loc[0] as num).toDouble(), (loc[1] as num).toDouble()];
    } catch (e) {
      debugPrint('⚠️ snapToRoad error: $e');
      return null;
    }
  }

  // ── OSRM routing (with road snapping) ────────────────────────
  static Future<RouteInfo?> getRoute({
    required double fromLon, required double fromLat,
    required double toLon,   required double toLat,
  }) async {

    // Step 1 — snap both points to nearest drivable road
    final snappedFrom = await _snapToRoad(fromLon, fromLat);
    final snappedTo   = await _snapToRoad(toLon,   toLat);

    if (snappedFrom == null) {
      debugPrint('🗺️ getRoute: FROM is not near any road');
      return null;
    }
    if (snappedTo == null) {
      debugPrint('🗺️ getRoute: TO is not near any road');
      return null;
    }

    debugPrint('🗺️ FROM ($fromLon,$fromLat) → snapped (${snappedFrom[0]},${snappedFrom[1]})');
    debugPrint('🗺️ TO   ($toLon,$toLat) → snapped (${snappedTo[0]},${snappedTo[1]})');

    // Step 2 — route using snapped coordinates
    final url =
        '${ApiConfig.osrmBase}/${snappedFrom[0]},${snappedFrom[1]};'
        '${snappedTo[0]},${snappedTo[1]}'
        '?overview=full&geometries=geojson&steps=true';

    try {
      final res = await http.get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        debugPrint('🗺️ getRoute error: ${res.statusCode} ${res.body}');
        return null;
      }

      final data   = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes[0] as Map<String, dynamic>;
      final geo   = route['geometry'] as Map<String, dynamic>;
      final coords = (geo['coordinates'] as List)
          .map((c) => [(c as List)[0] as double, c[1] as double])
          .toList();

      final legs     = route['legs'] as List?;
      final rawSteps = (legs?.isNotEmpty == true
          ? (legs![0] as Map<String, dynamic>)['steps'] as List? ?? []
          : []) as List;
      final steps = rawSteps
          .map((s) => RouteStep.fromJson(s as Map<String, dynamic>))
          .toList();

      return RouteInfo(
        distanceKm:  (route['distance'] as num) / 1000,
        durationMin: ((route['duration'] as num) / 60).round(),
        steps:       steps,
        coordinates: coords,
      );
    } catch (e) {
      debugPrint('🗺️ getRoute exception: $e');
      return null;
    }
  }

  // ── Save history ──────────────────────────────────────────────
  static Future<bool> saveHistory({
    required String token,
    required String fromName,
    required double fromLon, required double fromLat,
    required String toName,
    required double toLon,   required double toLat,
    required double distanceKm,
    required int    durationMin,
  }) async {
    final url  = '${ApiConfig.baseUrl}/api/route-history';
    final body = jsonEncode({
      'from': {'name': fromName, 'coords': {'lng': fromLon, 'lat': fromLat}},
      'to':   {'name': toName,   'coords': {'lng': toLon,   'lat': toLat}},
      'distanceKm':  distanceKm,
      'durationMin': durationMin,
    });

    debugPrint('💾 saveHistory → POST $url');
    debugPrint('💾 saveHistory body: $body');

    try {
      final res = await http.post(
        Uri.parse(url),
        headers: ApiConfig.authHeaders(token),
        body:    body,
      ).timeout(const Duration(seconds: 8));

      debugPrint('💾 saveHistory ← ${res.statusCode}: ${res.body}');
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('💾 saveHistory exception: $e');
      return false;
    }
  }

  // ── Fetch history ─────────────────────────────────────────────
  static Future<List<RouteHistoryEntry>> fetchHistory(String token) async {
    final url = '${ApiConfig.baseUrl}/api/route-history';
    debugPrint('📋 fetchHistory → GET $url');
    try {
      final res = await http.get(
        Uri.parse(url),
        headers: ApiConfig.authHeaders(token),
      ).timeout(const Duration(seconds: 8));

      debugPrint('📋 fetchHistory ← ${res.statusCode}: ${res.body}');
      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return ((data['routes'] as List?) ?? [])
          .map((j) => RouteHistoryEntry.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('📋 fetchHistory exception: $e');
      return [];
    }
  }

  // ── Delete one history entry ──────────────────────────────────
  static Future<bool> deleteHistory(String token, String id) async {
    final url = '${ApiConfig.baseUrl}/api/route-history/$id';
    debugPrint('🗑️ deleteHistory → DELETE $url');
    try {
      final res = await http.delete(
        Uri.parse(url),
        headers: ApiConfig.authHeaders(token),
      ).timeout(const Duration(seconds: 8));

      debugPrint('🗑️ deleteHistory ← ${res.statusCode}: ${res.body}');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('🗑️ deleteHistory exception: $e');
      return false;
    }
  }

  // ── Clear all history ─────────────────────────────────────────
  static Future<bool> clearHistory(String token) async {
    final url = '${ApiConfig.baseUrl}/api/route-history';
    debugPrint('🗑️ clearHistory → DELETE $url');
    try {
      final res = await http.delete(
        Uri.parse(url),
        headers: ApiConfig.authHeaders(token),
      ).timeout(const Duration(seconds: 8));

      debugPrint('🗑️ clearHistory ← ${res.statusCode}: ${res.body}');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('🗑️ clearHistory exception: $e');
      return false;
    }
  }
}