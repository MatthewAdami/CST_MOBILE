// lib/screens/student_maps_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;

import '../theme.dart';
import '../models/route_models.dart';
import '../services/map_service.dart';
import '../services/traffic_service.dart';        // ← NEW
import '../widgets/search_panel.dart';
import '../widgets/route_card.dart';
import '../widgets/drive_mode_ui.dart';
import '../widgets/history_sidebar.dart';
import '../widgets/traffic_badge.dart';            // ← NEW
import '../services/voice_guide_service.dart';
// ─────────────────────────────────────────────────────────────────
class StudentMapsScreen extends StatefulWidget {
  const StudentMapsScreen({super.key});

  @override
  State<StudentMapsScreen> createState() => _StudentMapsScreenState();
}

class _StudentMapsScreenState extends State<StudentMapsScreen> {
  // ── Map controller ─────────────────────────────────────────────
  MapLibreMapController? _ctrl;
  bool _styleLoaded = false;
  final _voice = VoiceGuideService();
  bool  _voiceOn = true;
  // ── Location state ─────────────────────────────────────────────
  LatLng? _userLatLng;
  double  _userHeading = 0;
  StreamSubscription<Position>? _posStream;
  String _locStatus = 'locating';
  bool    _markerImagesAdded = false;  
  // ── From / To ──────────────────────────────────────────────────
  bool         _useMyLoc  = true;
  PlaceResult? _fromPlace;
  PlaceResult? _toPlace;
  String _fromQuery = '';
  String _toQuery   = '';

  // ── Route state ────────────────────────────────────────────────
  RouteInfo? _route;
  bool       _routeLoading = false;

  // ── Drive mode ─────────────────────────────────────────────────
  bool    _driveMode   = false;
  int     _currentStep = 0;
  double? _stepDist;
  bool    _showSteps   = false;
  bool    _simMode     = false;
  Timer?  _simTimer;
  int     _simIndex    = 0;
  bool    _saving      = false;

  // ── History sidebar ────────────────────────────────────────────
  bool    _showHistory = false;
  String? _token;

  // ── Map symbols ───────────────────────────────────────────────
  Symbol? _fromSymbol;
  Symbol? _toSymbol;

  // ── User dot overlay ──────────────────────────────────────────
  Offset? _userScreenPos;
  int     _screenPosGen = 0;
  Offset? _driveFixedAnchor;

  // ── Traffic state ──────────────────────────────────────────────  ← NEW
  bool                   _trafficLayerOn    = false;
  bool                   _trafficLoading    = false;
  TrafficLevel?          _routeTrafficLevel;
  List<TrafficIncident>  _incidents         = [];
  Timer?                 _incidentRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadToken();
    _requestLocation();
    _voice.init(); 
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _token = prefs.getString('token'));
  }

  Offset _computeDriveAnchor() {
  final sz = MediaQuery.of(context).size;
  // Move from 0.65 up to 0.55 — puts dot on the visible road ahead
  return Offset(sz.width / 2, sz.height * 0.55);
}

  // ── Traffic layer helpers ──────────────────────────────────────  ← NEW

  /// Adds the TomTom flow heatmap + incident tile layers to the map.
Future<void> _addTrafficLayers() async {
  if (_ctrl == null || !_styleLoaded) return;

  await _ctrl!.addSource(
    'tomtom-flow',
    RasterSourceProperties(
      tiles: [TrafficService.flowTileUrl(style: 'relative0-dark')],
      tileSize: 256,
    ),
  );
  await _ctrl!.addRasterLayer(
    'tomtom-flow',
    'tomtom-flow-layer',
    const RasterLayerProperties(rasterOpacity: 0.75),
  );

  await _ctrl!.addSource(
    'tomtom-incidents',
    RasterSourceProperties(
      tiles: [TrafficService.incidentTileUrl()],
      tileSize: 256,
    ),
  );
  await _ctrl!.addRasterLayer(
    'tomtom-incidents',
    'tomtom-incidents-layer',
    const RasterLayerProperties(rasterOpacity: 0.9),
  );
}

  /// Removes both traffic layers and their sources from the map.
  Future<void> _removeTrafficLayers() async {
    if (_ctrl == null) return;
    for (final id in ['tomtom-flow-layer', 'tomtom-incidents-layer']) {
      try { await _ctrl!.removeLayer(id); } catch (_) {}
    }
    for (final id in ['tomtom-flow', 'tomtom-incidents']) {
      try { await _ctrl!.removeSource(id); } catch (_) {}
    }
  }

  /// Toggle traffic overlay on/off.
  Future<void> _toggleTrafficLayer() async {
    if (_trafficLayerOn) {
      await _removeTrafficLayers();
      _incidentRefreshTimer?.cancel();
      if (mounted) setState(() {
        _trafficLayerOn = false;
        _incidents      = [];
      });
    } else {
      await _addTrafficLayers();
      if (mounted) setState(() => _trafficLayerOn = true);
      // Fetch incidents near current location immediately
      _refreshIncidents();
      // Auto-refresh incidents every 90 seconds to stay within free tier
      _incidentRefreshTimer = Timer.periodic(
        const Duration(seconds: 90), (_) => _refreshIncidents());
    }
  }

  /// Fetch incidents near the user (or map centre).
  Future<void> _refreshIncidents() async {
    final center = _userLatLng;
    if (center == null || !_trafficLayerOn) return;
    final results = await TrafficService.getIncidents(center);
    if (mounted) setState(() => _incidents = results);
  }

  /// Called after a route is built — checks traffic level along the route.
  Future<void> _checkRouteTraffic(RouteInfo route) async {
    if (mounted) setState(() => _trafficLoading = true);
    final level = await TrafficService.checkRouteTraffic(
      route.coordinates,
      sampleEvery: 8,
    );
    if (mounted) setState(() {
      _routeTrafficLevel = level;
      _trafficLoading    = false;
    });
  }

  // ── Permissions & initial location ────────────────────────────
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
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) {
        _onPositionUpdate(pos);
        setState(() => _locStatus = 'found');
      }
    } catch (_) {
      if (mounted) setState(() => _locStatus = 'denied');
    }
  }

  void _onPositionUpdate(Position pos) {
  final ll = LatLng(pos.latitude, pos.longitude);
  if (mounted) {
    setState(() {
      _userLatLng  = ll;
      _userHeading = pos.heading;
      // In drive mode, dot is ALWAYS at the fixed anchor (camera follows user)
      if (_driveMode) _userScreenPos = _driveFixedAnchor;
    });
  }
  if (_driveMode && _ctrl != null) {
  _ctrl!.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
    target: ll,
    zoom: 17,   // ← increased
    tilt: 45,   // ← reduced
    bearing: pos.heading,
  )));
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
    if (_ctrl == null || _userLatLng == null || !_styleLoaded || _driveMode) return;
    final gen = ++_screenPosGen;
    try {
      final pt = await _ctrl!.toScreenLocation(_userLatLng!);
      if (mounted && !_driveMode && gen == _screenPosGen) {
        setState(() => _userScreenPos = Offset(pt.x.toDouble(), pt.y.toDouble()));
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
 
  // ── Voice approach cues ───────────────────────────────────────
  if (d < 200) {
  _voice.speakApproach(_currentStep, step.instruction, d);
}
 
  if (d < 30 && _currentStep < _route!.steps.length - 1) {
    if (mounted) setState(() => _currentStep++);
    // Speak the NEXT step immediately when we advance
    final next = _route!.steps[_currentStep];
    _voice.speakStep(_currentStep, next.instruction);
  }
}

  void _onMapCreated(MapLibreMapController ctrl) => _ctrl = ctrl;
Future<void> _onStyleLoaded() async {
  _markerImagesAdded = false;
  if (mounted) setState(() => _styleLoaded = true);
  await _addCustomMarkerImages(); // must finish before ANY symbol is added
  if (_userLatLng != null && _ctrl != null) {
    await _ctrl!.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: _userLatLng!, zoom: 14)));
    await _refreshUserScreenPos();
  }
}
 Future<void> _addCustomMarkerImages() async {
  if (_markerImagesAdded) return;
  if (_ctrl == null) { debugPrint('❌ _ctrl is null, skipping marker images'); return; }
  if (!_styleLoaded)  { debugPrint('❌ style not loaded, skipping marker images'); return; }
  try {
    await _createPin('pin-green', const Color(0xFF4ADE80));
    await _createPin('pin-gold',  const Color(0xFFB8963E));
    _markerImagesAdded = true;
    debugPrint('✅ Marker images added successfully');
  } catch (e) {
    debugPrint('❌ Failed to add marker images: $e');
  }
}

Future<void> _createPin(String name, Color color) async {
  if (_ctrl == null) return;
  try {
    const w = 80.0;
    const h = 110.0;

    final recorder = ui.PictureRecorder();
    final canvas   = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

    // Drop shadow
    final shadow = Paint()
      ..color      = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawOval(Rect.fromLTWH(w * .2, h * .82, w * .6, h * .12), shadow);

    // Pin body
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

    // White inner circle
    canvas.drawCircle(
      const Offset(cx, cy), r * 0.45,
      Paint()..color = Colors.white,
    );

    final picture = recorder.endRecording();
    final image   = await picture.toImage(w.toInt(), h.toInt());
    final bytes   = await image.toByteData(format: ui.ImageByteFormat.png);

    if (bytes == null) {
      debugPrint('❌ bytes null for $name');
      return;
    }

    await _ctrl!.addImage(name, bytes.buffer.asUint8List());
    debugPrint('✅ Image registered: $name (${bytes.lengthInBytes} bytes)');
  } catch (e) {
    debugPrint('❌ _createPin($name) error: $e');
  }
}
Future<void> _setFromMarker(LatLng ll, {String? label}) async {
  if (_ctrl == null || !_styleLoaded) return;
  await _addCustomMarkerImages();
  if (_fromSymbol != null) await _ctrl!.removeSymbol(_fromSymbol!);
  _fromSymbol = await _ctrl!.addSymbol(SymbolOptions(
    geometry:   ll,
    iconImage:  'pin-green',
    iconSize:   0.6,
    iconAnchor: 'bottom',
    // ← all textField/textColor/textHalo lines REMOVED
  ));
}

Future<void> _setToMarker(LatLng ll, {String? label}) async {
  if (_ctrl == null || !_styleLoaded) return;
  await _addCustomMarkerImages();
  if (_toSymbol != null) await _ctrl!.removeSymbol(_toSymbol!);
  _toSymbol = await _ctrl!.addSymbol(SymbolOptions(
    geometry:   ll,
    iconImage:  'pin-gold',
    iconSize:   0.6,
    iconAnchor: 'bottom',
    // ← all textField/textColor/textHalo lines REMOVED
  ));
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

  Future<void> _buildRoute(
      double fromLon, double fromLat, double toLon, double toLat) async {
    if (mounted) setState(() {
      _routeLoading = true;
      _route        = null;
      _routeTrafficLevel = null;  // ← reset traffic while rebuilding
    });
    final r = await MapService.getRoute(
      fromLon: fromLon, fromLat: fromLat, toLon: toLon, toLat: toLat);
    if (!mounted) return;
    setState(() { _route = r; _routeLoading = false; _currentStep = 0; });
    if (r != null) {
      await _drawRoute(r);
      // ── Check traffic along the new route ─────────────────────  ← NEW
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
      _ctrl?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(p.lat, p.lon), 14));
    }
  }

  Future<void> _onToPicked(PlaceResult p) async {
    if (mounted) setState(() { _toPlace = p; _toQuery = p.shortName; });
await _setToMarker(LatLng(p.lat, p.lon), label: p.shortName);
    final from = _effectiveFrom;
    if (from != null) {
      await _buildRoute(from.longitude, from.latitude, p.lon, p.lat);
    } else {
      _ctrl?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(p.lat, p.lon), 14));
    }
  }

  void _onClearFrom() {
    if (mounted) setState(() {
      _fromPlace = null; _fromQuery = ''; _useMyLoc = true;
      _route = null; _routeTrafficLevel = null;  // ← NEW
    });
    if (_fromSymbol != null) { _ctrl?.removeSymbol(_fromSymbol!); _fromSymbol = null; }
    _ctrl?.clearLines();
  }

  void _onClearTo() {
    if (mounted) setState(() {
      _toPlace = null; _toQuery = '';
      _route = null; _routeTrafficLevel = null;  // ← NEW
    });
    if (_toSymbol != null) { _ctrl?.removeSymbol(_toSymbol!); _toSymbol = null; }
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
      shortName: prevName, lat: from.latitude, lon: from.longitude);
    if (mounted) setState(() {
      _fromPlace = newFrom; _toPlace   = newTo;
      _fromQuery = newFrom.shortName; _toQuery = newTo.shortName;
      _useMyLoc  = false;
    });
    await _setFromMarker(LatLng(newFrom.lat, newFrom.lon), label: newFrom.shortName);
await _setToMarker(LatLng(newTo.lat, newTo.lon), label: newTo.shortName);
    await _buildRoute(newFrom.lon, newFrom.lat, newTo.lon, newTo.lat);
  }

  void _clearAll() {
    _exitDrive();
    if (mounted) setState(() {
      _fromPlace = null; _toPlace  = null; _route    = null;
      _fromQuery = '';   _toQuery  = '';   _useMyLoc = true;
      _currentStep = 0;  _stepDist = null; _showSteps = false;
      _routeTrafficLevel = null; // ← NEW
    });
    if (_fromSymbol != null) { _ctrl?.removeSymbol(_fromSymbol!); _fromSymbol = null; }
    if (_toSymbol   != null) { _ctrl?.removeSymbol(_toSymbol!);   _toSymbol   = null; }
    _ctrl?.clearLines();
  }

  void _enterDrive() {
  final anchor = _computeDriveAnchor();
  if (mounted) setState(() {
    _driveMode        = true;
    _currentStep      = 0;
    _showSteps        = false;
    _driveFixedAnchor = anchor;
    _userScreenPos    = anchor;
    _voice.reset();
  if (_route != null && _route!.steps.isNotEmpty) {
    _voice.speakStep(0, _route!.steps[0].instruction, force: true);
  }
  });
  if (_simMode) _startSim(); else _startWatch();
  final start = _effectiveFrom;
  if (start != null && _ctrl != null) {
    _ctrl!.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
      target: start,
      zoom: 17,      // ← increased from 16
      tilt: 45,      // ← reduced from 50, less extreme angle
      bearing: _userHeading,
    )));
  }
}

  void _exitDrive() {
    final gen = ++_screenPosGen;
    if (mounted) setState(() {
      _driveMode        = false;
      _userScreenPos    = null;
      _driveFixedAnchor = null;
      _voice.reset();

    });
    _stopWatch();
    _stopSim();
    _ctrl?.animateCamera(CameraUpdate.newCameraPosition(
      const CameraPosition(tilt: 0, bearing: 0, zoom: 13,
        target: LatLng(14.6091, 121.0244))));
    if (_route != null) {
      Future.delayed(const Duration(milliseconds: 900),
          () { if (mounted && _route != null) _drawRoute(_route!); });
    }
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted && gen == _screenPosGen) _refreshUserScreenPos();
    });
  }

  void _recenter() {
    final ll = _userLatLng;
    if (ll == null || _ctrl == null) return;
    if (_driveMode) {
      _ctrl!.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: ll, zoom: 16, tilt: 50, bearing: _userHeading)));
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
    final hdg  = math.atan2(next[0] - pt[0], next[1] - pt[1]) * 180 / math.pi;

    if (mounted) {
      setState(() {
        _userLatLng    = ll;
        _userHeading   = hdg;
        _userScreenPos = _driveFixedAnchor; // ← always fixed, camera follows
      });
    }

   _ctrl?.animateCamera(CameraUpdate.newCameraPosition(
  CameraPosition(
    target: ll,
    zoom: 17,   // ← increased
    tilt: 45,   // ← reduced
    bearing: hdg,
  ),
));
    _advanceStep(ll);
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
    _clearAll();
  }

 Future<void> _replayRoute(RouteHistoryEntry entry) async {
  // Close history sidebar first
  if (mounted) setState(() => _showHistory = false);

  // Show loading feedback
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Loading: ${entry.fromName} → ${entry.toName}'),
      backgroundColor: kBG2, behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  // Build PlaceResult for from and to using saved coords
  final fromPlace = PlaceResult(
    displayName: entry.fromName,
    shortName:   entry.fromName,
    lat: entry.fromLat,
    lon: entry.fromLon,
  );
  final toPlace = PlaceResult(
    displayName: entry.toName,
    shortName:   entry.toName,
    lat: entry.toLat,
    lon: entry.toLon,
  );

  // Set state
  if (mounted) setState(() {
    _fromPlace = fromPlace;
    _toPlace   = toPlace;
    _fromQuery = entry.fromName;
    _toQuery   = entry.toName;
    _useMyLoc  = false;
  });

  // Place markers on map
  await _setFromMarker(LatLng(entry.fromLat, entry.fromLon), label: entry.fromName);
  await _setToMarker(LatLng(entry.toLat,   entry.toLon),   label: entry.toName);

  // Build the route
  await _buildRoute(entry.fromLon, entry.fromLat, entry.toLon, entry.toLat);
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
        content:  Text('📍 ${!hasFrom ? "From" : "To"} set: $name'),
        backgroundColor: kBG2, behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ));
    }
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final step = (_route != null && _route!.steps.isNotEmpty)
        ? _route!.steps[_currentStep] : null;
    final nextStep = (_route != null && _currentStep + 1 < _route!.steps.length)
        ? _route!.steps[_currentStep + 1] : null;

    return Scaffold(
      backgroundColor: kBG,
      body: Stack(children: [

        // ── MapLibre map ─────────────────────────────────────────
        MapLibreMap(
          styleString: kMapStyle,
          initialCameraPosition: CameraPosition(
            target: _userLatLng ?? const LatLng(14.6091, 121.0244), zoom: 12),
          onMapCreated:          _onMapCreated,
          onStyleLoadedCallback: _onStyleLoaded,
          onMapClick:            _onMapTap,
          myLocationEnabled:     false,
          trackCameraPosition:   false,
          rotateGesturesEnabled: true,
          tiltGesturesEnabled:   true,
        ),

        // ── User dot overlay ─────────────────────────────────────
        if (_userLatLng != null) _userDotWidget(context),

        // ── Normal mode UI ───────────────────────────────────────
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
              _iconBtn(icon: Icons.history_rounded, color: kAccent,
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

          // ── Map controls (zoom + locate + TRAFFIC TOGGLE) ──────  ← UPDATED
          Positioned(
            right: 12, top: MediaQuery.of(context).padding.top + 140,
            child: Column(children: [
              _mapBtn(Icons.add,    () => _ctrl?.animateCamera(CameraUpdate.zoomIn())),
              const SizedBox(height: 8),
              _mapBtn(Icons.remove, () => _ctrl?.animateCamera(CameraUpdate.zoomOut())),
              const SizedBox(height: 8),
              _mapBtn(Icons.my_location_rounded, _recenter,
                color: _userLatLng != null ? kAccent : kTextSoft),
              const SizedBox(height: 8),
              // ── Traffic heatmap toggle ─────────────────────────  ← NEW
              TrafficLayerToggle(
                isOn:  _trafficLayerOn,
                onTap: _toggleTrafficLayer,
              ),
               const SizedBox(height: 8),
              // ── Voice guide toggle ─────────────────────────────
              GestureDetector(
                onTap: () async {
                  final now = await _voice.toggle();
                  if (mounted) setState(() => _voiceOn = now);
                  // Confirm the new state aloud (only when turning ON)
                  if (now) _voice.speak('Voice guide on');
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color:         _voiceOn
                                    ? kAccent.withValues(alpha: 0.18)
                                    : kBG2,
                    borderRadius:  BorderRadius.circular(8),
                    border: Border.all(
                      color: _voiceOn
                              ? kAccent.withValues(alpha: 0.6)
                              : kBorder,
                    ),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 8,
                    )],
                  ),
                  child: Icon(
                    _voiceOn
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                    color: _voiceOn ? kAccent : kTextSoft,
                    size: 16,
                  ),
                ),
              ),
            ]),
          ),

          if (_locStatus == 'locating')
            Positioned(top: MediaQuery.of(context).padding.top + 130, left: 0, right: 0,
              child: Center(child: _chip('Getting your location…', kBG2, kTextSoft))),
          if (_locStatus == 'denied')
            Positioned(top: MediaQuery.of(context).padding.top + 130, left: 0, right: 0,
              child: Center(child: _chip(
                '⚠ Location denied — set From manually',
                kRed.withValues(alpha: 0.12), kRed))),

          if (_styleLoaded && _toPlace == null && _route == null)
            Positioned.fill(child: IgnorePointer(child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kBorder),
                ),
                child: const Text('Tap map to pin From / To',
                    style: TextStyle(color: kTextMuted, fontSize: 11)),
              ),
            ))),

          // ── Route card + traffic badge ─────────────────────────  ← UPDATED
          if (_toPlace != null || _routeLoading)
            Positioned(bottom: 24, left: 12, right: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Traffic badge appears above route card when we have data
                  if (_routeTrafficLevel != null && !_routeLoading)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 4),
                      child: TrafficBadge(
                        level:          _routeTrafficLevel!,
                        incidentCount:  _incidents.length,
                        onTap: _incidents.isNotEmpty
                            ? () => TrafficIncidentSheet.show(context, _incidents)
                            : null,
                      ),
                    ),

                  if (_trafficLoading && _routeTrafficLevel == null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 4),
                      child: _chip('Checking traffic…', kBG2, kTextMuted),
                    ),

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
            Positioned(bottom: 24, left: 0, right: 0,
              child: Center(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorder),
                ),
                child: const Text('Search above to get driving directions',
                    style: TextStyle(color: kTextMuted, fontSize: 12)),
              ))),
        ],

        // ── Drive mode UI ────────────────────────────────────────
        if (_driveMode && _route != null && !_arrived) ...[
          if (step != null)
            Positioned(top: 0, left: 0, right: 0,
              child: DriveBanner(
                step: step, nextStep: nextStep,
                distToStep: _stepDist, durationMin: _route!.durationMin)),
          Positioned(bottom: 0, left: 0, right: 0,
            child: DriveBottomBar(
              route: _route!, currentStep: _currentStep,
              showSteps: _showSteps, simMode: _simMode, saving: _saving,
              onToggleSteps: () => setState(() => _showSteps = !_showSteps),
              onRecenter: _recenter, onExit: _exitDrive)),
          if (_showSteps)
            Positioned(bottom: 150, left: 10, right: 10,
              child: StepsPanel(
                steps: _route!.steps, currentStep: _currentStep,
                onStepTap: (i) => setState(() { _currentStep = i; _showSteps = false; }),
                onClose:   () => setState(() => _showSteps = false))),
        ],

        // ── Arrived overlay ──────────────────────────────────────
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

        // ── History sidebar ──────────────────────────────────────
        if (_showHistory)
          Positioned.fill(child: HistorySidebar(
            open: _showHistory, token: _token,
            onReplay: _replayRoute,
            onClose:  () => setState(() => _showHistory = false))),
      ]),
    );
  }

  Widget _userDotWidget(BuildContext context) {
    final pos = _userScreenPos;
    if (pos == null) return const SizedBox.shrink();
    return Positioned(
      left: pos.dx - 30, top: pos.dy - 30,
      child: IgnorePointer(
        child: _UserDot(heading: _userHeading, isSim: _simMode,
          key: const ValueKey('user-dot')),
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon, required Color color,
    Color? bg, Color? border, required VoidCallback onTap,
  }) => GestureDetector(onTap: onTap, child: Container(
    width: 40, height: 40,
    decoration: BoxDecoration(
      color: bg ?? kBG2, borderRadius: BorderRadius.circular(8),
      border: Border.all(color: border ?? color.withValues(alpha: 0.35)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8)]),
    child: Icon(icon, color: color, size: 18)));

  Widget _mapBtn(IconData icon, VoidCallback onTap, {Color color = kTextSoft}) =>
    GestureDetector(onTap: onTap, child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: kBG2, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8)]),
      child: Icon(icon, color: color, size: 16)));

  Widget _chip(String msg, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: bg, borderRadius: BorderRadius.circular(20),
      border: Border.all(color: fg.withValues(alpha: 0.25))),
    child: Text(msg, style: TextStyle(color: fg, fontSize: 11)));

  Widget _loadingCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: kBG2, borderRadius: BorderRadius.circular(18),
      border: Border.all(color: kAccent.withValues(alpha: 0.25)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 32)]),
    child: Row(children: [
      Container(width: 36, height: 36,
        decoration: BoxDecoration(
          color: kAccent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8)),
        child: const Padding(padding: EdgeInsets.all(9),
          child: CircularProgressIndicator(strokeWidth: 2, color: kAccent))),
      const SizedBox(width: 12),
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Calculating route…',           style: TextStyle(color: kTextSoft,  fontSize: 13)),
        Text('Finding fastest driving path', style: TextStyle(color: kTextMuted, fontSize: 11)),
      ]),
    ]));

  @override
  void dispose() {
    _stopWatch();
    _stopSim();
    _incidentRefreshTimer?.cancel(); // ← NEW
    _voice.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────
// USER DOT (unchanged)
// ─────────────────────────────────────────────────────────────────
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
      vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _scale = Tween<double>(begin: 0.45, end: 1.0)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut));
    _fade  = Tween<double>(begin: 0.65, end: 0.0)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut));
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final color = widget.isSim ? const Color(0xFF60A5FA) : const Color(0xFFB8963E);
    return SizedBox(
      width: 60, height: 80,
      child: Stack(alignment: Alignment.topCenter, children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) => Transform.scale(
            scale: _scale.value,
            child: Container(width: 58, height: 58,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: color.withOpacity(_fade.value))),
          ),
        ),
        Container(width: 40, height: 40, margin: const EdgeInsets.only(top: 9),
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: color.withOpacity(0.22))),
        Transform.rotate(
          angle: widget.heading * math.pi / 180,
          child: CustomPaint(size: const Size(60, 60),
            painter: _UserDotPainter(isSim: widget.isSim)),
        ),
        if (widget.isSim)
          Positioned(bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFF60A5FA),
                borderRadius: BorderRadius.circular(6)),
              child: const Text('SIM',
                style: TextStyle(color: Colors.white, fontSize: 9,
                  fontWeight: FontWeight.w800, letterSpacing: 0.5)),
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
    final fillColor = isSim ? const Color(0xFF60A5FA) : const Color(0xFFB8963E);
    final radius    = isSim ? 16.0 : 14.0;
    canvas.drawCircle(Offset(cx, cy + 2), radius,
        Paint()..color = Colors.black.withOpacity(0.38));
    canvas.drawCircle(Offset(cx, cy), radius, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(cx, cy), radius - 4, Paint()..color = fillColor);
    final arrow = Paint()
      ..color = Colors.white ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx, cy - radius - 1), Offset(cx - 6, cy - radius + 7), arrow);
    canvas.drawLine(Offset(cx, cy - radius - 1), Offset(cx + 6, cy - radius + 7), arrow);
  }

  @override
  bool shouldRepaint(_UserDotPainter old) => old.isSim != isSim;
}