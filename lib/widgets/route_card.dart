// lib/widgets/route_card.dart
import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/route_models.dart';

String _fmt(double km) => '${km.toStringAsFixed(1)} km';
String _fmtDur(int min) {
  if (min >= 60) return '${min ~/ 60}h ${min % 60}m';
  return '$min min';
}
String _arrivalTime(int min) {
  final d = DateTime.now().add(Duration(minutes: min));
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

class RouteCard extends StatelessWidget {
  final RouteInfo route;
  final String fromName;
  final String toName;
  final bool loading;
  final VoidCallback onStartDrive;
  final VoidCallback onClear;

  const RouteCard({
    super.key,
    required this.route,
    required this.fromName,
    required this.toName,
    required this.loading,
    required this.onStartDrive,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kBG2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kAccent.withOpacity(.25)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.55), blurRadius: 32, offset: const Offset(0, -4))],
      ),
      padding: const EdgeInsets.all(16),
      child: loading ? _loadingRow() : _content(),
    );
  }

  Widget _loadingRow() {
    return Row(
      children: [
        Container(
          width: 36, height: 36, decoration: BoxDecoration(
            color: kAccent.withOpacity(.12), borderRadius: BorderRadius.circular(8)),
          child: const Padding(padding: EdgeInsets.all(9),
            child: CircularProgressIndicator(strokeWidth: 2, color: kAccent)),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('Calculating route…', style: TextStyle(color: kTextSoft, fontSize: 13)),
          Text('Finding fastest driving path', style: TextStyle(color: kTextMuted, fontSize: 11)),
        ]),
      ],
    );
  }

  Widget _content() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── From / To summary ──────────────────────────────────
        Row(
          children: [
            Column(
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle)),
                Container(width: 1.5, height: 16, color: Colors.white12),
                Container(width: 8, height: 8, decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(2))),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fromName, style: const TextStyle(color: kGreen, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Text(toName, style: const TextStyle(color: kAccentLight, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: Colors.white.withOpacity(.05),
                foregroundColor: kTextMuted,
                textStyle: const TextStyle(fontSize: 11),
              ),
              child: const Text('Clear'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Stats row ──────────────────────────────────────────
        Row(
          children: [
            _statTile('Distance',  _fmt(route.distanceKm)),
            const SizedBox(width: 8),
            _statTile('Drive time', _fmtDur(route.durationMin)),
            const SizedBox(width: 8),
            _statTile('Arrive by',  _arrivalTime(route.durationMin)),
          ],
        ),
        const SizedBox(height: 14),

        // ── Start Drive ────────────────────────────────────────
        GestureDetector(
          onTap: onStartDrive,
          child: Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kAccent, kAccentLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: kAccent.withOpacity(.4), blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.directions_car_rounded, color: kNavyDark, size: 22),
                const SizedBox(width: 10),
                const Text('Start Drive',
                  style: TextStyle(color: kNavyDark, fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statTile(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: kLabel),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}