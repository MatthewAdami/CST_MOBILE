import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ── Colours (matches web exactly) ────────────────────────────────
class _OC {
  static const navy        = Color(0xFF0B1F3A);
  static const purple      = Color(0xFF7C3AED);
  static const purpleLight = Color(0xFF9F67FA);
  static const gold        = Color(0xFFC9A84C);
  static const white       = Color(0xFFFFFFFF);
  static const gray50      = Color(0xFFF8F9FA);
  static const gray100     = Color(0xFFF1F3F5);
  static const gray200     = Color(0xFFE9ECEF);
  static const gray400     = Color(0xFFADB5BD);
  static const gray600     = Color(0xFF6C757D);
  static const gray800     = Color(0xFF343A40);
  static const green       = Color(0xFF198754);
  static const red         = Color(0xFFDC3545);
  static const orange      = Color(0xFFFD7E14);
  static const blue        = Color(0xFF0D6EFD);
}

const _kApiBase = 'http://10.0.2.2:5000';

// ════════════════════════════════════════════════════════════════
// ONBOARDING MODAL
// mirrors OnboardingModal.jsx exactly — 4 steps
// ════════════════════════════════════════════════════════════════
class OnboardingModal extends StatefulWidget {
  final String   studentName;
  final VoidCallback onDismiss;
  /// When true (every-login reminder), the welcome step shows
  /// "Quick Reminder" copy instead of "Welcome!" copy.
  final bool isReminder;

  const OnboardingModal({
    super.key,
    required this.studentName,
    required this.onDismiss,
    this.isReminder = false,
  });

  @override
  State<OnboardingModal> createState() => _OnboardingModalState();
}

class _OnboardingModalState extends State<OnboardingModal>
    with SingleTickerProviderStateMixin {
  int _step = 0; // 0 = welcome, 1-3 = steps

  static const _totalSteps = 4;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 280));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override void dispose() { _animCtrl.dispose(); super.dispose(); }

  void _goNext() {
    if (_step == _totalSteps - 1) { widget.onDismiss(); return; }
    _animCtrl.reset();
    setState(() => _step++);
    _animCtrl.forward();
  }

  void _goBack() {
    if (_step == 0) return;
    _animCtrl.reset();
    setState(() => _step--);
    _animCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // ── Backdrop ─────────────────────────────────────────
          GestureDetector(
            onTap: widget.onDismiss,
            child: Container(color: const Color(0xB30B1F3A)),
          ),

          // ── Modal card ───────────────────────────────────────
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 520),
                      color: _OC.white,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Progress bar
                          _ProgressBar(step: _step, total: _totalSteps),

                          // Content
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: MediaQuery.of(context).size.height * 0.75),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
                              child: _buildStepContent(),
                            ),
                          ),

                          // Footer
                          _ModalFooter(
                            step:        _step,
                            totalSteps:  _totalSteps,
                            onNext:      _goNext,
                            onBack:      _goBack,
                            onSkip:      widget.onDismiss,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:  return _WelcomeStep(studentName: widget.studentName, isReminder: widget.isReminder);
      case 1:  return const _DocumentsStep();
      case 2:  return const _AgreementStep();
      case 3:  return const _StudyStep();
      default: return const SizedBox.shrink();
    }
  }
}

// ── Progress bar ─────────────────────────────────────────────────
class _ProgressBar extends StatelessWidget {
  final int step, total;
  const _ProgressBar({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = step == 0 ? 0.0 : step / (total - 1);
    return SizedBox(
      height: 4,
      child: LinearProgressIndicator(
        value: pct,
        backgroundColor: _OC.gray200,
        valueColor: const AlwaysStoppedAnimation(_OC.purple),
      ),
    );
  }
}

// ── Step dots + footer buttons ────────────────────────────────────
class _ModalFooter extends StatelessWidget {
  final int  step, totalSteps;
  final VoidCallback onNext, onBack, onSkip;

  const _ModalFooter({
    required this.step, required this.totalSteps,
    required this.onNext, required this.onBack, required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final isLast  = step == totalSteps - 1;
    final isFirst = step == 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
      child: Row(
        children: [
          // Step dots
          Row(
            children: List.generate(totalSteps, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width:  i == step ? 20 : 7,
              height: 7,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color:        i == step ? _OC.purple : _OC.gray200,
                borderRadius: BorderRadius.circular(4)),
            )),
          ),
          const Spacer(),

          // Back
          if (!isFirst) ...[
            TextButton(
              onPressed: onBack,
              style: TextButton.styleFrom(
                backgroundColor: _OC.white,
                foregroundColor: _OC.gray600,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                  side: const BorderSide(color: _OC.gray200)),
              ),
              child: const Text('Back',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 10),
          ],

          // Next / Finish
          if (isLast)
            ElevatedButton.icon(
              onPressed: onSkip,
              style: ElevatedButton.styleFrom(
                backgroundColor: _OC.green,
                foregroundColor: _OC.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              ),
              icon: const Icon(Icons.check_circle, size: 15),
              label: const Text('Go to Dashboard',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            )
          else
            ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: _OC.purple,
                foregroundColor: _OC.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Text('Next', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                SizedBox(width: 6),
                Icon(Icons.chevron_right, size: 14),
              ]),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// STEP 0 — WELCOME
// ════════════════════════════════════════════════════════════════
class _WelcomeStep extends StatelessWidget {
  final String studentName;
  final bool   isReminder;
  const _WelcomeStep({required this.studentName, this.isReminder = false});

  static const _previewSteps = [
    (icon: Icons.upload_file_outlined,  label: 'Upload Your Documents'),
    (icon: Icons.draw_outlined,          label: 'Sign Enrollment Agreement'),
    (icon: Icons.menu_book_outlined,     label: 'Study Your Manual'),
  ];

  @override
  Widget build(BuildContext context) {
    final badgeLabel = isReminder ? 'ONBOARDING REMINDER' : 'NEW STUDENT';
    final titleText  = isReminder
      ? 'Quick Reminder,\n$studentName! 👋'
      : 'Welcome to CST,\n$studentName! 🎉';
    final subtitleText = isReminder
      ? "Here's a quick look at the key steps to complete before your training begins. Tap any section to review."
      : "Your application has been approved and your account is ready. Let's walk you through the first steps to get you started on your CDL training journey.";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Purple avatar
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isReminder
                ? [const Color(0xFF0E9F8E), const Color(0xFF0B7A6E)]
                : [_OC.purple, _OC.purpleLight],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(
              color: (isReminder ? const Color(0xFF0E9F8E) : _OC.purple)
                .withValues(alpha: 0.35),
              blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Icon(
            isReminder ? Icons.notifications_active : Icons.school,
            color: _OC.white, size: 36)),

        const SizedBox(height: 20),

        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: (isReminder ? const Color(0xFF0E9F8E) : _OC.purple)
              .withValues(alpha: 0.1),
            border: Border.all(color: (isReminder
              ? const Color(0xFF0E9F8E) : _OC.purple).withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6,
              decoration: BoxDecoration(
                color: isReminder ? const Color(0xFF0E9F8E) : _OC.purple,
                shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(badgeLabel, style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: isReminder ? const Color(0xFF0E9F8E) : _OC.purple,
              letterSpacing: 0.8)),
          ])),

        const SizedBox(height: 14),

        // Title
        Text(titleText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24, fontWeight: FontWeight.w800,
            color: _OC.navy, height: 1.25)),

        const SizedBox(height: 12),

        Text(subtitleText,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: _OC.gray600, height: 1.6)),

        const SizedBox(height: 24),

        // Step preview pills
        ..._previewSteps.asMap().entries.map((e) {
          final i = e.key; final s = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _OC.gray50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _OC.gray200)),
              child: Row(children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: _OC.purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8)),
                  child: Icon(s.icon, color: _OC.purple, size: 16)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Step ${i + 1}: ${s.label}',
                    style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: _OC.navy))),
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _OC.gray200, width: 2)),
                  child: Center(child: Text('${i + 1}',
                    style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800, color: _OC.gray400)))),
              ]),
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// STEP 1 — DOCUMENTS
// ════════════════════════════════════════════════════════════════
class _DocumentsStep extends StatelessWidget {
  const _DocumentsStep();

  static const _items = [
    (icon: Icons.shield_outlined,           label: 'Government ID',                     required: true),
    (icon: Icons.directions_car_outlined,   label: "Driver's License",                  required: true),
    (icon: Icons.medical_services_outlined, label: 'DOT Medical Certificate',           required: true),
    (icon: Icons.verified_outlined,         label: 'Proof of Enrollment',               required: true),
    (icon: Icons.credit_card_outlined,      label: "Commercial Learner's Permit (CLP)", required: true),
    (icon: Icons.military_tech_outlined,    label: 'DD-214 (Veterans only)',            required: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeader(
          icon: Icons.upload_file_outlined,
          stepLabel: 'Step 1 of 3',
          title: 'Upload Your Documents',
          description: 'Upload the following required documents to complete your enrollment.',
        ),

        const SizedBox(height: 16),

        ..._items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _OC.gray50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _OC.gray200)),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: item.required
                    ? _OC.purple.withValues(alpha: 0.12)
                    : _OC.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(7)),
                child: Icon(item.icon,
                  color: item.required ? _OC.purple : _OC.gold, size: 15)),
              const SizedBox(width: 12),
              Expanded(child: Text(item.label,
                style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _OC.navy))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: item.required
                    ? const Color(0xFFFEE2E2)
                    : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20)),
                child: Text(
                  item.required ? 'Required' : 'Veterans',
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800,
                    color: item.required
                      ? const Color(0xFF991B1B) : const Color(0xFF92400E),
                    letterSpacing: 0.4))),
            ]),
          ),
        )),

        const SizedBox(height: 12),

        const Text(
          'You can upload documents anytime from the Documents section in your portal.',
          style: TextStyle(fontSize: 12, color: _OC.gray400)),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// STEP 2 — ENROLLMENT AGREEMENT
// ════════════════════════════════════════════════════════════════
class _AgreementStep extends StatelessWidget {
  const _AgreementStep();

  static const _highlights = [
    (label: 'Personal Information',   desc: 'Your basic student details'),
    (label: 'Course Selection',       desc: 'Your CDL class and program'),
    (label: 'Tuition & Payment Plan', desc: 'Financial terms and schedule'),
    (label: 'Code of Conduct',        desc: 'School rules and expectations'),
    (label: 'Digital Signature',      desc: 'Legally binding e-signature'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeader(
          icon: Icons.draw_outlined,
          stepLabel: 'Step 2 of 3',
          title: 'Sign Enrollment Agreement',
          description: 'Complete and e-sign your 9-step enrollment agreement before training begins.',
        ),

        const SizedBox(height: 16),

        ..._highlights.asMap().entries.map((e) {
          final i = e.key; final item = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: _OC.purple.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Center(child: Text('${i + 1}',
                  style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800, color: _OC.purple)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.label,
                  style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: _OC.navy)),
                Text(item.desc,
                  style: const TextStyle(fontSize: 11, color: _OC.gray400)),
              ])),
            ]),
          );
        }),

        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            border: Border.all(color: const Color(0xFFFDE68A)),
            borderRadius: BorderRadius.circular(8)),
          child: const Text(
            '⚠️ Your enrollment agreement must be completed and approved before your training begins.',
            style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.5))),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// STEP 3 — STUDY MANUAL
// ════════════════════════════════════════════════════════════════
class _StudyStep extends StatelessWidget {
  const _StudyStep();

  static const _resources = [
    (icon: Icons.menu_book_outlined,    color: _OC.purple, label: "Learner's Manual",
     desc: 'Full CST Student Driver Handbook — read it inline or download'),
    (icon: Icons.auto_awesome_outlined, color: _OC.green,  label: 'CDL Study AI',
     desc: 'Ask any CDL question and get instant answers powered by AI'),
    (icon: Icons.assignment_outlined,   color: _OC.gold,   label: 'Study Guide',
     desc: 'Section-by-section CDL exam preparation guide'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeader(
          icon: Icons.menu_book_outlined,
          stepLabel: 'Step 3 of 3',
          title: 'Study Your Manual',
          description: "Access the CST Learner's Manual and CDL Study AI to start preparing for your knowledge test.",
        ),

        const SizedBox(height: 16),

        ..._resources.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _OC.gray50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _OC.gray200)),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9)),
                child: Icon(item.icon, color: item.color, size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.label,
                  style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: _OC.navy)),
                Text(item.desc,
                  style: const TextStyle(fontSize: 11, color: _OC.gray600, height: 1.4)),
              ])),
              const Icon(Icons.chevron_right, size: 14, color: _OC.gray400),
            ]),
          ),
        )),

        // "All done" banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _OC.green.withValues(alpha: 0.08),
            border: Border.all(color: _OC.green.withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            const Icon(Icons.check_circle, size: 18, color: _OC.green),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                "That's everything! You're all set to begin your CDL journey with CST.",
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: _OC.green, height: 1.4))),
          ])),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Shared step header ────────────────────────────────────────────
class _StepHeader extends StatelessWidget {
  final IconData icon;
  final String   stepLabel, title, description;
  const _StepHeader({
    required this.icon, required this.stepLabel,
    required this.title, required this.description,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          color: _OC.purple.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, color: _OC.purple, size: 26)),
      const SizedBox(height: 14),
      Text(stepLabel.toUpperCase(),
        style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: _OC.purple, letterSpacing: 0.8)),
      const SizedBox(height: 6),
      Text(title,
        style: const TextStyle(
          fontSize: 22, fontWeight: FontWeight.w800, color: _OC.navy)),
      const SizedBox(height: 8),
      Text(description,
        style: const TextStyle(
          fontSize: 13, color: _OC.gray600, height: 1.5)),
    ],
  );
}

// ════════════════════════════════════════════════════════════════
// ONBOARDING BANNER
// mirrors OnboardingBanner.jsx — shown until docs + agreement done
// ════════════════════════════════════════════════════════════════
class OnboardingBanner extends StatelessWidget {
  final List<Map<String, dynamic>> documents;
  final Map<String, dynamic>?      agreement;
  final bool                       loading;

  const OnboardingBanner({
    super.key,
    required this.documents,
    required this.agreement,
    required this.loading,
  });

  static const _requiredDocs = [
    'government-id',
    'drivers-license',
    'medical-certificate',
    'proof-of-enrollment',
    'cdl-permit',
  ];

  @override
  Widget build(BuildContext context) {
    if (loading) return const SizedBox.shrink();

    final approvedDocs = documents.where((d) =>
      _requiredDocs.contains(d['docType']) && d['status'] == 'approved').length;
    final docsComplete    = approvedDocs == _requiredDocs.length;
    final agreementStatus = agreement?['status'] ?? '';
    final agreementDone   = agreementStatus == 'approved' || agreementStatus == 'submitted';

    if (docsComplete && agreementDone) return const SizedBox.shrink();

    final missingDocs = _requiredDocs.length - approvedDocs;
    final currentStep = (agreement?['currentStep'] as int?) ?? 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: _OC.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _OC.gray200),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      // Red left accent
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left red stripe
              Container(width: 4, color: _OC.red),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(9)),
                          child: const Icon(Icons.warning_amber_rounded,
                            color: _OC.red, size: 18)),
                        const SizedBox(width: 10),
                        const Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Complete Your Onboarding',
                              style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700,
                                color: _OC.navy)),
                            Text('Finish these steps before your training begins',
                              style: TextStyle(fontSize: 12, color: _OC.gray600)),
                          ])),
                      ]),

                      const SizedBox(height: 14),

                      // Documents item
                      _BannerItem(
                        icon: docsComplete
                          ? Icons.check_circle : Icons.upload_file_outlined,
                        iconColor: docsComplete ? _OC.green : _OC.red,
                        bgColor: docsComplete
                          ? _OC.green.withValues(alpha: 0.12)
                          : const Color(0xFFFEE2E2),
                        containerColor: docsComplete
                          ? const Color(0xFFF0FDF4) : const Color(0xFFFFF5F5),
                        borderColor: docsComplete
                          ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                        title: 'Upload Required Documents',
                        subtitle: docsComplete
                          ? 'All required documents submitted'
                          : '$missingDocs document${missingDocs != 1 ? "s" : ""} still missing or pending',
                        showButton: !docsComplete,
                        buttonLabel: 'Upload Now',
                      ),

                      const SizedBox(height: 10),

                      // Agreement item
                      _BannerItem(
                        icon: agreementDone
                          ? Icons.check_circle : Icons.draw_outlined,
                        iconColor: agreementDone ? _OC.green : _OC.red,
                        bgColor: agreementDone
                          ? _OC.green.withValues(alpha: 0.12)
                          : const Color(0xFFFEE2E2),
                        containerColor: agreementDone
                          ? const Color(0xFFF0FDF4) : const Color(0xFFFFF5F5),
                        borderColor: agreementDone
                          ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                        title: 'Sign Enrollment Agreement',
                        subtitle: agreementStatus == 'submitted'
                          ? 'Agreement submitted — awaiting admin review'
                          : (agreementStatus == 'draft' && currentStep > 1)
                            ? 'In progress — Step $currentStep of 9'
                            : 'Not started yet',
                        showButton: !agreementDone,
                        buttonLabel: (agreementStatus == 'draft' && currentStep > 1)
                          ? 'Continue' : 'Start',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerItem extends StatelessWidget {
  final IconData icon;
  final Color    iconColor, bgColor, containerColor, borderColor;
  final String   title, subtitle, buttonLabel;
  final bool     showButton;

  const _BannerItem({
    required this.icon, required this.iconColor, required this.bgColor,
    required this.containerColor, required this.borderColor,
    required this.title, required this.subtitle,
    required this.showButton, required this.buttonLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: borderColor)),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(7)),
          child: Icon(icon, color: iconColor, size: 16)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
            style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: _OC.navy)),
          Text(subtitle,
            style: const TextStyle(fontSize: 11, color: _OC.gray600)),
        ])),
        if (showButton) ...[
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: _OC.purple,
              foregroundColor: _OC.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
            ),
            child: Text(buttonLabel,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
        ],
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// AGREEMENT BANNER
// mirrors AgreementBanner in StudentDashboardHome.jsx
// ════════════════════════════════════════════════════════════════
class AgreementBanner extends StatelessWidget {
  final Map<String, dynamic>? agreement;
  final bool                  loading;

  const AgreementBanner({super.key, this.agreement, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) return const SizedBox.shrink();

    final status      = agreement?['status'] ?? '';
    final currentStep = (agreement?['currentStep'] as int?) ?? 1;
    final adminNotes  = agreement?['adminNotes'] ?? '';

    if (status == 'approved') return const SizedBox.shrink();

    // Not started or fresh draft
    if (agreement == null || (status == 'draft' && currentStep == 1)) {
      return _AgreementBannerCard(
        gradient: const [Color(0xFF7C3AED), Color(0xFF5B21B6)],
        icon: Icons.draw_outlined,
        badge: 'Action Required',
        badgeColor: _OC.red,
        title: 'Complete Your Enrollment Agreement',
        subtitle: 'You must complete and e-sign your enrollment agreement before your training begins.',
        buttonLabel: 'Start Agreement →',
        buttonTextColor: _OC.purple,
      );
    }

    // Draft in progress
    if (status == 'draft' && currentStep > 1) {
      final pct = ((currentStep / 9) * 100).round();
      return _AgreementBannerCard(
        gradient: const [Color(0xFF1D4ED8), Color(0xFF1E40AF)],
        icon: Icons.description_outlined,
        badge: 'In Progress',
        badgeColor: const Color(0xFFF59E0B),
        title: 'Continue Your Enrollment Agreement',
        subtitle: 'Step $currentStep of 9 — $pct% complete',
        buttonLabel: 'Continue →',
        buttonTextColor: const Color(0xFF1D4ED8),
        showProgress: true,
        progressPct: pct,
      );
    }

    // Submitted
    if (status == 'submitted') {
      return _AgreementBannerCard(
        gradient: const [Color(0xFF065F46), Color(0xFF047857)],
        icon: Icons.access_time_outlined,
        badge: null,
        badgeColor: null,
        title: 'Enrollment Agreement Submitted',
        subtitle: "Your agreement is under review by the admissions team. You'll be notified once approved.",
        buttonLabel: null,
        buttonTextColor: null,
        showStatusChip: true,
        statusChipLabel: 'Pending Review',
      );
    }

    // Rejected
    if (status == 'rejected') {
      return _AgreementBannerCard(
        gradient: const [Color(0xFF991B1B), Color(0xFFB91C1C)],
        icon: Icons.warning_amber_rounded,
        badge: 'Action Required',
        badgeColor: const Color(0xFFEF4444),
        title: 'Agreement Needs Revision',
        subtitle: adminNotes.isNotEmpty
          ? 'Admin note: $adminNotes'
          : 'Please review and resubmit your enrollment agreement.',
        buttonLabel: 'Revise & Resubmit →',
        buttonTextColor: const Color(0xFFB91C1C),
      );
    }

    return const SizedBox.shrink();
  }
}

class _AgreementBannerCard extends StatelessWidget {
  final List<Color> gradient;
  final IconData    icon;
  final String?     badge, buttonLabel, statusChipLabel;
  final Color?      badgeColor, buttonTextColor;
  final String      title, subtitle;
  final bool        showProgress, showStatusChip;
  final int         progressPct;

  const _AgreementBannerCard({
    required this.gradient, required this.icon,
    required this.badge, required this.badgeColor,
    required this.title, required this.subtitle,
    required this.buttonLabel, required this.buttonTextColor,
    this.showProgress    = false,
    this.showStatusChip  = false,
    this.statusChipLabel,
    this.progressPct     = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient, begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left icon
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _OC.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: _OC.white, size: 22)),
          const SizedBox(width: 14),

          // Text
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor, borderRadius: BorderRadius.circular(20)),
                child: Text(badge!,
                  style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800,
                    color: _OC.white, letterSpacing: 0.6))),
              const SizedBox(height: 6),
            ],
            Text(title,
              style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: _OC.white)),
            const SizedBox(height: 3),
            if (showProgress) ...[
              Text('Step ${(progressPct / 100 * 9).round()} of 9 · $progressPct% complete',
                style: TextStyle(
                  fontSize: 12, color: _OC.white.withValues(alpha: 0.75))),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progressPct / 100, minHeight: 5,
                  backgroundColor: _OC.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFF59E0B)))),
            ] else
              Text(subtitle,
                style: TextStyle(
                  fontSize: 12, color: _OC.white.withValues(alpha: 0.75),
                  height: 1.4)),
          ])),

          const SizedBox(width: 12),

          // CTA
          if (showStatusChip && statusChipLabel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _OC.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8)),
              child: Text(statusChipLabel!,
                style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: _OC.white)))
          else if (buttonLabel != null)
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: _OC.white,
                foregroundColor: buttonTextColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(buttonLabel!,
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: buttonTextColor))),
        ],
      ),
    );
  }
}