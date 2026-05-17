import 'dart:async';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class LocationBroadcastService {
  static final LocationBroadcastService _instance =
      LocationBroadcastService._internal();
  factory LocationBroadcastService() => _instance;
  LocationBroadcastService._internal();

  IO.Socket? _socket;
  DateTime?  _lastEmit;
  String?    _token;
  Map<String, dynamic>? _cachedProfile;

  // ── Init: call once from main.dart or StudentMapsScreen.initState ──
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _cachedProfile = _decodeJwt(_token);

    _socket = IO.io(
      ApiConfig.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .build(),
    );
    _socket!.connect();
  }

  // ── Emit location (throttled to once per 3 seconds, same as React) ──
  Future<void> broadcast({
    required List<double> coords,   // [lng, lat]
    required double heading,
    required double speed,          // km/h
    required String status,         // 'driving' | 'idle' | 'offline' | 'sim'
    String? origin,
    String? destination,
    double? distanceKm,
    int?    etaMin,
  }) async {
    final now = DateTime.now();
    if (_lastEmit != null &&
        now.difference(_lastEmit!).inSeconds < 3) return;
    _lastEmit = now;

    final profile = _cachedProfile ?? {};

    final payload = {
      'studentId':   profile['_id']      ?? '',
      'name':        profile['fullName']  ?? 'Student',
      'email':       profile['email']     ?? '',
      'location': {
        'type':        'Point',
        'coordinates': [coords[0], coords[1]],
      },
      'heading':     heading,
      'speed':       speed,
      'status':      status,
      'origin':      origin,
      'destination': destination,
      'distanceKm':  distanceKm,
      'etaMin':      etaMin,
      'updatedAt':   now.toIso8601String(),
    };

    // 1️⃣ Live socket broadcast → Admin monitor receives instantly
    _socket?.emit('student_location_update', payload);

    // 2️⃣ Persist to DB via REST (same as React broadcastLocation)
    if (_token != null) {
      try {
        await http.post(
          Uri.parse('${ApiConfig.baseUrl}/api/student-locations/me'),
          headers: ApiConfig.authHeaders(_token!),
          body: jsonEncode({
            'lng':         coords[0],
            'lat':         coords[1],
            'heading':     heading,
            'speed':       speed,
            'status':      status,
            'origin':      origin,
            'destination': destination,
            'distanceKm':  distanceKm,
            'etaMin':      etaMin,
          }),
        );
      } catch (e) {
        print('DB Sync Error: $e');
      }
    }
  }

  // ── Emit offline/idle (no throttle, send immediately) ──
  void emitIdle() {
    final profile = _cachedProfile ?? {};
    _socket?.emit('student_location_update', {
      'studentId':   profile['_id']     ?? '',
      'name':        profile['fullName'] ?? 'Student',
      'email':       profile['email']    ?? '',
      'heading':     0,
      'speed':       0,
      'status':      'offline',
      'origin':      null,
      'destination': null,
      'distanceKm':  null,
      'etaMin':      null,
      'updatedAt':   DateTime.now().toIso8601String(),
    });
  }

  void dispose() {
    emitIdle();
    _socket?.disconnect();
    _socket?.dispose();
  }

  // ── JWT decode (no external package needed) ──
  Map<String, dynamic>? _decodeJwt(String? token) {
    if (token == null) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      final normalized = base64.normalize(payload);
      final decoded = utf8.decode(base64.decode(normalized));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      // Normalize field names (same logic as React)
      return {
        '_id':      map['_id']      ?? map['id']  ?? map['sub'] ?? '',
        'fullName': map['fullName'] ??
            '${map['firstName'] ?? ''} ${map['lastName'] ?? ''}'.trim().isNotEmpty
                ? '${map['firstName'] ?? ''} ${map['lastName'] ?? ''}'.trim()
                : map['name'] ?? 'Student',
        'email':    map['email']    ?? '',
      };
    } catch (_) {
      return null;
    }
  }
}