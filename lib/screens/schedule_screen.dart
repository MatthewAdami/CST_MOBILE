import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════
// COLOURS
// ══════════════════════════════════════════════════════════════════
const _navy   = Color(0xFF0B1F3A);
const _purple = Color(0xFF7C3AED);
const _white  = Color(0xFFFFFFFF);
const _gray50 = Color(0xFFF8F9FA);
const _gray100= Color(0xFFF1F3F5);
const _gray200= Color(0xFFE9ECEF);
const _gray400= Color(0xFFADB5BD);
const _gray600= Color(0xFF6C757D);
const _gray800= Color(0xFF343A40);
const _green  = Color(0xFF28A745);
const _statusDone     = Color(0xFF6C757D);
const _statusOngoing  = Color(0xFF28A745);
const _statusUpcoming = Color(0xFF7C3AED);

// ══════════════════════════════════════════════════════════════════
// DATA MODEL
// ══════════════════════════════════════════════════════════════════
enum SessionStatus { done, ongoing, upcoming }

class Session {
  final int id, day;
  final String title, start, end, location, instructor;
  final SessionStatus status;

  const Session({
    required this.id, required this.day, required this.title,
    required this.start, required this.end, required this.location,
    required this.instructor, required this.status,
  });
}

// ══════════════════════════════════════════════════════════════════
// MOCK DATA
// ══════════════════════════════════════════════════════════════════
const _sessions = [
  Session(id:1, day:1, title:'Class A CDL — Pre-Trip Inspection',  start:'07:00', end:'09:00', location:'Yard A — Bay 3',        instructor:'Andrew Cooper', status:SessionStatus.done),
  Session(id:2, day:1, title:'Class A CDL — Basic Controls',        start:'10:00', end:'12:00', location:'Training Room 1',       instructor:'Andrew Cooper', status:SessionStatus.done),
  Session(id:3, day:2, title:'Hazmat Awareness — Module 1',          start:'08:00', end:'10:30', location:'Classroom B',           instructor:'Andrew Cooper', status:SessionStatus.done),
  Session(id:4, day:3, title:'Class A CDL — Road Maneuvers',         start:'07:00', end:'11:00', location:'Yard A — Track 2',      instructor:'Andrew Cooper', status:SessionStatus.ongoing),
  Session(id:5, day:3, title:'Class B CDL — City Driving',           start:'13:00', end:'16:00', location:'Route 9 Circuit',       instructor:'Andrew Cooper', status:SessionStatus.upcoming),
  Session(id:6, day:4, title:'Hazmat — Handling & Placarding',       start:'09:00', end:'11:30', location:'Classroom B',           instructor:'Andrew Cooper', status:SessionStatus.upcoming),
  Session(id:7, day:4, title:'Class A CDL — Backing Skills',         start:'13:00', end:'17:00', location:'Yard A — Bay 1',        instructor:'Andrew Cooper', status:SessionStatus.upcoming),
  Session(id:8, day:5, title:'CDL Knowledge Test Prep',              start:'08:00', end:'10:00', location:'Training Room 1',       instructor:'Andrew Cooper', status:SessionStatus.upcoming),
  Session(id:9, day:6, title:'Class A CDL — Skills Evaluation',      start:'07:00', end:'12:00', location:'Yard A — Full Circuit', instructor:'Andrew Cooper', status:SessionStatus.upcoming),
];

const _days     = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const _fullDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const _hours    = ['07:00','08:00','09:00','10:00','11:00','12:00','13:00','14:00','15:00','16:00','17:00'];

// ══════════════════════════════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════════════════════════════
int _toMin(String t) {
  final parts = t.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

Color _statusColor(SessionStatus s) {
  switch (s) {
    case SessionStatus.done:     return _statusDone;
    case SessionStatus.ongoing:  return _statusOngoing;
    case SessionStatus.upcoming: return _statusUpcoming;
  }
}

Color _statusBg(SessionStatus s) {
  switch (s) {
    case SessionStatus.done:     return _gray100;
    case SessionStatus.ongoing:  return const Color(0xFFD4EDDA);
    case SessionStatus.upcoming: return Color.fromRGBO(124, 58, 237, 0.09);
  }
}

String _statusLabel(SessionStatus s) {
  switch (s) {
    case SessionStatus.done:     return 'Completed';
    case SessionStatus.ongoing:  return 'Ongoing';
    case SessionStatus.upcoming: return 'Upcoming';
  }
}

IconData _statusIcon(SessionStatus s) {
  switch (s) {
    case SessionStatus.done:     return Icons.check_circle;
    case SessionStatus.ongoing:  return Icons.error;
    case SessionStatus.upcoming: return Icons.access_time;
  }
}

// ══════════════════════════════════════════════════════════════════
// ENTRY (standalone — remove if integrating into dashboard)
// ══════════════════════════════════════════════════════════════════
void main() => runApp(MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(colorSchemeSeed: _purple, useMaterial3: true),
  home: const ScheduleScreen(),
));

// ══════════════════════════════════════════════════════════════════
// SCHEDULE SCREEN
// ══════════════════════════════════════════════════════════════════
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  int? _selectedDay; // 1-based; null = show all

  List<Session> get _filtered =>
      _selectedDay == null ? _sessions : _sessions.where((s) => s.day == _selectedDay).toList();

  List<Session> get _upcoming {
  final list = _filtered.toList() // ← copy first
    ..sort((a, b) {
      final dc = a.day.compareTo(b.day);
      return dc != 0 ? dc : _toMin(a.start).compareTo(_toMin(b.start));
    });
  return list
      .where((s) => s.status == SessionStatus.upcoming || s.status == SessionStatus.ongoing)
      .toList();
}

List<Session> get _completed {
  return (_filtered.toList() // ← copy first
    ..sort((a, b) {
      final dc = a.day.compareTo(b.day);
      return dc != 0 ? dc : _toMin(a.start).compareTo(_toMin(b.start));
    }))
      .where((s) => s.status == SessionStatus.done)
      .toList();
}

  int get _totalCount    => _sessions.length;
  int get _doneCount     => _sessions.where((s) => s.status == SessionStatus.done).length;
  int get _ongoingCount  => _sessions.where((s) => s.status == SessionStatus.ongoing).length;
  int get _upcomingCount => _sessions.where((s) => s.status == SessionStatus.upcoming).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _gray100,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.calendar_month, color: _purple, size: 22),
                      const SizedBox(width: 8),
                      const Text('My Schedule',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                          color: _navy)),
                    ]),
                    const SizedBox(height: 4),
                    const Text('Week of April 7 – 12, 2026',
                      style: TextStyle(fontSize: 13, color: _gray600)),
                    const SizedBox(height: 20),

                    // ── Stat pills ────────────────────────────────
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _StatPill(label: 'Total Sessions', value: _totalCount,  color: _navy),
                          _StatPill(label: 'Completed',      value: _doneCount,    color: _statusDone),
                          _StatPill(label: 'Ongoing',        value: _ongoingCount, color: _statusOngoing),
                          _StatPill(label: 'Upcoming',       value: _upcomingCount,color: _statusUpcoming),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Weekly View title + clear filter ──────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Weekly View',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                            color: _navy)),
                        if (_selectedDay != null)
                          GestureDetector(
                            onTap: () => setState(() => _selectedDay = null),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Color.fromRGBO(124, 58, 237, 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Color.fromRGBO(124, 58, 237, 0.3)),
                              ),
                              child: Text(
                                'Clear filter — ${_fullDays[_selectedDay! - 1]}',
                                style: const TextStyle(fontSize: 11,
                                  fontWeight: FontWeight.w700, color: _purple)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text('Tap a day header to filter sessions below.',
                      style: TextStyle(fontSize: 12, color: _gray400)),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // ── Weekly Grid ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _WeeklyGrid(
                  sessions: _sessions,
                  selectedDay: _selectedDay,
                  onSelectDay: (d) => setState(() =>
                    _selectedDay = _selectedDay == d ? null : d),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // ── Upcoming & Ongoing ────────────────────────────────
            if (_upcoming.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: Row(children: [
                    const Text('Upcoming & Ongoing',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                        color: _navy)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(124, 58, 237, 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${_upcoming.length}',
                        style: const TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w700, color: _purple)),
                    ),
                  ]),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: _SessionCard(session: _upcoming[i]),
                  ),
                  childCount: _upcoming.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
            ],

            // ── Completed ─────────────────────────────────────────
            if (_completed.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: Row(children: [
                    const Text('Completed',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                        color: _gray600)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _gray100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${_completed.length}',
                        style: const TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w700, color: _gray600)),
                    ),
                  ]),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: _SessionCard(session: _completed[i]),
                  ),
                  childCount: _completed.length,
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// STAT PILL
// ══════════════════════════════════════════════════════════════════
class _StatPill extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 10),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    decoration: BoxDecoration(
      color: _white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _gray200),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 4)],
    ),
    child: Row(
      children: [
        Text('$value',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(width: 10),
        Text(label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: _gray600)),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════════
// WEEKLY GRID
// ══════════════════════════════════════════════════════════════════
class _WeeklyGrid extends StatelessWidget {
  final List<Session> sessions;
  final int? selectedDay;
  final ValueChanged<int> onSelectDay;

  static const double _rowH  = 64.0;
  static const double _timeW = 52.0;

  const _WeeklyGrid({
    required this.sessions, required this.selectedDay, required this.onSelectDay,
  });

  @override
  Widget build(BuildContext context) {
    final totalH = _hours.length * _rowH;

    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gray200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 4)],
      ),
      child: Column(
        children: [
          // ── Day header row ──
          Container(
            decoration: const BoxDecoration(
              color: _gray50,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: _gray200, width: 2)),
            ),
            child: Row(
              children: [
                SizedBox(width: _timeW), // time gutter
                ...List.generate(6, (i) {
                  final dayNum   = i + 1;
                  final hasItems = sessions.any((s) => s.day == dayNum);
                  final isActive = selectedDay == dayNum;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onSelectDay(dayNum),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Color.fromRGBO(124, 58, 237, 0.06)
                              : Colors.transparent,
                          border: Border(
                            left: const BorderSide(color: _gray200),
                            bottom: BorderSide(
                              color: isActive ? _purple : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(_days[i],
                              style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: isActive ? _purple : _gray400,
                                letterSpacing: .8,
                              )),
                            if (hasItems)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                width: 5, height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isActive ? _purple : _gray400,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // ── Grid body ──
          SizedBox(
            height: totalH,
            child: SingleChildScrollView(
              child: SizedBox(
                height: totalH,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time labels
                    SizedBox(
                      width: _timeW,
                      child: Stack(
                        children: List.generate(_hours.length, (i) => Positioned(
                          top: i * _rowH - 8,
                          right: 8, left: 0,
                          child: Text(_hours[i],
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 9,
                              color: _gray400, fontWeight: FontWeight.w600)),
                        )),
                      ),
                    ),

                    // Day columns
                    ...List.generate(6, (colIdx) {
                      final dayNum     = colIdx + 1;
                      final daySessions = sessions.where((s) => s.day == dayNum).toList();
                      final isActive   = selectedDay == dayNum;

                      return Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: isActive
                                ? Color.fromRGBO(124, 58, 237, 0.02)
                                : Colors.transparent,
                            border: const Border(
                              left: BorderSide(color: Color(0xFFF1F3F5))),
                          ),
                          child: Stack(
                            children: [
                              // Hour grid lines
                              ...List.generate(_hours.length, (i) => Positioned(
                                top: i * _rowH, left: 0, right: 0,
                                child: const Divider(height: 1, color: Color(0xFFF1F3F5)),
                              )),

                              // Session blocks
                              ...daySessions.map((s) {
                                final top = (((_toMin(s.start) - 7 * 60) / 60) * _rowH) + 2;
                                final height = ((_toMin(s.end) - _toMin(s.start)) / 60 * _rowH - 4)
                                    .clamp(24.0, double.infinity);
                                final color = _statusColor(s.status);
                                final bg    = _statusBg(s.status);

                                return Positioned(
                                  top: top, left: 3, right: 3,
                                  height: height,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: bg,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border(
                                        left: BorderSide(color: color, width: 3),
                                        top: BorderSide(
                                          color: color.withOpacity(.3), width: 1),
                                        right: BorderSide(
                                          color: color.withOpacity(.3), width: 1),
                                        bottom: BorderSide(
                                          color: color.withOpacity(.3), width: 1),
                                      ),
                                    ),
                                    padding: const EdgeInsets.fromLTRB(5, 4, 4, 4),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(s.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 9, fontWeight: FontWeight.w700,
                                            color: _navy, height: 1.3)),
                                        if (height > 38)
                                          Text('${s.start}–${s.end}',
                                            style: const TextStyle(
                                              fontSize: 8, color: _gray600)),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// SESSION CARD
// ══════════════════════════════════════════════════════════════════
class _SessionCard extends StatelessWidget {
  final Session session;
  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(session.status);
    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: color, width: 4),
          top:    BorderSide(color: _gray200),
          right:  BorderSide(color: _gray200),
          bottom: BorderSide(color: _gray200),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 4)],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon box
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: session.status == SessionStatus.done
                      ? _gray100
                      : Color.fromRGBO(124, 58, 237, 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.menu_book,
                  size: 16,
                  color: session.status == SessionStatus.done ? _gray400 : _purple),
              ),
              const SizedBox(width: 10),

              // Title + day
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                      color: _navy, height: 1.3)),
                  const SizedBox(height: 2),
                  Text(_fullDays[session.day - 1],
                    style: const TextStyle(fontSize: 12, color: _gray600)),
                ],
              )),
              const SizedBox(width: 8),

              // Status badge
              _StatusBadge(status: session.status),
            ],
          ),

          // Divider
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFF1F3F5)),
          ),

          // Details row
          Wrap(
            spacing: 16, runSpacing: 8,
            children: [
              _DetailChip(icon: Icons.access_time, color: _purple,
                label: '${session.start} – ${session.end}'),
              _DetailChip(icon: Icons.location_on_outlined, color: _purple,
                label: session.location),
              _DetailChip(icon: Icons.person_outline, color: _purple,
                label: session.instructor),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Status Badge ──────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final SessionStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    final bg    = _statusBg(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), size: 10, color: color),
          const SizedBox(width: 4),
          Text(_statusLabel(status).toUpperCase(),
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
              color: color, letterSpacing: .6)),
        ],
      ),
    );
  }
}

// ── Detail Chip ───────────────────────────────────────────────────
class _DetailChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _DetailChip({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 5),
      Text(label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
          color: _gray800)),
    ],
  );
}