import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cst_mobile/config/api_config.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _navy   = Color(0xFF0B1F3A);
const _purple = Color(0xFF7C3AED);
const _green  = Color(0xFF16A34A);
const _amber  = Color(0xFFF59E0B);
const _red    = Color(0xFFDC3545);
const _gray50 = Color(0xFFF8F9FA);
const _gray100= Color(0xFFF1F3F5);
const _gray200= Color(0xFFE9ECEF);
const _gray400= Color(0xFFADB5BD);
const _gray600= Color(0xFF6C757D);
const _white  = Color(0xFFFFFFFF);

// ── Color helpers ─────────────────────────────────────────────────────────────
Color _gradeColor(String? g) {
  if (g == null || g == '—' || g.isEmpty) return _gray400;
  if (g.startsWith('A')) return _green;
  if (g.startsWith('B')) return _purple;
  if (g.startsWith('C')) return _amber;
  return _red;
}

Color _readinessColor(num r) {
  if (r >= 85) return _green;
  if (r >= 70) return _purple;
  if (r >= 55) return _amber;
  return _red;
}

Color _scoreColor(num s) {
  if (s >= 85) return _green;
  if (s >= 70) return _purple;
  return _red;
}

String _scoreLabel(num s) {
  if (s >= 85) return 'Excellent';
  if (s >= 70) return 'Pass';
  return 'Needs Work';
}

// ── Models ────────────────────────────────────────────────────────────────────
class GradeScore {
  final String? id, label, notes;
  final double score;
  GradeScore({this.id, this.label, this.notes, required this.score});
  factory GradeScore.fromJson(Map<String, dynamic> j) => GradeScore(
    id: j['_id'], label: j['label'], notes: j['notes'],
    score: (j['score'] ?? 0).toDouble());
}

class GradeProgress {
  final bool? theoryDone, practicalDone, testPassed;
  GradeProgress({this.theoryDone, this.practicalDone, this.testPassed});
  factory GradeProgress.fromJson(Map<String, dynamic> j) => GradeProgress(
    theoryDone:    j['theoryDone'],
    practicalDone: j['practicalDone'],
    testPassed:    j['testPassed']);
}

class GradeData {
  final Map<String, dynamic> enrollment;
  final List<GradeScore> writtenScores, skillsScores;
  final double? writtenAvg, skillsAvg, gpa;
  final int? readiness;
  final String? overallGrade, instructorNotes;
  final GradeProgress? progress;

  GradeData({
    required this.enrollment,
    required this.writtenScores, required this.skillsScores,
    this.writtenAvg, this.skillsAvg, this.gpa,
    this.readiness, this.overallGrade, this.instructorNotes,
    this.progress,
  });

  factory GradeData.fromJson(Map<String, dynamic> j) => GradeData(
    enrollment:      j['enrollment'] ?? {},
    writtenScores:   (j['writtenScores'] as List? ?? []).map((e) => GradeScore.fromJson(e)).toList(),
    skillsScores:    (j['skillsScores']  as List? ?? []).map((e) => GradeScore.fromJson(e)).toList(),
    writtenAvg:      (j['writtenAvg'] as num?)?.toDouble(),
    skillsAvg:       (j['skillsAvg']  as num?)?.toDouble(),
    gpa:             (j['gpa']         as num?)?.toDouble(),
    readiness:       (j['readiness']   as num?)?.toInt(),
    overallGrade:    j['overallGrade'],
    instructorNotes: j['instructorNotes'],
    progress: j['progress'] != null ? GradeProgress.fromJson(j['progress']) : null,
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class StudentGradesScreen extends StatefulWidget {
  final String authToken;
  const StudentGradesScreen({super.key, required this.authToken});

  @override State<StudentGradesScreen> createState() => _StudentGradesScreenState();
}

class _StudentGradesScreenState extends State<StudentGradesScreen> {
  GradeData? _data;
  bool   _loading = true;
  String _error   = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/grades/my-grades'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.authToken}',
        },
      ).timeout(ApiConfig.timeout);

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode != 200) throw Exception(json['message'] ?? 'Failed to load grades.');
      setState(() { _data = GradeData.fromJson(json); _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _gray100,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: _white,
        elevation: 0,
        title: const Row(children: [
          Icon(Icons.school_outlined, color: _purple, size: 20),
          SizedBox(width: 8),
          Text('My Grades', style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w800, color: _white)),
        ]),
      ),
      body: _loading ? _buildLoading()
          : _error.isNotEmpty ? _buildError()
          : _data?.enrollment == null || (_data?.enrollment.isEmpty ?? true) ? _buildEmpty()
          : _buildContent(),
    );
  }

  // ── States ────────────────────────────────────────────────────────────────
  Widget _buildLoading() => const Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(color: _purple, strokeWidth: 2.5),
      SizedBox(height: 16),
      Text('Loading grades...', style: TextStyle(fontSize: 14, color: _gray400)),
    ]),
  );

  Widget _buildError() => Padding(
    padding: const EdgeInsets.all(24),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        border: Border.all(color: const Color(0xFFFECACA)),
        borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Icons.error_outline, color: _red, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(_error,
          style: const TextStyle(fontSize: 14, color: Color(0xFF991B1B)))),
      ]),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 64, height: 64,
          decoration: BoxDecoration(color: _gray100, shape: BoxShape.circle),
          child: const Icon(Icons.school_outlined, size: 28, color: _gray400)),
        const SizedBox(height: 16),
        const Text('No Grades Yet', style: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 8),
        const Text('Your grades will appear here once your instructor starts recording scores.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: _gray600, height: 1.5)),
      ]),
    ),
  );

  // ── Main content ──────────────────────────────────────────────────────────
  Widget _buildContent() {
    final d           = _data!;
    final readColor   = _readinessColor(d.readiness ?? 0);
    final gradeCol    = _gradeColor(d.overallGrade);
    final courseTitle = d.enrollment['courseTitle'] ?? 'CDL Program';

    return RefreshIndicator(
      onRefresh: _load,
      color: _purple,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Subtitle
          Text('$courseTitle · Updated by your instructor',
            style: const TextStyle(fontSize: 13, color: _gray600)),
          const SizedBox(height: 16),

          // ── KPI Cards ──
          _KpiGrid(
            writtenAvg:   d.writtenAvg,
            skillsAvg:    d.skillsAvg,
            readiness:    d.readiness ?? 0,
            overallGrade: d.overallGrade,
            gradeCol:     gradeCol,
            readColor:    readColor,
          ),
          const SizedBox(height: 14),

          // ── GPA + Readiness row ──
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // GPA Ring card
              Expanded(flex: 1, child: _GpaCard(gpa: d.gpa ?? 0)),
              const SizedBox(width: 12),
              // Readiness card
              Expanded(flex: 2, child: _ReadinessCard(
                readiness: d.readiness ?? 0,
                readColor: readColor,
                progress:  d.progress)),
            ]),
          ),
          const SizedBox(height: 14),

          // ── Score Cards ──
          _ScoreCard(
            title:     'Written Exam Scores',
            icon:      Icons.menu_book_outlined,
            iconColor: _purple,
            scores:    d.writtenScores,
            average:   d.writtenAvg,
            isWritten: true,
          ),
          const SizedBox(height: 12),
          _ScoreCard(
            title:     'Skills / Driving Scores',
            icon:      Icons.fact_check_outlined,
            iconColor: _gray600,
            scores:    d.skillsScores,
            average:   d.skillsAvg,
            isWritten: false,
          ),

          // ── Instructor Notes ──
          if (d.instructorNotes != null && d.instructorNotes!.isNotEmpty) ...[
            const SizedBox(height: 14),
            _InstructorNotes(notes: d.instructorNotes!),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// KPI GRID
// ══════════════════════════════════════════════════════════════════════════════
class _KpiGrid extends StatelessWidget {
  final double? writtenAvg, skillsAvg;
  final int readiness;
  final String? overallGrade;
  final Color gradeCol, readColor;

  const _KpiGrid({
    required this.writtenAvg, required this.skillsAvg,
    required this.readiness, required this.overallGrade,
    required this.gradeCol, required this.readColor});

  @override
  Widget build(BuildContext context) {
    final items = [
      _KpiItem(
        label: 'Written Avg',
        value: writtenAvg != null ? '${writtenAvg!.toStringAsFixed(0)}%' : '—',
        icon: Icons.menu_book_outlined,
        color: writtenAvg != null ? _scoreColor(writtenAvg!) : _gray400),
      _KpiItem(
        label: 'Skills Avg',
        value: skillsAvg != null ? '${skillsAvg!.toStringAsFixed(0)}%' : '—',
        icon: Icons.fact_check_outlined,
        color: skillsAvg != null ? _scoreColor(skillsAvg!) : _gray400),
      _KpiItem(
        label: 'CDL Readiness',
        value: '$readiness%',
        icon: Icons.emoji_events_outlined,
        color: readColor),
      _KpiItem(
        label: 'Overall Grade',
        value: overallGrade ?? '—',
        icon: Icons.star_outline_rounded,
        color: gradeCol),
    ];

    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.2,
      children: items.map((item) => Container(
        decoration: BoxDecoration(
          color: _white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _gray200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(width: 38, height: 38,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(item.icon, color: item.color, size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(item.value, style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800, color: item.color, height: 1)),
            const SizedBox(height: 3),
            Text(item.label, style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: _gray400),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
        ]),
      )).toList(),
    );
  }
}

class _KpiItem {
  final String label, value; final IconData icon; final Color color;
  const _KpiItem({required this.label, required this.value,
    required this.icon, required this.color});
}

// ══════════════════════════════════════════════════════════════════════════════
// GPA RING CARD
// ══════════════════════════════════════════════════════════════════════════════
class _GpaCard extends StatelessWidget {
  final double gpa;
  const _GpaCard({required this.gpa});

  @override
  Widget build(BuildContext context) {
    final color = gpa >= 3.5 ? _green : gpa >= 2.7 ? _purple : gpa >= 2.0 ? _amber : _red;
    final emoji = gpa >= 3.5 ? '🏆 Outstanding'
        : gpa >= 3.0 ? '✅ Good Standing'
        : gpa >= 2.0 ? '⚠️ Needs Improvement'
        : '❌ Below Passing';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gray200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
      child: Column(children: [
        _SectionLabel(text: 'GPA'),
        const SizedBox(height: 12),
        _GpaRing(gpa: gpa, color: color),
        const SizedBox(height: 10),
        Text(emoji, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: _gray600, height: 1.3)),
      ]),
    );
  }
}

// ── Animated GPA Ring ─────────────────────────────────────────────────────────
class _GpaRing extends StatefulWidget {
  final double gpa; final Color color;
  const _GpaRing({required this.gpa, required this.color});
  @override State<_GpaRing> createState() => _GpaRingState();
}

class _GpaRingState extends State<_GpaRing> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _anim = Tween<double>(begin: 0, end: math.min(widget.gpa / 4.0, 1.0))
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 90, height: 90,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => CustomPaint(
          painter: _RingPainter(progress: _anim.value, color: widget.color),
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(widget.gpa.toStringAsFixed(2), style: TextStyle(
              fontSize: 19, fontWeight: FontWeight.w800, color: widget.color, height: 1)),
            const Text('GPA', style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w700, color: _gray400)),
          ])),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress; final Color color;
  const _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r  = (size.width - 12) / 2;
    final bg = Paint()
      ..color = _gray200 ..style = PaintingStyle.stroke ..strokeWidth = 9 ..strokeCap = StrokeCap.round;
    final fg = Paint()
      ..color = color   ..style = PaintingStyle.stroke ..strokeWidth = 9 ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), r, bg);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -math.pi / 2, 2 * math.pi * progress, false, fg);
  }

  @override bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ══════════════════════════════════════════════════════════════════════════════
// CDL READINESS CARD
// ══════════════════════════════════════════════════════════════════════════════
class _ReadinessCard extends StatefulWidget {
  final int readiness; final Color readColor; final GradeProgress? progress;
  const _ReadinessCard({required this.readiness, required this.readColor, this.progress});
  @override State<_ReadinessCard> createState() => _ReadinessCardState();
}

class _ReadinessCardState extends State<_ReadinessCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _anim = Tween<double>(begin: 0, end: widget.readiness / 100.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final p = widget.progress;
    final testPassed = p?.testPassed;
    final readMsg = widget.readiness >= 85
        ? '🎉 You are ready to take the CDL test!'
        : widget.readiness >= 70
            ? '📚 Almost there — keep pushing!'
            : '💪 Keep practicing — you\'re making progress.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gray200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionLabel(text: 'CDL Test Readiness'),
        const SizedBox(height: 10),

        // Readiness bar
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Overall Readiness', style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: _gray600)),
          Text('${widget.readiness}%', style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w800, color: widget.readColor)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => LinearProgressIndicator(
              value: _anim.value,
              minHeight: 11,
              backgroundColor: _gray200,
              valueColor: AlwaysStoppedAnimation<Color>(widget.readColor)),
          ),
        ),
        const SizedBox(height: 8),
        Text(readMsg, style: const TextStyle(fontSize: 11, color: _gray600, height: 1.4)),
        const SizedBox(height: 14),

        // Milestones
        Wrap(spacing: 6, runSpacing: 6, children: [
          _Milestone(label: 'Theory Complete',    done: p?.theoryDone    ?? false),
          _Milestone(label: 'Practical Complete', done: p?.practicalDone ?? false),
          _Milestone(label: 'CDL Test Passed',    done: p?.testPassed    ?? false),
          // Test status badge
          if (testPassed == true)
            _StatusBadge(label: 'CDL Passed',     color: _green, bgColor: const Color(0xFFDCFCE7), borderColor: const Color(0xFF86EFAC), icon: Icons.check_circle_outline)
          else if (testPassed == false)
            _StatusBadge(label: 'Test Not Passed', color: _red,  bgColor: const Color(0xFFFEE2E2), borderColor: const Color(0xFFFCA5A5), icon: Icons.cancel_outlined)
          else
            _StatusBadge(label: 'In Training',    color: const Color(0xFFCA8A04), bgColor: const Color(0xFFFEF9C3), borderColor: const Color(0xFFFDE047), icon: Icons.info_outline),
        ]),
      ]),
    );
  }
}

class _Milestone extends StatelessWidget {
  final String label; final bool done;
  const _Milestone({required this.label, required this.done});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: done ? _purple.withOpacity(0.08) : _gray50,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: done ? _purple.withOpacity(0.25) : _gray200)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      done
          ? const Icon(Icons.check_circle_outline, size: 13, color: _purple)
          : Container(width: 13, height: 13,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD1D5DB), width: 2))),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(
        fontSize: 11, fontWeight: done ? FontWeight.w700 : FontWeight.w400,
        color: done ? _purple : _gray400)),
    ]),
  );
}

class _StatusBadge extends StatelessWidget {
  final String label; final Color color, bgColor, borderColor; final IconData icon;
  const _StatusBadge({required this.label, required this.color,
    required this.bgColor, required this.borderColor, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: bgColor, borderRadius: BorderRadius.circular(20),
      border: Border.all(color: borderColor)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// SCORE CARD
// ══════════════════════════════════════════════════════════════════════════════
class _ScoreCard extends StatelessWidget {
  final String title; final IconData icon; final Color iconColor;
  final List<GradeScore> scores; final double? average; final bool isWritten;
  const _ScoreCard({required this.title, required this.icon,
    required this.iconColor, required this.scores,
    required this.average, required this.isWritten});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gray200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: iconColor, size: 17)),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700, color: _navy))),
          if (average != null && scores.isNotEmpty) Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('Average', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: _gray400)),
            Text('${average!.toStringAsFixed(0)}%', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800, color: iconColor)),
          ]),
        ]),
        const SizedBox(height: 16),

        // Empty
        if (scores.isEmpty) Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(children: [
              Container(width: 40, height: 40,
                decoration: BoxDecoration(color: _gray50, shape: BoxShape.circle),
                child: const Icon(Icons.description_outlined, size: 18, color: _gray400)),
              const SizedBox(height: 10),
              const Text('No scores recorded yet',
                style: TextStyle(fontSize: 13, color: _gray400)),
            ]),
          ),
        )
        // Score rows
        else Column(children: [
          ...scores.asMap().entries.map((e) {
            final i = e.key; final s = e.value;
            final col = _scoreColor(s.score);
            final lbl = s.label ?? (isWritten ? 'Exam ${i + 1}' : 'Session ${i + 1}');
            return Padding(
              padding: EdgeInsets.only(bottom: i < scores.length - 1 ? 16 : 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(lbl, style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: _navy)),
                    if (s.notes != null && s.notes!.isNotEmpty) Text(s.notes!,
                      style: const TextStyle(fontSize: 11, color: _gray400, height: 1.3)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: col.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20)),
                    child: Text(_scoreLabel(s.score), style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: col))),
                ]),
                const SizedBox(height: 8),
                _AnimatedBar(value: s.score / 100, color: col),
              ]),
            );
          }),

          // Footer
          if (scores.length > 1) ...[
            const SizedBox(height: 14),
            Container(height: 1, color: _gray100),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${scores.length} score${scores.length != 1 ? 's' : ''} recorded',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _gray400)),
              if (average != null) Text('Avg: ${average!.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: iconColor)),
            ]),
          ],
        ]),
      ]),
    );
  }
}

// ── Animated score bar ────────────────────────────────────────────────────────
class _AnimatedBar extends StatefulWidget {
  final double value; final Color color;
  const _AnimatedBar({required this.value, required this.color});
  @override State<_AnimatedBar> createState() => _AnimatedBarState();
}

class _AnimatedBarState extends State<_AnimatedBar> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _anim = Tween<double>(begin: 0, end: widget.value)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: AnimatedBuilder(
          animation: _anim,
          builder: (_, __) => LinearProgressIndicator(
            value: _anim.value, minHeight: 8,
            backgroundColor: _gray200,
            valueColor: AlwaysStoppedAnimation<Color>(widget.color)),
        ),
      ),
    ),
    const SizedBox(width: 10),
    SizedBox(width: 40, child: Text('${(widget.value * 100).toStringAsFixed(0)}%',
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: widget.color),
      textAlign: TextAlign.right)),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════════
// INSTRUCTOR NOTES
// ══════════════════════════════════════════════════════════════════════════════
class _InstructorNotes extends StatelessWidget {
  final String notes;
  const _InstructorNotes({required this.notes});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _white, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _gray200),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionLabel(text: 'Instructor Notes'),
      const SizedBox(height: 10),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _purple.withOpacity(0.04),
          border: Border.all(color: _purple.withOpacity(0.12)),
          borderRadius: BorderRadius.circular(8)),
        child: Text('"$notes"', style: const TextStyle(
          fontSize: 14, color: Color(0xFF495057),
          height: 1.75, fontStyle: FontStyle.italic)),
      ),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ══════════════════════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 3, height: 15,
      decoration: BoxDecoration(color: _purple, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(text.toUpperCase(), style: const TextStyle(
      fontSize: 10, fontWeight: FontWeight.w800,
      letterSpacing: 1.0, color: _gray400)),
  ]);
}