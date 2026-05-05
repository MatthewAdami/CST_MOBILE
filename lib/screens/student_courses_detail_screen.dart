import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ── Constants ────────────────────────────────────────────────────
const String kApi    = 'http://10.0.2.2:5000/api';
const Color  kPurple = Color(0xFF7C3AED);
const Color  kNavy   = Color(0xFF0B1F3A);

// ── Category helpers ─────────────────────────────────────────────
Color _catBg(String? cat) {
  switch (cat) {
    case 'CDL Class A': return const Color(0xFFEEF2FF);
    case 'CDL Class B': return const Color(0xFFF0FDF4);
    case 'Endorsement': return const Color(0xFFFFF7ED);
    case 'Refresher':   return const Color(0xFFFDF4FF);
    default:            return const Color(0xFFF3F4F6);
  }
}

Color _catText(String? cat) {
  switch (cat) {
    case 'CDL Class A': return const Color(0xFF4338CA);
    case 'CDL Class B': return const Color(0xFF166534);
    case 'Endorsement': return const Color(0xFF9A3412);
    case 'Refresher':   return const Color(0xFF7E22CE);
    default:            return const Color(0xFF374151);
  }
}

Color _catBar(String? cat) {
  switch (cat) {
    case 'CDL Class A': return const Color(0xFF4338CA);
    case 'CDL Class B': return const Color(0xFF16A34A);
    case 'Endorsement': return const Color(0xFFEA580C);
    case 'Refresher':   return const Color(0xFF9333EA);
    default:            return const Color(0xFF6B7280);
  }
}

// ── Payment Methods ──────────────────────────────────────────────
class _PayMethod {
  final String id, label, desc;
  final IconData icon;
  const _PayMethod(this.id, this.label, this.icon, this.desc);
}

const List<_PayMethod> kPaymentMethods = [
  _PayMethod('va',       'VA Benefits',      Icons.military_tech_outlined,  'For eligible veterans'),
  _PayMethod('loan',     'Student Loan',     Icons.description_outlined,    'Federal or private loan'),
  _PayMethod('employer', 'Employer Sponsor', Icons.shield_outlined,         'Company-paid tuition'),
  _PayMethod('self',     'Self-Pay',         Icons.credit_card_outlined,    'Pay out of pocket'),
  _PayMethod('grant',    'Grants',           Icons.menu_book_outlined,      'Scholarships and grants'),
];

const Map<String, String> kMethodMap = {
  'va': 'VA Benefits', 'loan': 'Student Loan',
  'employer': 'Employer Sponsor', 'self': 'Self-Pay', 'grant': 'Grants',
};

// ── What You'll Learn ────────────────────────────────────────────
List<String> _getWhatYouLearn(String? category) {
  const map = {
    'CDL Class A': [
      'Pre-trip vehicle inspection', 'Shifting and clutch techniques',
      'Backing and parking maneuvers', 'Highway and city driving',
      'Coupling and uncoupling trailers', 'CDL written exam preparation',
    ],
    'CDL Class B': [
      'Straight truck operation', 'Passenger vehicle procedures',
      'City route navigation', 'Emergency exit protocols',
      'Air brake systems', 'Class B written exam prep',
    ],
    'Endorsement': [
      'Endorsement-specific regulations', 'Safety and compliance procedures',
      'Handling and transport rules', 'Emergency response protocols',
      'Federal and state requirements', 'Endorsement exam preparation',
    ],
    'Refresher': [
      'Updated CDL regulations', 'Skills assessment and review',
      'Range practice sessions', 'Road test preparation',
      'Log book and HOS rules', 'Defensive driving techniques',
    ],
  };
  return (map[category] ?? map['Endorsement'])!;
}

// ── Course Model ─────────────────────────────────────────────────
class CourseDetail {
  final String id, title;
  final String? category, description, status;
  final double price;
  final int capacity, enrolledCount;
  final Map<String, dynamic>? duration;
  final List<String> requirements;
  final Map<String, dynamic>? instructor;
  final List<dynamic> schedule;

  CourseDetail({
    required this.id, required this.title, this.category,
    this.description, this.status, required this.price,
    required this.capacity, required this.enrolledCount,
    this.duration, required this.requirements,
    this.instructor, required this.schedule,
  });

  factory CourseDetail.fromJson(Map<String, dynamic> j) => CourseDetail(
    id:            j['_id']           ?? '',
    title:         j['title']         ?? '',
    category:      j['category'],
    description:   j['description'],
    status:        j['status'],
    price:         (j['price'] ?? 0).toDouble(),
    capacity:      j['capacity']      ?? 0,
    enrolledCount: j['enrolledCount'] ?? 0,
    duration:      j['duration'],
    requirements:  List<String>.from(j['requirements'] ?? []),
    instructor:    j['instructor'],
    schedule:      j['schedule']      ?? [],
  );

  int  get seatsLeft => capacity - enrolledCount;
  bool get isFull    => seatsLeft <= 0;
  int  get pctFull   => capacity > 0 ? ((enrolledCount / capacity) * 100).round() : 0;
}

// ════════════════════════════════════════════════════════════════
//  StudentCourseDetailPage
// ════════════════════════════════════════════════════════════════
class StudentCourseDetailPage extends StatefulWidget {
  final String courseId;
  final String authToken;

  const StudentCourseDetailPage({
    super.key,
    required this.courseId,
    required this.authToken,
  });

  @override
  State<StudentCourseDetailPage> createState() => _StudentCourseDetailPageState();
}

class _StudentCourseDetailPageState extends State<StudentCourseDetailPage> {
  CourseDetail?          _course;
  Map<String, dynamic>?  _enrollment;
  bool                   _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Map<String, String> get _headers => {
    'Content-Type':  'application/json',
    'Authorization': 'Bearer ${widget.authToken}',
  };

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        http.get(Uri.parse('$kApi/courses/${widget.courseId}'), headers: _headers),
        http.get(Uri.parse('$kApi/enrollments/my'),            headers: _headers),
      ]);

      final course      = CourseDetail.fromJson(jsonDecode(results[0].body));
      final enrollments = jsonDecode(results[1].body) as List;
      final found       = enrollments.firstWhere(
        (e) {
          final cId = e['courseId'];
          return (cId is Map ? cId['_id'] : cId) == widget.courseId;
        },
        orElse: () => null,
      );

      setState(() {
        _course     = course;
        _enrollment = found;
      });
    } catch (_) {
      setState(() { _course = null; });
    } finally {
      setState(() => _loading = false);
    }
  }

  void _openPaymentModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentModal(
        course:    _course!,
        headers:   _headers,
        onSuccess: _fetchData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF9FAFB),
        body: Center(child: CircularProgressIndicator(color: kPurple)),
      );
    }

    if (_course == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('Course not found.', style: TextStyle(color: Colors.grey[500])),
          ]),
        ),
      );
    }

    final c          = _course!;
    final isEnrolled = _enrollment != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──
          SliverAppBar(
            expandedHeight: 0,
            floating: true,
            backgroundColor: const Color(0xFFF9FAFB),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.chevron_left, color: kNavy, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Course Detail',
              style: TextStyle(color: kNavy, fontWeight: FontWeight.w700, fontSize: 16)),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Hero Card ──
                _HeroCard(course: c, isEnrolled: isEnrolled),
                const SizedBox(height: 14),

                // ── Enrollment / Price Card ──
                _EnrollmentCard(
                  course:      c,
                  isEnrolled:  isEnrolled,
                  enrollment:  _enrollment,
                  onEnroll:    _openPaymentModal,
                  onProgress:  () => Navigator.pushNamed(context, '/student/progress'),
                ),
                const SizedBox(height: 14),

                // ── Requirements ──
                if (c.requirements.isNotEmpty) ...[
                  _RequirementsCard(requirements: c.requirements),
                  const SizedBox(height: 14),
                ],

                // ── What You'll Learn ──
                _WhatYouLearnCard(category: c.category),
                const SizedBox(height: 14),

                // ── Instructor ──
                if (c.instructor != null) ...[
                  _InstructorCard(instructor: c.instructor!),
                  const SizedBox(height: 14),
                ],

                // ── Schedule ──
                if (c.schedule.isNotEmpty) ...[
                  _ScheduleCard(schedule: c.schedule),
                  const SizedBox(height: 14),
                ],

                // ── Course Info ──
                _CourseInfoCard(course: c),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero Card ────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final CourseDetail course;
  final bool isEnrolled;
  const _HeroCard({required this.course, required this.isEnrolled});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Color bar
        Container(height: 6, decoration: BoxDecoration(
          color: _catBar(course.category),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        )),

        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Category + enrolled badge
            Row(children: [
              _Badge(label: course.category ?? '', bg: _catBg(course.category), fg: _catText(course.category)),
              const Spacer(),
              if (isEnrolled)
                _Badge(label: '✓ Enrolled', bg: const Color(0xFFD1FAE5), fg: const Color(0xFF065F46)),
            ]),
            const SizedBox(height: 12),

            // Title
            Text(course.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kNavy, height: 1.2)),

            // Description
            if (course.description != null) ...[
              const SizedBox(height: 10),
              Text(course.description!,
                style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.7)),
            ],
            const SizedBox(height: 16),

            // Stats row
            Row(children: [
              Expanded(child: _StatBox(
                icon: Icons.access_time, label: 'Duration',
                value: '${course.duration?['value']} ${course.duration?['unit']}',
              )),
              const SizedBox(width: 10),
              Expanded(child: _StatBox(
                icon: Icons.attach_money, label: 'Tuition',
                value: '\$${course.price.toStringAsFixed(0)}',
              )),
              const SizedBox(width: 10),
              Expanded(child: _StatBox(
                icon: Icons.people, label: 'Seats Left',
                value: '${course.seatsLeft} of ${course.capacity}',
              )),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ── Enrollment Card ──────────────────────────────────────────────
class _EnrollmentCard extends StatelessWidget {
  final CourseDetail course;
  final bool isEnrolled;
  final Map<String, dynamic>? enrollment;
  final VoidCallback onEnroll, onProgress;

  const _EnrollmentCard({
    required this.course, required this.isEnrolled,
    required this.enrollment, required this.onEnroll, required this.onProgress,
  });

  @override
  Widget build(BuildContext context) {
    final pct = course.pctFull;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        // Navy header with price
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: kNavy,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Tuition Fee',
              style: TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w600, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text('\$${course.price.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Seat availability bar
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${course.enrolledCount} enrolled', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              Text('${course.seatsLeft} seats left', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: pct / 100,
                minHeight: 6,
                backgroundColor: const Color(0xFFF3F4F6),
                valueColor: AlwaysStoppedAnimation(pct > 80 ? Colors.red : kPurple),
              ),
            ),
            const SizedBox(height: 16),

            // CTA
            if (isEnrolled) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(10)),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.check_circle, color: Color(0xFF065F46), size: 16),
                  SizedBox(width: 8),
                  Text('You are enrolled', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF065F46))),
                ]),
              ),
              const SizedBox(height: 10),
              // Enrollment status
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Enrollment Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[400], letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(
                    (enrollment?['status'] ?? 'active').toString().toUpperCase()[0] +
                    (enrollment?['status'] ?? 'active').toString().substring(1),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: kNavy, fontSize: 14),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onProgress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPurple, elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('View My Progress',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14)),
                ),
              ),
            ] else if (course.isFull)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10)),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.lock_outline, color: Color(0xFF991B1B), size: 16),
                  SizedBox(width: 8),
                  Text('Course is Full', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF991B1B))),
                ]),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onEnroll,
                  icon: const Icon(Icons.credit_card, size: 16, color: Colors.white),
                  label: const Text('Enroll Now',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPurple, elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),

            const SizedBox(height: 14),

            // Trust badges
            ...[
              [Icons.shield_outlined,       'Secure enrollment process'],
              [Icons.check_circle_outline,  'Instant confirmation on sign-up'],
              [Icons.description_outlined,  'Finance record auto-generated'],
            ].map((row) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Icon(row[0] as IconData, size: 13, color: const Color(0xFF10B981)),
                const SizedBox(width: 8),
                Text(row[1] as String, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ]),
            )),
          ]),
        ),
      ]),
    );
  }
}

// ── Requirements Card ────────────────────────────────────────────
class _RequirementsCard extends StatelessWidget {
  final List<String> requirements;
  const _RequirementsCard({required this.requirements});

  @override
  Widget build(BuildContext context) => _SectionCard(
    icon: Icons.shield_outlined,
    title: 'Enrollment Requirements',
    child: Column(
      children: requirements.map((req) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(req, style: const TextStyle(fontSize: 13, color: Color(0xFF374151)))),
        ]),
      )).toList(),
    ),
  );
}

// ── What You'll Learn Card ───────────────────────────────────────
class _WhatYouLearnCard extends StatelessWidget {
  final String? category;
  const _WhatYouLearnCard({required this.category});

  @override
  Widget build(BuildContext context) {
    final items = _getWhatYouLearn(category);
    return _SectionCard(
      icon: Icons.menu_book_outlined,
      title: "What You'll Learn",
      child: Wrap(
        spacing: 10, runSpacing: 8,
        children: items.map((item) => SizedBox(
          width: (MediaQuery.of(context).size.width - 80) / 2,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.check_circle, size: 15, color: kPurple),
            const SizedBox(width: 6),
            Expanded(child: Text(item, style: const TextStyle(fontSize: 13, color: Color(0xFF374151)))),
          ]),
        )).toList(),
      ),
    );
  }
}

// ── Instructor Card ──────────────────────────────────────────────
class _InstructorCard extends StatelessWidget {
  final Map<String, dynamic> instructor;
  const _InstructorCard({required this.instructor});

  @override
  Widget build(BuildContext context) {
    final firstName = instructor['firstName'] ?? '';
    final lastName  = instructor['lastName']  ?? '';
    final initials  = '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}';

    return _SectionCard(
      icon: Icons.workspace_premium_outlined,
      title: 'Your Instructor',
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: const BoxDecoration(color: Color(0xFFEEF2FF), shape: BoxShape.circle),
          child: Center(child: Text(initials,
            style: const TextStyle(fontWeight: FontWeight.w700, color: kPurple, fontSize: 18))),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$firstName $lastName',
            style: const TextStyle(fontWeight: FontWeight.w700, color: kNavy, fontSize: 15)),
          const SizedBox(height: 2),
          Text('CDL Instructor', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ]),
      ]),
    );
  }
}

// ── Schedule Card ────────────────────────────────────────────────
class _ScheduleCard extends StatelessWidget {
  final List<dynamic> schedule;
  const _ScheduleCard({required this.schedule});

  @override
  Widget build(BuildContext context) => _SectionCard(
    icon: Icons.calendar_month_outlined,
    title: 'Available Schedules',
    child: Column(
      children: schedule.map<Widget>((slot) {
        String start = '', end = '';
        try {
          start = DateTime.parse(slot['startDate']).toLocal().toString().split(' ')[0];
          end   = DateTime.parse(slot['endDate']).toLocal().toString().split(' ')[0];
        } catch (_) {}
        final days = (slot['days'] as List?)?.join(', ') ?? '';
        final time = slot['time'] ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFF3F4F6)),
          ),
          child: Row(children: [
            Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey[400]),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$start — $end',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kNavy)),
              if (days.isNotEmpty || time.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('$days${time.isNotEmpty ? ' · $time' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ]),
          ]),
        );
      }).toList(),
    ),
  );
}

// ── Course Info Card ─────────────────────────────────────────────
class _CourseInfoCard extends StatelessWidget {
  final CourseDetail course;
  const _CourseInfoCard({required this.course});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['Category', course.category ?? '—'],
      ['Duration', '${course.duration?['value']} ${course.duration?['unit']}'],
      ['Capacity', '${course.capacity} students'],
      ['Status',   course.status ?? '—'],
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Course Info',
          style: TextStyle(fontWeight: FontWeight.w700, color: kNavy, fontSize: 14)),
        const SizedBox(height: 12),
        ...rows.asMap().entries.map((entry) {
          final isLast = entry.key == rows.length - 1;
          final row    = entry.value;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(row[0], style: TextStyle(fontSize: 13, color: Colors.grey[400], fontWeight: FontWeight.w600)),
              Text(
                row[0] == 'Status'
                  ? row[1][0].toUpperCase() + row[1].substring(1)
                  : row[1],
                style: const TextStyle(fontSize: 13, color: kNavy, fontWeight: FontWeight.w700),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}

// ── Section Card wrapper ─────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _SectionCard({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    padding: const EdgeInsets.all(18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 18, color: kPurple),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: kNavy, fontSize: 14)),
      ]),
      const SizedBox(height: 14),
      child,
    ]),
  );
}

// ── Reusable widgets ─────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color bg, fg;
  const _Badge({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
  );
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _StatBox({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFF3F4F6)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 14, color: kPurple),
        const SizedBox(width: 4),
        Flexible(child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[400], letterSpacing: 0.5),
          overflow: TextOverflow.ellipsis)),
      ]),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kNavy)),
    ]),
  );
}

// ════════════════════════════════════════════════════════════════
//  Payment Modal (Bottom Sheet)
// ════════════════════════════════════════════════════════════════
class _PaymentModal extends StatefulWidget {
  final CourseDetail course;
  final Map<String, String> headers;
  final VoidCallback onSuccess;

  const _PaymentModal({required this.course, required this.headers, required this.onSuccess});

  @override
  State<_PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<_PaymentModal> {
  String _payMethod = 'self';
  int    _step      = 1;
  bool   _enrolling = false;
  String _error     = '';

  Future<void> _confirmEnroll() async {
    setState(() { _enrolling = true; _error = ''; });
    try {
      final res = await http.post(
        Uri.parse('$kApi/enrollments'),
        headers: widget.headers,
        body: jsonEncode({
          'courseId':      widget.course.id,
          'paymentMethod': kMethodMap[_payMethod],
        }),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode != 200 && res.statusCode != 201) {
        setState(() => _error = data['message'] ?? 'Enrollment failed.');
      } else {
        setState(() => _step = 3);
        widget.onSuccess();
      }
    } catch (_) {
      setState(() => _error = 'Server error. Please try again.');
    } finally {
      setState(() => _enrolling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        // ── Modal Header ──
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: kNavy,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: kPurple, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.credit_card, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Enrollment',
                style: TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w600, letterSpacing: 1)),
              Text(widget.course.title,
                style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w700)),
            ])),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ]),
        ),

        // ── Step Indicators ──
        if (_step < 3)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: ['Payment Method', 'Confirm'].asMap().entries.map((e) {
                final active = _step == e.key + 1;
                final done   = _step >  e.key + 1;
                return Expanded(child: Padding(
                  padding: EdgeInsets.only(right: e.key == 0 ? 8 : 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(height: 3, decoration: BoxDecoration(
                      color: (active || done) ? kPurple : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(99),
                    )),
                    const SizedBox(height: 4),
                    Text(e.value, style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600,
                      color: active ? kPurple : Colors.grey[400])),
                  ]),
                ));
              }).toList(),
            ),
          ),

        // ── Step Content ──
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _step == 1 ? _buildStep1()
                 : _step == 2 ? _buildStep2()
                 : _buildStep3(),
          ),
        ),
      ]),
    );
  }

  // ── Step 1: Choose Payment Method ──
  Widget _buildStep1() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('How will you be paying?',
      style: TextStyle(fontWeight: FontWeight.w700, color: kNavy, fontSize: 14)),
    const SizedBox(height: 12),

    ...kPaymentMethods.map((pm) {
      final sel = _payMethod == pm.id;
      return GestureDetector(
        onTap: () => setState(() => _payMethod = pm.id),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFFEEF2FF) : Colors.white,
            border: Border.all(color: sel ? kPurple : const Color(0xFFE5E7EB), width: sel ? 2 : 1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: sel ? kPurple : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(pm.icon, size: 18, color: sel ? Colors.white : const Color(0xFF6B7280)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pm.label,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kNavy)),
              Text(pm.desc,
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ])),
            Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: sel ? kPurple : const Color(0xFFD1D5DB), width: 2),
                color: sel ? kPurple : Colors.transparent,
              ),
              child: sel
                ? const Center(child: CircleAvatar(radius: 3, backgroundColor: Colors.white))
                : null,
            ),
          ]),
        ),
      );
    }),

    const SizedBox(height: 12),

    // Notice
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        border: Border.all(color: const Color(0xFFFCD34D)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline, size: 15, color: Color(0xFFD97706)),
        const SizedBox(width: 8),
        Expanded(child: RichText(text: const TextSpan(
          style: TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.5),
          children: [
            TextSpan(text: 'Payment gateway coming soon. ',
              style: TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: 'Your enrollment will be confirmed automatically and our team will contact you to finalize payment.'),
          ],
        ))),
      ]),
    ),

    const SizedBox(height: 16),
    SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => setState(() => _step = 2),
        style: ElevatedButton.styleFrom(
          backgroundColor: kPurple, elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: const Text('Continue →',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white)),
      ),
    ),
  ]);

  // ── Step 2: Review & Confirm ──
  Widget _buildStep2() {
    final pm = kPaymentMethods.firstWhere((p) => p.id == _payMethod);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Review your enrollment',
        style: TextStyle(fontWeight: FontWeight.w700, color: kNavy, fontSize: 14)),
      const SizedBox(height: 12),

      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          // Course row
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.local_shipping_outlined, color: kPurple, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.course.title,
                style: const TextStyle(fontWeight: FontWeight.w700, color: kNavy, fontSize: 13)),
              Text('${widget.course.category} · ${widget.course.duration?['value']} ${widget.course.duration?['unit']}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ])),
          ]),
          const Divider(height: 20, color: Color(0xFFE5E7EB)),

          ...[
            ['Course Fee',     '\$${widget.course.price.toStringAsFixed(0)}'],
            ['Payment Method', pm.label],
            ['Payment Status', 'Pending — Office will contact you'],
          ].map((row) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(row[0], style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              Text(row[1], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kNavy)),
            ]),
          )),

          const Divider(height: 12, color: Color(0xFFE5E7EB)),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Total Due', style: TextStyle(fontWeight: FontWeight.w700, color: kNavy)),
            Text('\$${widget.course.price.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w800, color: kPurple, fontSize: 18)),
          ]),
        ]),
      ),

      const SizedBox(height: 12),

      // Trust badges
      Wrap(spacing: 8, runSpacing: 8, children: const [
        _TrustBadge(icon: Icons.shield_outlined,       label: 'Secure Enrollment'),
        _TrustBadge(icon: Icons.lock_outline,          label: 'Data Protected'),
        _TrustBadge(icon: Icons.check_circle_outline,  label: 'Instant Confirmation'),
      ]),

      if (_error.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 14),
            const SizedBox(width: 8),
            Expanded(child: Text(_error,
              style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)))),
          ]),
        ),
      ],

      const SizedBox(height: 16),
      Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => setState(() => _step = 1),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            child: const Text('← Back',
              style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF374151))),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _enrolling ? null : _confirmEnroll,
            icon: _enrolling
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_circle, size: 16, color: Colors.white),
            label: Text(_enrolling ? 'Processing...' : 'Confirm Enrollment',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPurple,
              disabledBackgroundColor: kPurple.withOpacity(0.7),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ),
      ]),
    ]);
  }

  // ── Step 3: Success ──
  Widget _buildStep3() => Column(children: [
    const SizedBox(height: 8),
    Container(
      width: 72, height: 72,
      decoration: const BoxDecoration(color: Color(0xFFD1FAE5), shape: BoxShape.circle),
      child: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 36),
    ),
    const SizedBox(height: 16),
    const Text("You're Enrolled! 🎉",
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kNavy)),
    const SizedBox(height: 6),
    Text("You've successfully enrolled in",
      style: TextStyle(color: Colors.grey[600], fontSize: 13)),
    const SizedBox(height: 4),
    Text(widget.course.title,
      style: const TextStyle(fontWeight: FontWeight.w700, color: kPurple, fontSize: 15),
      textAlign: TextAlign.center),
    const SizedBox(height: 16),
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        border: Border.all(color: const Color(0xFFFCD34D)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        '📋 A pending payment record has been created. Our admissions team will contact you within 1–2 business days to finalize your payment method.',
        style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.5),
        textAlign: TextAlign.center,
      ),
    ),
    const SizedBox(height: 20),
    Row(children: [
      Expanded(
        child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            side: BorderSide(color: Colors.grey[300]!),
          ),
          child: const Text('Close',
            style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF374151))),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/student/progress');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: kPurple, elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('View Progress',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ),
    ]),
  ]);
}

// ── Trust Badge ──────────────────────────────────────────────────
class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TrustBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(999)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: const Color(0xFF166534)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF166534))),
    ]),
  );
}