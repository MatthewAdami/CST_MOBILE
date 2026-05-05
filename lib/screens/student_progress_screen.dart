// lib/screens/student_progress_screen.dart

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

// ══════════════════════════════════════════════════════════════════
// COLOURS
// ══════════════════════════════════════════════════════════════════
const _kNavy    = Color(0xFF0B1F3A);
const _kPurple  = Color(0xFF7C3AED);
const _kGold    = Color(0xFFC9A84C);
const _kGreen   = Color(0xFF198754);
const _kOrange  = Color(0xFFFD7E14);
const _kRed     = Color(0xFFDC3545);
const _kIndigo  = Color(0xFF6366F1);
const _kWhite   = Color(0xFFFFFFFF);
const _kGray50  = Color(0xFFF8F9FA);
const _kGray100 = Color(0xFFF1F3F5);
const _kGray200 = Color(0xFFE9ECEF);
const _kGray400 = Color(0xFFADB5BD);
const _kGray600 = Color(0xFF6C757D);

// ══════════════════════════════════════════════════════════════════
// STATUS CONFIG
// ══════════════════════════════════════════════════════════════════
class _StatusCfg {
  final String label;
  final Color bg, text, bar;
  const _StatusCfg(this.label, this.bg, this.text, this.bar);
}

const _statusCfg = {
  'pending':   _StatusCfg('Pending Approval', Color(0xFFFEF3C7), Color(0xFF92400E), _kOrange),
  'active':    _StatusCfg('Active',           Color(0xFFD1FAE5), Color(0xFF065F46), _kPurple),
  'completed': _StatusCfg('Completed',        Color(0xFFEEF2FF), Color(0xFF3730A3), _kGreen),
  'dropped':   _StatusCfg('Dropped',          Color(0xFFFEE2E2), Color(0xFF991B1B), _kRed),
};

const _finCfg = {
  'paid':    (bg: Color(0xFFD1FAE5), text: Color(0xFF065F46)),
  'pending': (bg: Color(0xFFFEF3C7), text: Color(0xFF92400E)),
  'overdue': (bg: Color(0xFFFEE2E2), text: Color(0xFF991B1B)),
};

// ══════════════════════════════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════════════════════════════
String _fmtDate(String? iso) {
  if (iso == null) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return '—';
  const m = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${m[d.month - 1]} ${d.day}, ${d.year}';
}

int _pct(Map<String, dynamic> prog) {
  final steps = [prog['theoryDone'], prog['practicalDone'], prog['testPassed']];
  return ((steps.where((s) => s == true).length / 3) * 100).round();
}

Color _scoreColor(int pct) {
  if (pct >= 88) return _kGreen;
  if (pct >= 50) return _kPurple;
  return _kOrange;
}

// ══════════════════════════════════════════════════════════════════
// CIRCULAR PROGRESS PAINTER
// ══════════════════════════════════════════════════════════════════
class _RingPainter extends CustomPainter {
  final double value;
  final Color color;
  const _RingPainter(this.value, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final cx   = size.width / 2;
    final cy   = size.height / 2;
    final r    = (size.width - 10) / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    canvas.drawArc(rect, 0, 2 * math.pi, false,
      Paint()
        ..color       = _kGray200
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 8);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * value, false,
      Paint()
        ..color       = color
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap   = StrokeCap.round);

    final tp = TextPainter(
      text: TextSpan(
        text: '${(value * 100).round()}%',
        style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w800, color: _kNavy),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.value != value;
}

// ══════════════════════════════════════════════════════════════════
// PROGRESS SCREEN
// ══════════════════════════════════════════════════════════════════
class StudentProgressPage extends StatefulWidget {
  const StudentProgressPage({super.key});

  @override
  State<StudentProgressPage> createState() => _StudentProgressPageState();
}

class _StudentProgressPageState extends State<StudentProgressPage> {
  List<Map<String, dynamic>> _enrollments = [];
  bool   _loading = true;
  String _error   = '';
  String _filter  = 'all';
  String _token   = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token') ??
             prefs.getString('auth_token') ??
             prefs.getString('authToken') ??
             prefs.getString('jwt') ??
             '';

    debugPrint('DEBUG ▶ token: $_token');
    debugPrint('DEBUG ▶ url  : ${ApiConfig.enrollments}');

    if (_token.isEmpty) {
      setState(() {
        _loading = false;
        _error   = 'Not logged in. Please log in and try again.';
      });
      return;
    }
    await _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.enrollments),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $_token',
        },
      ).timeout(ApiConfig.timeout);

      debugPrint('DEBUG ▶ status : ${res.statusCode}');
      debugPrint('DEBUG ▶ body   : ${res.body}');

      if (res.statusCode == 200) {
        final dynamic decoded = jsonDecode(res.body);
        List<dynamic> list;
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map) {
          list = (decoded['data']        as List?) ??
                 (decoded['enrollments'] as List?) ??
                 [];
        } else {
          list = [];
        }
        setState(() {
          _enrollments = list
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      } else if (res.statusCode == 401) {
        setState(() => _error = 'Session expired. Please log in again.');
      } else {
        setState(() => _error = 'Server error (${res.statusCode}). Please try again.');
      }
    } on Exception catch (e) {
      debugPrint('DEBUG ▶ error: $e');
      setState(() => _error = 'Network error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── KPIs ──────────────────────────────────────────────────────
  int get _total     => _enrollments.length;
  int get _active    => _enrollments.where((e) => e['status'] == 'active').length;
  int get _completed => _enrollments.where((e) => e['status'] == 'completed').length;
  int get _pending   => _enrollments.where((e) => e['status'] == 'pending').length;

  int get _avgPct {
    if (_enrollments.isEmpty) return 0;
    final sum = _enrollments.fold<int>(0, (acc, e) =>
      acc + _pct(Map<String, dynamic>.from(e['progress'] ?? {})));
    return (sum / _enrollments.length).round();
  }

  List<Map<String, dynamic>> get _filtered => _filter == 'all'
      ? _enrollments
      : _enrollments.where((e) => e['status'] == _filter).toList();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _kGray100,
    body: _loading
        ? const Center(child: CircularProgressIndicator(color: _kPurple))
        : _error.isNotEmpty
            ? _buildError()
            : RefreshIndicator(
                onRefresh: _fetch,
                color: _kPurple,
                child: CustomScrollView(slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          const Text('STUDENT PORTAL',
                            style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: _kPurple, letterSpacing: 1.5)),
                          const SizedBox(height: 4),
                          const Text('My Progress',
                            style: TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w800,
                              color: _kNavy)),
                          const SizedBox(height: 4),
                          const Text(
                            'Track your enrolled courses and training progress',
                            style: TextStyle(fontSize: 13, color: _kGray600)),
                          const SizedBox(height: 20),

                          // ── KPI grid ─────────────────────────
                          // ✅ FIX: use IntrinsicHeight + Row so both
                          //    cards in a row share the same height,
                          //    no GridView childAspectRatio guessing
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: _KpiCard(
                                  label: 'Total Enrolled',
                                  value: '$_total',
                                  icon:  Icons.trending_up,
                                  color: _kPurple,
                                  sub:   'All courses',
                                )),
                                const SizedBox(width: 12),
                                Expanded(child: _KpiCard(
                                  label: 'Active',
                                  value: '$_active',
                                  icon:  Icons.check_circle_outline,
                                  color: _kGreen,
                                  sub:   'Currently training',
                                )),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: _KpiCard(
                                  label: 'Completed',
                                  value: '$_completed',
                                  icon:  Icons.emoji_events_outlined,
                                  color: _kIndigo,
                                  sub:   'Courses finished',
                                )),
                                const SizedBox(width: 12),
                                Expanded(child: _KpiCard(
                                  label: 'Avg Progress',
                                  value: '$_avgPct%',
                                  icon:  Icons.track_changes,
                                  color: _kGold,
                                  sub:   'Across enrollments',
                                )),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Filter chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(children: [
                              _chip('all',       'All ($_total)'),
                              _chip('pending',   'Pending ($_pending)'),
                              _chip('active',    'Active ($_active)'),
                              _chip('completed', 'Completed ($_completed)'),
                              _chip('dropped',   'Dropped'),
                            ]),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // Enrollment cards
                  if (_filtered.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.emoji_events_outlined,
                              size: 48, color: _kGray200),
                            const SizedBox(height: 12),
                            Text(
                              _filter == 'all'
                                  ? "You haven't enrolled in any courses yet."
                                  : 'No $_filter enrollments.',
                              style: const TextStyle(
                                fontSize: 14, color: _kGray400)),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          final e      = _filtered[i];
                          final isLast = i == _filtered.length - 1;
                          return Padding(
                            padding: EdgeInsets.fromLTRB(
                              20, 0, 20, isLast ? 32 : 12),
                            child: _EnrollmentCard(enrollment: e),
                          );
                        },
                        childCount: _filtered.length,
                      ),
                    ),
                ]),
              ),
  );

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 56, color: _kGray400),
          const SizedBox(height: 16),
          Text(_error,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: _kGray600)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _fetch,
            icon:  const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPurple,
              foregroundColor: _kWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _chip(String value, String label) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color:        selected ? _kPurple : _kWhite,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? _kPurple : _kGray200),
        ),
        child: Text(label,
          style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: selected ? _kWhite : _kGray600)),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// KPI CARD
// ✅ FIX: mainAxisSize.max + Spacer pushes content apart naturally
//    without needing a fixed aspect ratio that causes overflow
// ══════════════════════════════════════════════════════════════════
class _KpiCard extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color:        _kWhite,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _kGray200),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 6),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.max, // ✅ fills parent height
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color:        color.withOpacity(.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const Spacer(), // ✅ pushes value/label to bottom
        Text(value,
          style: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.w800,
            color: _kNavy, height: 1)),
        const SizedBox(height: 2),
        Text(label,
          style: const TextStyle(
            fontSize: 9, fontWeight: FontWeight.w700,
            color: _kGray600, letterSpacing: .6)),
        Text(sub,
          style: const TextStyle(fontSize: 9, color: _kGray400),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════════
// ENROLLMENT CARD
// ══════════════════════════════════════════════════════════════════
class _EnrollmentCard extends StatefulWidget {
  final Map<String, dynamic> enrollment;
  const _EnrollmentCard({required this.enrollment});

  @override
  State<_EnrollmentCard> createState() => _EnrollmentCardState();
}

class _EnrollmentCardState extends State<_EnrollmentCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e       = widget.enrollment;
    final course  = Map<String, dynamic>.from(e['courseId']  ?? {});
    final finance = e['financeId'] != null
        ? Map<String, dynamic>.from(e['financeId'] as Map)
        : null;
    final prog   = Map<String, dynamic>.from(e['progress'] ?? {});
    final status = e['status'] as String? ?? 'pending';
    final cfg    = _statusCfg[status] ?? _statusCfg['pending']!;
    final pct    = _pct(prog);
    final color  = _scoreColor(pct);

    return Container(
      decoration: BoxDecoration(
        color:        _kWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: status == 'active'
              ? _kPurple.withOpacity(.25) : _kGray200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 6),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(children: [
        // Color bar
        Container(height: 4, color: cfg.bar),

        // Header
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 72, height: 72,
                  child: CustomPaint(
                    painter: _RingPainter(pct / 100, color))),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8, runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(course['title'] ?? 'Course',
                            style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700,
                              color: _kNavy)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: cfg.bg,
                              borderRadius: BorderRadius.circular(999)),
                            child: Text(cfg.label,
                              style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w700,
                                color: cfg.text)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(spacing: 12, runSpacing: 4, children: [
                        if (course['duration'] != null)
                          _MetaChip('⏱ ${course['duration']['value']} '
                            '${course['duration']['unit']}'),
                        if (course['price'] != null)
                          _MetaChip('💲${course['price']}'),
                        if (e['enrolledAt'] != null)
                          _MetaChip('📅 ${_fmtDate(e['enrolledAt'])}'),
                      ]),
                      const SizedBox(height: 8),

                      if (status == 'active') ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Training progress',
                              style: TextStyle(
                                fontSize: 11, color: _kGray400)),
                            Text(
                              '${[prog['theoryDone'], prog['practicalDone'],
                                prog['testPassed']].where((s) => s == true).length}/3 steps',
                              style: const TextStyle(
                                fontSize: 11, color: _kGray400)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: pct / 100, minHeight: 8,
                            backgroundColor: _kGray100,
                            valueColor:
                              const AlwaysStoppedAnimation(_kPurple)),
                        ),
                      ],

                      if (status == 'completed' && prog['score'] != null)
                        Row(children: [
                          const Icon(Icons.emoji_events,
                            size: 14, color: _kPurple),
                          const SizedBox(width: 5),
                          Text('Final Score: ${prog['score']}%',
                            style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: _kPurple)),
                        ]),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _expanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                  color: _kGray400),
              ],
            ),
          ),
        ),

        // Expanded detail
        if (_expanded)
          Container(
            decoration: const BoxDecoration(
              color:  _kGray50,
              border: Border(top: BorderSide(color: _kGray100)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _DetailHeader('Training Progress'),
                          const SizedBox(height: 10),
                          _ProgressStep('Theory / Classroom',
                            prog['theoryDone'] == true),
                          _ProgressStep('Practical / Range',
                            prog['practicalDone'] == true),
                          _ProgressStep('CDL Test Passed',
                            prog['testPassed'] == true),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _DetailHeader('Payment Info'),
                          const SizedBox(height: 10),
                          if (finance == null)
                            const Text('No payment record linked.',
                              style: TextStyle(
                                fontSize: 13, color: _kGray400))
                          else ...[
                            _FinanceRow('Transaction',
                              finance['transactionId'] ?? '—'),
                            _FinanceRow('Amount',
                              '\$${finance['amount'] ?? '—'}'),
                            _FinanceStatusRow(
                              finance['status'] as String?),
                            if (finance['dueDate'] != null)
                              _FinanceRow('Due Date',
                                _fmtDate(finance['dueDate'] as String?)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                if (e['notes'] != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFED7AA)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline,
                        size: 14, color: Color(0xFF92400E)),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${e['notes']}',
                        style: const TextStyle(
                          fontSize: 13, color: Color(0xFF92400E)))),
                    ]),
                  ),
                ],

                if (e['completedAt'] != null) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.emoji_events,
                      size: 14, color: _kPurple),
                    const SizedBox(width: 6),
                    Text(
                      'Completed on ${_fmtDate(e['completedAt'] as String?)}',
                      style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: _kPurple)),
                  ]),
                ],
              ],
            ),
          ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// SMALL REUSABLE WIDGETS
// ══════════════════════════════════════════════════════════════════
class _MetaChip extends StatelessWidget {
  final String text;
  const _MetaChip(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(fontSize: 12, color: _kGray600));
}

class _DetailHeader extends StatelessWidget {
  final String text;
  const _DetailHeader(this.text);
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
    style: const TextStyle(
      fontSize: 10, fontWeight: FontWeight.w800,
      color: _kNavy, letterSpacing: 1.0));
}

class _ProgressStep extends StatelessWidget {
  final String label;
  final bool done;
  const _ProgressStep(this.label, this.done);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Icon(done ? Icons.check_circle : Icons.access_time,
        size: 16, color: done ? _kGreen : _kGray400),
      const SizedBox(width: 8),
      Expanded(child: Text(label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: done ? FontWeight.w700 : FontWeight.w400,
          color: done ? _kNavy : _kGray400))),
    ]),
  );
}

class _FinanceRow extends StatelessWidget {
  final String label, value;
  const _FinanceRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
          style: const TextStyle(fontSize: 12, color: _kGray600)),
        Flexible(child: Text(value,
          style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: _kNavy),
          textAlign: TextAlign.end)),
      ],
    ),
  );
}

class _FinanceStatusRow extends StatelessWidget {
  final String? status;
  const _FinanceStatusRow(this.status);
  @override
  Widget build(BuildContext context) {
    final cfg = _finCfg[status];
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Status',
            style: TextStyle(fontSize: 12, color: _kGray600)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:        cfg?.bg ?? _kGray100,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text((status ?? '—').toUpperCase(),
              style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: cfg?.text ?? _kGray600)),
          ),
        ],
      ),
    );
  }
}