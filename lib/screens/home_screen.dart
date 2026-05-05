// lib/screens/home_screen.dart
//
// Flutter replica of the CST web HomePage.
// Sections (in order):
//   1. Hero
//   2. Mission Quote
//   3. Our Mission
//   4. Programs
//   5. Tuition blurb (no calculator — links to financing screen)
//   6. Why Choose Us
//   7. Meet the Team
//   8. Testimonials (read-only, live from API)
//   9. Blog / Articles
//  10. FAQ
//  11. CTA
//  12. Footer
//
// NO enrollment form anywhere.

import 'dart:convert';
import 'package:cst_mobile/screens/messages/components/chat_bot_widget.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cst_mobile/screens/login_screen.dart';

// ── Palette ───────────────────────────────────────────────────────
class _C {
  static const navy        = Color(0xFF1B2B4B);
  static const navyDark    = Color(0xFF101D33);
  static const navyLight   = Color(0xFF243860);
  static const gold        = Color(0xFFB8963E);
  static const goldLight   = Color(0xFFD4AE5A);
  // ignore: unused_field
  static const goldPale    = Color(0xFFF5EDD8);
  static const white       = Color(0xFFFFFFFF);
  static const offWhite    = Color(0xFFF8F7F4);
  static const lightGray   = Color(0xFFEEECE8);
  static const midGray     = Color(0xFF9B9890);
  static const darkGray    = Color(0xFF4A4844);
  static const textMuted   = Color(0xFF6B6966);
  static const border      = Color(0x1F1B2B4B);
  static const dark1       = Color(0xFF1A1A1A);
  static const dark2       = Color(0xFF262523);
  static const errorRed    = Color(0xFFF09595);
}

const _kApiBase = 'http://10.0.2.2:5000'; // change for prod

// ── Testimonial model ─────────────────────────────────────────────
class _T {
  final String id, name, comment;
  final String? location, course;
  final int    rating;
  final bool   recommend;
  const _T({required this.id, required this.name, required this.comment,
    this.location, this.course, required this.rating, required this.recommend});
  factory _T.fromJson(Map<String, dynamic> j) => _T(
    id:        j['_id']?.toString() ?? '',
    name:      j['name']?.toString() ?? '',
    comment:   j['comment']?.toString() ?? '',
    location:  j['location']?.toString(),
    course:    j['course']?.toString(),
    rating:    (j['rating'] as num?)?.toInt() ?? 5,
    recommend: j['recommend'] == true,
  );
}

// ══════════════════════════════════════════════════════════════════
// HomeScreen
// ══════════════════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  int?  _openFaq;

  // ── Data fields (moved here so .map() works reliably) ──────────
  final List<(String, String)> stats = [
    ('34',    'Years of Expertise'),
    ('96%',   'Job Placement Rate'),
    ('\$55K+', 'Avg. Starting Salary'),
    ('\$0',   'Out-of-Pocket for Vets'),
  ];

  final List<(IconData, String, String, String, String, bool)> programs = [
    (Icons.local_shipping_outlined,
     'Class A CDL', 'Commercial Driver License',
     'Full tractor-trailer training covering pre-trip inspection, backing maneuvers, highway driving, and DOT compliance.',
     '10 Weeks', true),
    (Icons.shield_outlined,
     'Class B CDL', 'Single-Unit Vehicle',
     'Comprehensive training for straight trucks, passenger buses, and large single-unit commercial vehicles.',
     '8 Weeks', false),
    (Icons.description_outlined,
     'Hazmat Endorsement', 'Hazardous Materials',
     'Federal certification training for transporting hazardous materials with full regulatory compliance preparation.',
     '1 Week', false),
  ];

  final List<(IconData, String, String)> features = [
    (Icons.menu_book_outlined,         'ELDT-Compliant Curriculum',
        'Federally registered Entry-Level Driver Training meeting all federal requirements.'),
    (Icons.people_outline,             'Experienced Instructors',
        'CDL-certified instructors with professional driving and teaching experience.'),
    (Icons.trending_up,                'Career Placement',
        'Dedicated career services connecting graduates with top carriers nationwide.'),
    (Icons.attach_money,               'Financial Assistance',
        'Multiple financing options covering up to 100% of tuition for qualifying students.'),
    (Icons.workspace_premium_outlined, 'CVTA Accredited',
        'Proud member of the Commercial Vehicle Training Association.'),
    (Icons.military_tech_outlined,     'Veterans Benefits',
        'Approved for Post 9/11 GI Bill and VA education benefits.'),
  ];

  final List<String> whyChecks = [
    'Federally registered ELDT provider',
    'State-licensed campus operations',
    'Late-model Freightliner training fleet',
    'On-site CDL skills testing at select campuses',
  ];

  final List<(String, String, String, String, String, Color, String?)> team = [
    ('Mr. Otis Cooper', 'Founder & CEO', 'Founder · 34 Years Experience',
     'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
     'OC', const Color(0xFFB8963E), 'assets/peopleImage/mr_otis_image_.jpeg'),
    ('Mr. Andrew Cooper', 'Chief Operating Officer (COO)', 'Operations & Training',
     'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
     'AC', const Color(0xFFD4AE5A), 'assets/peopleImage/mr_andrew_image.jpeg'),
    ('Mr. Randy Harden', 'Director of Veteran Affairs · VP of Veteran Advocacy', 'Veteran Advocacy',
     'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
     'RH', const Color(0xFFB22234), null),
    ('Mr. Andy Zubia', 'Chief Financial Officer (CFO)', 'Finance & Strategy',
     'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
     'AZ', const Color(0xFF1B2B4B), null),
  ];

  final List<(String, String, String, String)> blogs = [
    ('Career Guidance',
     'How to Choose the Right CDL Program for Your Career Goals',
     'Understanding the differences between Class A and Class B licensing and which path aligns best with your professional aspirations.',
     'March 18, 2026'),
    ('Industry News',
     'Federal ELDT Regulations: What Every Aspiring Driver Must Know',
     'A comprehensive overview of the Entry-Level Driver Training requirements and how they affect new CDL applicants in California.',
     'March 5, 2026'),
    ('Veterans',
     'Maximizing Your GI Bill Benefits for Commercial Driver Training',
     'A step-by-step guide for veterans looking to use their education benefits to launch a high-paying trucking career.',
     'February 20, 2026'),
  ];

  final List<(String, String)> faqs = [
    ('What are the requirements to enroll?',
     'Applicants must be at least 18 years old (21 for interstate driving), hold a valid driver\'s license, pass a DOT physical, and meet eligibility criteria for their state.'),
    ('How long does the CDL training program take?',
     'Our Class A CDL program is completed in 10 weeks, and our Class B CDL program in 8 weeks — covering all required classroom instruction and behind-the-wheel training hours.'),
    ('Do you offer financial assistance?',
     'Yes. We offer multiple financing options including in-house financing, carrier-sponsored tuition reimbursement, and acceptance of the Post 9/11 GI Bill for qualifying veterans.'),
    ('Will I have a job after graduation?',
     'Our Career Services team works actively with partner carriers to connect graduates with employment opportunities. Many students receive job offers before completing the program.'),
  ];

  late final AnimationController _heroCtrl;
  late final Animation<double>   _heroFade;
  late final Animation<Offset>   _heroSlide;

  @override
  void initState() {
    super.initState();
    _heroCtrl  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 900));
    _heroFade  = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, 0.07), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut));
    _heroCtrl.forward();
  }

  @override
  void dispose() { _heroCtrl.dispose(); _scroll.dispose(); super.dispose(); }

  void _goLogin() => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const StudentLoginPage()));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _C.dark1,
    body: Stack(children: [
      SingleChildScrollView(
        controller: _scroll,
        child: Column(children: [
          _hero(),
          _missionQuote(),
          _ourMission(),
          _programs(),
          _tuitionBlurb(),
          _whyUs(),
          _team(),
          _testimonials(),
          _blog(),
          _faq(),
          _cta(),
          _footer(),
        ]),
      ),
      const ChatbotWidget(),
    ]),
  );

  // ── 1. HERO ───────────────────────────────────────────────────
  Widget _hero() => Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF0D1628), _C.navyDark, _C.navyLight],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
    child: Stack(children: [
      Positioned.fill(child: CustomPaint(painter: _GridPainter())),
      // Gold left accent line
      Positioned(left: 0, top: 0, bottom: 0,
        child: Container(width: 3, decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.transparent, _C.gold, Colors.transparent],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ))),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 52, 24, 56),
          child: FadeTransition(opacity: _heroFade,
            child: SlideTransition(position: _heroSlide,
              child: Column(crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      border: Border.all(color: _C.gold.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text("CALIFORNIA'S PREMIER CDL TRAINING",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                        letterSpacing: 1.2, color: _C.gold)),
                  ),
                  const SizedBox(height: 22),
                  // Headline
                  RichText(textAlign: TextAlign.center, text: const TextSpan(
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900,
                      color: _C.white, height: 1.1, letterSpacing: 0.5,
                      fontFamily: 'serif'),
                    children: [
                      TextSpan(text: "California's\n"),
                      TextSpan(text: "Road-Ready CDL\nTraining Program.",
                        style: TextStyle(color: _C.goldLight, fontStyle: FontStyle.italic)),
                    ],
                  )),
                  const SizedBox(height: 18),
                  Text(
                    'California School of Trucking is built on a founder with 34 years of industry experience — delivering rigorous, professional CDL training that produces safer roads and stronger careers.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w300,
                      color: _C.white.withValues(alpha: 0.80), height: 1.75),
                  ),
                  const SizedBox(height: 28),
                  // Buttons — login only, no enrollment
                  _GoldBtn(label: 'Call Us: 1-888-498-2689',
                    icon: Icons.phone_outlined, onTap: () {}),
                  const SizedBox(height: 12),
                  _OutlineBtn(label: 'Student Portal Login',
                    icon: Icons.school_outlined, onTap: _goLogin),
                  const SizedBox(height: 40),
                  // Stats row
                  Container(
                    padding: const EdgeInsets.only(top: 24),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: _C.white.withValues(alpha: 0.12)))),
                    child: Row(
                      children: List.generate(stats.length, (i) {
                        final s = stats[i];
                        return Expanded(child: Container(
                          padding: EdgeInsets.only(
                            left: i == 0 ? 0 : 8,
                            right: i == stats.length - 1 ? 0 : 8),
                          decoration: BoxDecoration(border: Border(
                            right: i == stats.length - 1
                              ? BorderSide.none
                              : BorderSide(color: _C.white.withValues(alpha: 0.12)))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(s.$1, style: const TextStyle(
                                fontFamily: 'serif', fontSize: 22,
                                fontWeight: FontWeight.w700, color: _C.goldLight)),
                              const SizedBox(height: 4),
                              Text(s.$2, textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 9,
                                  fontWeight: FontWeight.w500, letterSpacing: 0.5,
                                  color: _C.white.withValues(alpha: 0.45))),
                            ],
                          ),
                        ));
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ]),
  );

  // ── 2. MISSION QUOTE ─────────────────────────────────────────
  Widget _missionQuote() => Container(
    color: _C.dark1,
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 56),
    child: Stack(children: [
      // radial glow
      Positioned.fill(child: Container(decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [_C.gold.withValues(alpha: 0.05), Colors.transparent],
          radius: 0.8,
        ),
      ))),
      // Gold left accent line
      Positioned(left: 0, top: 0, bottom: 0,
        child: Container(width: 4, decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.transparent, _C.gold, Colors.transparent],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ))),
      Column(children: [
        Icon(Icons.format_quote_rounded,
          color: _C.gold.withValues(alpha: 0.4), size: 36),
        const SizedBox(height: 16),
        RichText(textAlign: TextAlign.center, text: const TextSpan(
          style: TextStyle(fontFamily: 'serif', fontSize: 20,
            fontStyle: FontStyle.italic, color: _C.white, height: 1.45),
          children: [
            TextSpan(text: '"The harder you work, '),
            TextSpan(text: 'the harder it is to surrender to mediocrity."',
              style: TextStyle(color: _C.goldLight)),
          ],
        )),
        const SizedBox(height: 18),
        Text('— Otis Cooper, Founder & CEO · California School of Trucking',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w300,
            letterSpacing: 0.8, color: _C.white.withValues(alpha: 0.35))),
      ]),
    ]),
  );

  // ── 3. OUR MISSION ───────────────────────────────────────────
  Widget _ourMission() => Container(
    color: _C.dark2,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
    child: Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: _C.gold),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('OUR MISSION', style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w600,
          letterSpacing: 1.2, color: _C.gold)),
      ),
      const SizedBox(height: 18),
      const Text("We Don't Just Train Drivers.\nWe Launch Careers.",
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'serif', fontSize: 26,
          fontWeight: FontWeight.w700, color: _C.goldLight, height: 1.2)),
      const SizedBox(height: 20),
      Text(
        'Our mission is to provide the highest quality commercial driver training in California — '
        'training that meets federal standards, exceeds carrier expectations, and gives every '
        'graduate the knowledge, skill, and confidence to thrive on the road.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w300,
          color: _C.white.withValues(alpha: 0.70), height: 1.8),
      ),
      const SizedBox(height: 10),
      Text(
        'We serve veterans transitioning to civilian careers, individuals seeking a career change, '
        'and new entrants to the workforce — providing accessible, affordable, and fully funded '
        'pathways to a high-paying profession.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w300,
          color: _C.white.withValues(alpha: 0.70), height: 1.8),
      ),
      const SizedBox(height: 28),
      // Mission image cards
      _MissionCard(
        imageUrl: 'https://images.unsplash.com/photo-1601584115197-04ecc0da31d7?w=800&q=80',
        title: 'Federally Registered ELDT Provider',
        desc: 'One of the first in California to meet the 2022 FMCSA mandate',
      ),
      const SizedBox(height: 12),
      _MissionCard(
        imageUrl: 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&q=80',
        title: 'CVTA-Accredited Institution',
        desc: 'Member of the Commercial Vehicle Training Association',
      ),
      const SizedBox(height: 12),
      _MissionCard(
        imageUrl: 'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=800&q=80',
        title: 'VA-Approved School',
        desc: 'Post-9/11 GI Bill accepted at all authorized campus locations nationwide',
      ),
      const SizedBox(height: 12),
      _MissionCard(
        imageUrl: 'https://images.unsplash.com/photo-1601584115197-04ecc0da31d7?w=800&q=80',
        title: '96% Graduate Job Placement',
        desc: 'Active professional partnerships with regional and national freight carriers',
      ),
    ]),
  );

  // ── 4. PROGRAMS ──────────────────────────────────────────────
  Widget _programs() => Container(
    color: _C.white,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionLabel(text: 'Training Programs'),
      const SizedBox(height: 10),
      const Text('Programs Designed\nfor Your Career',
        style: TextStyle(fontFamily: 'serif', fontSize: 26,
          fontWeight: FontWeight.w700, color: _C.navy, height: 1.2)),
      const SizedBox(height: 10),
      Text('Every program is structured around federal ELDT requirements with hands-on '
        'training using late-model Freightliner tractors and 53-foot trailers.',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w300,
          color: _C.textMuted, height: 1.7)),
      const SizedBox(height: 28),
      ...programs.map((p) => _ProgramCard(
        icon: p.$1, title: p.$2, subtitle: p.$3,
        desc: p.$4, duration: p.$5, popular: p.$6,
      )),
    ]),
  );

  // ── 5. TUITION BLURB ─────────────────────────────────────────
  Widget _tuitionBlurb() => Container(
    color: _C.dark1,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionLabel(text: 'Tuition & Financing', light: true),
      const SizedBox(height: 10),
      RichText(text: const TextSpan(
        style: TextStyle(fontFamily: 'serif', fontSize: 26,
          fontWeight: FontWeight.w700, color: _C.white, height: 1.2),
        children: [
          TextSpan(text: 'Most Students Pay\n'),
          TextSpan(text: 'Zero Out of Pocket.',
            style: TextStyle(color: _C.goldLight)),
        ],
      )),
      const SizedBox(height: 16),
      Text('Between GI Bill benefits, federal WIOA grants, and employer sponsorships '
        '— there\'s a funding path for everyone.',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w300,
          color: _C.white.withValues(alpha: 0.65), height: 1.8)),
      const SizedBox(height: 24),
      // Funding options chips
      Wrap(spacing: 10, runSpacing: 10, children: [
        _FundingChip(label: 'Post-9/11 GI Bill', icon: Icons.military_tech_outlined),
        _FundingChip(label: 'WIOA Federal Grant', icon: Icons.account_balance_outlined),
        _FundingChip(label: 'Employer Sponsorship', icon: Icons.business_center_outlined),
        _FundingChip(label: 'In-House Financing', icon: Icons.credit_card_outlined),
      ]),
      const SizedBox(height: 28),
      GestureDetector(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _C.gold, borderRadius: BorderRadius.circular(3)),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_forward, size: 16, color: _C.navyDark),
              SizedBox(width: 8),
              Text('VIEW ALL FINANCING OPTIONS', style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                letterSpacing: 0.8, color: _C.navyDark)),
            ]),
        ),
      ),
    ]),
  );

  // ── 6. WHY CHOOSE US ─────────────────────────────────────────
  Widget _whyUs() => Container(
    color: _C.offWhite,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionLabel(text: 'Why Choose Us'),
      const SizedBox(height: 10),
      const Text('Built by an Expert.\nDesigned for Your Success.',
        style: TextStyle(fontFamily: 'serif', fontSize: 26,
          fontWeight: FontWeight.w700, color: _C.navy, height: 1.2)),
      const SizedBox(height: 14),
      Text('California School of Trucking is led by a founder with 34 years of hands-on '
        'industry experience — bringing real-world knowledge, professional standards, '
        'and genuine commitment to every student\'s career.',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w300,
          color: _C.textMuted, height: 1.8)),
      const SizedBox(height: 20),
      ...whyChecks.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          const Icon(Icons.check_circle_outline, size: 16, color: _C.gold),
          const SizedBox(width: 10),
          Expanded(child: Text(item, style: const TextStyle(
            fontSize: 14, color: _C.darkGray))),
        ]),
      )),
      const SizedBox(height: 28),
      LayoutBuilder(builder: (context, constraints) {
        final w = (constraints.maxWidth - 14) / 2;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: features.map((f) => SizedBox(
            width: w,
            child: _FeatureCard(icon: f.$1, title: f.$2, desc: f.$3),
          )).toList(),
        );
      }),
    ]),
  );

  // ── 7. MEET THE TEAM ─────────────────────────────────────────
  Widget _team() => Container(
    color: _C.dark1,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
    child: Column(children: [
      _SectionLabel(text: 'Meet the Team', center: true),
      const SizedBox(height: 8),
      const Text('The People Behind CST', textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'serif', fontSize: 26,
          fontWeight: FontWeight.w700, color: _C.white)),
      const SizedBox(height: 8),
      Text(
        'Experienced professionals dedicated to building California\'s next generation of commercial drivers.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w300,
          color: _C.white.withValues(alpha: 0.5), height: 1.7)),
      const SizedBox(height: 36),
      ...team.map((m) => _TeamCard(
        name: m.$1, title: m.$2, exp: m.$3,
        bio: m.$4, initials: m.$5, accent: m.$6,
        photoPath: m.$7,
      )),
    ]),
  );

  // ── 8. TESTIMONIALS ──────────────────────────────────────────
  Widget _testimonials() => const _TestimonialsSection();

  // ── 9. BLOG ──────────────────────────────────────────────────
  Widget _blog() => Container(
    color: _C.white,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SectionLabel(text: 'Resources & Insights'),
          const Text('Latest Articles', style: TextStyle(
            fontFamily: 'serif', fontSize: 24,
            fontWeight: FontWeight.w700, color: _C.navy)),
        ]),
        GestureDetector(onTap: () {}, child: Row(children: [
          const Text('View All', style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: _C.gold)),
          const Icon(Icons.chevron_right, size: 16, color: _C.gold),
        ])),
      ]),
      const SizedBox(height: 24),
      ...blogs.map((b) => _BlogCard(
        category: b.$1, title: b.$2, excerpt: b.$3, date: b.$4)),
    ]),
  );

  // ── 10. FAQ ───────────────────────────────────────────────────
  Widget _faq() => Container(
    color: _C.dark1,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
    child: Column(children: [
      _SectionLabel(text: 'Frequently Asked Questions', center: true),
      const SizedBox(height: 8),
      const Text('Common Questions', textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'serif', fontSize: 26,
          fontWeight: FontWeight.w700, color: _C.white)),
      const SizedBox(height: 28),
      ...List.generate(faqs.length, (i) {
        final f = faqs[i];
        final open = _openFaq == i;
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: _C.dark2,
            border: Border.all(color: _C.gold.withValues(alpha: 0.15)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(children: [
            InkWell(
              onTap: () => setState(() => _openFaq = open ? null : i),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  Expanded(child: Text(f.$1, style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500, color: _C.white))),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down, color: _C.gold)),
                ]),
              ),
            ),
            if (open)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: _C.gold.withValues(alpha: 0.15)))),
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(f.$2, style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w300,
                    color: _C.white.withValues(alpha: 0.6), height: 1.75)),
                ),
              ),
          ]),
        );
      }),
    ]),
  );

  // ── 11. CTA ───────────────────────────────────────────────────
  Widget _cta() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [_C.navyDark, _C.navy],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionLabel(text: 'Begin Your Journey', light: true),
      const SizedBox(height: 10),
      const Text('Ready to Start Your Career\nin Commercial Driving?',
        style: TextStyle(fontFamily: 'serif', fontSize: 26,
          fontWeight: FontWeight.w700, color: _C.white, height: 1.2)),
      const SizedBox(height: 14),
      Text(
        'Classes begin every Monday. Speak with an admissions advisor today to review '
        'your eligibility, financing options, and program selection.',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w300,
          color: _C.white.withValues(alpha: 0.65), height: 1.75)),
      const SizedBox(height: 28),
      // Call button
      _GoldBtn(label: 'Call 1-888-498-2689',
        icon: Icons.phone_outlined, onTap: () {}),
      const SizedBox(height: 12),
      // Login only — NO enrollment
      _OutlineBtn(label: 'Student Portal Login',
        icon: Icons.school_outlined, onTap: _goLogin),
    ]),
  );

  // ── 12. FOOTER ────────────────────────────────────────────────
  Widget _footer() => Container(
    color: _C.navyDark,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _C.gold, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.local_shipping, color: _C.navyDark, size: 20),
        ),
        const SizedBox(width: 10),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('California School', style: TextStyle(
            fontFamily: 'serif', fontSize: 14,
            fontWeight: FontWeight.w700, color: _C.white)),
          Text('of Trucking', style: TextStyle(
            fontSize: 11, color: _C.gold, letterSpacing: 0.5)),
        ]),
      ]),
      const SizedBox(height: 24),
      Divider(color: _C.white.withValues(alpha: 0.08)),
      const SizedBox(height: 16),
      Text(
        '© 2026 California School of Trucking. All rights reserved.\n'
        'CVTA Accredited · ELDT Registered Provider',
        style: TextStyle(fontSize: 12, color: _C.white.withValues(alpha: 0.30), height: 1.7)),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: _goLogin,
        child: Text('Student Portal Login →',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
            color: _C.white.withValues(alpha: 0.40))),
      ),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════
// Testimonials — live fetch, read-only
// ══════════════════════════════════════════════════════════════════
class _TestimonialsSection extends StatefulWidget {
  const _TestimonialsSection();
  @override State<_TestimonialsSection> createState() => _TestimonialsSectionState();
}

class _TestimonialsSectionState extends State<_TestimonialsSection> {
  List<_T> _items = [];
  bool     _loading = true;
  String?  _error;

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    try {
      final res = await http.get(Uri.parse('$_kApiBase/api/testimonials'))
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['success'] != true) throw Exception();
      final list = (body['data'] as List)
          .map((e) => _T.fromJson(e as Map<String, dynamic>)).toList();
      if (mounted) setState(() { _items = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() {
        _error = 'Could not load testimonials.'; _loading = false; });
    }
  }

  // ── Form state ────────────────────────────────────────────────
  String _name = '', _email = '', _location = '', _comment = '', _course = '';
  int    _rating = 0;
  bool?  _recommend;
  bool   _submitting = false, _submitted = false;
  String? _submitError;
  Map<String, String> _formErrors = {};

  bool _validateForm() {
    final e = <String, String>{};
    if (_name.trim().isEmpty)   e['name']    = 'Name is required.';
    if (_email.trim().isEmpty || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email))
                                e['email']   = 'A valid email is required.';
    if (_rating == 0)           e['rating']  = 'Please select a star rating.';
    if (_recommend == null)     e['recommend']= 'Please choose an option.';
    if (_comment.trim().length < 20) e['comment'] = 'Please write at least 20 characters.';
    setState(() => _formErrors = e);
    return e.isEmpty;
  }

  Future<void> _submitReview() async {
    if (!_validateForm()) return;
    setState(() { _submitting = true; _submitError = null; });
    try {
      final res = await http.post(
        Uri.parse('$_kApiBase/api/testimonials'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': _name.trim(), 'email': _email.trim(),
          'course': _course, 'location': _location.trim(),
          'rating': _rating, 'recommend': _recommend,
          'comment': _comment.trim(),
        }),
      ).timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['success'] != true) throw Exception(body['message'] ?? 'Failed');
      if (mounted) setState(() { _submitted = true; _submitting = false; });
    } catch (err) {
      if (mounted) setState(() {
        _submitError = err.toString().replaceAll('Exception: ', '');
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    color: _C.dark2,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionLabel(text: 'Graduate Testimonials', light: true),
      const SizedBox(height: 10),
      const Text('What Our Alumni Say', style: TextStyle(
        fontFamily: 'serif', fontSize: 26,
        fontWeight: FontWeight.w700, color: _C.white)),
      const SizedBox(height: 28),
      if (_loading)
        Center(child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: _C.gold)),
            const SizedBox(width: 12),
            Text('Loading testimonials...',
              style: TextStyle(fontSize: 14, color: _C.white.withValues(alpha: 0.4))),
          ]),
        ))
      else if (_error != null)
        Text(_error!, style: const TextStyle(fontSize: 14, color: _C.errorRed))
      else if (_items.isEmpty)
        Text('No testimonials yet.',
          style: TextStyle(fontSize: 14, color: _C.white.withValues(alpha: 0.3)))
      else
        ..._items.map((t) => _TestCard(t: t)),

      // ── Divider ──
      if (!_loading) ...[
        Container(
          margin: const EdgeInsets.symmetric(vertical: 36),
          height: 1, color: _C.gold.withValues(alpha: 0.2)),

        // ── Review form ──
        Container(
          decoration: BoxDecoration(
            color: _C.dark1,
            border: Border.all(color: _C.gold.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.all(24),
          child: _submitted ? _buildSuccess() : _buildForm(),
        ),
      ],
    ]),
  );

  Widget _buildSuccess() => Column(children: [
    const SizedBox(height: 12),
    const Icon(Icons.check_circle_rounded, size: 52, color: _C.gold),
    const SizedBox(height: 16),
    const Text('Thank You for Your Review!', textAlign: TextAlign.center,
      style: TextStyle(fontFamily: 'serif', fontSize: 22,
        fontWeight: FontWeight.w700, color: _C.goldLight)),
    const SizedBox(height: 12),
    Text('Your submission has been received and will be reviewed shortly.',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w300,
        color: _C.white.withValues(alpha: 0.5), height: 1.75)),
    const SizedBox(height: 12),
  ]);

  Widget _buildForm() {
    final inputDec = InputDecoration(
      filled: true,
      fillColor: _C.white.withValues(alpha: 0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border:        OutlineInputBorder(borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: _C.gold.withValues(alpha: 0.25))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: _C.gold.withValues(alpha: 0.25))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: _C.gold.withValues(alpha: 0.6))),
    );
    const inputStyle = TextStyle(fontSize: 14, color: _C.white, fontWeight: FontWeight.w300);
    const labelStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
      letterSpacing: 1.0, color: Color(0x73FFFFFF));
    const errStyle   = TextStyle(fontSize: 12, color: _C.errorRed);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionLabel(text: 'Share Your Experience', light: true),
      const SizedBox(height: 6),
      const Text('Leave a Review', style: TextStyle(fontFamily: 'serif',
        fontSize: 22, fontWeight: FontWeight.w700, color: _C.goldLight)),
      const SizedBox(height: 8),
      Text('Your feedback helps future students make confident decisions.',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w300,
          color: _C.white.withValues(alpha: 0.45), height: 1.65)),
      const SizedBox(height: 20),

      // Full Name
      const Text('FULL NAME', style: labelStyle),
      const SizedBox(height: 6),
      TextField(style: inputStyle, decoration: inputDec.copyWith(
        hintText: 'e.g. Alex M.',
        hintStyle: TextStyle(color: _C.white.withValues(alpha: 0.2)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: _formErrors['name'] != null
            ? _C.errorRed : _C.gold.withValues(alpha: 0.25)))),
        onChanged: (v) { _name = v; if (_formErrors['name'] != null) setState(() => _formErrors.remove('name')); }),
      if (_formErrors['name'] != null) Padding(padding: const EdgeInsets.only(top: 4),
        child: Text(_formErrors['name']!, style: errStyle)),
      const SizedBox(height: 14),

      // Email
      const Text('EMAIL ADDRESS', style: labelStyle),
      const SizedBox(height: 6),
      TextField(style: inputStyle, keyboardType: TextInputType.emailAddress,
        decoration: inputDec.copyWith(hintText: 'you@email.com',
          hintStyle: TextStyle(color: _C.white.withValues(alpha: 0.2)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: _formErrors['email'] != null
              ? _C.errorRed : _C.gold.withValues(alpha: 0.25)))),
        onChanged: (v) { _email = v; if (_formErrors['email'] != null) setState(() => _formErrors.remove('email')); }),
      if (_formErrors['email'] != null) Padding(padding: const EdgeInsets.only(top: 4),
        child: Text(_formErrors['email']!, style: errStyle)),
      const SizedBox(height: 14),

      // Course
      const Text('COURSE ATTENDED (OPTIONAL)', style: labelStyle),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: _C.white.withValues(alpha: 0.05),
          border: Border.all(color: _C.gold.withValues(alpha: 0.25)),
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: DropdownButtonHideUnderline(child: DropdownButton<String>(
          value: _course.isEmpty ? null : _course,
          hint: Text('Select a program...', style: TextStyle(
            fontSize: 14, color: _C.white.withValues(alpha: 0.2))),
          isExpanded: true,
          dropdownColor: _C.dark2,
          style: const TextStyle(fontSize: 14, color: _C.white),
          items: ['Class A CDL','Class B CDL','Hazmat Endorsement','Other']
            .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: (v) => setState(() => _course = v ?? ''),
        )),
      ),
      const SizedBox(height: 14),

      // Location
      const Text('YOUR LOCATION (OPTIONAL)', style: labelStyle),
      const SizedBox(height: 6),
      TextField(style: inputStyle, decoration: inputDec.copyWith(
        hintText: 'City, State',
        hintStyle: TextStyle(color: _C.white.withValues(alpha: 0.2))),
        onChanged: (v) => _location = v),
      const SizedBox(height: 14),

      // Star rating
      const Text('STAR RATING', style: labelStyle),
      const SizedBox(height: 8),
      Row(children: List.generate(5, (n) => GestureDetector(
        onTap: () => setState(() { _rating = n + 1; _formErrors.remove('rating'); }),
        child: Padding(padding: const EdgeInsets.only(right: 6),
          child: Icon(
            (n + 1) <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 34, color: (n + 1) <= _rating ? _C.gold : _C.white.withValues(alpha: 0.18))),
      ))),
      if (_formErrors['rating'] != null) Padding(padding: const EdgeInsets.only(top: 4),
        child: Text(_formErrors['rating']!, style: errStyle)),
      const SizedBox(height: 14),

      // Recommend
      const Text('WOULD YOU RECOMMEND US?', style: labelStyle),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _RecommendBtn(label: 'Yes', icon: Icons.thumb_up_outlined,
          active: _recommend == true,
          onTap: () => setState(() { _recommend = true; _formErrors.remove('recommend'); }))),
        const SizedBox(width: 10),
        Expanded(child: _RecommendBtn(label: 'No', icon: Icons.thumb_down_outlined,
          active: _recommend == false,
          onTap: () => setState(() { _recommend = false; _formErrors.remove('recommend'); }))),
      ]),
      if (_formErrors['recommend'] != null) Padding(padding: const EdgeInsets.only(top: 4),
        child: Text(_formErrors['recommend']!, style: errStyle)),
      const SizedBox(height: 14),

      // Comment
      const Text('YOUR COMMENT', style: labelStyle),
      const SizedBox(height: 6),
      TextField(style: inputStyle, maxLines: 5,
        decoration: inputDec.copyWith(
          hintText: 'Tell us about your experience...',
          hintStyle: TextStyle(color: _C.white.withValues(alpha: 0.2)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: _formErrors['comment'] != null
              ? _C.errorRed : _C.gold.withValues(alpha: 0.25)))),
        onChanged: (v) { _comment = v; if (_formErrors['comment'] != null) setState(() => _formErrors.remove('comment')); }),
      if (_formErrors['comment'] != null) Padding(padding: const EdgeInsets.only(top: 4),
        child: Text(_formErrors['comment']!, style: errStyle)),
      const SizedBox(height: 20),

      if (_submitError != null) Padding(padding: const EdgeInsets.only(bottom: 12),
        child: Text(_submitError!, style: errStyle)),

      // Submit button
      SizedBox(width: double.infinity,
        child: GestureDetector(
          onTap: _submitting ? null : _submitReview,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: _submitting ? _C.midGray : _C.gold,
              borderRadius: BorderRadius.circular(3)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (_submitting) ...[
                const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _C.navyDark)),
                const SizedBox(width: 8),
                const Text('Submitting...', style: TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w700, letterSpacing: 0.8, color: _C.navyDark)),
              ] else ...[
                const Icon(Icons.send_rounded, size: 14, color: _C.navyDark),
                const SizedBox(width: 8),
                const Text('SUBMIT MY REVIEW', style: TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w700, letterSpacing: 0.8, color: _C.navyDark)),
              ],
            ]),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Text('Your email is used for verification only and will never be published.',
        style: TextStyle(fontSize: 11, color: _C.white.withValues(alpha: 0.25), height: 1.6)),
    ]);
  }
}

// ── Recommend toggle button ───────────────────────────────────────
class _RecommendBtn extends StatelessWidget {
  final String label; final IconData icon; final bool active; final VoidCallback onTap;
  const _RecommendBtn({required this.label, required this.icon,
    required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: active ? _C.gold.withValues(alpha: 0.15) : _C.white.withValues(alpha: 0.04),
        border: Border.all(color: active ? _C.gold : _C.gold.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 14, color: active ? _C.goldLight : _C.white.withValues(alpha: 0.45)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 13,
          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          color: active ? _C.goldLight : _C.white.withValues(alpha: 0.45))),
      ]),
    ),
  );
}

class _TestCard extends StatelessWidget {
  final _T t;
  const _TestCard({required this.t});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: _C.dark1,
      border: Border.all(color: _C.gold.withValues(alpha: 0.15)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: List.generate(t.rating, (i) => const Padding(
        padding: EdgeInsets.only(right: 3),
        child: Icon(Icons.star_rounded, size: 14, color: _C.gold),
      ))),
      const SizedBox(height: 12),
      Text('"${t.comment}"', style: TextStyle(
        fontFamily: 'serif', fontSize: 15,
        color: _C.white.withValues(alpha: 0.80),
        height: 1.75, fontStyle: FontStyle.italic)),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: _C.white.withValues(alpha: 0.08)))),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.name, style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: _C.white)),
              if (t.location != null && t.location!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.location_on_outlined,
                    size: 11, color: _C.white.withValues(alpha: 0.45)),
                  const SizedBox(width: 3),
                  Text(t.location!, style: TextStyle(
                    fontSize: 12, color: _C.white.withValues(alpha: 0.45))),
                ]),
              ],
              const SizedBox(height: 6),
              Row(children: [
                Icon(t.recommend ? Icons.thumb_up_rounded : Icons.thumb_down_rounded,
                  size: 11, color: t.recommend ? _C.gold : _C.white.withValues(alpha: 0.3)),
                const SizedBox(width: 4),
                Text(t.recommend ? 'Recommends' : 'Does not recommend',
                  style: TextStyle(fontSize: 11,
                    color: t.recommend ? _C.gold : _C.white.withValues(alpha: 0.3))),
              ]),
            ],
          )),
          if (t.course != null && t.course!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _C.gold, borderRadius: BorderRadius.circular(2)),
              child: Text(t.course!, style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600,
                letterSpacing: 0.5, color: _C.dark1)),
            ),
        ]),
      ),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════
// Reusable sub-widgets
// ══════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool   light;
  final bool   center;
  const _SectionLabel({required this.text, this.light = false, this.center = false});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
    children: [
      Container(width: 28, height: 2, color: _C.gold),
      const SizedBox(width: 8),
      Text(text.toUpperCase(), style: const TextStyle(
        fontSize: 11, fontWeight: FontWeight.w600,
        letterSpacing: 1.2, color: _C.gold)),
      if (center) ...[
        const SizedBox(width: 8),
        Container(width: 28, height: 2, color: _C.gold),
      ],
    ],
  );
}

class _GoldBtn extends StatelessWidget {
  final String label; final IconData icon; final VoidCallback onTap;
  const _GoldBtn({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: _C.gold, borderRadius: BorderRadius.circular(3)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 16, color: _C.navyDark),
        const SizedBox(width: 8),
        Text(label.toUpperCase(), style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700,
          letterSpacing: 0.8, color: _C.navyDark)),
      ]),
    ),
  );
}

class _OutlineBtn extends StatelessWidget {
  final String label; final IconData icon; final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _C.white.withValues(alpha: 0.35))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 16, color: _C.white),
        const SizedBox(width: 8),
        Text(label.toUpperCase(), style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700,
          letterSpacing: 0.8, color: _C.white)),
      ]),
    ),
  );
}

class _ProgramCard extends StatelessWidget {
  final IconData icon; final String title; final String subtitle;
  final String desc; final String duration; final bool popular;
  const _ProgramCard({required this.icon, required this.title,
    required this.subtitle, required this.desc,
    required this.duration, required this.popular});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: _C.white,
      border: Border.all(color: _C.border),
      borderRadius: BorderRadius.circular(4),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 12, offset: const Offset(0, 4))],
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Gold top accent bar
      Container(height: 3, color: _C.gold),
      Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _C.lightGray, borderRadius: BorderRadius.circular(4)),
            child: Icon(icon, size: 20, color: _C.navy),
          ),
          const Spacer(),
          if (popular)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _C.gold, borderRadius: BorderRadius.circular(2)),
              child: const Text('Most Popular', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600,
                letterSpacing: 0.5, color: _C.white)),
            ),
        ]),
        const SizedBox(height: 14),
        Text(subtitle.toUpperCase(), style: const TextStyle(
          fontSize: 10, fontWeight: FontWeight.w600,
          letterSpacing: 0.8, color: _C.gold)),
        const SizedBox(height: 6),
        Text(title, style: const TextStyle(fontFamily: 'serif',
          fontSize: 20, fontWeight: FontWeight.w700, color: _C.navy)),
        const SizedBox(height: 10),
        Text(desc, style: const TextStyle(fontSize: 14,
          fontWeight: FontWeight.w300, color: _C.textMuted, height: 1.65)),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.only(top: 14),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: _C.border))),
          child: Row(children: [
            const Icon(Icons.access_time_outlined, size: 14, color: _C.midGray),
            const SizedBox(width: 5),
            Text(duration, style: const TextStyle(
              fontSize: 13, color: _C.textMuted)),
          ]),
        ),
      ]),      // end inner Column
      ),        // end Padding
    ]),         // end outer Column (gold bar + Padding)
  );
}

class _FeatureCard extends StatelessWidget {
  final IconData icon; final String title; final String desc;
  const _FeatureCard({required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _C.white,
      border: Border.all(color: _C.border),
      borderRadius: BorderRadius.circular(4),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 10, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 20, color: _C.gold),
      const SizedBox(height: 10),
      Text(title, style: const TextStyle(fontSize: 13,
        fontWeight: FontWeight.w600, color: _C.navy)),
      const SizedBox(height: 6),
      Text(desc, maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w300,
          color: _C.textMuted, height: 1.55)),
    ]),
  );
}

class _TeamCard extends StatelessWidget {
  final String name, title, exp, bio, initials;
  final Color  accent;
  final String? photoPath;
  const _TeamCard({required this.name, required this.title, required this.exp,
    required this.bio, required this.initials, required this.accent,
    this.photoPath});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 20),
    decoration: BoxDecoration(
      color: _C.dark2,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35),
        blurRadius: 24, offset: const Offset(0, 8))],
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(children: [
      // Photo / initials block
      SizedBox(
        height: 260, width: double.infinity,
        child: Stack(children: [
          // Background
          Positioned.fill(child: photoPath != null
            ? Image.asset(photoPath!, fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, __, ___) => Container(
                  color: _C.dark2,
                  child: Center(child: Text(initials, style: TextStyle(
                    fontFamily: 'serif', fontSize: 64,
                    fontWeight: FontWeight.w700,
                    color: accent.withValues(alpha: 0.6))))))
            : Container(decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent.withValues(alpha: 0.25), accent.withValues(alpha: 0.08)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                )),
              child: Center(child: Text(initials, style: TextStyle(
                fontFamily: 'serif', fontSize: 64,
                fontWeight: FontWeight.w700,
                color: accent.withValues(alpha: 0.6)))))),
          // Gradient overlay
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.88)],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              stops: const [0.4, 1.0],
            ),
          ))),
          // Name overlay
          Positioned(bottom: 0, left: 0, right: 0,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.18),
                      border: Border.all(color: accent.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(exp.toUpperCase(), style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      letterSpacing: 0.6, color: accent)),
                  ),
                  const SizedBox(height: 8),
                  Text(name, style: const TextStyle(fontFamily: 'serif',
                    fontSize: 18, fontWeight: FontWeight.w700, color: _C.white)),
                  const SizedBox(height: 3),
                  Text(title, style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: accent)),
                ],
              ),
            )),
        ]),
      ),
      // Bio
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: accent, width: 2))),
        child: Text(bio, style: TextStyle(fontSize: 13,
          fontWeight: FontWeight.w300,
          color: _C.white.withValues(alpha: 0.55), height: 1.7)),
      ),
    ]),
  );
}

class _BlogCard extends StatelessWidget {
  final String category, title, excerpt, date;
  const _BlogCard({required this.category, required this.title,
    required this.excerpt, required this.date});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: _C.white,
      border: Border.all(color: _C.border),
      borderRadius: BorderRadius.circular(4),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(children: [
      // Placeholder image header
      Container(
        height: 120,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_C.navy, _C.navyLight],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Icon(Icons.menu_book_outlined,
            size: 32, color: Color(0x40FFFFFF))),
      ),
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(category.toUpperCase(), style: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600,
            letterSpacing: 0.8, color: _C.gold)),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontFamily: 'serif',
            fontSize: 16, fontWeight: FontWeight.w700,
            color: _C.navy, height: 1.35)),
          const SizedBox(height: 10),
          Text(excerpt, style: const TextStyle(fontSize: 13,
            fontWeight: FontWeight.w300, color: _C.textMuted, height: 1.65)),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(date, style: const TextStyle(fontSize: 11, color: _C.midGray)),
            const Row(children: [
              Text('Read More', style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: _C.navy)),
              Icon(Icons.chevron_right, size: 14, color: _C.navy),
            ]),
          ]),
        ]),
      ),
    ]),
  );
}

class _MissionCard extends StatelessWidget {
  final String imageUrl, title, desc;
  const _MissionCard({required this.imageUrl, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) => Container(
    height: 180,
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
    clipBehavior: Clip.antiAlias,
    child: Stack(children: [
      Positioned.fill(child: Image.network(imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: _C.navyDark))),
      Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.82)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
      ))),
      Positioned(bottom: 0, left: 0, right: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: _C.goldLight)),
            const SizedBox(height: 4),
            Text(desc, style: TextStyle(fontSize: 12,
              fontWeight: FontWeight.w300,
              color: _C.white.withValues(alpha: 0.75))),
          ]),
        )),
    ]),
  );
}

class _FundingChip extends StatelessWidget {
  final String label; final IconData icon;
  const _FundingChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: _C.gold.withValues(alpha: 0.12),
      border: Border.all(color: _C.gold.withValues(alpha: 0.35)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: _C.goldLight),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(
        fontSize: 12, fontWeight: FontWeight.w600, color: _C.goldLight)),
    ]),
  );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.025)..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 50) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 50) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }
  @override bool shouldRepaint(_GridPainter _) => false;
}