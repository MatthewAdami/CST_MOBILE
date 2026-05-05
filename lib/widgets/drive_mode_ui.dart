// lib/widgets/drive_mode_ui.dart
import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/route_models.dart';
import 'turn_arrow.dart';

String _fmtDist(double? m) {
  if (m == null) return '—';
  if (m < 1000) return '${m.round()} m';
  return '${(m / 1000).toStringAsFixed(1)} km';
}

String _fmtDur(int min) {
  if (min >= 60) return '${min ~/ 60}h ${min % 60}m';
  return '$min min';
}

String _arrival(int min) {
  final d = DateTime.now().add(Duration(minutes: min));
  return '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
}

// ── Top instruction banner ────────────────────────────────────────
class DriveBanner extends StatelessWidget {
  final RouteStep step;
  final RouteStep? nextStep;
  final double? distToStep;
  final int durationMin;

  const DriveBanner({
    super.key,
    required this.step,
    this.nextStep,
    this.distToStep,
    required this.durationMin,
  });

  @override
  Widget build(BuildContext context) {
    final displayDist = (distToStep != null && distToStep! < step.distance)
        ? distToStep! : step.distance;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Main instruction ──────────────────────────────
              Container(
                color: const Color(0xFF0F2E1E),
                child: Row(
                  children: [
                    // Arrow column
                    Container(
                      width: 88,
                      decoration: const BoxDecoration(
                        border: Border(right: BorderSide(color: Colors.white10)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: TurnArrow(type: step.maneuverType, size: 52, color: kGreen),
                      ),
                    ),
                    // Distance + street
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _fmtDist(displayDist),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                height: 1,
                                letterSpacing: -.5,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              step.name.isEmpty ? 'Continue on route' : step.name,
                              style: const TextStyle(color: kGreen, fontSize: 17, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // ETA
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('ARRIVE', style: kLabel),
                          const SizedBox(height: 3),
                          Text(_arrival(durationMin),
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ── Then row ──────────────────────────────────────
              if (nextStep != null)
                Container(
                  color: Colors.black38,
                  padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
                  child: Row(
                    children: [
                      Text('Then  ', style: kLabel),
                      TurnArrow(type: nextStep!.maneuverType, size: 22, color: Colors.white38),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          nextStep!.name.isEmpty ? 'Continue' : nextStep!.name,
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(_fmtDist(nextStep!.distance),
                          style: const TextStyle(color: Colors.white30, fontSize: 11)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bottom drive bar ──────────────────────────────────────────────
class DriveBottomBar extends StatelessWidget {
  final RouteInfo route;
  final int currentStep;
  final bool showSteps;
  final bool simMode;
  final bool saving;
  final VoidCallback onToggleSteps;
  final VoidCallback onRecenter;
  final VoidCallback onExit;

  const DriveBottomBar({
    super.key,
    required this.route,
    required this.currentStep,
    required this.showSteps,
    required this.simMode,
    required this.saving,
    required this.onToggleSteps,
    required this.onRecenter,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (currentStep + 1) / (route.steps.length.clamp(1, 9999));

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Container(
          decoration: BoxDecoration(
            color: kBG2,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kAccent.withOpacity(.18)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.5), blurRadius: 24, offset: const Offset(0, -4))],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _fmtDur(route.durationMin),
                          style: const TextStyle(
                            color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -.5, height: 1),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${route.distanceKm.toStringAsFixed(1)} km · ${_arrival(route.durationMin)}',
                          style: const TextStyle(color: kTextMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                  // Steps toggle
                  _iconBtn(
                    onTap: onToggleSteps,
                    child: const Icon(Icons.list_rounded, color: kTextSoft, size: 20),
                  ),
                  const SizedBox(width: 8),

                  // Re-center
                  GestureDetector(
                    onTap: onRecenter,
                    child: Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        color: kAccent, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.my_location_rounded, color: kNavyDark, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Exit
                  _iconBtn(
                    color: kRed.withOpacity(.14),
                    border: kRed.withOpacity(.3),
                    onTap: onExit,
                    child: const Icon(Icons.close_rounded, color: kRed, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(kAccent),
                  minHeight: 3,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Step ${currentStep + 1} of ${route.steps.length}',
                      style: const TextStyle(color: kTextMuted, fontSize: 10)),
                  if (simMode)
                    Row(children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      const Text('SIMULATING', style: TextStyle(color: kGreen, fontSize: 10, fontWeight: FontWeight.w700)),
                    ]),
                  if (saving)
                    Row(children: [
                      const SizedBox(width: 10, height: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: kAccentLight)),
                      const SizedBox(width: 5),
                      const Text('Saving…', style: TextStyle(color: kAccentLight, fontSize: 10)),
                    ]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBtn({required Widget child, required VoidCallback onTap, Color? color, Color? border}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
          color: color ?? Colors.white.withOpacity(.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border ?? kBorder),
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ── Steps list panel ──────────────────────────────────────────────
class StepsPanel extends StatelessWidget {
  final List<RouteStep> steps;
  final int currentStep;
  final void Function(int) onStepTap;
  final VoidCallback onClose;

  const StepsPanel({
    super.key,
    required this.steps,
    required this.currentStep,
    required this.onStepTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kBG2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.65), blurRadius: 32, offset: const Offset(0, -8))],
      ),
      constraints: const BoxConstraints(maxHeight: 280),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 6),
            child: Row(
              children: [
                Text('TURN-BY-TURN', style: kLabel),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 14, color: kTextMuted),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: kBorder),
          // List
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: steps.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: kBorder),
              itemBuilder: (_, i) {
                final s = steps[i];
                final active = i == currentStep;
                return InkWell(
                  onTap: () => onStepTap(i),
                  child: Container(
                    color: active ? kAccent.withOpacity(.1) : Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: active ? kAccent.withOpacity(.18) : Colors.white.withOpacity(.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: TurnArrow(
                              type: s.maneuverType, size: 24,
                              color: active ? kAccentLight : Colors.white38),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.name.isEmpty ? 'Continue' : s.name,
                                style: TextStyle(
                                  color: active ? Colors.white : kTextSoft,
                                  fontSize: 13,
                                  fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(_fmtDist(s.distance),
                                  style: const TextStyle(color: kTextMuted, fontSize: 11)),
                            ],
                          ),
                        ),
                        if (active)
                          Container(width: 7, height: 7,
                            decoration: const BoxDecoration(color: kAccent, shape: BoxShape.circle)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Arrived card ──────────────────────────────────────────────────
class ArrivedCard extends StatelessWidget {
  final String destName;
  final RouteInfo route;
  final bool saving;
  final VoidCallback onDone;
  final VoidCallback onViewHistory;

  const ArrivedCard({
    super.key,
    required this.destName,
    required this.route,
    required this.saving,
    required this.onDone,
    required this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: kBG2,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kGreen.withOpacity(.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.7), blurRadius: 48)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 10),
          const Text("You've arrived!",
              style: TextStyle(color: kGreen, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(destName,
              style: const TextStyle(color: kTextMuted, fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('${route.distanceKm.toStringAsFixed(1)} km · ${_fmtDur(route.durationMin)}',
              style: const TextStyle(color: kTextMuted, fontSize: 11)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onViewHistory,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kAccentLight,
                    side: BorderSide(color: kAccent.withOpacity(.3)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('View History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: saving ? null : onDone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent,
                    foregroundColor: kNavyDark,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(saving ? 'Saving…' : 'Done',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}