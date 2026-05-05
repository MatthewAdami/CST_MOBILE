// lib/widgets/traffic_badge.dart
//
// UI components for traffic display:
//   • TrafficLayerToggle  — small button to show/hide the heatmap overlay
//   • TrafficBadge        — coloured chip showing current traffic level on route
//   • TrafficIncidentSheet — bottom sheet listing incidents near the user

import 'package:flutter/material.dart';
import '../services/traffic_service.dart';
import '../theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TrafficLayerToggle
// A small icon button placed in the map controls column.
// ─────────────────────────────────────────────────────────────────────────────

class TrafficLayerToggle extends StatelessWidget {
  final bool isOn;
  final VoidCallback onTap;

  const TrafficLayerToggle({
    super.key,
    required this.isOn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isOn ? kAccent.withValues(alpha: 0.18) : kBG2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isOn ? kAccent.withValues(alpha: 0.6) : kBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(
          Icons.traffic_rounded,
          color: isOn ? kAccent : kTextSoft,
          size: 16,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TrafficBadge
// Shows the traffic level on the current route — sits above the RouteCard.
// ─────────────────────────────────────────────────────────────────────────────

class TrafficBadge extends StatelessWidget {
  final TrafficLevel level;
  final int incidentCount;
  final VoidCallback? onTap;

  const TrafficBadge({
    super.key,
    required this.level,
    this.incidentCount = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(
      int.parse(level.color.replaceFirst('#', 'FF'), radix: 16),
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              level.label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (incidentCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$incidentCount incident${incidentCount > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: color, size: 14),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TrafficIncidentSheet
// Bottom sheet listing incidents — shown when user taps the TrafficBadge.
// ─────────────────────────────────────────────────────────────────────────────

class TrafficIncidentSheet extends StatelessWidget {
  final List<TrafficIncident> incidents;

  const TrafficIncidentSheet({super.key, required this.incidents});

  static void show(BuildContext context, List<TrafficIncident> incidents) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kBG2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => TrafficIncidentSheet(incidents: incidents),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Title
            Row(children: [
              const Icon(Icons.warning_amber_rounded, color: kAccent, size: 18),
              const SizedBox(width: 8),
              Text(
                'Traffic incidents nearby',
                style: const TextStyle(
                  color: kTextSoft,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${incidents.length} found',
                style: const TextStyle(color: kTextMuted, fontSize: 11),
              ),
            ]),
            const SizedBox(height: 12),

            if (incidents.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No incidents reported in this area',
                    style: TextStyle(color: kTextMuted, fontSize: 12),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: incidents.length,
                  separatorBuilder: (_, __) => const Divider(
                    color: Color(0xFF2a2a3a),
                    height: 1,
                  ),
                  itemBuilder: (_, i) => _IncidentTile(incident: incidents[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _IncidentTile extends StatelessWidget {
  final TrafficIncident incident;
  const _IncidentTile({required this.incident});

  @override
  Widget build(BuildContext context) {
    final color = Color(
      int.parse(incident.markerColor.replaceFirst('#', 'FF'), radix: 16),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Severity dot
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  incident.description,
                  style: const TextStyle(
                    color: kTextSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (incident.fromRoad != null || incident.toRoad != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      [
                        if (incident.fromRoad != null) 'From: ${incident.fromRoad}',
                        if (incident.toRoad   != null) 'To: ${incident.toRoad}',
                      ].join('  •  '),
                      style: const TextStyle(color: kTextMuted, fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),

          // Delay badge
          if (incident.delay != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                incident.delay!,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}