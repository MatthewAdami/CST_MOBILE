// lib/models/route_models.dart

class PlaceResult {
  final String displayName;
  final String shortName;
  final double lat;
  final double lon;

  const PlaceResult({
    required this.displayName,
    required this.shortName,
    required this.lat,
    required this.lon,
  });

  factory PlaceResult.fromJson(Map<String, dynamic> j) {
    final full  = j['display_name'] as String? ?? '';
    final parts = full.split(',');
    final short = parts.take(2).join(',').trim();
    return PlaceResult(
      displayName: full,
      shortName:   short,
      lat: double.tryParse(j['lat']?.toString() ?? '') ?? 0,
      lon: double.tryParse(j['lon']?.toString() ?? '') ?? 0,
    );
  }
}

// ── OSRM step ────────────────────────────────────────────────────
class RouteStep {
  final String       name;
  final double       distance;     // metres
  final double       duration;     // seconds
  final String       maneuverType; // e.g. 'turn-left', 'straight', 'arrive'
  final List<double> location;     // [lng, lat]

  const RouteStep({
    required this.name,
    required this.distance,
    required this.duration,
    required this.maneuverType,
    required this.location,
  });

  factory RouteStep.fromJson(Map<String, dynamic> j) {
    final m        = j['maneuver'] as Map<String, dynamic>? ?? {};
    final type     = m['type']     as String? ?? '';
    final modifier = m['modifier'] as String? ?? '';
    final loc      = (m['location'] as List?)?.cast<num>() ?? [0, 0];
    return RouteStep(
      name:         j['name'] as String? ?? '',
      distance:     (j['distance'] as num?)?.toDouble() ?? 0,
      duration:     (j['duration'] as num?)?.toDouble() ?? 0,
      maneuverType: _parseManeuver(type, modifier),
      location:     [loc[0].toDouble(), loc[1].toDouble()],
    );
  }

  static String _parseManeuver(String type, String modifier) {
    if (type == 'arrive') return 'arrive';
    if (type == 'depart') return 'straight';
    switch (modifier) {
      case 'left':         return 'turn-left';
      case 'right':        return 'turn-right';
      case 'slight left':  return 'turn-slight-left';
      case 'slight right': return 'turn-slight-right';
      case 'uturn':        return 'uturn';
      default:             return 'straight';
    }
  }

  /// Human-readable instruction for TTS / display.
  /// e.g.  "Turn left onto Katipunan Avenue"
  ///        "Continue straight"
  ///        "You have arrived at your destination"
  String get instruction {
    final street = name.isNotEmpty ? ' onto $name' : '';
    switch (maneuverType) {
      case 'turn-left':         return 'Turn left$street';
      case 'turn-right':        return 'Turn right$street';
      case 'turn-slight-left':  return 'Keep left$street';
      case 'turn-slight-right': return 'Keep right$street';
      case 'uturn':             return 'Make a U-turn$street';
      case 'arrive':            return 'You have arrived at your destination';
      case 'straight':
      default:
        return name.isNotEmpty ? 'Continue onto $name' : 'Continue straight';
    }
  }
}

// ── Full route ───────────────────────────────────────────────────
class RouteInfo {
  final double             distanceKm;
  final int                durationMin;
  final List<RouteStep>    steps;
  final List<List<double>> coordinates; // [[lng, lat], ...]

  const RouteInfo({
    required this.distanceKm,
    required this.durationMin,
    required this.steps,
    required this.coordinates,
  });
}

// ── History entry ────────────────────────────────────────────────
class RouteHistoryEntry {
  final String   id;
  final String   fromName;
  final double   fromLat;
  final double   fromLon;
  final String   toName;
  final double   toLat;
  final double   toLon;
  final double   distanceKm;
  final int      durationMin;
  final DateTime createdAt;

  const RouteHistoryEntry({
    required this.id,
    required this.fromName,
    required this.fromLat,
    required this.fromLon,
    required this.toName,
    required this.toLat,
    required this.toLon,
    required this.distanceKm,
    required this.durationMin,
    required this.createdAt,
  });

  factory RouteHistoryEntry.fromJson(Map<String, dynamic> j) {
    final from       = j['from']   as Map<String, dynamic>? ?? {};
    final to         = j['to']     as Map<String, dynamic>? ?? {};
    final fromCoords = from['coords'] as Map<String, dynamic>? ?? {};
    final toCoords   = to['coords']   as Map<String, dynamic>? ?? {};

    return RouteHistoryEntry(
      id:          j['_id']      as String?  ?? '',
      fromName:    from['name']  as String?  ?? '',
      fromLat:     (fromCoords['lat'] as num?)?.toDouble() ?? 0,
      fromLon:     (fromCoords['lng'] as num?)?.toDouble() ?? 0,
      toName:      to['name']    as String?  ?? '',
      toLat:       (toCoords['lat'] as num?)?.toDouble() ?? 0,
      toLon:       (toCoords['lng'] as num?)?.toDouble() ?? 0,
      distanceKm:  (j['distanceKm']  as num?)?.toDouble() ?? 0,
      durationMin: (j['durationMin'] as num?)?.toInt()    ?? 0,
      createdAt:   DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    '_id':  id,
    'from': {
      'name':   fromName,
      'coords': {'lat': fromLat, 'lng': fromLon},
    },
    'to': {
      'name':   toName,
      'coords': {'lat': toLat, 'lng': toLon},
    },
    'distanceKm':  distanceKm,
    'durationMin': durationMin,
    'createdAt':   createdAt.toIso8601String(),
  };
}