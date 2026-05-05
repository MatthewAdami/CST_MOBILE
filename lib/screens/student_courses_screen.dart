import 'dart:convert';
import 'package:cst_mobile/screens/student_courses_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ── Constants ────────────────────────────────────────────────────
const String kApi = 'http://10.0.2.2:5000/api';
const Color kPurple = Color(0xFF7C3AED);
const Color kNavy = Color(0xFF0B1F3A);

// ── Helpers ──────────────────────────────────────────────────────
Color _catBg(String? cat) {
  switch (cat) {
    case 'CDL Class A':  return const Color(0xFFEEF2FF);
    case 'CDL Class B':  return const Color(0xFFF0FDF4);
    case 'Endorsement':  return const Color(0xFFFFF7ED);
    case 'Refresher':    return const Color(0xFFFDF4FF);
    default:             return const Color(0xFFF3F4F6);
  }
}

Color _catText(String? cat) {
  switch (cat) {
    case 'CDL Class A':  return const Color(0xFF4338CA);
    case 'CDL Class B':  return const Color(0xFF166534);
    case 'Endorsement':  return const Color(0xFF9A3412);
    case 'Refresher':    return const Color(0xFF7E22CE);
    default:             return const Color(0xFF374151);
  }
}

// ── Payment Methods ──────────────────────────────────────────────
class PaymentMethod {
  final String id, label, icon, desc;
  const PaymentMethod(this.id, this.label, this.icon, this.desc);
}

const List<PaymentMethod> kPaymentMethods = [
  PaymentMethod('va',       'VA Benefits',     '🎖️', 'For eligible veterans'),
  PaymentMethod('loan',     'Student Loan',    '🏦', 'Federal or private loan'),
  PaymentMethod('employer', 'Employer Sponsor','🏢', 'Company-paid tuition'),
  PaymentMethod('self',     'Self-Pay',        '💳', 'Pay out of pocket'),
  PaymentMethod('grant',    'Grants',          '📋', 'Scholarships & grants'),
];

// ── Course Model ─────────────────────────────────────────────────
class Course {
  final String id, title;
  final String? category, description;
  final double price;
  final int capacity, enrolledCount;
  final Map<String, dynamic>? duration;
  final List<String> requirements;

  Course({
    required this.id,
    required this.title,
    this.category,
    this.description,
    required this.price,
    required this.capacity,
    required this.enrolledCount,
    this.duration,
    required this.requirements,
  });

  factory Course.fromJson(Map<String, dynamic> j) => Course(
    id:            j['_id']           ?? '',
    title:         j['title']         ?? '',
    category:      j['category'],
    description:   j['description'],
    price:         (j['price'] ?? 0).toDouble(),
    capacity:      j['capacity']      ?? 0,
    enrolledCount: j['enrolledCount'] ?? 0,
    duration:      j['duration'],
    requirements:  List<String>.from(j['requirements'] ?? []),
  );

  int get seatsLeft => capacity - enrolledCount;
  bool get isFull   => seatsLeft <= 0;
}

// ════════════════════════════════════════════════════════════════
//  StudentCoursesPage
// ════════════════════════════════════════════════════════════════
class StudentCoursesPage extends StatefulWidget {
  final String authToken;
  const StudentCoursesPage({super.key, required this.authToken});

  @override
  State<StudentCoursesPage> createState() => _StudentCoursesPageState();
}

class _StudentCoursesPageState extends State<StudentCoursesPage> {
  List<Course> _courses     = [];
  Set<String>  _enrolledIds = {};
  bool         _loading     = true;
  String       _search      = '';
  String       _filterCat   = 'all';

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
        http.get(Uri.parse('$kApi/courses'),          headers: _headers),
        http.get(Uri.parse('$kApi/enrollments/my'),   headers: _headers),
      ]);

      final courses = (jsonDecode(results[0].body) as List)
          .map((e) => Course.fromJson(e))
          .toList();

      final enrollments = jsonDecode(results[1].body) as List;
      final ids = enrollments.map<String>((e) {
        final courseId = e['courseId'];
        return (courseId is Map ? courseId['_id'] : courseId) ?? '';
      }).toSet();

      setState(() {
        _courses     = courses;
        _enrolledIds = ids;
      });
    } catch (_) {
      setState(() { _courses = []; _enrolledIds = {}; });
    } finally {
      setState(() => _loading = false);
    }
  }

  List<String> get _categories => _courses.map((c) => c.category ?? '').toSet().toList();

  List<Course> get _filtered => _courses.where((c) {
    final matchSearch = c.title.toLowerCase().contains(_search.toLowerCase());
    final matchCat    = _filterCat == 'all' || c.category == _filterCat;
    return matchSearch && matchCat;
  }).toList();

  void _openPayment(Course course) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentModal(
        course:    course,
        headers:   _headers,
        onSuccess: _fetchData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Browse Courses',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kNavy)),
                  const SizedBox(height: 4),
                  Text('Enroll in a CDL program or endorsement course',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                ],
              ),
            ),

            // ── Search + filter ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Search courses...',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                      prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey[400]),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      filled: true, fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[200]!)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[200]!)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey[200]!),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _filterCat,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('All')),
                        ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                      ],
                      onChanged: (v) => setState(() => _filterCat = v ?? 'all'),
                    ),
                  ),
                ),
              ]),
            ),

            // ── Course list ──
            Expanded(
              child: _loading
                ? const Center(child: CircularProgressIndicator(color: kPurple))
                : _filtered.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.menu_book_outlined, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No courses available right now.', style: TextStyle(color: Colors.grey[500])),
                      ]),
                    )
                  : RefreshIndicator(
  color: kPurple,
  onRefresh: _fetchData,
  child: ListView.builder(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
    itemCount: _filtered.length,
    itemBuilder: (_, i) => _CourseCard(
      course:   _filtered[i],
      enrolled: _enrolledIds.contains(_filtered[i].id),
      onDetails: () => Navigator.push(          // ← change this line
        context,
        MaterialPageRoute(
          builder: (_) => StudentCourseDetailPage(
            courseId:  _filtered[i].id,
            authToken: widget.authToken,
          ),
        ),
      ),
      onEnroll: () => _openPayment(_filtered[i]),
    ),
  ),
),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailSheet(Course c) {
    final enrolled = _enrolledIds.contains(c.id);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            // Purple bar
            Container(height: 5, margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(99))),
            Expanded(
              child: ListView(controller: ctrl, padding: const EdgeInsets.all(20), children: [
                // Category
                Row(children: [
                  _Badge(label: c.category ?? '', bg: _catBg(c.category), fg: _catText(c.category)),
                  const Spacer(),
                  if (enrolled) _Badge(label: '✓ Enrolled', bg: const Color(0xFFD1FAE5), fg: const Color(0xFF065F46)),
                ]),
                const SizedBox(height: 10),
                Text(c.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kNavy)),
                if (c.description != null) ...[
                  const SizedBox(height: 8),
                  Text(c.description!, style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.6)),
                ],
                const SizedBox(height: 16),
                // Stats grid
                GridView.count(
                  crossAxisCount: 2, shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10, mainAxisSpacing: 10,
                  childAspectRatio: 2.5,
                  children: [
                    _StatTile(icon: Icons.access_time, label: 'Duration',   value: '${c.duration?['value']} ${c.duration?['unit']}'),
                    _StatTile(icon: Icons.attach_money, label: 'Price',     value: '\$${c.price.toStringAsFixed(0)}'),
                    _StatTile(icon: Icons.people,       label: 'Enrolled',  value: '${c.enrolledCount} / ${c.capacity}'),
                    _StatTile(icon: Icons.event_seat,   label: 'Seats Left',value: '${c.seatsLeft} available'),
                  ],
                ),
                if (c.requirements.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Requirements', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF374151))),
                  const SizedBox(height: 6),
                  ...c.requirements.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('• ', style: TextStyle(color: Color(0xFF6B7280))),
                      Expanded(child: Text(r, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)))),
                    ]),
                  )),
                ],
                const SizedBox(height: 20),
                if (enrolled)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(10)),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.check_circle, color: Color(0xFF065F46), size: 16),
                      SizedBox(width: 8),
                      Text('You are enrolled in this course', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF065F46))),
                    ]),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: c.isFull ? null : () { Navigator.pop(context); _openPayment(c); },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPurple,
                        disabledBackgroundColor: const Color(0xFFF3F4F6),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        c.isFull ? 'Course Full' : 'Enroll Now — \$${c.price.toStringAsFixed(0)}',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: c.isFull ? Colors.grey[400] : Colors.white),
                      ),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Course Card ──────────────────────────────────────────────────
class _CourseCard extends StatelessWidget {
  final Course course;
  final bool enrolled;
  final VoidCallback onDetails, onEnroll;

  const _CourseCard({
    required this.course,
    required this.enrolled,
    required this.onDetails,
    required this.onEnroll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: enrolled ? const Color(0xFFA7F3D0) : const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top accent bar
          Container(height: 5, decoration: BoxDecoration(
            color: enrolled ? const Color(0xFF10B981) : kPurple,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          )),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badges row
                Row(children: [
                  _Badge(label: course.category ?? '', bg: _catBg(course.category), fg: _catText(course.category)),
                  const Spacer(),
                  if (enrolled)
                    _Badge(label: '✓ Enrolled', bg: const Color(0xFFD1FAE5), fg: const Color(0xFF065F46))
                  else if (course.isFull)
                    _Badge(label: 'Full', bg: const Color(0xFFFEE2E2), fg: const Color(0xFF991B1B)),
                ]),
                const SizedBox(height: 10),

                // Title
                Text(course.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kNavy)),

                // Description
                if (course.description != null) ...[
                  const SizedBox(height: 6),
                  Text(course.description!,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.5)),
                ],
                const SizedBox(height: 12),

                // Meta row
                Row(children: [
                  _MetaChip(icon: Icons.access_time, label: '${course.duration?['value']} ${course.duration?['unit']}'),
                  const SizedBox(width: 12),
                  _MetaChip(icon: Icons.people, label: '${course.seatsLeft} seats'),
                  const SizedBox(width: 12),
                  _MetaChip(icon: Icons.attach_money, label: '\$${course.price.toStringAsFixed(0)}'),
                ]),

                // Requirements preview
                if (course.requirements.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Requirements', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey[700], letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  ...course.requirements.take(2).map((r) =>
                    Text('• $r', style: TextStyle(fontSize: 11, color: Colors.grey[600]))),
                  if (course.requirements.length > 2)
                    Text('+${course.requirements.length - 2} more...', style: const TextStyle(fontSize: 11, color: kPurple)),
                ],

                const SizedBox(height: 14),

                // Action buttons
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDetails,
                      icon: const Icon(Icons.info_outline, size: 14),
                      label: const Text('Details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF374151),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  if (!enrolled) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: course.isFull ? null : onEnroll,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPurple,
                          disabledBackgroundColor: const Color(0xFFF3F4F6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                        ),
                        child: Text(
                          course.isFull ? 'Course Full' : 'Enroll Now',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: course.isFull ? Colors.grey[400] : Colors.white),
                        ),
                      ),
                    ),
                  ],
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Payment Modal ────────────────────────────────────────────────
class _PaymentModal extends StatefulWidget {
  final Course course;
  final Map<String, String> headers;
  final VoidCallback onSuccess;

  const _PaymentModal({required this.course, required this.headers, required this.onSuccess});

  @override
  State<_PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<_PaymentModal> {
  String  _payMethod = 'self';
  int     _step      = 1;
  bool    _enrolling = false;
  String  _error     = '';

  Future<void> _confirmEnroll() async {
    setState(() { _enrolling = true; _error = ''; });
    const methodMap = {
      'va': 'VA Benefits', 'loan': 'Student Loan',
      'employer': 'Employer Sponsor', 'self': 'Self-Pay', 'grant': 'Grants',
    };
    try {
      final res = await http.post(
        Uri.parse('$kApi/enrollments'),
        headers: widget.headers,
        body: jsonEncode({ 'courseId': widget.course.id, 'paymentMethod': methodMap[_payMethod] }),
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
        // ── Modal header ──
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
              const Text('Enrollment', style: TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w600, letterSpacing: 1)),
              Text(widget.course.title, style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w700)),
            ])),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ]),
        ),

        // ── Steps indicator ──
        if (_step < 3)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: ['Payment Method', 'Confirm'].asMap().entries.map((e) {
              final active = _step == e.key + 1;
              final done   = _step > e.key + 1;
              return Expanded(child: Padding(
                padding: EdgeInsets.only(right: e.key == 0 ? 8 : 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(height: 3, decoration: BoxDecoration(
                    color: (active || done) ? kPurple : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(99),
                  )),
                  const SizedBox(height: 4),
                  Text(e.value, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: active ? kPurple : Colors.grey[400])),
                ]),
              ));
            }).toList()),
          ),

        // ── Step content ──
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _step == 1 ? _buildStep1() : _step == 2 ? _buildStep2() : _buildStep3(),
          ),
        ),
      ]),
    );
  }

  Widget _buildStep1() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('How will you be paying for this course?',
      style: TextStyle(fontWeight: FontWeight.w700, color: kNavy, fontSize: 14)),
    const SizedBox(height: 12),

    ...kPaymentMethods.map((pm) {
      final selected = _payMethod == pm.id;
      return GestureDetector(
        onTap: () => setState(() => _payMethod = pm.id),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEEF2FF) : Colors.white,
            border: Border.all(color: selected ? kPurple : const Color(0xFFE5E7EB), width: selected ? 2 : 1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Text(pm.icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pm.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kNavy)),
              Text(pm.desc,  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ])),
            Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? kPurple : const Color(0xFFD1D5DB), width: 2),
                color: selected ? kPurple : Colors.transparent,
              ),
              child: selected ? const Center(child: CircleAvatar(radius: 3, backgroundColor: Colors.white)) : null,
            ),
          ]),
        ),
      );
    }),

    const SizedBox(height: 12),

    // Notice banner
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
            TextSpan(text: 'Payment gateway coming soon. ', style: TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: 'Your enrollment will be confirmed automatically. A pending payment record will be created and our team will contact you to finalize payment.'),
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
        child: const Text('Continue →', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white)),
      ),
    ),
  ]);

  Widget _buildStep2() {
    final pm = kPaymentMethods.firstWhere((p) => p.id == _payMethod);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Review your enrollment', style: TextStyle(fontWeight: FontWeight.w700, color: kNavy, fontSize: 14)),
      const SizedBox(height: 12),

      // Summary card
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
              Text(widget.course.title, style: const TextStyle(fontWeight: FontWeight.w700, color: kNavy, fontSize: 13)),
              Text('${widget.course.category} · ${widget.course.duration?['value']} ${widget.course.duration?['unit']}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ])),
          ]),
          const Divider(height: 20, color: Color(0xFFE5E7EB)),

          // Line items
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
      Wrap(spacing: 8, runSpacing: 8, children: [
        _TrustBadge(icon: Icons.shield_outlined,      label: 'Secure Enrollment'),
        _TrustBadge(icon: Icons.lock_outline,         label: 'Data Protected'),
        _TrustBadge(icon: Icons.check_circle_outline, label: 'Instant Confirmation'),
      ]),

      if (_error.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 14),
            const SizedBox(width: 8),
            Expanded(child: Text(_error, style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)))),
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
            child: const Text('← Back', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF374151))),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _enrolling ? null : _confirmEnroll,
            icon: _enrolling
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_circle, size: 16, color: Colors.white),
            label: Text(_enrolling ? 'Processing...' : 'Confirm Enrollment',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPurple, disabledBackgroundColor: kPurple.withOpacity(0.7),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ),
      ]),
    ]);
  }

  Widget _buildStep3() => Column(children: [
    const SizedBox(height: 8),
    Container(
      width: 72, height: 72,
      decoration: const BoxDecoration(color: Color(0xFFD1FAE5), shape: BoxShape.circle),
      child: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 36),
    ),
    const SizedBox(height: 16),
    const Text("You're Enrolled! 🎉", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kNavy)),
    const SizedBox(height: 6),
    Text("You've successfully enrolled in", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
    const SizedBox(height: 4),
    Text(widget.course.title, style: const TextStyle(fontWeight: FontWeight.w700, color: kPurple, fontSize: 15)),
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
          child: const Text('Browse More', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF374151))),
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
          child: const Text('View Progress', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ),
    ]),
  ]);
}

// ── Reusable small widgets ───────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color bg, fg;
  const _Badge({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
  );
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 13, color: Colors.grey[500]),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
  ]);
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _StatTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 14, color: Colors.grey[400]),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
      ]),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111827), fontSize: 13)),
    ]),
  );
}

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