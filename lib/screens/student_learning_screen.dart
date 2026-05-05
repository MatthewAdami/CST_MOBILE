import 'package:flutter/material.dart';

// ── Constants ─────────────────────────────────────────────────────
const Color kPurple = Color(0xFF7C3AED);
const Color kNavy = Color(0xFF0B1F3A);
const Color kGreen = Color(0xFF28A745);
const Color kYellow = Color(0xFFFFC107);
const Color kRed = Color(0xFFDC3545);
const Color kBg = Color(0xFFF1F3F5);
const Color kBorder = Color(0xFFE9ECEF);
const Color kMuted = Color(0xFF6C757D);
const Color kLight = Color(0xFFADB5BD);

// ── Models ────────────────────────────────────────────────────────
class LessonModel {
  final int id;
  final String title;
  final String duration;
  bool completed;
  bool quizPassed;

  LessonModel({
    required this.id,
    required this.title,
    required this.duration,
    this.completed = false,
    this.quizPassed = false,
  });

  LessonModel copyWith({bool? completed, bool? quizPassed}) => LessonModel(
        id: id,
        title: title,
        duration: duration,
        completed: completed ?? this.completed,
        quizPassed: quizPassed ?? this.quizPassed,
      );
}

class CourseModel {
  final int id;
  final String title;
  final String description;
  final Color color;
  final IconData icon;
  final int totalLessons;
  int completedLessons;
  List<LessonModel> lessons;

  CourseModel({
    required this.id,
    required this.title,
    required this.description,
    required this.color,
    required this.icon,
    required this.totalLessons,
    required this.completedLessons,
    required this.lessons,
  });

  CourseModel copyWith({int? completedLessons, List<LessonModel>? lessons}) =>
      CourseModel(
        id: id,
        title: title,
        description: description,
        color: color,
        icon: icon,
        totalLessons: totalLessons,
        completedLessons: completedLessons ?? this.completedLessons,
        lessons: lessons ?? this.lessons,
      );
}

class QuizQuestion {
  final String question;
  final List<String> options;
  final int answer;

  const QuizQuestion(
      {required this.question, required this.options, required this.answer});
}

// ── Mock Data ─────────────────────────────────────────────────────
final List<QuizQuestion> kQuizQuestions = [
  QuizQuestion(
    question:
        'What is the minimum tread depth required for front tires on a commercial vehicle?',
    options: ['2/32 inch', '4/32 inch', '6/32 inch', '8/32 inch'],
    answer: 1,
  ),
  QuizQuestion(
    question:
        'How many hours of off-duty time are required before a driver can restart their 60/70-hour clock?',
    options: ['24 hours', '34 hours', '48 hours', '10 hours'],
    answer: 1,
  ),
  QuizQuestion(
    question:
        'Which placard is required when transporting more than 1,000 lbs of a hazardous material?',
    options: ['FLAMMABLE', 'DANGEROUS', 'HAZMAT', 'CAUTION'],
    answer: 1,
  ),
];

List<CourseModel> buildInitialCourses() => [
      CourseModel(
        id: 1,
        title: 'Class A CDL Theory',
        description:
            'Master the knowledge required for your Class A Commercial Driver\'s License.',
        color: kPurple,
        icon: Icons.school_rounded,
        totalLessons: 6,
        completedLessons: 4,
        lessons: [
          LessonModel(
              id: 1,
              title: 'Introduction to Class A CDL',
              duration: '18 min',
              completed: true,
              quizPassed: true),
          LessonModel(
              id: 2,
              title: 'Vehicle Systems & Components',
              duration: '24 min',
              completed: true,
              quizPassed: true),
          LessonModel(
              id: 3,
              title: 'Pre-Trip Inspection Theory',
              duration: '30 min',
              completed: true,
              quizPassed: true),
          LessonModel(
              id: 4,
              title: 'Shifting & Basic Controls',
              duration: '22 min',
              completed: true,
              quizPassed: false),
          LessonModel(
              id: 5,
              title: 'Backing & Turning Techniques',
              duration: '28 min',
              completed: false,
              quizPassed: false),
          LessonModel(
              id: 6,
              title: 'CDL Written Exam Prep',
              duration: '35 min',
              completed: false,
              quizPassed: false),
        ],
      ),
      CourseModel(
        id: 2,
        title: 'Class B CDL Theory',
        description:
            'Learn the essentials of operating straight trucks and passenger vehicles.',
        color: const Color(0xFF0E9F8E),
        icon: Icons.menu_book_rounded,
        totalLessons: 4,
        completedLessons: 1,
        lessons: [
          LessonModel(
              id: 1,
              title: 'Class B Vehicle Overview',
              duration: '16 min',
              completed: true,
              quizPassed: true),
          LessonModel(
              id: 2,
              title: 'Passenger Vehicle Safety',
              duration: '20 min',
              completed: false,
              quizPassed: false),
          LessonModel(
              id: 3,
              title: 'City Driving & Intersections',
              duration: '25 min',
              completed: false,
              quizPassed: false),
          LessonModel(
              id: 4,
              title: 'Class B Written Exam Prep',
              duration: '30 min',
              completed: false,
              quizPassed: false),
        ],
      ),
      CourseModel(
        id: 3,
        title: 'Hazmat Regulations',
        description:
            'Understand hazardous materials handling, placarding, and safety compliance.',
        color: kRed,
        icon: Icons.warning_amber_rounded,
        totalLessons: 5,
        completedLessons: 2,
        lessons: [
          LessonModel(
              id: 1,
              title: 'Hazmat Classification & Types',
              duration: '20 min',
              completed: true,
              quizPassed: true),
          LessonModel(
              id: 2,
              title: 'Placarding Requirements',
              duration: '18 min',
              completed: true,
              quizPassed: true),
          LessonModel(
              id: 3,
              title: 'Loading & Unloading Procedures',
              duration: '22 min',
              completed: false,
              quizPassed: false),
          LessonModel(
              id: 4,
              title: 'Emergency Response Protocols',
              duration: '26 min',
              completed: false,
              quizPassed: false),
          LessonModel(
              id: 5,
              title: 'Hazmat Endorsement Exam Prep',
              duration: '32 min',
              completed: false,
              quizPassed: false),
        ],
      ),
      CourseModel(
        id: 4,
        title: 'DOT Compliance',
        description:
            'Stay compliant with Federal Motor Carrier Safety Administration regulations.',
        color: kYellow,
        icon: Icons.description_rounded,
        totalLessons: 4,
        completedLessons: 0,
        lessons: [
          LessonModel(
              id: 1,
              title: 'Hours of Service (HOS) Rules',
              duration: '22 min',
              completed: false,
              quizPassed: false),
          LessonModel(
              id: 2,
              title: 'Electronic Logging Devices (ELD)',
              duration: '18 min',
              completed: false,
              quizPassed: false),
          LessonModel(
              id: 3,
              title: 'Driver Qualification Files',
              duration: '15 min',
              completed: false,
              quizPassed: false),
          LessonModel(
              id: 4,
              title: 'Drug & Alcohol Testing Requirements',
              duration: '20 min',
              completed: false,
              quizPassed: false),
        ],
      ),
    ];

// ── Entry ─────────────────────────────────────────────────────────

// ── Main Screen ───────────────────────────────────────────────────
class StudentLearningScreen extends StatefulWidget {
  const StudentLearningScreen({super.key});

  @override
  State<StudentLearningScreen> createState() => _StudentLearningScreenState();
}

class _StudentLearningScreenState extends State<StudentLearningScreen> {
  late List<CourseModel> _courses;
  CourseModel? _selectedCourse;
  LessonModel? _selectedLesson;

  @override
  void initState() {
    super.initState();
    _courses = buildInitialCourses();
  }

  int get totalLessons => _courses.fold(0, (a, c) => a + c.totalLessons);
  int get completedLessons =>
      _courses.fold(0, (a, c) => a + c.completedLessons);
  double get overallPct =>
      totalLessons == 0 ? 0 : completedLessons / totalLessons;

  void _handleCompleteLesson(int lessonId, bool quizPassed) {
    setState(() {
      _courses = _courses.map((c) {
        if (c.id != _selectedCourse!.id) return c;
        final alreadyDone = c.lessons.any((l) => l.id == lessonId && l.completed);
        final newLessons = c.lessons
            .map((l) => l.id == lessonId ? l.copyWith(completed: true, quizPassed: quizPassed) : l)
            .toList();
        return c.copyWith(
          completedLessons: alreadyDone ? c.completedLessons : c.completedLessons + 1,
          lessons: newLessons,
        );
      }).toList();

      // Sync selected course
      _selectedCourse = _courses.firstWhere((c) => c.id == _selectedCourse!.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedLesson != null && _selectedCourse != null) {
      return LessonViewScreen(
        lesson: _selectedLesson!,
        course: _selectedCourse!,
        onBack: () => setState(() => _selectedLesson = null),
        onCompleteLesson: _handleCompleteLesson,
      );
    }

    if (_selectedCourse != null) {
      final fresh = _courses.firstWhere((c) => c.id == _selectedCourse!.id);
      return CourseDetailScreen(
        course: fresh,
        onBack: () => setState(() => _selectedCourse = null),
        onSelectLesson: (lesson) => setState(() {
          _selectedLesson = lesson;
          _selectedCourse = _courses.firstWhere((c) => c.id == _selectedCourse!.id);
        }),
      );
    }

    return _buildCoursesHome();
  }

  Widget _buildCoursesHome() {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.menu_book_rounded, color: kPurple, size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    'Online Learning',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: kNavy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Complete theory modules and quizzes before your practical sessions.',
                style: TextStyle(fontSize: 13, color: kMuted),
              ),
              const SizedBox(height: 20),

              // Overall progress banner
              _OverallProgressCard(
                overallPct: overallPct,
                completedLessons: completedLessons,
                totalLessons: totalLessons,
                courseCount: _courses.length,
              ),
              const SizedBox(height: 20),

              // Course grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: _courses.length,
                itemBuilder: (_, i) => _CourseCard(
                  course: _courses[i],
                  onTap: () => setState(() => _selectedCourse = _courses[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Overall Progress Card ─────────────────────────────────────────
class _OverallProgressCard extends StatelessWidget {
  final double overallPct;
  final int completedLessons;
  final int totalLessons;
  final int courseCount;

  const _OverallProgressCard({
    required this.overallPct,
    required this.completedLessons,
    required this.totalLessons,
    required this.courseCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Overall Learning Progress',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kNavy)),
              Text('${(overallPct * 100).round()}%',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kPurple)),
            ],
          ),
          const SizedBox(height: 8),
          _ProgressBar(value: overallPct, color: kPurple, height: 10),
          const SizedBox(height: 6),
          Text('$completedLessons of $totalLessons lessons completed across all courses',
              style: const TextStyle(fontSize: 12, color: kLight)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatChip(label: 'Courses', value: courseCount, color: kPurple),
              _StatChip(label: 'Completed', value: completedLessons, color: kGreen),
              _StatChip(label: 'Remaining', value: totalLessons - completedLessons, color: kYellow),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text('$value',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: kLight)),
        ],
      );
}

// ── Course Card ───────────────────────────────────────────────────
class _CourseCard extends StatelessWidget {
  final CourseModel course;
  final VoidCallback onTap;

  const _CourseCard({required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pct = course.totalLessons == 0
        ? 0.0
        : course.completedLessons / course.totalLessons;
    final allDone = course.completedLessons == course.totalLessons;
    final inProgress = !allDone && course.completedLessons > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 4)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: course.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(course.icon, color: course.color, size: 20),
                ),
                _StatusBadge(
                  allDone: allDone,
                  inProgress: inProgress,
                  color: course.color,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(course.title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: kNavy),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(course.description,
                style: const TextStyle(fontSize: 11, color: kMuted, height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
            const Spacer(),
            _ProgressBar(value: pct, color: course.color, height: 6),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${course.completedLessons}/${course.totalLessons} lessons',
                    style: const TextStyle(fontSize: 11, color: kLight)),
                Text('${(pct * 100).round()}%',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800, color: course.color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool allDone;
  final bool inProgress;
  final Color color;

  const _StatusBadge(
      {required this.allDone, required this.inProgress, required this.color});

  @override
  Widget build(BuildContext context) {
    if (allDone) {
      return _badge('Complete', kGreen, const Color(0xFFE8F5E9), Icons.check_circle, 10);
    } else if (inProgress) {
      return _badge('In Progress', color, color.withOpacity(0.1), null, null);
    } else {
      return _badge('Not Started', kLight, const Color(0xFFF1F3F5), null, null);
    }
  }

  Widget _badge(String text, Color fg, Color bg, IconData? icon, double? iconSize) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: fg, size: iconSize),
              const SizedBox(width: 3),
            ],
            Text(text,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
          ],
        ),
      );
}

// ── Progress Bar ──────────────────────────────────────────────────
class _ProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;

  const _ProgressBar({required this.value, required this.color, required this.height});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          minHeight: height,
          backgroundColor: kBorder,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
}

// ── Course Detail Screen ──────────────────────────────────────────
class CourseDetailScreen extends StatelessWidget {
  final CourseModel course;
  final VoidCallback onBack;
  final void Function(LessonModel) onSelectLesson;

  const CourseDetailScreen({
    super.key,
    required this.course,
    required this.onBack,
    required this.onSelectLesson,
  });

  @override
  Widget build(BuildContext context) {
    final pct = course.totalLessons == 0
        ? 0.0
        : course.completedLessons / course.totalLessons;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            // Back + header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  _BackButton(onTap: onBack),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(course.title,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800, color: kNavy)),
                        Text(course.description,
                            style: const TextStyle(fontSize: 12, color: kMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Progress card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kBorder),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Course Progress',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kNavy)),
                        Text('${(pct * 100).round()}%',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w800, color: course.color)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _ProgressBar(value: pct, color: course.color, height: 10),
                    const SizedBox(height: 6),
                    Text('${course.completedLessons} of ${course.totalLessons} lessons completed',
                        style: const TextStyle(fontSize: 12, color: kLight)),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatChip(label: 'Total', value: course.totalLessons, color: kNavy),
                        _StatChip(label: 'Completed', value: course.completedLessons, color: kGreen),
                        _StatChip(
                            label: 'Remaining',
                            value: course.totalLessons - course.completedLessons,
                            color: course.color),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Lessons list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: course.lessons.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, idx) {
                  final lesson = course.lessons[idx];
                  final locked = idx > 0 && !course.lessons[idx - 1].completed;
                  return _LessonTile(
                    lesson: lesson,
                    index: idx,
                    locked: locked,
                    course: course,
                    onTap: locked ? null : () => onSelectLesson(lesson),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  final LessonModel lesson;
  final int index;
  final bool locked;
  final CourseModel course;
  final VoidCallback? onTap;

  const _LessonTile({
    required this.lesson,
    required this.index,
    required this.locked,
    required this.course,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: locked ? 0.6 : 1.0,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border(
                left: BorderSide(
                  color: lesson.completed
                      ? kGreen
                      : locked
                          ? kBorder
                          : course.color,
                  width: 4,
                ),
                top: BorderSide(color: locked ? const Color(0xFFF1F3F5) : kBorder),
                right: BorderSide(color: locked ? const Color(0xFFF1F3F5) : kBorder),
                bottom: BorderSide(color: locked ? const Color(0xFFF1F3F5) : kBorder),
              ),
            ),
            child: Row(
              children: [
                // Status circle
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: lesson.completed
                        ? const Color(0xFFE8F5E9)
                        : locked
                            ? const Color(0xFFF1F3F5)
                            : course.color.withOpacity(0.1),
                  ),
                  child: Center(
                    child: lesson.completed
                        ? const Icon(Icons.check_circle, color: kGreen, size: 18)
                        : locked
                            ? const Icon(Icons.lock, color: kLight, size: 16)
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: course.color),
                              ),
                  ),
                ),
                const SizedBox(width: 12),

                // Title + meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lesson.title,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: locked ? kLight : kNavy)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _MetaChip(icon: Icons.play_circle_outline, label: 'Video'),
                          const SizedBox(width: 10),
                          _MetaChip(icon: Icons.description_outlined, label: 'Quiz'),
                          const SizedBox(width: 10),
                          _MetaChip(icon: Icons.download_outlined, label: 'Notes'),
                          const SizedBox(width: 10),
                          _MetaChip(icon: Icons.access_time, label: lesson.duration),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Badge or chevron
                if (lesson.completed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: lesson.quizPassed
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          lesson.quizPassed
                              ? Icons.check_circle
                              : Icons.warning_amber_rounded,
                          color: lesson.quizPassed ? kGreen : kYellow,
                          size: 11,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          lesson.quizPassed ? 'Passed' : 'Retake',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: lesson.quizPassed ? kGreen : kYellow),
                        ),
                      ],
                    ),
                  )
                else if (!locked)
                  const Icon(Icons.chevron_right, color: kLight, size: 18),
              ],
            ),
          ),
        ),
      );
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: kLight),
          const SizedBox(width: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: kLight)),
        ],
      );
}

// ── Lesson View Screen ────────────────────────────────────────────
class LessonViewScreen extends StatefulWidget {
  final LessonModel lesson;
  final CourseModel course;
  final VoidCallback onBack;
  final void Function(int lessonId, bool quizPassed) onCompleteLesson;

  const LessonViewScreen({
    super.key,
    required this.lesson,
    required this.course,
    required this.onBack,
    required this.onCompleteLesson,
  });

  @override
  State<LessonViewScreen> createState() => _LessonViewScreenState();
}

class _LessonViewScreenState extends State<LessonViewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<int, int> _quizAnswers = {};
  bool _quizSubmitted = false;
  int _quizScore = 0;

  final List<QuizQuestion> _questions = kQuizQuestions;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _submitQuiz() {
    int score = 0;
    for (int i = 0; i < _questions.length; i++) {
      if (_quizAnswers[i] == _questions[i].answer) score++;
    }
    setState(() {
      _quizScore = score;
      _quizSubmitted = true;
    });
    widget.onCompleteLesson(widget.lesson.id, score >= 2);
  }

  bool get _passed => _quizScore >= 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  _BackButton(onTap: widget.onBack),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.course.title,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: widget.course.color)),
                        Text(widget.lesson.title,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800, color: kNavy),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kBorder),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: widget.course.color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: kMuted,
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Video'),
                    Tab(text: 'Quiz'),
                    Tab(text: 'Notes'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _VideoTab(
                    lesson: widget.lesson,
                    course: widget.course,
                    onGoToQuiz: () => _tabController.animateTo(1),
                    onGoToNotes: () => _tabController.animateTo(2),
                  ),
                  _QuizTab(
                    questions: _questions,
                    quizAnswers: _quizAnswers,
                    quizSubmitted: _quizSubmitted,
                    quizScore: _quizScore,
                    passed: _passed,
                    course: widget.course,
                    onAnswerSelected: (qi, oi) =>
                        setState(() => _quizAnswers[qi] = oi),
                    onSubmit: _submitQuiz,
                    onRetry: () => setState(() {
                      _quizSubmitted = false;
                      _quizAnswers.clear();
                    }),
                    onBack: widget.onBack,
                  ),
                  _NotesTab(lesson: widget.lesson, course: widget.course),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Video Tab ─────────────────────────────────────────────────────
class _VideoTab extends StatelessWidget {
  final LessonModel lesson;
  final CourseModel course;
  final VoidCallback onGoToQuiz;
  final VoidCallback onGoToNotes;

  const _VideoTab({
    required this.lesson,
    required this.course,
    required this.onGoToQuiz,
    required this.onGoToNotes,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video player mockup
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0B1F3A), Color(0xFF1a3a5c)],
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: course.color.withOpacity(0.2),
                            border: Border.all(color: course.color, width: 3),
                          ),
                          child: Icon(Icons.play_circle_fill_rounded,
                              color: course.color, size: 36),
                        ),
                        const SizedBox(height: 14),
                        Text(lesson.title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('${lesson.duration} · Tap to play',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                    // Fake progress bar
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(14)),
                        child: SizedBox(
                          height: 4,
                          child: LinearProgressIndicator(
                            value: 0.35,
                            backgroundColor: Colors.white12,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(course.color),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // About card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('About this lesson',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: kNavy)),
                  const SizedBox(height: 8),
                  Text(
                    'This lesson covers the essential theory and concepts you need to know for ${lesson.title.toLowerCase()}. '
                    'Watch the full video before proceeding to the quiz. You can download the lesson notes below for offline review.',
                    style: const TextStyle(
                        fontSize: 13, color: kMuted, height: 1.6),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _ActionButton(
                        label: 'Take Quiz',
                        icon: Icons.description_rounded,
                        color: course.color,
                        onTap: onGoToQuiz,
                      ),
                      const SizedBox(width: 10),
                      _ActionButton(
                        label: 'Download Notes',
                        icon: Icons.download_rounded,
                        color: kMuted,
                        outlined: true,
                        onTap: onGoToNotes,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

// ── Quiz Tab ──────────────────────────────────────────────────────
class _QuizTab extends StatelessWidget {
  final List<QuizQuestion> questions;
  final Map<int, int> quizAnswers;
  final bool quizSubmitted;
  final int quizScore;
  final bool passed;
  final CourseModel course;
  final void Function(int qi, int oi) onAnswerSelected;
  final VoidCallback onSubmit;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _QuizTab({
    required this.questions,
    required this.quizAnswers,
    required this.quizSubmitted,
    required this.quizScore,
    required this.passed,
    required this.course,
    required this.onAnswerSelected,
    required this.onSubmit,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    if (quizSubmitted) {
      return _QuizResult(
        score: quizScore,
        total: questions.length,
        passed: passed,
        course: course,
        onRetry: onRetry,
        onBack: onBack,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: course.color.withOpacity(0.05),
              border: Border.all(color: course.color.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '📝 ${questions.length} questions · Pass mark: 2/${questions.length} · You can retake if needed',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: course.color),
            ),
          ),

          // Questions
          ...List.generate(questions.length, (qi) {
            final q = questions[qi];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${qi + 1}. ${q.question}',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: kNavy)),
                  const SizedBox(height: 12),
                  ...List.generate(q.options.length, (oi) {
                    final selected = quizAnswers[qi] == oi;
                    return GestureDetector(
                      onTap: () => onAnswerSelected(qi, oi),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? course.color.withOpacity(0.05)
                              : const Color(0xFFFAFAFA),
                          border: Border.all(
                              color: selected ? course.color : kBorder,
                              width: selected ? 1.5 : 1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: selected ? course.color : kBorder,
                                    width: 2),
                                color: selected ? course.color : Colors.transparent,
                              ),
                              child: selected
                                  ? const Icon(Icons.circle,
                                      color: Colors.white, size: 8)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(q.options[oi],
                                  style: const TextStyle(
                                      fontSize: 13, color: kNavy)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),

          // Submit button
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: quizAnswers.length < questions.length ? null : onSubmit,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                decoration: BoxDecoration(
                  color: quizAnswers.length < questions.length
                      ? kBorder
                      : course.color,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: quizAnswers.length >= questions.length
                      ? [
                          BoxShadow(
                              color: course.color.withOpacity(0.3),
                              blurRadius: 14,
                              offset: const Offset(0, 4))
                        ]
                      : null,
                ),
                child: Text(
                  'Submit Quiz',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: quizAnswers.length < questions.length
                          ? kLight
                          : Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizResult extends StatelessWidget {
  final int score;
  final int total;
  final bool passed;
  final CourseModel course;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _QuizResult({
    required this.score,
    required this.total,
    required this.passed,
    required this.course,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: passed ? const Color(0xFFE8F5E9) : const Color(0xFFFDECEA),
                  ),
                  child: Icon(
                    passed ? Icons.emoji_events_rounded : Icons.cancel_rounded,
                    color: passed ? kGreen : kRed,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  passed ? 'Quiz Passed! 🎉' : 'Not quite there yet',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800, color: kNavy),
                ),
                const SizedBox(height: 8),
                Text('$score / $total',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: passed ? kGreen : kRed)),
                const SizedBox(height: 6),
                Text(
                  passed
                      ? 'Great job! You can proceed to the next lesson.'
                      : 'You need 2/3 to pass. Review the video and try again.',
                  style: const TextStyle(fontSize: 13, color: kMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!passed)
                      _ActionButton(
                        label: 'Retry Quiz',
                        icon: Icons.refresh_rounded,
                        color: course.color,
                        onTap: onRetry,
                      ),
                    if (!passed) const SizedBox(width: 10),
                    _ActionButton(
                      label: 'Back to Course',
                      icon: Icons.arrow_back_rounded,
                      color: kMuted,
                      outlined: true,
                      onTap: onBack,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

// ── Notes Tab ─────────────────────────────────────────────────────
class _NotesTab extends StatelessWidget {
  final LessonModel lesson;
  final CourseModel course;

  const _NotesTab({required this.lesson, required this.course});

  @override
  Widget build(BuildContext context) {
    final notes = [
      {'title': '${lesson.title} — Full Notes', 'size': '1.2 MB', 'pages': 8},
      {'title': '${lesson.title} — Quick Reference', 'size': '0.4 MB', 'pages': 2},
      {'title': '${course.title} — Glossary', 'size': '0.6 MB', 'pages': 4},
    ];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: notes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final note = notes[i];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: course.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.picture_as_pdf_rounded,
                    color: course.color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(note['title'] as String,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kNavy),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(
                        'PDF · ${note['pages']} pages · ${note['size']}',
                        style: const TextStyle(fontSize: 11, color: kLight)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: course.color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download_rounded,
                          color: Colors.white, size: 13),
                      SizedBox(width: 4),
                      Text('Download',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────
class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F3F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.chevron_left_rounded, color: kNavy, size: 20),
        ),
      );
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool outlined;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.outlined = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: outlined ? const Color(0xFFF8F9FA) : color,
            border: outlined ? Border.all(color: kBorder) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: outlined ? color : Colors.white, size: 14),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: outlined ? color : Colors.white)),
            ],
          ),
        ),
      );
}