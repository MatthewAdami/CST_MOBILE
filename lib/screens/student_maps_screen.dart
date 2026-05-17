// lib/screens/student_maps_screen.dart
//
// FIXED: Stopover bottom bar disappearing, resume from stopover routing,
//        and pause/resume state management.
// Changes vs previous version:
//   1. _buildRoute now accepts preserveRoute param — keeps old route visible
//      while stopover/resume route is loading so bottom bar never disappears.
//   2. _addStopover no longer calls _pauseDrive() (double-stop bug fixed);
//      sets _isPaused inline and passes preserveRoute: true to _buildRoute.
//   3. _resumeFromStopover always routes from current _userLatLng (not
//      _activeStopover coords), clears state BEFORE restarting watch, and
//      passes preserveRoute: true so the bottom bar stays visible.
//   4. Drive mode build guard changed to (_route != null || _routeLoading)
//      so the UI shell stays rendered during route recalculation.
//   5. _DriveBottomBar is wrapped in an extra null-check on _route so it
//      only renders when data is available (no crash during loading).
//   All other functionality preserved exactly.
//
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:ui' as ui;

import '../theme.dart';
import '../models/route_models.dart';
import '../services/map_service.dart';
import '../services/traffic_service.dart';
import '../widgets/search_panel.dart';
import '../widgets/route_card.dart';
import '../widgets/drive_mode_ui.dart';
import '../widgets/history_sidebar.dart';
import '../widgets/traffic_badge.dart';
import '../services/voice_guide_service.dart';
import '../config/api_config.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// LOCATION BROADCAST SERVICE (unchanged)
// ═══════════════════════════════════════════════════════════════════════════════
class _LocationBroadcaster {
  IO.Socket? _socket;
  DateTime?  _lastEmit;
  String?    _token;
  Map<String, dynamic> _profile = {};

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _profile = _decodeJwt(_token);
    _socket = IO.io(
      ApiConfig.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .build(),
    );
    _socket!.connect();
  }

  Future<void> broadcast({
    required double lng,
    required double lat,
    required double heading,
    required double speed,
    required String status,
    String?  origin,
    String?  destination,
    double?  distanceKm,
    int?     etaMin,
  }) async {
    final now = DateTime.now();
    if (_lastEmit != null && now.difference(_lastEmit!).inSeconds < 3) return;
    _lastEmit = now;
    final payload = {
      'studentId':   _profile['_id']      ?? '',
      'name':        _profile['fullName']  ?? 'Student',
      'email':       _profile['email']     ?? '',
      'location':    { 'type': 'Point', 'coordinates': [lng, lat] },
      'heading':     heading,
      'speed':       speed,
      'status':      status,
      'origin':      origin,
      'destination': destination,
      'distanceKm':  distanceKm,
      'etaMin':      etaMin,
      'updatedAt':   now.toIso8601String(),
    };
    _socket?.emit('student_location_update', payload);
    if (_token != null) {
      try {
        await http.post(
          Uri.parse('${ApiConfig.baseUrl}/api/student-locations/me'),
          headers: ApiConfig.authHeaders(_token!),
          body: jsonEncode({
            'lng': lng, 'lat': lat,
            'heading': heading, 'speed': speed, 'status': status,
            'origin': origin, 'destination': destination,
            'distanceKm': distanceKm, 'etaMin': etaMin,
          }),
        );
      } catch (e) {
        debugPrint('DB Sync Error: $e');
      }
    }
  }

  void emitOffline() {
    _socket?.emit('student_location_update', {
      'studentId':   _profile['_id']     ?? '',
      'name':        _profile['fullName'] ?? 'Student',
      'email':       _profile['email']   ?? '',
      'heading':     0, 'speed': 0, 'status': 'offline',
      'origin':      null, 'destination': null,
      'distanceKm':  null, 'etaMin':      null,
      'updatedAt':   DateTime.now().toIso8601String(),
    });
  }

  void dispose() {
    emitOffline();
    _socket?.disconnect();
    _socket?.dispose();
  }

  static Map<String, dynamic> _decodeJwt(String? token) {
    if (token == null) return {};
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};
      final decoded = utf8.decode(base64.decode(base64.normalize(parts[1])));
      final map     = jsonDecode(decoded) as Map<String, dynamic>;
      final first   = map['firstName'] ?? '';
      final last    = map['lastName']  ?? '';
      final full    = (first.toString() + ' ' + last.toString()).trim();
      return {
        '_id':      map['_id']      ?? map['id']  ?? map['sub'] ?? '',
        'fullName': map['fullName'] ?? (full.isNotEmpty ? full : map['name'] ?? 'Student'),
        'email':    map['email']    ?? '',
      };
    } catch (_) {
      return {'_id': '', 'fullName': 'Student', 'email': ''};
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SPEED LIMIT SIGN WIDGET
// ═══════════════════════════════════════════════════════════════════════════════
class _SpeedLimitSign extends StatelessWidget {
  final int?  limit;
  final int?  currentSpeed;
  final bool  isOverSpeeding;

  const _SpeedLimitSign({
    required this.limit,
    required this.currentSpeed,
    required this.isOverSpeeding,
  });

  @override
  Widget build(BuildContext context) {
    if (limit == null) return const SizedBox.shrink();
    final borderColor = isOverSpeeding
        ? const Color(0xFFE24B4A)
        : const Color(0xFF1A1A1A);
    final shadowColor = isOverSpeeding
        ? const Color(0x80E24B4A)
        : Colors.black54;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 56, height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 3),
            boxShadow: [
              BoxShadow(color: shadowColor, blurRadius: 14, spreadRadius: 1),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'SPEED\nLIMIT',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 8, fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A), height: 1.1,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '$limit',
                style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A1A), height: 1.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        if (currentSpeed != null)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isOverSpeeding
                  ? const Color(0xE6E24B4A)
                  : Colors.black.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isOverSpeeding
                    ? const Color(0x99E24B4A)
                    : Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$currentSpeed',
                  style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w900,
                    color: Colors.white, height: 1,
                  ),
                ),
                Text(
                  'km/h',
                  style: TextStyle(
                    fontSize: 8,
                    color: isOverSpeeding ? Colors.white70 : Colors.white38,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        if (isOverSpeeding) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0x26E24B4A),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0x66E24B4A)),
            ),
            child: const Text(
              'OVER LIMIT',
              style: TextStyle(
                fontSize: 8, fontWeight: FontWeight.w800,
                color: Color(0xFFF87171), letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STOPOVER MODAL
// ═══════════════════════════════════════════════════════════════════════════════
class _StopoverModal extends StatefulWidget {
  final void Function(PlaceResult) onConfirm;
  final VoidCallback onClose;
  final LatLng? userLatLng;

  const _StopoverModal({
    required this.onConfirm,
    required this.onClose,
    this.userLatLng,
  });

  @override
  State<_StopoverModal> createState() => _StopoverModalState();
}

class _StopoverModalState extends State<_StopoverModal> {
  final _ctrl = TextEditingController();
  List<dynamic> _sugg    = [];
  bool          _loading = false;
  Timer?        _debounce;

  static const _chips = [
    'Gas station', 'Restaurant', 'Convenience store',
    'ATM', 'Pharmacy', 'Hospital',
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      if (mounted) setState(() { _sugg = []; _loading = false; });
      return;
    }
    if (mounted) setState(() => _loading = true);
    try {
      final loc = widget.userLatLng;
      String url;
      if (loc != null) {
        final minLon = (loc.longitude - 0.3).toStringAsFixed(6);
        final minLat = (loc.latitude  - 0.3).toStringAsFixed(6);
        final maxLon = (loc.longitude + 0.3).toStringAsFixed(6);
        final maxLat = (loc.latitude  + 0.3).toStringAsFixed(6);
        url = 'https://nominatim.openstreetmap.org/search'
            '?q=${Uri.encodeComponent(q)}'
            '&format=json&limit=8&addressdetails=1'
            '&viewbox=$minLon,$maxLat,$maxLon,$minLat'
            '&bounded=1'
            '&lat=${loc.latitude}&lon=${loc.longitude}';
      } else {
        url = 'https://nominatim.openstreetmap.org/search'
            '?q=${Uri.encodeComponent(q)}'
            '&format=json&limit=6&addressdetails=1';
      }

      final res = await http.get(
        Uri.parse(url),
        headers: {'Accept-Language': 'en', 'User-Agent': 'StudentMapsApp/1.0'},
      );

      List<dynamic> results = jsonDecode(res.body) as List<dynamic>;

      if (results.isEmpty && loc != null) {
        final fallback = await http.get(
          Uri.parse(
            'https://nominatim.openstreetmap.org/search'
            '?q=${Uri.encodeComponent(q)}'
            '&format=json&limit=6&addressdetails=1',
          ),
          headers: {'Accept-Language': 'en', 'User-Agent': 'StudentMapsApp/1.0'},
        );
        results = jsonDecode(fallback.body) as List<dynamic>;
      }

      if (loc != null && results.isNotEmpty) {
        results.sort((a, b) {
          final aLat = double.tryParse(a['lat'] as String? ?? '') ?? 0;
          final aLon = double.tryParse(a['lon'] as String? ?? '') ?? 0;
          final bLat = double.tryParse(b['lat'] as String? ?? '') ?? 0;
          final bLon = double.tryParse(b['lon'] as String? ?? '') ?? 0;
          final dA = _distSquared(loc.latitude, loc.longitude, aLat, aLon);
          final dB = _distSquared(loc.latitude, loc.longitude, bLat, bLon);
          return dA.compareTo(dB);
        });
      }

      if (mounted) setState(() { _sugg = results; _loading = false; });
    } catch (e) {
      debugPrint('Stopover search error: $e');
      if (mounted) setState(() { _sugg = []; _loading = false; });
    }
  }

  double _distSquared(double lat1, double lon1, double lat2, double lon2) {
    final dlat = lat2 - lat1;
    final dlon = lon2 - lon1;
    return dlat * dlat + dlon * dlon;
  }

  void _onQueryChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(v));
    if (mounted) setState(() {});
  }

  void _pick(dynamic p) {
    final displayName = (p['display_name'] as String)
        .split(',').take(2).join(',').trim();
    final place = PlaceResult(
      displayName: p['display_name'] as String,
      shortName:   displayName,
      lat: double.parse(p['lat'] as String),
      lon: double.parse(p['lon'] as String),
    );
    widget.onConfirm(place);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onClose,
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: Container(
                  decoration: BoxDecoration(
                    color: kBG2,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                    border: Border.all(color: kAccent.withValues(alpha: 0.2)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 40,
                          offset: const Offset(0, -8)),
                    ],
                  ),
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.80,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Add a stopover',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white)),
                                const SizedBox(height: 2),
                                Text(
                                    'Search for a place to stop along your route',
                                    style: TextStyle(
                                        fontSize: 11, color: kTextMuted)),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: widget.onClose,
                            child: Container(
                              width: 30, height: 30,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: kBorder),
                              ),
                              child: Icon(Icons.close_rounded,
                                  size: 14, color: kTextMuted),
                            ),
                          ),
                        ]),
                      ),

                      const SizedBox(height: 12),

                      // Search input
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.14)),
                          ),
                          child: Row(children: [
                            Expanded(
                              child: TextField(
                                controller: _ctrl,
                                autofocus: true,
                                onChanged: _onQueryChanged,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'e.g. Jollibee, Shell, 7-Eleven…',
                                  hintStyle: TextStyle(
                                      color: kTextMuted, fontSize: 13),
                                  border: InputBorder.none,
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 12),
                                ),
                              ),
                            ),
                            if (_loading)
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: SizedBox(
                                  width: 14, height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: kAccent),
                                ),
                              )
                            else if (_ctrl.text.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _ctrl.clear();
                                  setState(() => _sugg = []);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: Icon(Icons.close_rounded,
                                      size: 16, color: kTextMuted),
                                ),
                              ),
                          ]),
                        ),
                      ),

                      // Suggestions
                      if (_sugg.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Container(
                              decoration: BoxDecoration(
                                color: kBG,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: kAccent.withValues(alpha: 0.3)),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: ListView.separated(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  physics: const ClampingScrollPhysics(),
                                  itemCount: _sugg.length,
                                  separatorBuilder: (_, __) =>
                                      Divider(height: 1, color: kBorder),
                                  itemBuilder: (_, i) {
                                    final p = _sugg[i];
                                    final parts =
                                        (p['display_name'] as String).split(',');
                                    return InkWell(
                                      onTap: () => _pick(p),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                        child: Row(children: [
                                          Container(
                                            width: 30, height: 30,
                                            decoration: BoxDecoration(
                                              color: kAccent
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(7),
                                              border: Border.all(
                                                  color: kAccent
                                                      .withValues(alpha: 0.2)),
                                            ),
                                            child: Icon(
                                                Icons.location_on_rounded,
                                                size: 15, color: kAccent),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  parts.take(2).join(','),
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                if (parts.length > 2)
                                                  Text(
                                                    parts
                                                        .skip(2)
                                                        .take(2)
                                                        .join(',')
                                                        .trim(),
                                                    style: TextStyle(
                                                        color: kTextMuted,
                                                        fontSize: 10),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ]),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 10),

                      // Quick chips
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Wrap(
                          spacing: 6, runSpacing: 6,
                          children: _chips.map((chip) => GestureDetector(
                            onTap: () {
                              _ctrl.text = chip;
                              _ctrl.selection = TextSelection.fromPosition(
                                  TextPosition(offset: _ctrl.text.length));
                              _search(chip);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: kBorder),
                              ),
                              child: Text(chip,
                                  style: TextStyle(
                                      color: kTextSoft, fontSize: 11)),
                            ),
                          )).toList(),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Cancel
                      Padding(
                        padding:
                            EdgeInsets.fromLTRB(18, 0, 18, bottomInset + 18),
                        child: GestureDetector(
                          onTap: widget.onClose,
                          child: Container(
                            width: double.infinity,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: kBorder),
                            ),
                            child: Center(
                              child: Text('Cancel',
                                  style: TextStyle(
                                      color: kTextSoft,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class StudentMapsScreen extends StatefulWidget {
  const StudentMapsScreen({super.key});

  @override
  State<StudentMapsScreen> createState() => _StudentMapsScreenState();
}

class _StudentMapsScreenState extends State<StudentMapsScreen> {

  final _broadcaster = _LocationBroadcaster();

  MapLibreMapController? _ctrl;
  bool _styleLoaded = false;
  final _voice = VoiceGuideService();
  bool  _voiceOn = true;

  LatLng? _userLatLng;
  double  _userHeading = 0;
  StreamSubscription<Position>? _posStream;
  String _locStatus = 'locating';
  bool   _markerImagesAdded = false;

  bool         _useMyLoc  = true;
  PlaceResult? _fromPlace;
  PlaceResult? _toPlace;
  String _fromQuery = '';
  String _toQuery   = '';

  RouteInfo? _route;
  bool       _routeLoading = false;

  bool    _driveMode   = false;
  int     _currentStep = 0;
  double? _stepDist;
  bool    _showSteps   = false;
  bool    _simMode     = false;
  Timer?  _simTimer;
  int     _simIndex    = 0;
  bool    _saving      = false;

  // ── Pause & Stopover ─────────────────────────────────────────────
  bool         _isPaused          = false;
  bool         _showStopoverModal = false;
  PlaceResult? _activeStopover;
  PlaceResult? _finalDest;
  List<String> _stopoverNames     = [];

  // ── Speed limit ──────────────────────────────────────────────────
  int?   _speedLimit;
  int?   _currentSpeedKmh;
  bool   _isOverSpeeding  = false;
  bool   _overSpeedWarned = false;
  LatLng? _lastSpeedCheckPos;

  bool    _showHistory = false;
  String? _token;

  Symbol? _fromSymbol;
  Symbol? _toSymbol;
  Symbol? _stopoverSymbol;

  Offset? _userScreenPos;
  int     _screenPosGen = 0;
  Offset? _driveFixedAnchor;

  bool                   _trafficLayerOn    = false;
  bool                   _trafficLoading    = false;
  TrafficLevel?          _routeTrafficLevel;
  List<TrafficIncident>  _incidents         = [];
  Timer?                 _incidentRefreshTimer;

  double _lastLng = 121.0244;
  double _lastLat = 14.6091;

  // ─────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadToken();
    _requestLocation();
    _voice.init();
    _broadcaster.init();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _token = prefs.getString('token'));
  }

  void _emitIdle() {
    _broadcaster.broadcast(
      lng: _lastLng, lat: _lastLat,
      heading: 0, speed: 0, status: 'idle',
      origin:      _fromPlace?.shortName,
      destination: _toPlace?.shortName,
    );
  }

  Offset _computeDriveAnchor() {
    final sz = MediaQuery.of(context).size;
    return Offset(sz.width / 2, sz.height * 0.55);
  }

  // ── Speed limit ──────────────────────────────────────────────────
  Future<void> _fetchSpeedLimit(LatLng pos) async {
    if (_lastSpeedCheckPos != null) {
      final d = _haversine(pos, _lastSpeedCheckPos!);
      if (d < 100) return;
    }
    _lastSpeedCheckPos = pos;
    try {
      final key = ApiConfig.tomTomKey;
      final url =
          'https://api.tomtom.com/traffic/services/4/flowSegmentData/'
          'relative0/10/json?key=$key'
          '&point=${pos.latitude},${pos.longitude}';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final ffs  = (body['flowSegmentData']?['freeFlowSpeed'] as num?)
            ?.round();
        if (ffs != null && mounted) {
          setState(() => _speedLimit = ffs);
        }
      }
    } catch (e) {
      debugPrint('SpeedLimit fetch error: $e');
    }
  }

  void _updateSpeedDisplay(int kmh) {
    if (!mounted) return;
    final limit = _speedLimit;
    final over  = limit != null && kmh > limit;
    setState(() {
      _currentSpeedKmh = kmh;
      _isOverSpeeding  = over;
    });
    if (over && !_overSpeedWarned && _voiceOn) {
      _overSpeedWarned = true;
      _voice.speak(
          'Speed limit is $_speedLimit kilometres per hour. Please slow down.');
    }
    if (!over) _overSpeedWarned = false;
  }

  // ── Traffic helpers ──────────────────────────────────────────────
  Future<void> _addTrafficLayers() async {
    if (_ctrl == null || !_styleLoaded) return;
    await _ctrl!.addSource('tomtom-flow', RasterSourceProperties(
      tiles: [TrafficService.flowTileUrl(style: 'relative0-dark')],
      tileSize: 256,
    ));
    await _ctrl!.addRasterLayer('tomtom-flow', 'tomtom-flow-layer',
        const RasterLayerProperties(rasterOpacity: 0.75));
    await _ctrl!.addSource('tomtom-incidents', RasterSourceProperties(
      tiles: [TrafficService.incidentTileUrl()],
      tileSize: 256,
    ));
    await _ctrl!.addRasterLayer('tomtom-incidents', 'tomtom-incidents-layer',
        const RasterLayerProperties(rasterOpacity: 0.9));
  }

  Future<void> _removeTrafficLayers() async {
    if (_ctrl == null) return;
    for (final id in ['tomtom-flow-layer', 'tomtom-incidents-layer']) {
      try { await _ctrl!.removeLayer(id); } catch (_) {}
    }
    for (final id in ['tomtom-flow', 'tomtom-incidents']) {
      try { await _ctrl!.removeSource(id); } catch (_) {}
    }
  }

  Future<void> _toggleTrafficLayer() async {
    if (_trafficLayerOn) {
      await _removeTrafficLayers();
      _incidentRefreshTimer?.cancel();
      if (mounted) setState(() { _trafficLayerOn = false; _incidents = []; });
    } else {
      await _addTrafficLayers();
      if (mounted) setState(() => _trafficLayerOn = true);
      _refreshIncidents();
      _incidentRefreshTimer = Timer.periodic(
          const Duration(seconds: 90), (_) => _refreshIncidents());
    }
  }

  Future<void> _refreshIncidents() async {
    final center = _userLatLng;
    if (center == null || !_trafficLayerOn) return;
    final results = await TrafficService.getIncidents(center);
    if (mounted) setState(() => _incidents = results);
  }

  Future<void> _checkRouteTraffic(RouteInfo route) async {
    if (mounted) setState(() => _trafficLoading = true);
    final level = await TrafficService.checkRouteTraffic(
        route.coordinates, sampleEvery: 8);
    if (mounted) setState(() {
      _routeTrafficLevel = level;
      _trafficLoading    = false;
    });
  }

  // ── Permissions & location ───────────────────────────────────────
  Future<void> _requestLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _locStatus = 'denied');
      return;
    }
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      if (mounted) setState(() => _locStatus = 'denied');
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high));
      if (mounted) {
        _onPositionUpdate(pos);
        setState(() => _locStatus = 'found');
      }
    } catch (_) {
      if (mounted) setState(() => _locStatus = 'denied');
    }
  }

  void _onPositionUpdate(Position pos) {
    final ll  = LatLng(pos.latitude, pos.longitude);
    final spd = (pos.speed * 3.6).clamp(0.0, 300.0);

    _lastLng = pos.longitude;
    _lastLat = pos.latitude;

    if (mounted) {
      setState(() {
        _userLatLng  = ll;
        _userHeading = pos.heading;
        if (_driveMode) _userScreenPos = _driveFixedAnchor;
      });
    }

    _updateSpeedDisplay(spd.round());
    _fetchSpeedLimit(ll);

    _broadcaster.broadcast(
      lng:         pos.longitude,
      lat:         pos.latitude,
      heading:     pos.heading,
      speed:       spd,
      status:      _driveMode ? (_isPaused ? 'idle' : 'driving') : 'idle',
      origin:      _fromPlace?.shortName ?? (_useMyLoc ? 'My Location' : null),
      destination: _toPlace?.shortName,
      distanceKm:  _route?.distanceKm,
      etaMin:      _route?.durationMin,
    );

    if (_driveMode && !_isPaused && _ctrl != null) {
      _ctrl!.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
          target: ll, zoom: 17, tilt: 45, bearing: pos.heading)));
      _advanceStep(ll);
    }
  }

  void _startWatch() {
    _posStream?.cancel();
    _posStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy:       LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen(_onPositionUpdate);
  }

  void _stopWatch() {
    _posStream?.cancel();
    _posStream = null;
  }

  Future<void> _refreshUserScreenPos() async {
    if (_ctrl == null || _userLatLng == null || !_styleLoaded || _driveMode)
      return;
    final gen = ++_screenPosGen;
    try {
      final pt = await _ctrl!.toScreenLocation(_userLatLng!);
      if (mounted && !_driveMode && gen == _screenPosGen) {
        setState(() =>
            _userScreenPos = Offset(pt.x.toDouble(), pt.y.toDouble()));
      }
    } catch (_) {}
  }

  double _haversine(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = (b.latitude  - a.latitude)  * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final s = math.pow(math.sin(dLat / 2), 2) +
        math.cos(a.latitude  * math.pi / 180) *
        math.cos(b.latitude  * math.pi / 180) *
        math.pow(math.sin(dLon / 2), 2);
    return R * 2 * math.atan2(math.sqrt(s), math.sqrt(1 - s));
  }

  void _advanceStep(LatLng pos) {
    if (_route == null) return;
    final step = _route!.steps[_currentStep];
    final loc  = LatLng(step.location[1], step.location[0]);
    final d    = _haversine(pos, loc);
    if (mounted) setState(() => _stepDist = d);
    if (d < 200) _voice.speakApproach(_currentStep, step.instruction, d);
    if (d < 30 && _currentStep < _route!.steps.length - 1) {
      if (mounted) setState(() => _currentStep++);
      final next = _route!.steps[_currentStep];
      _voice.speakStep(_currentStep, next.instruction);
    }
  }

  void _onMapCreated(MapLibreMapController ctrl) => _ctrl = ctrl;

  Future<void> _onStyleLoaded() async {
    _markerImagesAdded = false;
    if (mounted) setState(() => _styleLoaded = true);
    await _addCustomMarkerImages();
    if (_userLatLng != null && _ctrl != null) {
      await _ctrl!.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: _userLatLng!, zoom: 14)));
      await _refreshUserScreenPos();
    }
    _broadcaster.broadcast(
      lng: _lastLng, lat: _lastLat,
      heading: 0, speed: 0, status: 'idle',
    );
  }

  Future<void> _addCustomMarkerImages() async {
    if (_markerImagesAdded) return;
    if (_ctrl == null || !_styleLoaded) return;
    try {
      await _createPin('pin-green', const Color(0xFF4ADE80));
      await _createPin('pin-gold',  const Color(0xFFB8963E));
      await _createPin('pin-blue',  const Color(0xFF60A5FA));
      _markerImagesAdded = true;
    } catch (e) {
      debugPrint('Failed to add marker images: $e');
    }
  }

  Future<void> _createPin(String name, Color color) async {
    if (_ctrl == null) return;
    try {
      const w = 80.0;
      const h = 110.0;
      final recorder = ui.PictureRecorder();
      final canvas   = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
      final shadow   = Paint()
        ..color      = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawOval(
          Rect.fromLTWH(w * .2, h * .82, w * .6, h * .12), shadow);
      final body = Paint()..color = color;
      final path = Path();
      const cx = w / 2;
      const cy = 42.0;
      const r  = 30.0;
      path.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      path.moveTo(cx - 10, cy + r - 6);
      path.quadraticBezierTo(cx, h * .88, cx, h * .88);
      path.quadraticBezierTo(cx + 10, cy + r - 6, cx + 10, cy + r - 6);
      path.close();
      canvas.drawPath(path, body);
      canvas.drawCircle(
          const Offset(cx, cy), r * 0.45, Paint()..color = Colors.white);
      final picture = recorder.endRecording();
      final image   = await picture.toImage(w.toInt(), h.toInt());
      final bytes   = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      await _ctrl!.addImage(name, bytes.buffer.asUint8List());
    } catch (e) {
      debugPrint('_createPin($name) error: $e');
    }
  }

  Future<void> _setFromMarker(LatLng ll, {String? label}) async {
    if (_ctrl == null || !_styleLoaded) return;
    await _addCustomMarkerImages();
    if (_fromSymbol != null) await _ctrl!.removeSymbol(_fromSymbol!);
    _fromSymbol = await _ctrl!.addSymbol(SymbolOptions(
        geometry: ll, iconImage: 'pin-green',
        iconSize: 0.6, iconAnchor: 'bottom'));
  }

  Future<void> _setToMarker(LatLng ll, {String? label}) async {
    if (_ctrl == null || !_styleLoaded) return;
    await _addCustomMarkerImages();
    if (_toSymbol != null) await _ctrl!.removeSymbol(_toSymbol!);
    _toSymbol = await _ctrl!.addSymbol(SymbolOptions(
        geometry: ll, iconImage: 'pin-gold',
        iconSize: 0.6, iconAnchor: 'bottom'));
  }

  Future<void> _setStopoverMarker(LatLng ll) async {
    if (_ctrl == null || !_styleLoaded) return;
    await _addCustomMarkerImages();
    if (_stopoverSymbol != null) await _ctrl!.removeSymbol(_stopoverSymbol!);
    _stopoverSymbol = await _ctrl!.addSymbol(SymbolOptions(
        geometry: ll, iconImage: 'pin-blue',
        iconSize: 0.6, iconAnchor: 'bottom'));
  }

  Future<void> _drawRoute(RouteInfo r) async {
    if (_ctrl == null || !_styleLoaded) return;
    await _ctrl!.clearLines();
    if (r.coordinates.isEmpty) return;
    final pts = r.coordinates.map((c) => LatLng(c[1], c[0])).toList();
    await _ctrl!.addLine(LineOptions(
        geometry: pts, lineColor: '#000000',
        lineWidth: 12, lineOpacity: 0.45, lineJoin: 'round'));
    await _ctrl!.addLine(LineOptions(
        geometry: pts, lineColor: '#B8963E',
        lineWidth: 6,  lineOpacity: 1,    lineJoin: 'round'));
    final lngs = r.coordinates.map((c) => c[0]);
    final lats  = r.coordinates.map((c) => c[1]);
    await _ctrl!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(lats.reduce(math.min), lngs.reduce(math.min)),
        northeast: LatLng(lats.reduce(math.max), lngs.reduce(math.max)),
      ),
      left: 60, top: 80, right: 60, bottom: 220,
    ));
  }

  // ── FIX 1: preserveRoute keeps existing _route visible during reroute ──────
  Future<void> _buildRoute(
      double fromLon, double fromLat, double toLon, double toLat,
      {bool preserveRoute = false}) async {
    if (mounted) setState(() {
      _routeLoading      = true;
      // Only null out _route if we are NOT in a stopover/resume reroute.
      // This prevents the bottom bar from disappearing during recalculation.
      if (!preserveRoute) _route = null;
      _routeTrafficLevel = null;
    });
    final r = await MapService.getRoute(
        fromLon: fromLon, fromLat: fromLat, toLon: toLon, toLat: toLat);
    if (!mounted) return;
    setState(() { _route = r; _routeLoading = false; _currentStep = 0; });
    if (r != null) {
      await _drawRoute(r);
      _checkRouteTraffic(r);
    }
  }

  LatLng? get _effectiveFrom {
    if (_useMyLoc) return _userLatLng;
    if (_fromPlace != null) return LatLng(_fromPlace!.lat, _fromPlace!.lon);
    return null;
  }

  Future<void> _onFromPicked(PlaceResult p) async {
    if (mounted) setState(() {
      _fromPlace = p; _fromQuery = p.shortName; _useMyLoc = false;
    });
    await _setFromMarker(LatLng(p.lat, p.lon), label: p.shortName);
    final to = _toPlace;
    if (to != null) {
      await _buildRoute(p.lon, p.lat, to.lon, to.lat);
    } else {
      _ctrl?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(p.lat, p.lon), 14));
    }
  }

  Future<void> _onToPicked(PlaceResult p) async {
    if (mounted) setState(() { _toPlace = p; _toQuery = p.shortName; });
    await _setToMarker(LatLng(p.lat, p.lon), label: p.shortName);
    final from = _effectiveFrom;
    if (from != null) {
      await _buildRoute(from.longitude, from.latitude, p.lon, p.lat);
    } else {
      _ctrl?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(p.lat, p.lon), 14));
    }
  }

  void _onClearFrom() {
    if (mounted) setState(() {
      _fromPlace = null; _fromQuery = ''; _useMyLoc = true;
      _route = null; _routeTrafficLevel = null;
    });
    if (_fromSymbol != null) {
      _ctrl?.removeSymbol(_fromSymbol!);
      _fromSymbol = null;
    }
    _ctrl?.clearLines();
  }

  void _onClearTo() {
    if (mounted) setState(() {
      _toPlace = null; _toQuery = '';
      _route = null; _routeTrafficLevel = null;
    });
    if (_toSymbol != null) {
      _ctrl?.removeSymbol(_toSymbol!);
      _toSymbol = null;
    }
    _ctrl?.clearLines();
  }

  Future<void> _onSwap() async {
    final from = _effectiveFrom;
    final to   = _toPlace;
    if (from == null || to == null) return;
    final prevName = _fromPlace?.shortName ?? 'My Location';
    final newFrom  = PlaceResult(
        displayName: to.displayName, shortName: to.shortName,
        lat: to.lat, lon: to.lon);
    final newTo = PlaceResult(
        displayName: _fromPlace?.displayName ?? 'My Location',
        shortName: prevName,
        lat: from.latitude, lon: from.longitude);
    if (mounted) setState(() {
      _fromPlace = newFrom; _toPlace   = newTo;
      _fromQuery = newFrom.shortName; _toQuery = newTo.shortName;
      _useMyLoc  = false;
    });
    await _setFromMarker(LatLng(newFrom.lat, newFrom.lon));
    await _setToMarker(LatLng(newTo.lat, newTo.lon));
    await _buildRoute(newFrom.lon, newFrom.lat, newTo.lon, newTo.lat);
  }

  void _clearAll() {
    _exitDrive();
    if (mounted) setState(() {
      _fromPlace = null; _toPlace  = null; _route    = null;
      _fromQuery = '';   _toQuery  = '';   _useMyLoc = true;
      _currentStep = 0;  _stepDist = null; _showSteps = false;
      _routeTrafficLevel = null;
      _isPaused = false; _activeStopover = null;
      _finalDest = null; _stopoverNames = [];
      _speedLimit = null; _currentSpeedKmh = null;
      _isOverSpeeding = false;
    });
    if (_fromSymbol     != null) {
      _ctrl?.removeSymbol(_fromSymbol!);     _fromSymbol     = null;
    }
    if (_toSymbol       != null) {
      _ctrl?.removeSymbol(_toSymbol!);       _toSymbol       = null;
    }
    if (_stopoverSymbol != null) {
      _ctrl?.removeSymbol(_stopoverSymbol!); _stopoverSymbol = null;
    }
    _ctrl?.clearLines();
    _broadcaster.broadcast(
      lng: _lastLng, lat: _lastLat,
      heading: 0, speed: 0, status: 'idle',
    );
  }

  void _enterDrive() {
    final anchor = _computeDriveAnchor();
    if (mounted) setState(() {
      _driveMode        = true;
      _isPaused         = false;
      _currentStep      = 0;
      _showSteps        = false;
      _driveFixedAnchor = anchor;
      _userScreenPos    = anchor;
      _voice.reset();
      if (_route != null && _route!.steps.isNotEmpty) {
        _voice.speakStep(0, _route!.steps[0].instruction, force: true);
      }
    });
    _broadcaster.broadcast(
      lng: _lastLng, lat: _lastLat,
      heading: _userHeading, speed: 0,
      status: 'driving',
      origin:      _fromPlace?.shortName ?? 'My Location',
      destination: _toPlace?.shortName,
      distanceKm:  _route?.distanceKm,
      etaMin:      _route?.durationMin,
    );
    if (_simMode) _startSim(); else _startWatch();
    final start = _effectiveFrom;
    if (start != null && _ctrl != null) {
      _ctrl!.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
          target: start, zoom: 17, tilt: 45, bearing: _userHeading)));
    }
  }

  void _exitDrive() {
    final gen = ++_screenPosGen;
    if (mounted) setState(() {
      _driveMode        = false;
      _isPaused         = false;
      _userScreenPos    = null;
      _driveFixedAnchor = null;
      _activeStopover   = null;
      _finalDest        = null;
      _stopoverNames    = [];
      _speedLimit       = null;
      _currentSpeedKmh  = null;
      _isOverSpeeding   = false;
      _voice.reset();
    });
    _stopWatch();
    _stopSim();
    _broadcaster.broadcast(
      lng: _lastLng, lat: _lastLat,
      heading: 0, speed: 0, status: 'idle',
      origin:      _fromPlace?.shortName,
      destination: _toPlace?.shortName,
    );
    _ctrl?.animateCamera(CameraUpdate.newCameraPosition(
        const CameraPosition(
            tilt: 0, bearing: 0, zoom: 13,
            target: LatLng(14.6091, 121.0244))));
    if (_route != null) {
      Future.delayed(const Duration(milliseconds: 900),
          () { if (mounted && _route != null) _drawRoute(_route!); });
    }
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted && gen == _screenPosGen) _refreshUserScreenPos();
    });
  }

  // ── Pause / Resume ────────────────────────────────────────────────
  void _pauseDrive() {
    if (mounted) setState(() => _isPaused = true);
    _stopWatch();
    _stopSim();
    _voice.speak('Navigation paused.');
    _broadcaster.broadcast(
      lng: _lastLng, lat: _lastLat,
      heading: 0, speed: 0, status: 'idle',
      origin:      _fromPlace?.shortName,
      destination: _toPlace?.shortName,
    );
  }

  void _resumeDrive() {
    if (mounted) setState(() {
      _isPaused       = false;
      _activeStopover = null;
    });
    if (_stopoverSymbol != null) {
      _ctrl?.removeSymbol(_stopoverSymbol!);
      _stopoverSymbol = null;
    }
    _voice.speak('Resuming navigation.');
    if (_simMode) _startSim(); else _startWatch();
    _broadcaster.broadcast(
      lng: _lastLng, lat: _lastLat,
      heading: _userHeading, speed: 0, status: 'driving',
      origin:      _fromPlace?.shortName,
      destination: _toPlace?.shortName,
    );
  }

  // ── FIX 2: _addStopover — no double-stop, preserveRoute: true ────
  Future<void> _addStopover(PlaceResult place) async {
    // Save original destination before rerouting to stopover
    _finalDest ??= _toPlace;
    final origin = _userLatLng;
    if (origin == null) return;

    // Stop movement first (don't call _pauseDrive to avoid double-stop)
    _stopWatch();
    _stopSim();

    await _setStopoverMarker(LatLng(place.lat, place.lon));

    // preserveRoute: true → keeps the current route drawn so the
    // bottom bar doesn't vanish while the new route loads.
    await _buildRoute(
      origin.longitude, origin.latitude,
      place.lon, place.lat,
      preserveRoute: true,
    );

    if (mounted) setState(() {
      _activeStopover = place;
      _stopoverNames  = [..._stopoverNames, place.shortName];
      _isPaused       = true; // set inline, not via _pauseDrive()
    });

    _voice.speak(
        'Stopover added at ${place.shortName}. Tap Resume when ready.');

    _broadcaster.broadcast(
      lng: _lastLng, lat: _lastLat,
      heading: 0, speed: 0, status: 'idle',
      origin:      _fromPlace?.shortName,
      destination: place.shortName,
    );
  }

  // ── FIX 3: _resumeFromStopover — always route from current GPS pos ─
  Future<void> _resumeFromStopover() async {
    final finalDest = _finalDest ?? _toPlace;
    if (finalDest == null) { _resumeDrive(); return; }

    // Always use current GPS position as the routing origin,
    // NOT the stopover's saved coordinates.
    final origin = _userLatLng;
    if (origin == null) { _resumeDrive(); return; }

    // Remove the stopover pin
    if (_stopoverSymbol != null) {
      _ctrl?.removeSymbol(_stopoverSymbol!);
      _stopoverSymbol = null;
    }

    // ✅ Clear stopover & unpause BEFORE restarting the watcher.
    // This ensures the onResume callback won't loop back here.
    if (mounted) setState(() {
      _activeStopover = null;
      _isPaused       = false;
    });

    // Restore the final destination marker
    await _setToMarker(
        LatLng(finalDest.lat, finalDest.lon), label: finalDest.shortName);

    // Route from current position → original destination.
    // preserveRoute: true keeps the bottom bar visible during load.
    await _buildRoute(
      origin.longitude, origin.latitude,
      finalDest.lon,    finalDest.lat,
      preserveRoute: true,
    );

    _voice.speak('Continuing to ${finalDest.shortName}.');

    // Restart GPS / simulation AFTER state is clean
    if (_simMode) _startSim(); else _startWatch();

    _broadcaster.broadcast(
      lng:         origin.longitude,
      lat:         origin.latitude,
      heading:     _userHeading,
      speed:       0,
      status:      'driving',
      origin:      _fromPlace?.shortName,
      destination: finalDest.shortName,
      distanceKm:  _route?.distanceKm,
      etaMin:      _route?.durationMin,
    );
  }

  void _recenter() {
    final ll = _userLatLng;
    if (ll == null || _ctrl == null) return;
    if (_driveMode) {
      _ctrl!.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
          target: ll, zoom: 16, tilt: 50, bearing: _userHeading)));
    } else {
      _ctrl!.animateCamera(CameraUpdate.newLatLngZoom(ll, 14));
      Future.delayed(const Duration(milliseconds: 800), _refreshUserScreenPos);
    }
  }

  void _startSim() {
    final coords = _route?.coordinates;
    if (coords == null || coords.isEmpty) return;
    _simIndex = 0;
    _simTimer?.cancel();
    _simTimer = Timer.periodic(const Duration(milliseconds: 500), (t) {
      final c = _route?.coordinates;
      if (c == null || _simIndex >= c.length) { _stopSim(); return; }
      final pt   = c[_simIndex];
      final ll   = LatLng(pt[1], pt[0]);
      final next = _simIndex < c.length - 1 ? c[_simIndex + 1] : pt;
      final hdg  =
          math.atan2(next[0] - pt[0], next[1] - pt[1]) * 180 / math.pi;
      if (mounted) {
        setState(() {
          _userLatLng    = ll;
          _userHeading   = hdg;
          _userScreenPos = _driveFixedAnchor;
        });
      }
      _updateSpeedDisplay(40);
      _fetchSpeedLimit(ll);
      _ctrl?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
          target: ll, zoom: 17, tilt: 45, bearing: hdg)));
      _broadcaster.broadcast(
        lng:         pt[0],
        lat:         pt[1],
        heading:     hdg,
        speed:       40,
        status:      'sim',
        origin:      _fromPlace?.shortName,
        destination: _toPlace?.shortName,
        distanceKm:  _route?.distanceKm,
        etaMin:      _route?.durationMin,
      );
      _advanceStep(ll);
      _lastLng = pt[0];
      _lastLat = pt[1];
      _simIndex++;
      if (_simIndex >= c.length) {
        _stopSim();
        if (mounted) setState(() => _stepDist = 0);
      }
    });
  }

  void _stopSim() { _simTimer?.cancel(); _simTimer = null; }

  bool get _arrived =>
      _driveMode && _route != null &&
      _currentStep >= _route!.steps.length - 1 &&
      (_stepDist ?? 999) < 50;

  Future<void> _handleArrived() async {
    final from  = _effectiveFrom;
    final to    = _toPlace;
    final route = _route;
    if (_token != null && route != null && from != null && to != null) {
      if (mounted) setState(() => _saving = true);
      final ok = await MapService.saveHistory(
        token:       _token!,
        fromName:    _fromPlace?.shortName ?? 'My Location',
        fromLon:     from.longitude, fromLat: from.latitude,
        toName:      to.shortName,
        toLon:       to.lon, toLat: to.lat,
        distanceKm:  route.distanceKm,
        durationMin: route.durationMin,
      );
      debugPrint(ok ? '✅ Route saved' : '❌ Route save failed');
      if (mounted) setState(() => _saving = false);
    }
    await _voice.speakArrived(_toPlace?.shortName ?? 'your destination');
    _broadcaster.emitOffline();
    _clearAll();
  }

  Future<void> _replayRoute(RouteHistoryEntry entry) async {
    if (mounted) setState(() => _showHistory = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Loading: ${entry.fromName} → ${entry.toName}'),
          backgroundColor: kBG2,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2)));
    }
    final fromPlace = PlaceResult(
        displayName: entry.fromName, shortName: entry.fromName,
        lat: entry.fromLat, lon: entry.fromLon);
    final toPlace = PlaceResult(
        displayName: entry.toName, shortName: entry.toName,
        lat: entry.toLat, lon: entry.toLon);
    if (mounted) setState(() {
      _fromPlace = fromPlace; _toPlace   = toPlace;
      _fromQuery = entry.fromName; _toQuery = entry.toName;
      _useMyLoc  = false;
    });
    await _setFromMarker(LatLng(entry.fromLat, entry.fromLon));
    await _setToMarker(LatLng(entry.toLat, entry.toLon));
    await _buildRoute(
        entry.fromLon, entry.fromLat, entry.toLon, entry.toLat);
  }

  Future<void> _onMapTap(dynamic point, LatLng ll) async {
    if (_driveMode) return;
    final name  = await MapService.reverseGeocode(ll.latitude, ll.longitude);
    final place = PlaceResult(
        displayName: name, shortName: name,
        lat: ll.latitude, lon: ll.longitude);
    final hasFrom = _useMyLoc ? _userLatLng != null : _fromPlace != null;
    if (!hasFrom) await _onFromPicked(place); else await _onToPicked(place);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('📍 ${!hasFrom ? "From" : "To"} set: $name'),
          backgroundColor: kBG2,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3)));
    }
  }

  // ── Build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final step = (_route != null && _route!.steps.isNotEmpty)
        ? _route!.steps[_currentStep]
        : null;
    final nextStep =
        (_route != null && _currentStep + 1 < _route!.steps.length)
            ? _route!.steps[_currentStep + 1]
            : null;

    return Scaffold(
      backgroundColor: kBG,
      body: Stack(children: [

        // ── Map ────────────────────────────────────────────────────
        MapLibreMap(
          styleString: kMapStyle,
          initialCameraPosition: CameraPosition(
              target: _userLatLng ?? const LatLng(14.6091, 121.0244),
              zoom: 12),
          onMapCreated:          _onMapCreated,
          onStyleLoadedCallback: _onStyleLoaded,
          onMapClick:            _onMapTap,
          myLocationEnabled:     false,
          trackCameraPosition:   false,
          rotateGesturesEnabled: true,
          tiltGesturesEnabled:   true,
        ),

        // ── User dot ───────────────────────────────────────────────
        if (_userLatLng != null) _userDotWidget(context),

        // ══ NORMAL MODE ═══════════════════════════════════════════
        if (!_driveMode) ...[
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 12, right: 60,
            child: SearchPanel(
              useMyLocation:          _useMyLoc,
              fromQuery:              _fromQuery,
              toQuery:                _toQuery,
              onUseMyLocationChanged: (v) {
                setState(() => _useMyLoc = v);
                if (v) _onClearFrom();
              },
              onFromPicked: _onFromPicked, onToPicked:  _onToPicked,
              onClearFrom:  _onClearFrom,  onClearTo:   _onClearTo,
              onSwap:       _onSwap,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12, right: 12,
            child: Column(children: [
              _iconBtn(
                  icon: Icons.history_rounded, color: kAccent,
                  onTap: () => setState(() => _showHistory = true)),
              const SizedBox(height: 8),
              _iconBtn(
                icon:   Icons.play_arrow_rounded,
                color:  _simMode ? kGreen : kTextMuted,
                bg:     _simMode ? kGreen.withValues(alpha: 0.15) : kBG2,
                border: _simMode ? kGreen.withValues(alpha: 0.4)  : kBorder,
                onTap:  () => setState(() => _simMode = !_simMode),
              ),
            ]),
          ),
          Positioned(
            right: 12,
            top:   MediaQuery.of(context).padding.top + 140,
            child: Column(children: [
              _mapBtn(Icons.add,
                  () => _ctrl?.animateCamera(CameraUpdate.zoomIn())),
              const SizedBox(height: 8),
              _mapBtn(Icons.remove,
                  () => _ctrl?.animateCamera(CameraUpdate.zoomOut())),
              const SizedBox(height: 8),
              _mapBtn(Icons.my_location_rounded, _recenter,
                  color: _userLatLng != null ? kAccent : kTextSoft),
              const SizedBox(height: 8),
              TrafficLayerToggle(
                  isOn: _trafficLayerOn, onTap: _toggleTrafficLayer),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final now = await _voice.toggle();
                  if (mounted) setState(() => _voiceOn = now);
                  if (now) _voice.speak('Voice guide on');
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _voiceOn
                        ? kAccent.withValues(alpha: 0.18) : kBG2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _voiceOn
                          ? kAccent.withValues(alpha: 0.6) : kBorder),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 8)],
                  ),
                  child: Icon(
                    _voiceOn
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    color: _voiceOn ? kAccent : kTextSoft, size: 16),
                ),
              ),
            ]),
          ),
          if (_locStatus == 'locating')
            Positioned(
              top: MediaQuery.of(context).padding.top + 130,
              left: 0, right: 0,
              child: Center(
                  child: _chip('Getting your location…', kBG2, kTextSoft))),
          if (_locStatus == 'denied')
            Positioned(
              top: MediaQuery.of(context).padding.top + 130,
              left: 0, right: 0,
              child: Center(child: _chip(
                  '⚠ Location denied — set From manually',
                  kRed.withValues(alpha: 0.12), kRed))),
          if (_styleLoaded && _toPlace == null && _route == null)
            Positioned.fill(child: IgnorePointer(child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kBorder)),
                child: const Text('Tap map to pin From / To',
                    style: TextStyle(color: kTextMuted, fontSize: 11)),
              ),
            ))),
          if (_toPlace != null || _routeLoading)
            Positioned(
              bottom: 24, left: 12, right: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_routeTrafficLevel != null && !_routeLoading)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 4),
                      child: TrafficBadge(
                        level:         _routeTrafficLevel!,
                        incidentCount: _incidents.length,
                        onTap: _incidents.isNotEmpty
                            ? () => TrafficIncidentSheet.show(
                                context, _incidents)
                            : null,
                      ),
                    ),
                  if (_trafficLoading && _routeTrafficLevel == null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 4),
                      child: _chip(
                          'Checking traffic…', kBG2, kTextMuted)),
                  _route != null
                      ? RouteCard(
                          route:        _route!,
                          fromName:     _fromPlace?.shortName ?? 'My Location',
                          toName:       _toPlace?.shortName ?? '',
                          loading:      _routeLoading,
                          onStartDrive: _enterDrive,
                          onClear:      _clearAll)
                      : _loadingCard(),
                ],
              )),
          if (_toPlace == null && !_routeLoading && _styleLoaded)
            Positioned(
              bottom: 24, left: 0, right: 0,
              child: Center(child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorder)),
                child: const Text(
                    'Search above to get driving directions',
                    style: TextStyle(color: kTextMuted, fontSize: 12)),
              ))),
        ],

        // ══ DRIVE MODE ════════════════════════════════════════════
        // FIX 4: Guard changed to (_route != null || _routeLoading)
        // so the UI shell stays rendered while a stopover route loads.
        if (_driveMode && (_route != null || _routeLoading) && !_arrived) ...[

          // Top nav banner (dimmed when paused)
          if (step != null)
            Positioned(
              top: 0, left: 0, right: 0,
              child: Opacity(
                opacity: _isPaused ? 0.45 : 1.0,
                child: DriveBanner(
                    step: step, nextStep: nextStep,
                    distToStep:  _stepDist,
                    durationMin: _route?.durationMin ?? 0),
              ),
            ),

          // Speed limit sign
          Positioned(
            bottom: 165, left: 14,
            child: _SpeedLimitSign(
              limit:          _speedLimit,
              currentSpeed:   _currentSpeedKmh,
              isOverSpeeding: _isOverSpeeding,
            ),
          ),

          // FIX 5: Only render _DriveBottomBar when _route != null
          // (prevents crash during brief null window while rerouting).
          if (_route != null)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _DriveBottomBar(
                route:         _route!,
                currentStep:   _currentStep,
                showSteps:     _showSteps,
                simMode:       _simMode,
                saving:        _saving,
                isPaused:      _isPaused,
                hasStopover:   _activeStopover != null,
                stopoverCount: _stopoverNames.length,
                onToggleSteps: () => setState(() => _showSteps = !_showSteps),
                onRecenter:    _recenter,
                onExit:        _exitDrive,
                onPause:       _pauseDrive,
                // When there's an active stopover, Resume goes to
                // _resumeFromStopover; otherwise plain _resumeDrive.
                onResume: _activeStopover != null
                    ? _resumeFromStopover
                    : _resumeDrive,
                onStopover: () => setState(() => _showStopoverModal = true),
              ),
            ),

          // Loading indicator during reroute (shown instead of bottom bar)
          if (_routeLoading && _route == null)
            Positioned(
              bottom: 20, left: 0, right: 0,
              child: Center(child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: kBG2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kAccent.withValues(alpha: 0.2)),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20)],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: kAccent)),
                  const SizedBox(width: 10),
                  Text('Recalculating route…',
                      style: TextStyle(color: kTextSoft, fontSize: 13)),
                ]),
              )),
            ),

          if (_showSteps && _route != null)
            Positioned(
              bottom: 160, left: 10, right: 10,
              child: StepsPanel(
                  steps: _route!.steps, currentStep: _currentStep,
                  onStepTap: (i) => setState(() {
                    _currentStep = i; _showSteps = false;
                  }),
                  onClose: () => setState(() => _showSteps = false))),

          // Pause banner
          if (_isPaused && _activeStopover == null)
            Positioned(
              top: 130, left: 12, right: 12,
              child: _infoBanner(
                color:    const Color(0xFF60A5FA),
                title:    'Navigation paused',
                subtitle: 'GPS tracking stopped · Resume when ready',
              ),
            ),

          // Stopover banner
          if (_activeStopover != null)
            Positioned(
              top: 130, left: 12, right: 12,
              child: _infoBanner(
                color:    const Color(0xFFEF9F27),
                title:    'Stopover — ${_activeStopover!.shortName}',
                subtitle: 'Tap "Resume" to continue to your destination',
                badge:
                    '${_stopoverNames.length} stop${_stopoverNames.length != 1 ? 's' : ''}',
              ),
            ),
        ],

        // ── Arrived overlay ────────────────────────────────────────
        if (_driveMode && _arrived && _route != null)
          Positioned.fill(child: Container(
            color: Colors.black54,
            child: Center(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ArrivedCard(
                  destName:      _toPlace?.shortName ?? 'Destination',
                  route:         _route!,
                  saving:        _saving,
                  onDone:        _handleArrived,
                  onViewHistory: () async {
                    await _handleArrived();
                    if (mounted) setState(() => _showHistory = true);
                  }),
            )),
          )),

        // ── Stopover modal ─────────────────────────────────────────
        if (_showStopoverModal)
          Positioned.fill(
            child: _StopoverModal(
              userLatLng: _userLatLng,
              onConfirm:  (place) {
                setState(() => _showStopoverModal = false);
                _addStopover(place);
              },
              onClose: () => setState(() => _showStopoverModal = false),
            ),
          ),

        // ── History sidebar ────────────────────────────────────────
        if (_showHistory)
          Positioned.fill(child: HistorySidebar(
              open:     _showHistory,
              token:    _token,
              onReplay: _replayRoute,
              onClose:  () => setState(() => _showHistory = false))),
      ]),
    );
  }

  // ── Info banner helper ───────────────────────────────────────────
  Widget _infoBanner({
    required Color  color,
    required String title,
    required String subtitle,
    String?         badge,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Container(
          width: 8, height: 8,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(height: 1),
              Text(subtitle, style: TextStyle(
                  fontSize: 11, color: color.withValues(alpha: 0.65))),
            ],
          ),
        ),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(badge, style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          ),
      ]),
    );
  }

  Widget _userDotWidget(BuildContext context) {
    final pos = _userScreenPos;
    if (pos == null) return const SizedBox.shrink();
    return Positioned(
      left: pos.dx - 30, top: pos.dy - 30,
      child: IgnorePointer(
        child: _UserDot(
            heading: _userHeading, isSim: _simMode,
            key: const ValueKey('user-dot')),
      ),
    );
  }

  Widget _iconBtn({
    required IconData    icon,
    required Color       color,
    Color?               bg,
    Color?               border,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
          onTap: onTap,
          child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: bg ?? kBG2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: border ?? color.withValues(alpha: 0.35)),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 8)]),
              child: Icon(icon, color: color, size: 18)));

  Widget _mapBtn(IconData icon, VoidCallback onTap,
          {Color color = kTextSoft}) =>
      GestureDetector(
          onTap: onTap,
          child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: kBG2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kBorder),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 8)]),
              child: Icon(icon, color: color, size: 16)));

  Widget _chip(String msg, Color bg, Color fg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: fg.withValues(alpha: 0.25))),
      child: Text(msg, style: TextStyle(color: fg, fontSize: 11)));

  Widget _loadingCard() => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: kBG2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kAccent.withValues(alpha: 0.25)),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 32)]),
      child: Row(children: [
        Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color:        kAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8)),
            child: const Padding(
                padding: EdgeInsets.all(9),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: kAccent))),
        const SizedBox(width: 12),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Calculating route…',
              style: TextStyle(color: kTextSoft, fontSize: 13)),
          Text('Finding fastest driving path',
              style: TextStyle(color: kTextMuted, fontSize: 11)),
        ]),
      ]));

  @override
  void dispose() {
    _stopWatch();
    _stopSim();
    _incidentRefreshTimer?.cancel();
    _voice.dispose();
    _broadcaster.dispose();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DRIVE BOTTOM BAR
// ═══════════════════════════════════════════════════════════════════════════════
class _DriveBottomBar extends StatelessWidget {
  final RouteInfo    route;
  final int          currentStep;
  final bool         showSteps;
  final bool         simMode;
  final bool         saving;
  final bool         isPaused;
  final bool         hasStopover;
  final int          stopoverCount;
  final VoidCallback onToggleSteps;
  final VoidCallback onRecenter;
  final VoidCallback onExit;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStopover;

  const _DriveBottomBar({
    required this.route,
    required this.currentStep,
    required this.showSteps,
    required this.simMode,
    required this.saving,
    required this.isPaused,
    required this.hasStopover,
    required this.stopoverCount,
    required this.onToggleSteps,
    required this.onRecenter,
    required this.onExit,
    required this.onPause,
    required this.onResume,
    required this.onStopover,
  });

  String _fmtDuration(int mins) {
    if (mins >= 60) return '${mins ~/ 60}h ${mins % 60}m';
    return '${mins}min';
  }

  String _arrivalTime(int mins) {
    final t = DateTime.now().add(Duration(minutes: mins));
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final progress =
        (currentStep + 1) / (route.steps.length.clamp(1, 9999));
    final pauseColor    = const Color(0xFF60A5FA);
    final stopoverColor = const Color(0xFFEF9F27);

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      decoration: BoxDecoration(
        color: kBG2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPaused
              ? pauseColor.withValues(alpha: 0.25)
              : kAccent.withValues(alpha: 0.18),
        ),
        boxShadow: [BoxShadow(
            color:  Colors.black.withValues(alpha: 0.5),
            blurRadius: 32, offset: const Offset(0, -4))],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        // Main row
        Row(children: [
          // ETA info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_fmtDuration(route.durationMin),
                    style: const TextStyle(
                        fontSize: 32, fontWeight: FontWeight.w900,
                        color: Colors.white, height: 1,
                        letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text(
                    '${route.distanceKm} km · ${_arrivalTime(route.durationMin)}',
                    style: TextStyle(fontSize: 12, color: kTextMuted)),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Steps toggle
          _btn(
            icon:  Icons.list_rounded,
            color: kTextSoft,
            bg:    Colors.white.withValues(alpha: 0.06),
            onTap: onToggleSteps,
          ),
          const SizedBox(width: 8),

          // Pause / Resume
          _btn(
            icon:  isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            color: isPaused ? const Color(0xFF4ADE80) : pauseColor,
            bg:    isPaused
                ? const Color(0xFF4ADE80).withValues(alpha: 0.15)
                : pauseColor.withValues(alpha: 0.12),
            border: isPaused
                ? const Color(0xFF4ADE80).withValues(alpha: 0.4)
                : pauseColor.withValues(alpha: 0.3),
            onTap:   isPaused ? onResume : onPause,
            tooltip: isPaused ? 'Resume' : 'Pause',
          ),
          const SizedBox(width: 8),

          // Stopover
          Stack(
            clipBehavior: Clip.none,
            children: [
              _btn(
                icon:    Icons.add_location_rounded,
                color:   stopoverColor,
                bg:      stopoverColor.withValues(alpha: 0.12),
                border:  stopoverColor.withValues(alpha: 0.3),
                onTap:   onStopover,
                tooltip: 'Add stopover',
              ),
              if (stopoverCount > 0)
                Positioned(
                  top: 2, right: 2,
                  child: Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: stopoverColor),
                    child: Center(
                      child: Text('$stopoverCount',
                          style: const TextStyle(
                              fontSize: 8, fontWeight: FontWeight.w900,
                              color: Color(0xFF101D33))),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),

          // Recenter
          _btn(
            icon:  Icons.my_location_rounded,
            color: const Color(0xFF101D33),
            bg:    kAccent,
            onTap: onRecenter,
          ),
          const SizedBox(width: 8),

          // Exit
          _btn(
            icon:   Icons.close_rounded,
            color:  const Color(0xFFF87171),
            bg:     const Color(0xFFEF4444).withValues(alpha: 0.14),
            border: const Color(0xFFEF4444).withValues(alpha: 0.3),
            onTap:  onExit,
          ),
        ]),

        const SizedBox(height: 10),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value:           progress.clamp(0.0, 1.0),
            backgroundColor: Colors.white.withValues(alpha: 0.07),
            valueColor: AlwaysStoppedAnimation<Color>(
              isPaused ? pauseColor : kAccent,
            ),
            minHeight: 3,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Step ${currentStep + 1} of ${route.steps.length}',
                style: TextStyle(fontSize: 10, color: kTextMuted)),
            Row(children: [
              if (simMode) ...[
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF4ADE80)),
                ),
                const SizedBox(width: 4),
                const Text('SIMULATING',
                    style: TextStyle(
                        fontSize: 10, color: Color(0xFF4ADE80),
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
              ],
              if (isPaused) ...[
                Container(
                  width: 5, height: 5,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: pauseColor),
                ),
                const SizedBox(width: 3),
                Text('PAUSED',
                    style: TextStyle(
                        fontSize: 10, color: pauseColor,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
              ],
              if (saving) ...[
                SizedBox(
                  width: 10, height: 10,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: kAccent)),
                const SizedBox(width: 4),
                Text('Saving…',
                    style: TextStyle(fontSize: 10, color: kTextMuted)),
              ],
            ]),
          ],
        ),
      ]),
    );
  }

  Widget _btn({
    required IconData      icon,
    required Color         color,
    required Color         bg,
    Color?                 border,
    required VoidCallback  onTap,
    String?                tooltip,
  }) {
    final w = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: border ?? Colors.white.withValues(alpha: 0.06)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
    if (tooltip != null) return Tooltip(message: tooltip, child: w);
    return w;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// USER DOT WIDGET (unchanged)
// ═══════════════════════════════════════════════════════════════════════════════
class _UserDot extends StatefulWidget {
  final double heading;
  final bool   isSim;
  const _UserDot({super.key, required this.heading, this.isSim = false});

  @override
  State<_UserDot> createState() => _UserDotState();
}

class _UserDotState extends State<_UserDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double>   _scale;
  late final Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
    _scale = Tween<double>(begin: 0.45, end: 1.0)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut));
    _fade  = Tween<double>(begin: 0.65, end: 0.0)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.isSim ? const Color(0xFF60A5FA) : const Color(0xFFB8963E);
    return SizedBox(
      width: 60, height: 80,
      child: Stack(alignment: Alignment.topCenter, children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) => Transform.scale(
            scale: _scale.value,
            child: Container(
                width: 58, height: 58,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(_fade.value))),
          ),
        ),
        Container(
            width: 40, height: 40,
            margin: const EdgeInsets.only(top: 9),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.22))),
        Transform.rotate(
          angle: widget.heading * math.pi / 180,
          child: CustomPaint(
              size: const Size(60, 60),
              painter: _UserDotPainter(isSim: widget.isSim)),
        ),
        if (widget.isSim)
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: const Color(0xFF60A5FA),
                  borderRadius: BorderRadius.circular(6)),
              child: const Text('SIM',
                  style: TextStyle(
                      color: Colors.white, fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
            )),
      ]),
    );
  }
}

class _UserDotPainter extends CustomPainter {
  final bool isSim;
  const _UserDotPainter({this.isSim = false});

  @override
  void paint(Canvas canvas, Size size) {
    final cx        = size.width  / 2;
    final cy        = size.height / 2;
    final fillColor =
        isSim ? const Color(0xFF60A5FA) : const Color(0xFFB8963E);
    final radius    = isSim ? 16.0 : 14.0;
    canvas.drawCircle(Offset(cx, cy + 2), radius,
        Paint()..color = Colors.black.withOpacity(0.38));
    canvas.drawCircle(
        Offset(cx, cy), radius, Paint()..color = Colors.white);
    canvas.drawCircle(
        Offset(cx, cy), radius - 4, Paint()..color = fillColor);
    final arrow = Paint()
      ..color      = Colors.white
      ..strokeWidth = 3.0
      ..strokeCap  = StrokeCap.round
      ..style      = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx, cy - radius - 1),
        Offset(cx - 6, cy - radius + 7), arrow);
    canvas.drawLine(Offset(cx, cy - radius - 1),
        Offset(cx + 6, cy - radius + 7), arrow);
  }

  @override
  bool shouldRepaint(_UserDotPainter old) => old.isSim != isSim;
}