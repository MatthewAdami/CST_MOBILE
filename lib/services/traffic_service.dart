// lib/services/traffic_service.dart
//
// TomTom Traffic API integration
// Free tier: 2,500 non-tile requests/day — no credit card required
// Sign up at: https://developer.tomtom.com
//
// Provides:
//   • Traffic flow tile URL  → plug directly into MapLibre as a raster layer
//   • Traffic incidents       → list of accidents/closures near a location
//   • Flow segment data       → jam factor (0–10) for a specific coordinate

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// IMPORTANT: Replace with your key from https://developer.tomtom.com
// Keep this in a .env file or use flutter_dotenv in production — never commit
// a real key to source control.
// ─────────────────────────────────────────────────────────────────────────────
const String _kTomTomKey = '83SaKCaOjYlAcOAtQ8tuc8Am7qgZ7vGd';

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

enum TrafficSeverity { unknown, minor, moderate, major, closed }

class TrafficIncident {
  final String id;
  final String description;
  final TrafficSeverity severity;
  final LatLng location;
  final String? fromRoad;
  final String? toRoad;
  final String? delay; // e.g. "5 min delay"

  const TrafficIncident({
    required this.id,
    required this.description,
    required this.severity,
    required this.location,
    this.fromRoad,
    this.toRoad,
    this.delay,
  });

  /// Colour to use for the incident marker on the map
  String get markerColor {
    switch (severity) {
      case TrafficSeverity.minor:    return '#EF9F27'; // amber
      case TrafficSeverity.moderate: return '#E85D24'; // orange
      case TrafficSeverity.major:    return '#E24B4A'; // red
      case TrafficSeverity.closed:   return '#791F1F'; // dark red
      case TrafficSeverity.unknown:  return '#888780'; // gray
    }
  }

  /// Icon character shown inside the marker
  String get icon {
    switch (severity) {
      case TrafficSeverity.closed:   return '🚫';
      case TrafficSeverity.major:    return '🔴';
      case TrafficSeverity.moderate: return '🟠';
      case TrafficSeverity.minor:    return '🟡';
      case TrafficSeverity.unknown:  return '⚠️';
    }
  }
}

/// Flow data for a single coordinate point
class TrafficFlowData {
  /// Current speed in km/h
  final double currentSpeedKmh;

  /// Free-flow (no-traffic) speed in km/h
  final double freeFlowSpeedKmh;

  /// 0.0–1.0 — how congested this segment is (1.0 = fully jammed)
  final double congestionRatio;

  /// TomTom jam factor 0–10
  final double jamFactor;

  const TrafficFlowData({
    required this.currentSpeedKmh,
    required this.freeFlowSpeedKmh,
    required this.congestionRatio,
    required this.jamFactor,
  });

  TrafficLevel get level {
    if (jamFactor >= 8)   return TrafficLevel.heavy;
    if (jamFactor >= 5)   return TrafficLevel.moderate;
    if (jamFactor >= 2)   return TrafficLevel.light;
    return TrafficLevel.free;
  }
}

enum TrafficLevel { free, light, moderate, heavy }

extension TrafficLevelX on TrafficLevel {
  String get label {
    switch (this) {
      case TrafficLevel.free:     return 'Free flow';
      case TrafficLevel.light:    return 'Light traffic';
      case TrafficLevel.moderate: return 'Moderate traffic';
      case TrafficLevel.heavy:    return 'Heavy traffic';
    }
  }

  String get color {
    switch (this) {
      case TrafficLevel.free:     return '#4ADE80'; // green
      case TrafficLevel.light:    return '#63991A'; // dark green
      case TrafficLevel.moderate: return '#EF9F27'; // amber
      case TrafficLevel.heavy:    return '#E24B4A'; // red
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TrafficService
// ─────────────────────────────────────────────────────────────────────────────

class TrafficService {
  TrafficService._();

  // ── Tile URL helpers ───────────────────────────────────────────────────────

  /// Raster tile URL template for MapLibre's addSource().
  ///
  /// [style] options:
  ///   'relative0'        — coloured tubes relative to free-flow (recommended)
  ///   'relative0-dark'   — dark map variant
  ///   'absolute'         — absolute speed colours
  ///   'reduced-sensitivity' — less sensitive to small changes
  static String flowTileUrl({String style = 'relative0'}) {
    return 'https://api.tomtom.com/traffic/map/4/tile/flow/$style/{z}/{x}/{y}.png'
        '?key=$_kTomTomKey&tileSize=256';
  }

  /// Raster tile URL template for incident overlay (shows accident icons).
  static String incidentTileUrl({String style = 's3'}) {
    return 'https://api.tomtom.com/traffic/map/4/tile/incidents/$style/{z}/{x}/{y}.png'
        '?key=$_kTomTomKey&tileSize=256';
  }

  // ── REST: incidents near a bounding box ───────────────────────────────────

  /// Fetches traffic incidents within ~5 km of [center].
  /// Returns an empty list on error (never throws).
  static Future<List<TrafficIncident>> getIncidents(LatLng center) async {
    const double delta = 0.045; // ~5 km bounding box
    final bbox = '${center.longitude - delta},${center.latitude - delta},'
        '${center.longitude + delta},${center.latitude + delta}';

    final uri = Uri.parse(
      'https://api.tomtom.com/traffic/services/5/incidentDetails'
      '?key=$_kTomTomKey'
      '&bbox=$bbox'
      '&fields={incidents{type,geometry,properties{id,magnitudeOfDelay,'
      'events{description,code,iconCategory},startTime,endTime,'
      'from,to,length,delay,roadNumbers,timeValidity}}}'
      '&language=en-GB'
      '&categoryFilter=0,1,2,3,4,5,6,7,8,9,10,11,14'
      '&timeValidityFilter=present',
    );

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        debugPrint('TrafficService incidents HTTP ${res.statusCode}');
        return [];
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final incidents = data['incidents'] as List<dynamic>? ?? [];
      return incidents.map(_parseIncident).whereType<TrafficIncident>().toList();
    } catch (e) {
      debugPrint('TrafficService incidents error: $e');
      return [];
    }
  }

  static TrafficIncident? _parseIncident(dynamic raw) {
    try {
      final props      = raw['properties'] as Map<String, dynamic>;
      final geometry   = raw['geometry']   as Map<String, dynamic>;
      final coords     = (geometry['coordinates'] as List<dynamic>).first as List<dynamic>;
      final events     = props['events'] as List<dynamic>? ?? [];
      final desc       = events.isNotEmpty
          ? (events.first['description'] as String? ?? 'Traffic incident')
          : 'Traffic incident';
      final magnitude  = props['magnitudeOfDelay'] as int? ?? 0;
      final delayStr   = props['delay'] != null
          ? '${(props['delay'] as num).round()} sec delay'
          : null;

      return TrafficIncident(
        id:          props['id']?.toString() ?? UniqueKey().toString(),
        description: desc,
        severity:    _magnitudeToSeverity(magnitude),
        location:    LatLng((coords[1] as num).toDouble(), (coords[0] as num).toDouble()),
        fromRoad:    props['from'] as String?,
        toRoad:      props['to']   as String?,
        delay:       delayStr,
      );
    } catch (e) {
      debugPrint('TrafficService _parseIncident error: $e');
      return null;
    }
  }

  static TrafficSeverity _magnitudeToSeverity(int magnitude) {
    // TomTom magnitudeOfDelay: 0=unknown, 1=minor, 2=moderate, 3=major, 4=closed
    switch (magnitude) {
      case 1:  return TrafficSeverity.minor;
      case 2:  return TrafficSeverity.moderate;
      case 3:  return TrafficSeverity.major;
      case 4:  return TrafficSeverity.closed;
      default: return TrafficSeverity.unknown;
    }
  }

  // ── REST: flow data at a single coordinate ─────────────────────────────────

  /// Returns real-time flow data (speed, jam factor) at the given coordinate.
  /// Returns null on error.
  static Future<TrafficFlowData?> getFlowAtPoint(LatLng point) async {
    final uri = Uri.parse(
      'https://api.tomtom.com/traffic/services/4/flowSegmentData/relative0/10/json'
      '?key=$_kTomTomKey'
      '&point=${point.latitude},${point.longitude}'
      '&unit=KMPH',
    );

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        debugPrint('TrafficService flow HTTP ${res.statusCode}');
        return null;
      }
      final data     = jsonDecode(res.body) as Map<String, dynamic>;
      final flowData = data['flowSegmentData'] as Map<String, dynamic>;

      final currentSpeed  = (flowData['currentSpeed']  as num).toDouble();
      final freeFlowSpeed = (flowData['freeFlowSpeed']  as num).toDouble();
      final jamFactor     = (flowData['currentTravelTime'] as num).toDouble() /
          (flowData['freeFlowTravelTime'] as num).toDouble();
      // Clamp to 0–10 TomTom jam scale
      final jamFactorScaled = ((jamFactor - 1.0) * 3.33).clamp(0.0, 10.0);
      final congestion = freeFlowSpeed > 0
          ? (1.0 - currentSpeed / freeFlowSpeed).clamp(0.0, 1.0)
          : 0.0;

      return TrafficFlowData(
        currentSpeedKmh:  currentSpeed,
        freeFlowSpeedKmh: freeFlowSpeed,
        congestionRatio:  congestion,
        jamFactor:        jamFactorScaled,
      );
    } catch (e) {
      debugPrint('TrafficService flow error: $e');
      return null;
    }
  }

  // ── Convenience: check if a route passes through heavy traffic ────────────

  /// Samples flow data at every [sampleEvery]th coordinate along the route.
  /// Returns the worst [TrafficLevel] found, or null if no data available.
  /// Uses minimal requests — typically 3–5 samples for an average route.
  static Future<TrafficLevel?> checkRouteTraffic(
    List<List<double>> coordinates, {
    int sampleEvery = 10,
  }) async {
    if (coordinates.isEmpty) return null;

    // Pick evenly-spaced sample points to stay within free tier limits
    final indices = <int>[0];
    for (var i = sampleEvery; i < coordinates.length - 1; i += sampleEvery) {
      indices.add(i);
    }
    indices.add(coordinates.length - 1);

    TrafficLevel worst = TrafficLevel.free;

    for (final idx in indices) {
      final c  = coordinates[idx];
      final pt = LatLng(c[1], c[0]);
      final flow = await getFlowAtPoint(pt);
      if (flow == null) continue;
      if (flow.level.index > worst.index) {
        worst = flow.level;
      }
      // Early exit — no point checking further if already worst case
      if (worst == TrafficLevel.heavy) break;
    }

    return worst;
  }
}