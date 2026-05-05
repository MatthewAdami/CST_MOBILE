// lib/services/voice_guide_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceGuideService {
  static final VoiceGuideService _instance = VoiceGuideService._internal();
  factory VoiceGuideService() => _instance;
  VoiceGuideService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _enabled = true;
  bool _initialized = false;
  int  _lastSpokenStep = -1; // prevents repeating the same step

  bool get isEnabled => _enabled;

  Future<void> init() async {
    if (_initialized) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);   // slightly slower than default — clearer
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    // On Android, use a network voice if available
    await _tts.setSharedInstance(true);

    _initialized = true;
    debugPrint('🔊 VoiceGuideService initialized');
  }

  /// Toggle voice on/off. Returns the new state.
  Future<bool> toggle() async {
    _enabled = !_enabled;
    if (!_enabled) await _tts.stop();
    debugPrint('🔊 Voice guide: ${_enabled ? "ON" : "OFF"}');
    return _enabled;
  }

  void setEnabled(bool value) {
    _enabled = value;
    if (!_enabled) _tts.stop();
  }

  /// Speak a navigation instruction for a step index.
  /// Will not re-speak the same step unless [force] is true.
  Future<void> speakStep(int stepIndex, String instruction, {bool force = false}) async {
    if (!_enabled) return;
    if (!force && stepIndex == _lastSpokenStep) return;
    _lastSpokenStep = stepIndex;
    await _tts.stop();
    await _tts.speak(_cleanInstruction(instruction));
  }

  /// Speak an arbitrary phrase (e.g. "You have arrived").
  Future<void> speak(String text) async {
    if (!_enabled) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  /// Speak distance + instruction when approaching a maneuver.
  /// Call this when distToStep crosses a threshold (e.g. 200 m, 80 m, 30 m).
  Future<void> speakApproach(int stepIndex, String instruction, double distMeters) async {
    if (!_enabled) return;
    final key = _approachKey(stepIndex, distMeters);
    if (_spokenApproachKeys.contains(key)) return;
    _spokenApproachKeys.add(key);

    String prefix;
    if (distMeters > 150) {
      prefix = 'In ${_formatDist(distMeters)},';
    } else if (distMeters > 60) {
      prefix = 'In ${_formatDist(distMeters)},';
    } else {
      prefix = 'Now,';
    }

    await _tts.stop();
    await _tts.speak('$prefix ${_cleanInstruction(instruction)}');
  }

  /// Called when the user arrives at destination.
  Future<void> speakArrived(String destName) async {
    if (!_enabled) return;
    _spokenApproachKeys.clear();
    _lastSpokenStep = -1;
    await _tts.stop();
    await _tts.speak('You have arrived at $destName.');
  }

  /// Reset tracking (e.g. when a new route starts).
  void reset() {
    _lastSpokenStep = -1;
    _spokenApproachKeys.clear();
    _tts.stop();
  }

  Future<void> dispose() async {
    await _tts.stop();
  }

  // ── Internal helpers ──────────────────────────────────────────

  final Set<String> _spokenApproachKeys = {};

  String _approachKey(int step, double dist) {
    if (dist > 150) return '${step}_far';
    if (dist > 60)  return '${step}_mid';
    return '${step}_near';
  }

  String _formatDist(double meters) {
    if (meters >= 1000) {
      final km = (meters / 1000).toStringAsFixed(1);
      return '$km kilometers';
    }
    final m = meters.round();
    return '$m meters';
  }

  /// Strip HTML tags sometimes returned by routing APIs (e.g. OSRM).
  String _cleanInstruction(String raw) {
    return raw
        .replaceAll(RegExp(r'<[^>]+>'), '')   // strip HTML
        .replaceAll('&amp;', 'and')
        .replaceAll('&lt;',  '<')
        .replaceAll('&gt;',  '>')
        .trim();
  }
}