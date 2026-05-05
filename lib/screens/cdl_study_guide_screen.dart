import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:cst_mobile/config/api_config.dart';

// ── Colours ───────────────────────────────────────────────────────────────────
const _navy   = Color(0xFF0B1F3A);
const _purple = Color(0xFF7C3AED);
const _teal   = Color(0xFF0E9F8E);
const _gold   = Color(0xFFB8963E);
const _green  = Color(0xFF059669);
const _red    = Color(0xFFDC2626);
const _orange = Color(0xFFD97706);
const _gray50 = Color(0xFFF8F9FA);
const _gray100 = Color(0xFFF1F3F5);
const _gray200 = Color(0xFFE5E7EB);
const _gray400 = Color(0xFF9CA3AF);
const _gray600 = Color(0xFF6B7280);
const _gray800 = Color(0xFF374151);
const _white  = Color(0xFFFFFFFF);

const _sectionColors = [
  Color(0xFF7C3AED), Color(0xFF0E9F8E), Color(0xFF2563EB), Color(0xFFD97706),
  Color(0xFFDC2626), Color(0xFF059669), Color(0xFF0891B2), Color(0xFFEA580C),
  Color(0xFF4F46E5), Color(0xFFB8963E), Color(0xFF7C3AED), Color(0xFF0E9F8E),
  Color(0xFFDC2626),
];

// ── Models ────────────────────────────────────────────────────────────────────
class StudySection {
  final String id;
  final int sectionNumber;
  final String title;
  final String description;
  final List<String> keyPoints;
  final int questionCount;

  StudySection({
    required this.id, required this.sectionNumber, required this.title,
    required this.description, required this.keyPoints, required this.questionCount,
  });

  factory StudySection.fromJson(Map<String, dynamic> j) => StudySection(
    id: j['_id']?.toString() ?? '',
    sectionNumber: j['sectionNumber'] ?? 0,
    title: j['title'] ?? '',
    description: j['description'] ?? '',
    keyPoints: List<String>.from(j['keyPoints'] ?? []),
    questionCount: j['questionCount'] ?? 0,
  );
}

class SectionProgress {
  final String sectionId;
  final int bestScore;
  final bool passed;

  SectionProgress({required this.sectionId, required this.bestScore, required this.passed});

  factory SectionProgress.fromJson(Map<String, dynamic> j) => SectionProgress(
    sectionId: j['sectionId']?.toString() ?? '',
    bestScore: j['bestScore'] ?? 0,
    passed: j['passed'] ?? false,
  );
}

class Question {
  final String id;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String? explanation;
  final String? difficulty;

  Question({
    required this.id, required this.question, required this.options,
    required this.correctIndex, this.explanation, this.difficulty,
  });

  factory Question.fromJson(Map<String, dynamic> j) => Question(
    id: j['_id']?.toString() ?? '',
    question: j['question'] ?? '',
    options: List<String>.from(j['options'] ?? []),
    correctIndex: j['correctIndex'] ?? 0,
    explanation: j['explanation'],
    difficulty: j['difficulty'],
  );
}

class QuizResultQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int correctIndex;
  final int selectedIndex;
  final bool isCorrect;
  final String? explanation;

  QuizResultQuestion({
    required this.id, required this.question, required this.options,
    required this.correctIndex, required this.selectedIndex,
    required this.isCorrect, this.explanation,
  });

  factory QuizResultQuestion.fromJson(Map<String, dynamic> j) => QuizResultQuestion(
    id: j['_id']?.toString() ?? '',
    question: j['question'] ?? '',
    options: List<String>.from(j['options'] ?? []),
    correctIndex: j['correctIndex'] ?? 0,
    selectedIndex: j['selectedIndex'] ?? 0,
    isCorrect: j['isCorrect'] ?? false,
    explanation: j['explanation'],
  );
}

class QuizAttemptResult {
  final int score, total, percentage;
  final bool passed;
  final List<QuizResultQuestion> questions;

  QuizAttemptResult({
    required this.score, required this.total, required this.percentage,
    required this.passed, required this.questions,
  });

  factory QuizAttemptResult.fromJson(Map<String, dynamic> j) => QuizAttemptResult(
    score: j['score'] ?? 0,
    total: j['total'] ?? 0,
    percentage: j['percentage'] ?? 0,
    passed: j['passed'] ?? false,
    questions: (j['questions'] as List? ?? [])
        .map((q) => QuizResultQuestion.fromJson(q)).toList(),
  );
}

// ── Auth helper ───────────────────────────────────────────────────────────────
Future<String> _getToken() async {
  final p = await SharedPreferences.getInstance();
  return p.getString('token') ?? '';
}

Map<String, String> _authHeaders(String token) => ApiConfig.authHeaders(token);

// ═════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ═════════════════════════════════════════════════════════════════════════════
class CDLStudyGuideScreen extends StatefulWidget {
  const CDLStudyGuideScreen({super.key});
  @override
  State<CDLStudyGuideScreen> createState() => _CDLStudyGuideScreenState();
}

class _CDLStudyGuideScreenState extends State<CDLStudyGuideScreen> {
  List<StudySection> _sections = [];
  List<SectionProgress> _progress = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchData());
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = ''; });
    try {
      final token = await _getToken();
      final h = _authHeaders(token);
      final results = await Future.wait([
        http.get(Uri.parse(ApiConfig.quizSections), headers: h),
        http.get(Uri.parse(ApiConfig.quizProgress), headers: h),
      ]);
      if (!mounted) return;
      final secBody  = jsonDecode(results[0].body);
      final progBody = jsonDecode(results[1].body);
      if (results[0].statusCode != 200) {
        setState(() { _error = secBody['message'] ?? 'Error'; _loading = false; });
        return;
      }
      setState(() {
        _sections = (secBody as List).map((s) => StudySection.fromJson(s)).toList();
        _progress = results[1].statusCode == 200
            ? (progBody as List).map((p) => SectionProgress.fromJson(p)).toList()
            : [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Failed to load study guide. Please refresh.'; _loading = false; });
    }
  }

  Map<String, SectionProgress> get _progressMap {
    final map = <String, SectionProgress>{};
    for (final p in _progress) { map[p.sectionId] = p; }
    return map;
  }

  int get _totalQuestions => _sections.fold(0, (acc, s) => acc + s.questionCount);
  int get _passedCount => _progress.where((p) => p.passed).length;

  @override
  Widget build(BuildContext context) {
    final pm = _progressMap;
    return Scaffold(
      backgroundColor: _gray50,
      body: RefreshIndicator(
        color: _purple,
        onRefresh: _fetchData,
        child: CustomScrollView(
          slivers: [

            // ── White header block ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                color: _white,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Icon + title
                  Row(children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: _purple.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _purple.withValues(alpha: .20)),
                      ),
                      child: const Icon(Icons.menu_book_rounded, color: _purple, size: 20),
                    ),
                    const SizedBox(width: 14),
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('STUDY RESOURCES',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                          color: _purple, letterSpacing: 1.3)),
                      SizedBox(height: 1),
                      Text('CDL Study Guide',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                          color: _navy, height: 1.1)),
                    ]),
                  ]),
                  const SizedBox(height: 10),
                  const Text(
                    'Study each section added by your instructor, then take the practice quiz. '
                    'Your scores are saved so you can track your progress over time.',
                    style: TextStyle(fontSize: 13, color: _gray600, height: 1.65)),
                  const SizedBox(height: 14),

                  // Stat pills
                  if (!_loading) Wrap(spacing: 8, runSpacing: 8, children: [
                    _pill(Icons.menu_book_outlined,
                      '${_sections.length} Sections', _purple),
                    _pill(Icons.help_outline_rounded,
                      '$_totalQuestions Practice Questions', _teal),
                    _pill(Icons.star_border_rounded,
                      '80% to pass each section', _gold),
                    _pill(Icons.trending_up_rounded,
                      '$_passedCount section${_passedCount != 1 ? 's' : ''} passed', _green),
                  ]),
                ]),
              ),
            ),

            // ── Exam tip ───────────────────────────────────────────────────
            // FIX: Use uniform border + inner Row for left accent strip
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left accent bar — stretches to content height via IntrinsicHeight
                          Container(width: 4, color: const Color(0xFFF59E0B)),
                          // Content
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: _orange, size: 17),
                                  const SizedBox(width: 10),
                                  Expanded(child: RichText(text: const TextSpan(
                                    style: TextStyle(fontSize: 13, color: Color(0xFF92400E), height: 1.6),
                                    children: [
                                      TextSpan(text: 'Exam tip: ',
                                        style: TextStyle(fontWeight: FontWeight.w800)),
                                      TextSpan(
                                        text: 'For Class A CDL, focus on Sections 1, 2, 5, 6, 11, 12, and 13. '
                                          'You must score 80% or higher to pass the DMV knowledge test.'),
                                    ],
                                  ))),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Progress overview ──────────────────────────────────────────
            if (_progress.isNotEmpty && _sections.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _ProgressOverview(
                    progress: _progress, totalSections: _sections.length),
                ),
              ),

            // ── Loading ────────────────────────────────────────────────────
            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 70),
                  child: Center(child: CircularProgressIndicator(color: _purple)),
                ),
              ),

            // ── Error ──────────────────────────────────────────────────────
            if (_error.isNotEmpty && !_loading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _ErrorCard(message: _error, onRetry: _fetchData),
                ),
              ),

            // ── Empty ──────────────────────────────────────────────────────
            if (!_loading && _error.isEmpty && _sections.isEmpty)
              const SliverToBoxAdapter(child: _EmptyState()),

            // ── Section cards ──────────────────────────────────────────────
            if (!_loading && _error.isEmpty && _sections.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SectionCard(
                        section: _sections[i],
                        index: i,
                        progress: pm[_sections[i].id],
                        onAttemptDone: _fetchData,
                      ),
                    ),
                    childCount: _sections.length,
                  ),
                ),
              ),

            // ── Footer ────────────────────────────────────────────────────
            if (!_loading && _sections.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _gray50,
                      border: Border.all(color: _gray200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Content based on the California Commercial Driver Handbook (DL 650). '
                      'Always refer to the latest version at dmv.ca.gov before your test.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: _gray400, height: 1.7)),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      border: Border.all(color: color.withValues(alpha: .25)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// PROGRESS OVERVIEW
// ═════════════════════════════════════════════════════════════════════════════
class _ProgressOverview extends StatelessWidget {
  final List<SectionProgress> progress;
  final int totalSections;
  const _ProgressOverview({required this.progress, required this.totalSections});

  @override
  Widget build(BuildContext context) {
    final passed = progress.where((p) => p.passed).length;
    final pct    = totalSections > 0 ? passed / totalSections : 0.0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _white,
        border: Border.all(color: _gray200),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .04), blurRadius: 6)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.bar_chart_rounded, color: _purple, size: 16),
          SizedBox(width: 8),
          Text('Your Progress',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _navy)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _stat('${progress.length}', 'Sections\nAttempted', _purple),
          const SizedBox(width: 24),
          _stat('$passed', 'Sections\nPassed', _teal),
          const SizedBox(width: 24),
          _stat('${(pct * 100).round()}%', 'Overall\nCompletion', _gold),
        ]),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct, minHeight: 7,
            backgroundColor: _gray100,
            valueColor: const AlwaysStoppedAnimation(_purple),
          ),
        ),
        const SizedBox(height: 8),
        Text('$passed of $totalSections sections passed (need 80%+ to pass each)',
          style: const TextStyle(fontSize: 11, color: _gray400)),
      ]),
    );
  }

  Widget _stat(String value, String label, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: TextStyle(
        fontSize: 24, fontWeight: FontWeight.w800, color: color, height: 1)),
      const SizedBox(height: 3),
      Text(label, style: const TextStyle(
        fontSize: 10, fontWeight: FontWeight.w700, color: _gray400, height: 1.3)),
    ],
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION CARD  — FIX: uniform border + inner accent strip via Row
// ═════════════════════════════════════════════════════════════════════════════
class _SectionCard extends StatefulWidget {
  final StudySection section;
  final int index;
  final SectionProgress? progress;
  final VoidCallback onAttemptDone;

  const _SectionCard({
    required this.section, required this.index,
    this.progress, required this.onAttemptDone,
  });

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  bool   _expanded = false;
  String _tab      = 'study';

  Color get _color => _sectionColors[widget.index % _sectionColors.length];

  @override
  Widget build(BuildContext context) {
    final p = widget.progress;
    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(10),
        // FIX: uniform border colour — no more non-uniform BorderSide colours
        border: Border.all(color: _gray200),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: _expanded ? .06 : .03),
          blurRadius: _expanded ? 12 : 4, offset: const Offset(0, 2),
        )],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: IntrinsicHeight(
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Left accent bar ────────────────────────────────────────
            Container(width: 4, color: _color),

            // ── Card body ─────────────────────────────────────────────
            Expanded(
              child: Column(children: [
                // ── Header row ──────────────────────────────────────────
                InkWell(
                  onTap: () => setState(() {
                    _expanded = !_expanded;
                    if (!_expanded) _tab = 'study';
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: _color.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text('${widget.section.sectionNumber}',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                              color: _color)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('SECTION ${widget.section.sectionNumber}',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                            color: _color, letterSpacing: 1.1)),
                        const SizedBox(height: 2),
                        Text(widget.section.title,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                            color: _navy),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ])),
                      if (p != null) ...[
                        _ProgressBadge(progress: p),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: _color.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('${widget.section.questionCount} Q',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _color)),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _expanded ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                        color: _gray400, size: 20),
                    ]),
                  ),
                ),

                // ── Expanded body ──────────────────────────────────────────
                if (_expanded) ...[
                  const Divider(height: 1, thickness: 1, color: _gray100),
                  Row(children: [
                    _tabBtn('study', 'Study Notes'),
                    Container(width: 1, height: 44, color: _gray100),
                    _tabBtn('quiz', 'Practice Quiz (${widget.section.questionCount})'),
                  ]),
                  const Divider(height: 1, thickness: 1, color: _gray100),
                  if (_tab == 'study')
                    _StudyTab(section: widget.section, color: _color,
                      onQuizTap: () => setState(() => _tab = 'quiz')),
                  if (_tab == 'quiz')
                    _QuizTab(section: widget.section, color: _color,
                      onAttemptDone: widget.onAttemptDone),
                ],
              ]),
            ),
          ],
        ),
        ), // IntrinsicHeight
      ),
    );
  }

  Widget _tabBtn(String id, String label) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() => _tab = id),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _tab == id ? _color.withValues(alpha: .07) : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: _tab == id ? _color : Colors.transparent, width: 2)),
        ),
        child: Text(label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
            color: _tab == id ? _color : _gray400)),
      ),
    ),
  );
}

// ── Progress Badge ────────────────────────────────────────────────────────────
class _ProgressBadge extends StatelessWidget {
  final SectionProgress progress;
  const _ProgressBadge({required this.progress});

  @override
  Widget build(BuildContext context) {
    final color = progress.passed ? _green : _orange;
    final bg    = progress.passed
        ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(progress.passed ? Icons.check_circle : Icons.adjust, size: 11, color: color),
        const SizedBox(width: 4),
        Text('${progress.bestScore}% ${progress.passed ? 'Passed' : 'In Progress'}',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// STUDY TAB
// ═════════════════════════════════════════════════════════════════════════════
class _StudyTab extends StatelessWidget {
  final StudySection section;
  final Color color;
  final VoidCallback onQuizTap;
  const _StudyTab({required this.section, required this.color, required this.onQuizTap});

  @override
  Widget build(BuildContext context) {
    final hasContent = section.description.isNotEmpty || section.keyPoints.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (section.description.isNotEmpty) ...[
          Text(section.description,
            style: const TextStyle(fontSize: 14, color: _gray600, height: 1.7)),
          const SizedBox(height: 18),
        ],
        if (section.keyPoints.isNotEmpty) ...[
          const Text('KEY POINTS TO REMEMBER',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
              color: _gray400, letterSpacing: 1.1)),
          const SizedBox(height: 12),
          ...section.keyPoints.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12), shape: BoxShape.circle),
                child: Center(child: Text('${e.key + 1}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                    color: color))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(e.value,
                  style: const TextStyle(fontSize: 14, color: _gray800, height: 1.65)),
              )),
            ]),
          )),
        ],
        if (!hasContent)
          const Text('No study notes added yet. Take the quiz to test your knowledge!',
            style: TextStyle(fontSize: 14, color: _gray400)),
        if (section.questionCount > 0) ...[
          const SizedBox(height: 18),
          SizedBox(width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onQuizTap,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('Take Practice Quiz'),
              style: ElevatedButton.styleFrom(
                backgroundColor: color, foregroundColor: _white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// QUIZ TAB
// ═════════════════════════════════════════════════════════════════════════════
class _QuizTab extends StatefulWidget {
  final StudySection section;
  final Color color;
  final VoidCallback onAttemptDone;
  const _QuizTab({required this.section, required this.color, required this.onAttemptDone});

  @override
  State<_QuizTab> createState() => _QuizTabState();
}

class _QuizTabState extends State<_QuizTab> {
  List<Question> _questions = [];
  bool _loading = true;
  String _error = '';
  int _current = 0;
  int? _selected;
  bool _confirmed = false;
  List<Map<String, dynamic>> _answers = [];
  bool _submitting = false;
  QuizAttemptResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadQuestions());
  }

  Future<void> _loadQuestions() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = ''; });
    try {
      final token = await _getToken();
      final res = await http.get(
        Uri.parse(ApiConfig.quizQuestions(widget.section.id)),
        headers: _authHeaders(token),
      );
      if (!mounted) return;
      final data = jsonDecode(res.body);
      if (res.statusCode != 200) {
        setState(() { _error = data['message'] ?? 'Error'; _loading = false; });
        return;
      }
      setState(() {
        _questions = (data as List).map((q) => Question.fromJson(q)).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Failed to load questions.'; _loading = false; });
    }
  }

  void _confirm() {
    if (_selected == null) return;
    // Record the answer now so _next() doesn't need _selected anymore
    _answers.add({
      'questionId': _questions[_current].id,
      'selectedIndex': _selected!,
    });
    setState(() => _confirmed = true);
  }

  Future<void> _next() async {
    final next = _current + 1;
    if (next < _questions.length) {
      setState(() { _current = next; _selected = null; _confirmed = false; });
    } else {
      setState(() => _submitting = true);
      try {
        // All answers already recorded in _confirm(), just use _answers as-is
        final allAnswers = List<Map<String, dynamic>>.from(_answers);
        final token = await _getToken();
        final res = await http.post(
          Uri.parse(ApiConfig.quizAttempt(widget.section.id)),
          headers: _authHeaders(token),
          body: jsonEncode({'answers': allAnswers}),
        );
        if (!mounted) return;
        final data = jsonDecode(res.body);
        if (res.statusCode != 200) {
          setState(() { _error = data['message'] ?? 'Submission failed.'; _submitting = false; });
          return;
        }
        setState(() { _result = QuizAttemptResult.fromJson(data); _submitting = false; });
        widget.onAttemptDone();
      } catch (_) {
        if (!mounted) return;
        setState(() { _error = 'Failed to submit. Please try again.'; _submitting = false; });
      }
    }
  }

  void _restart() => setState(() {
    _current = 0; _selected = null; _confirmed = false;
    _answers = []; _result = null; _error = '';
  });

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(color: _purple)),
      );
    }
    if (_error.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(_error, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: _red)),
        ),
      );
    }
    if (_questions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.help_outline_rounded, size: 36, color: _gray200),
          SizedBox(height: 10),
          Text('No questions yet for this section.',
            style: TextStyle(fontSize: 14, color: _gray400)),
          SizedBox(height: 4),
          Text('Check back soon — your instructor will add questions here.',
            style: TextStyle(fontSize: 12, color: _gray200), textAlign: TextAlign.center),
        ]),
      );
    }
    if (_result != null) {
      return _buildResult();
    }
    return _buildActiveQuiz();
  }

  Widget _buildResult() {
    final r = _result!;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: r.passed ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
            shape: BoxShape.circle,
          ),
          child: Center(child: Icon(
            r.passed ? Icons.emoji_events_rounded : Icons.adjust_rounded,
            size: 34, color: r.passed ? _green : _orange,
          )),
        ),
        const SizedBox(height: 12),
        Text(r.passed ? 'Section Passed!' : 'Keep Practicing!',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 6),
        RichText(textAlign: TextAlign.center, text: TextSpan(
          style: const TextStyle(fontSize: 14, color: _gray600),
          children: [
            const TextSpan(text: 'You scored '),
            TextSpan(text: '${r.score}/${r.total} (${r.percentage}%)',
              style: TextStyle(fontWeight: FontWeight.w800, color: widget.color)),
            if (!r.passed) const TextSpan(
              text: ' — You need 80% to pass. Review the notes and try again.'),
          ],
        )),
        const SizedBox(height: 20),
        ...r.questions.asMap().entries.map((e) {
          final i = e.key; final q = e.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: q.isCorrect ? const Color(0xFFF0FDF4) : const Color(0xFFFFF1F2),
              border: Border.all(
                color: q.isCorrect ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5)),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(q.isCorrect ? Icons.check_circle : Icons.cancel,
                size: 16, color: q.isCorrect ? _green : _red),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Q${i + 1}: ${q.question}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: _navy)),
                const SizedBox(height: 4),
                if (!q.isCorrect)
                  Text('Your answer: ${q.options.length > q.selectedIndex ? q.options[q.selectedIndex] : 'No answer'}',
                    style: const TextStyle(fontSize: 12, color: _red)),
                Text('Correct: ${q.options.length > q.correctIndex ? q.options[q.correctIndex] : ''}',
                  style: const TextStyle(fontSize: 12, color: _green)),
                if (q.explanation != null) ...[
                  const SizedBox(height: 4),
                  Text(q.explanation!,
                    style: const TextStyle(fontSize: 12, color: _gray600, height: 1.5)),
                ],
              ])),
            ]),
          );
        }),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _restart,
            icon: const Icon(Icons.refresh_rounded, size: 15),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.color, foregroundColor: _white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildActiveQuiz() {
    final q     = _questions[_current];
    final total = _questions.length;
    final diff  = q.difficulty;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Question ${_current + 1} of $total',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: _gray400)),
          if (diff != null) Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: diff == 'hard' ? const Color(0xFFFEE2E2)
                  : diff == 'medium' ? const Color(0xFFFEF3C7)
                  : const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(diff.toUpperCase(),
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8,
                color: diff == 'hard' ? _red : diff == 'medium' ? _orange : _green)),
          ),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: _current / total, minHeight: 4,
            backgroundColor: _gray100,
            valueColor: AlwaysStoppedAnimation(widget.color),
          ),
        ),
        const SizedBox(height: 18),
        Text(q.question,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
            color: _navy, height: 1.55)),
        const SizedBox(height: 14),
        ...q.options.asMap().entries.map((e) {
          final i = e.key; final opt = e.value;
          final sel = _selected == i;
          Color bg = _gray50; Color border = _gray200;
          if (!_confirmed && sel) { bg = widget.color.withValues(alpha: .08); border = widget.color; }
          if (_confirmed  && sel) { bg = widget.color.withValues(alpha: .12); border = widget.color; }
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: _confirmed ? null : () => setState(() => _selected = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: bg,
                  border: Border.all(color: border, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, color: _white,
                      border: Border.all(color: border, width: 2),
                    ),
                    child: Center(child: Text(String.fromCharCode(65 + i),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                        color: sel ? widget.color : _gray600))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(opt,
                    style: const TextStyle(fontSize: 14, color: _gray800))),
                ]),
              ),
            ),
          );
        }),
        if (_confirmed) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              border: Border.all(color: const Color(0xFFBFDBFE)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Answer recorded. You will see the correct answer and explanation after submitting all questions.',
              style: TextStyle(fontSize: 13, color: Color(0xFF1D4ED8))),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(width: double.infinity,
          child: !_confirmed
            ? ElevatedButton(
                onPressed: _selected != null ? _confirm : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selected != null ? widget.color : _gray200,
                  foregroundColor: _selected != null ? _white : _gray400,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                child: const Text('Confirm Answer'),
              )
            : ElevatedButton.icon(
                onPressed: _submitting ? null : _next,
                icon: _submitting
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(color: _white, strokeWidth: 2))
                  : Icon(_current + 1 >= total
                      ? Icons.check_rounded : Icons.arrow_forward_rounded, size: 16),
                label: Text(_submitting ? 'Submitting…'
                  : _current + 1 >= total ? 'Submit & See Results' : 'Next Question'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy, foregroundColor: _white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═════════════════════════════════════════════════════════════════════════════
class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1F2),
      border: Border.all(color: const Color(0xFFFECDD3)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(children: [
      Text(message, style: const TextStyle(fontSize: 14, color: _red),
        textAlign: TextAlign.center),
      const SizedBox(height: 12),
      ElevatedButton(
        onPressed: onRetry,
        style: ElevatedButton.styleFrom(
          backgroundColor: _red, foregroundColor: _white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    ]),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 70),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: const [
      Icon(Icons.menu_book_rounded, size: 48, color: _gray200),
      SizedBox(height: 14),
      Text('No sections yet',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _navy)),
      SizedBox(height: 6),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          "Your instructor hasn't added any study sections yet. Check back soon!",
          style: TextStyle(fontSize: 14, color: _gray400),
          textAlign: TextAlign.center),
      ),
    ])),
  );
}