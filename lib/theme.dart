// lib/theme.dart
import 'package:flutter/material.dart';

// ── Colours matching the React portal tokens ─────────────────────
const Color kAccent      = Color(0xFFB8963E);
const Color kAccentLight = Color(0xFFD4AE5A);
const Color kNavyDark    = Color(0xFF101D33);
const Color kBG          = Color(0xFF1A1A1A);
const Color kBG2         = Color(0xFF262523);
const Color kBorder      = Color(0x0FFFFFFF);
const Color kTextSoft    = Color(0x99FFFFFF);
const Color kTextMuted   = Color(0x59FFFFFF);
const Color kGreen       = Color(0xFF4ADE80);
const Color kRed         = Color(0xFFF87171);

// ── Text styles ──────────────────────────────────────────────────
const TextStyle kLabel = TextStyle(
  fontFamily: 'sans-serif',
  fontSize: 10,
  fontWeight: FontWeight.w700,
  color: kTextMuted,
  letterSpacing: 1.1,
);

// ── MapLibre dark style (free, no key) ──────────────────────────
const String kMapStyle = 'https://tiles.openfreemap.org/styles/dark';

// ── Free OSRM routing endpoint ───────────────────────────────────
const String kOsrmBase = 'https://router.project-osrm.org/route/v1/driving';

// ── Nominatim geocoding ──────────────────────────────────────────
const String kNominatimSearch  = 'https://nominatim.openstreetmap.org/search';
const String kNominatimReverse = 'https://nominatim.openstreetmap.org/reverse';