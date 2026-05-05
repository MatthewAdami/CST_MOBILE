import 'dart:convert';
import 'dart:math';
import 'package:cst_mobile/screens/document_screen.dart';
import 'package:cst_mobile/screens/load_profit_calculator_screen.dart';
import 'package:cst_mobile/screens/login_screen.dart';
import 'package:cst_mobile/screens/messages/student_messages_screen.dart';
import 'package:cst_mobile/screens/onboarding_widgets.dart';
import 'package:cst_mobile/screens/schedule_screen.dart';
import 'package:cst_mobile/screens/student_courses_screen.dart';
import 'package:cst_mobile/screens/student_finance_screen.dart';
import 'package:cst_mobile/screens/student_grades_screen.dart';
import 'package:cst_mobile/screens/student_learning_screen.dart';
import 'package:cst_mobile/screens/student_maps_screen.dart';
import 'package:cst_mobile/screens/student_progress_screen.dart';
import 'package:cst_mobile/screens/student_settings.dart';
import 'package:cst_mobile/screens/study_assisstant_screen.dart';
import 'package:cst_mobile/screens/student_tribe_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cst_mobile/screens/cdl_study_guide_screen.dart';
import 'package:cst_mobile/screens/enrollment_agreement_screen.dart';
import 'package:cst_mobile/screens/student_announcements_screen.dart';
import 'package:cst_mobile/screens/student_id_card_screen.dart';
import 'package:cst_mobile/screens/student_support_screen.dart';
import 'package:cst_mobile/screens/student_learner_manual_screen.dart';
import 'package:cst_mobile/screens/student_service_screen.dart';

// ─────────────────────────────────────────────────────────────────
// COLOURS  (mirrors web C object, gold/navy/sand palette)
// ─────────────────────────────────────────────────────────────────
class _C {
  static const navy        = Color(0xFF11233B);
  static const navySoft    = Color(0xFF1D3557);
  static const navyDeep    = Color(0xFF0D1B2D);
  static const bronze      = Color(0xFF8C6A2B);
  static const gold        = Color(0xFFB8963E);
  static const goldLight   = Color(0xFFD4AE5A);
  static const sand        = Color(0xFFF3E7CC);
  static const white       = Color(0xFFFFFFFF);
  static const gray50      = Color(0xFFFAF8F4);
  static const gray100     = Color(0xFFF3F0E9);
  static const gray200     = Color(0xFFE5DFD4);
  static const gray400     = Color(0xFFA49D90);
  static const gray600     = Color(0xFF6D675F);
  static const gray800     = Color(0xFF2F2B27);
  static const green       = Color(0xFF2F7A55);
  static const greenLight  = Color(0xFF8ED3A8);
  static const red         = Color(0xFFB64B4B);
  static const orange      = Color(0xFFC97A2B);
  static const orangeLight = Color(0xFFF5B36B);
  static const blue        = Color(0xFF365C88);
  static const olive       = Color(0xFF7D8C53);
  static const purple      = Color(0xFF7C3AED);

  static const sidebarBg   = Color(0xFF111318);
  static const sidebarBg2  = Color(0xFF1A1D24);
}

const _kApiBase = 'http://10.0.2.2:5000';

// ─────────────────────────────────────────────────────────────────
// SIDEBAR NAV MODEL
// ─────────────────────────────────────────────────────────────────
class _NavItem {
  final String   label;
  final IconData icon;
  final IconData activeIcon;
  final int      pageIndex;
  final bool     showBadge;
  final String?  badgeLabel;
  final Color?   badgeColor;
  const _NavItem({
    required this.label, required this.icon, required this.activeIcon,
    required this.pageIndex, this.showBadge = false,
    this.badgeLabel, this.badgeColor,
  });
}

class _NavGroup {
  final String?       category;
  final List<_NavItem> items;
  const _NavGroup({this.category, required this.items});
}

final _navGroups = [
  _NavGroup(items: [
    _NavItem(label: 'Dashboard', icon: Icons.space_dashboard_outlined,
      activeIcon: Icons.space_dashboard, pageIndex: 0),
  ]),
  _NavGroup(category: 'Learning', items: [
    _NavItem(label: 'My Progress', icon: Icons.trending_up_outlined,
      activeIcon: Icons.trending_up, pageIndex: 1),
    _NavItem(label: 'My Grades', icon: Icons.school_outlined,
      activeIcon: Icons.school, pageIndex: 14),
    _NavItem(label: 'Schedule', icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today, pageIndex: 2),
    _NavItem(label: 'Courses', icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book, pageIndex: 5),
    _NavItem(label: 'CDL Study AI', icon: Icons.auto_awesome_outlined,
      activeIcon: Icons.auto_awesome, pageIndex: 7,
      showBadge: true, badgeLabel: 'AI', badgeColor: _C.purple),
    _NavItem(label: 'Study Guide', icon: Icons.assignment_outlined,
      activeIcon: Icons.assignment, pageIndex: 9,
      showBadge: true, badgeLabel: 'NEW', badgeColor: _C.olive),
    _NavItem(label: "Learner's Manual", icon: Icons.picture_as_pdf_outlined,
      activeIcon: Icons.picture_as_pdf, pageIndex: 15,
      showBadge: true, badgeLabel: 'PDF', badgeColor: _C.purple),
  ]),
  _NavGroup(category: 'Documents & Finance', items: [
    _NavItem(label: 'Enrollment Agreement', icon: Icons.description_outlined,
      activeIcon: Icons.description, pageIndex: 10),
    _NavItem(label: 'Documents', icon: Icons.folder_outlined,
      activeIcon: Icons.folder, pageIndex: 3),
    _NavItem(label: 'Finances', icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet, pageIndex: 4),
  ]),
  _NavGroup(category: 'Communication', items: [
    _NavItem(label: 'Messages', icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble, pageIndex: 6),
    _NavItem(label: 'Announcements', icon: Icons.campaign_outlined,
      activeIcon: Icons.campaign, pageIndex: 11,
      showBadge: true, badgeLabel: 'NEW', badgeColor: _C.purple),
    _NavItem(label: 'CST Tribe', icon: Icons.group_outlined,
      activeIcon: Icons.group, pageIndex: 16,
      showBadge: true, badgeLabel: 'NEW', badgeColor: _C.olive),
    _NavItem(label: 'Support', icon: Icons.headset_mic_outlined,
      activeIcon: Icons.headset_mic, pageIndex: 13),
  ]),
  _NavGroup(category: 'Tools', items: [
  _NavItem(label: 'Maps', icon: Icons.map_outlined,
    activeIcon: Icons.map, pageIndex: 17,
    showBadge: true, badgeLabel: 'NEW', badgeColor: _C.gold),
  _NavItem(label: 'Load Calculator', icon: Icons.calculate_outlined,
    activeIcon: Icons.calculate, pageIndex: 8,
    showBadge: true, badgeLabel: 'NEW', badgeColor: _C.gold),
  _NavItem(label: 'My ID Card', icon: Icons.credit_card_outlined,
    activeIcon: Icons.credit_card, pageIndex: 12),
  _NavItem(label: 'Services', icon: Icons.build_outlined,
    activeIcon: Icons.build, pageIndex: 18,  // ← was 17, now 18
    showBadge: true, badgeLabel: 'NEW', badgeColor: _C.gold),
]),
  _NavGroup(category: 'Account', items: [
    _NavItem(label: 'Settings', icon: Icons.settings_outlined,
      activeIcon: Icons.settings, pageIndex: -1),
  ]),
];

// ─────────────────────────────────────────────────────────────────
// STUDENT DASHBOARD  (root shell)
// ─────────────────────────────────────────────────────────────────
class StudentDashboard extends StatefulWidget {
  final bool forceOnboarding;
  const StudentDashboard({super.key, this.forceOnboarding = false});
  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int    _currentIndex = 0;
  String _token        = '';
  String _firstName    = '';
  String _lastName     = '';
  bool   _tokenLoaded  = false;
  bool   _showOnboarding = false;

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() { super.initState(); _loadToken(); }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> user = {};
    try {
      final s = prefs.getString('user') ?? '{}';
      user = jsonDecode(s);
    } catch (_) {}

    setState(() {
      _token       = prefs.getString('token') ?? '';
      _firstName   = user['firstName'] ?? '';
      _lastName    = user['lastName']  ?? '';
      _tokenLoaded = true;
      final done          = prefs.getBool('onboardingCompleted') ?? false;
      final doneInUser    = user['onboardingCompleted'] == true;
      _showOnboarding = _token.isNotEmpty &&
        (widget.forceOnboarding || (!done && !doneInUser));
    });
  }

  Future<void> _dismissOnboarding() async {
    setState(() => _showOnboarding = false);
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('onboardingCompleted') ?? false)) {
      await prefs.setBool('onboardingCompleted', true);
      try {
        await http.patch(
          Uri.parse('$_kApiBase/api/auth/complete-onboarding'),
          headers: {
            'Content-Type': 'application/json',
            if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
          },
        ).timeout(const Duration(seconds: 8));
      } catch (_) {}
    }
  }

  // Pages list — import your actual screen classes here
  List<Widget> get _pages => [
    _HomeBody(token: _token),                                // 0
    const StudentProgressPage(),                             // 1
    const ScheduleScreen(),                                  // 2
    const DocumentsScreen(),                                 // 3
    const StudentFinancesScreen(),                           // 4
    StudentCoursesPage(authToken: _token),                   // 5
    const StudentMessagesScreen(),                           // 6
    const StudyAssistantScreen(),                            // 7
    const CalculatorPage(),                                  // 8
    const CDLStudyGuideScreen(),                             // 9
    const EnrollmentAgreementScreen(),                       // 10
    StudentAnnouncementsScreen(authToken: _token),           // 11
    StudentIdCardScreen(authToken: _token),                  // 12
    StudentSupportScreen(
      authToken: _token,
      firstName: _firstName,
      lastName:  _lastName),                                 // 13
    StudentGradesScreen(authToken: _token),                  // 14
    StudentLearnerManualScreen(authToken: _token),           // 15
    const StudentTribeScreen(),                              // 16
    const StudentMapsScreen(),                               // 17  ← Maps now at 17
    const StudentServiceScreen(),   // 18  ← fix comment, was also 17


    // Settings is pageIndex: -1, handled via Navigator.push, so no slot needed
  ];
  static const _titles = [
    'Dashboard','My Progress','Schedule','Documents','Finances',
    'My Courses','Messages','CDL Study AI','Load Calculator',
    'Study Guide','Enrollment Agreement','Announcements','My ID Card',
    'Support','My Grades',"Learner's Manual",'CST Tribe','Maps','Services'
  ];

  String get _title =>
    _currentIndex < _titles.length ? _titles[_currentIndex] : 'Portal';

 void _navigateTo(int idx) {
  Navigator.pop(context); // close drawer
  if (idx == -1) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StudentSettingsScreen()),
    );
    return;
  }
  setState(() => _currentIndex = idx); // ← Maps (17) goes here
}

  @override
  Widget build(BuildContext context) {
    if (!_tokenLoaded) {
      return const Scaffold(
        backgroundColor: _C.navyDeep,
        body: Center(child: CircularProgressIndicator(color: _C.gold)),
      );
    }

    final initials =
      '${_firstName.isNotEmpty ? _firstName[0] : ""}${_lastName.isNotEmpty ? _lastName[0] : ""}';

    return Stack(children: [
      Scaffold(
        key: _scaffoldKey,
        backgroundColor: _C.gray100,
        appBar: AppBar(
          backgroundColor: _C.navyDeep,
          foregroundColor: _C.white,
          elevation: 0,
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(Icons.menu_rounded, color: _C.white, size: 26),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          title: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: _C.gold, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.school, color: _C.navyDeep, size: 16)),
            const SizedBox(width: 10),
            Text(_title, style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: _C.white)),
          ]),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_none, color: _C.white),
              onPressed: () {}),
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: CircleAvatar(
                radius: 15,
                backgroundColor: _C.bronze,
                child: Text(
                  initials.isNotEmpty ? initials : '?',
                  style: const TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w800, color: _C.white)))),
          ],
        ),
        drawer: _Sidebar(
          currentIndex: _currentIndex,
          onNavigate:   _navigateTo,
          firstName:    _firstName,
          lastName:     _lastName,
          token:        _token,
        ),
        body: IndexedStack(index: _currentIndex, children: _pages),
      ),

      if (_showOnboarding)
        Positioned.fill(
          child: OnboardingModal(
            studentName: _firstName.isNotEmpty ? _firstName : 'Student',
            onDismiss:   _dismissOnboarding,
            isReminder:  widget.forceOnboarding,
          ),
        ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────
// SIDEBAR
// ─────────────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final int    currentIndex;
  final void Function(int) onNavigate;
  final String firstName, lastName, token;
  const _Sidebar({
    required this.currentIndex, required this.onNavigate,
    required this.firstName, required this.lastName, required this.token,
  });

  @override
  Widget build(BuildContext context) {
    final initials =
      '${firstName.isNotEmpty ? firstName[0] : "?"}${lastName.isNotEmpty ? lastName[0] : ""}';
    final displayName =
      (firstName.isNotEmpty || lastName.isNotEmpty)
        ? '$firstName $lastName'.trim() : 'Student';

    return Drawer(
      width: 272,
      backgroundColor: _C.sidebarBg,
      child: Column(children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 52, 16, 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x14FFFFFF)))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: _C.gold, borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.local_shipping,
                  color: _C.navyDeep, size: 18)),
              const SizedBox(width: 10),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('CALIFORNIA', style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800,
                  letterSpacing: 0.5, color: _C.white)),
                Text('School of Trucking', style: TextStyle(
                  fontSize: 10, color: Color(0x59FFFFFF))),
              ]),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Container(width: 5, height: 5,
                decoration: const BoxDecoration(
                  color: _C.gold, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Text('STUDENT PORTAL', style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w700,
                letterSpacing: 1.4, color: Color(0x59FFFFFF))),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_C.bronze, _C.gold],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(18)),
                child: Center(child: Text(initials,
                  style: const TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w800, color: _C.white)))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(displayName, style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _C.white),
                  overflow: TextOverflow.ellipsis),
                const Text('CDL Student', style: TextStyle(
                  fontSize: 10, color: Color(0x59FFFFFF))),
              ])),
            ]),
          ]),
        ),

        // Nav
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: _navGroups.map((g) => _NavGroupTile(
              group: g, currentIndex: currentIndex, onNavigate: onNavigate,
            )).toList(),
          ),
        ),

        // Sign out
        Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0x14FFFFFF)))),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('token');
                await prefs.remove('user');
                await prefs.remove('onboardingCompleted');
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const StudentLoginPage()),
                    (_) => false);
                }
              },
              child: const Padding(
                padding: EdgeInsets.fromLTRB(20, 14, 20, 32),
                child: Row(children: [
                  Icon(Icons.logout_rounded,
                    color: Color(0x88FFFFFF), size: 16),
                  SizedBox(width: 12),
                  Text('Sign Out', style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: Color(0x88FFFFFF))),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _NavGroupTile extends StatefulWidget {
  final _NavGroup group;
  final int       currentIndex;
  final void Function(int) onNavigate;
  const _NavGroupTile({required this.group, required this.currentIndex, required this.onNavigate});
  @override State<_NavGroupTile> createState() => _NavGroupTileState();
}

class _NavGroupTileState extends State<_NavGroupTile>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _expanded = widget.group.category == null ||
      widget.group.items.any((i) => i.pageIndex == widget.currentIndex);
    _ctrl = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 220),
      value: _expanded ? 1.0 : 0.0);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final hasCategory = widget.group.category != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (hasCategory) ...[
        const SizedBox(height: 6),
        InkWell(
          onTap: () {
            setState(() => _expanded = !_expanded);
            _expanded ? _ctrl.forward() : _ctrl.reverse();
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 12, 4),
            child: Row(children: [
              Expanded(child: Text(widget.group.category!.toUpperCase(),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  letterSpacing: 1.2, color: Color(0x47FFFFFF)))),
              AnimatedRotation(
                turns: _expanded ? 0 : -0.25,
                duration: const Duration(milliseconds: 220),
                child: const Icon(Icons.chevron_right,
                  size: 14, color: Color(0x33FFFFFF))),
            ]),
          ),
        ),
      ],
      SizeTransition(
        sizeFactor: hasCategory ? _anim : const AlwaysStoppedAnimation(1.0),
        child: Column(children: widget.group.items.map((item) {
          final active = item.pageIndex == widget.currentIndex;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => widget.onNavigate(item.pageIndex),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: active
                      ? _C.gold.withOpacity(.14) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Icon(active ? item.activeIcon : item.icon,
                      size: 16,
                      color: active ? _C.gold : const Color(0x73FFFFFF)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item.label, style: TextStyle(
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      color: active ? _C.white : const Color(0x99FFFFFF)))),
                    if (item.showBadge && item.badgeLabel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.badgeColor ?? _C.gold,
                          borderRadius: BorderRadius.circular(20)),
                        child: Text(item.badgeLabel!,
                          style: const TextStyle(fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: _C.white, letterSpacing: 0.5))),
                  ]),
                ),
              ),
            ),
          );
        }).toList()),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────
// HOME BODY  (all live data)
// ─────────────────────────────────────────────────────────────────
class _HomeBody extends StatefulWidget {
  final String token;
  const _HomeBody({required this.token});
  @override State<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<_HomeBody> {
  // ── data ───────────────────────────────────────────────────────
  Map<String, dynamic>?      _profile;
  Map<String, dynamic>?      _enrollment;
  Map<String, dynamic>?      _finances;
  List<Map<String, dynamic>> _schedule  = [];
  List<Map<String, dynamic>> _documents = [];
  Map<String, dynamic>?      _agreement;
  List<Map<String, dynamic>> _scores    = [];
  bool _loading    = true;
  bool _agreeLoad  = true;

  @override
  void initState() { super.initState(); _fetchAll(); _fetchAgreement(); }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (widget.token.isNotEmpty) 'Authorization': 'Bearer ${widget.token}',
  };

  Future<void> _fetchAll() async {
    try {
      final results = await Future.wait([
        http.get(Uri.parse('$_kApiBase/api/student-settings/profile'), headers: _headers),
        http.get(Uri.parse('$_kApiBase/api/enrollments/my'),           headers: _headers),
        http.get(Uri.parse('$_kApiBase/api/finances/my'),              headers: _headers),
        http.get(Uri.parse('$_kApiBase/api/schedule/my'),              headers: _headers),
        http.get(Uri.parse('$_kApiBase/api/documents'),                headers: _headers),
      ].map((f) => f.timeout(const Duration(seconds: 8))));

      if (!mounted) return;
      setState(() {
        if (results[0].statusCode == 200)
          _profile = jsonDecode(results[0].body);

        if (results[1].statusCode == 200) {
          final list = (jsonDecode(results[1].body) as List)
            .cast<Map<String, dynamic>>();
          _enrollment = list.firstWhere(
            (e) => e['status'] == 'active',
            orElse: () => list.isNotEmpty ? list.first : {},
          );
        }

        if (results[2].statusCode == 200)
          _finances = jsonDecode(results[2].body);

        if (results[3].statusCode == 200) {
          final all = (jsonDecode(results[3].body) as List)
            .cast<Map<String, dynamic>>();
          final now = DateTime.now();
          _schedule = all
            .where((s) {
              try {
                return DateTime.parse(s['date']).isAfter(
                  DateTime(now.year, now.month, now.day)
                    .subtract(const Duration(seconds: 1)));
              } catch (_) { return false; }
            })
            .toList()
            ..sort((a, b) => DateTime.parse(a['date'])
              .compareTo(DateTime.parse(b['date'])));
          if (_schedule.length > 3) _schedule = _schedule.sublist(0, 3);
        }

        if (results[4].statusCode == 200)
          _documents = (jsonDecode(results[4].body) as List)
            .cast<Map<String, dynamic>>();

        _loading = false;
      });

      // Scores (needs enrollment ID)
      final eid = _enrollment?['_id'];
      if (eid != null) {
        final sr = await http.get(
          Uri.parse('$_kApiBase/api/skills/my'), headers: _headers,
        ).timeout(const Duration(seconds: 8));
        if (sr.statusCode == 200 && mounted) {
          setState(() => _scores =
            (jsonDecode(sr.body) as List).cast<Map<String, dynamic>>());
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchAgreement() async {
    try {
      final res = await http.get(
        Uri.parse('$_kApiBase/api/enrollment-agreement/my'),
        headers: _headers,
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200 && mounted)
        setState(() => _agreement = jsonDecode(res.body));
    } catch (_) {}
    if (mounted) setState(() => _agreeLoad = false);
  }

  // ── derived values ─────────────────────────────────────────────
  String get _firstName => _profile?['firstName'] ?? '';
  String get _program   => _enrollment?['courseId']?['title'] ?? '—';

  String _fmtDate(String? iso, {String fallback = '—'}) {
    if (iso == null) return fallback;
    try {
      final d = DateTime.parse(iso);
      const months = ['Jan','Feb','Mar','Apr','May','Jun',
                      'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) { return fallback; }
  }

  String get _startDate {
    return _fmtDate(
      _enrollment?['scheduleSlot']?['startDate'] ??
      _enrollment?['enrolledAt']);
  }

  String get _endDate =>
    _fmtDate(_enrollment?['scheduleSlot']?['endDate']);

  String get _instructorName {
    final inst = _enrollment?['instructorId'];
    if (inst == null) return '—';
    return '${inst['firstName'] ?? ''} ${inst['lastName'] ?? ''}'.trim();
  }

  int get _overallProgress {
    final p = _enrollment?['progress'] ?? {};
    final done = [p['theoryDone'], p['practicalDone'], p['testPassed']]
      .where((v) => v == true).length;
    return ((done / 3) * 100).round();
  }

  int get _attendanceRate =>
    (_enrollment?['attendanceRate'] as num?)?.toInt() ?? 0;

  int get _tuitionTotal   => (_finances?['total']       as num?)?.toInt() ?? 0;
  int get _tuitionPaid    => (_finances?['paid']         as num?)?.toInt() ?? 0;
  int get _tuitionBalance => (_finances?['outstanding']  as num?)?.toInt() ?? 0;
  double get _tuitionPct  => _tuitionTotal > 0 ? _tuitionPaid / _tuitionTotal : 0;

  int get _daysLeft {
    final end = _enrollment?['scheduleSlot']?['endDate'];
    if (end == null) return 0;
    try {
      return max(0,
        DateTime.parse(end).difference(DateTime.now()).inDays);
    } catch (_) { return 0; }
  }

  List<Map<String, dynamic>> get _recentScores =>
    _scores.length > 4 ? _scores.sublist(0, 4) : _scores;

  int? get _avgScore {
    if (_recentScores.isEmpty) return null;
    final sum = _recentScores.fold<int>(
      0, (a, s) => a + ((s['score'] as num?)?.toInt() ?? 0));
    return (sum / _recentScores.length).round();
  }

  static const _docTypes = [
    'government-id', 'drivers-license', 'medical-certificate',
    'proof-of-enrollment', 'cdl-permit',
  ];

  static const _docLabels = {
    'government-id':        'Government-issued ID submitted',
    'drivers-license':      "Driver's license submitted",
    'medical-certificate':  'Medical certificate uploaded',
    'proof-of-enrollment':  'Proof of enrollment submitted',
    'cdl-permit':           'CDL permit obtained',
  };

  List<({String label, bool done})> get _checklist {
    final list = _docTypes.map((t) {
      final d = _documents.firstWhere(
        (d) => d['docType'] == t, orElse: () => {});
      return (label: _docLabels[t]!, done: d['status'] == 'approved');
    }).toList();
    list.add((
      label: 'Enrollment agreement signed',
      done: _agreement?['status'] == 'approved',
    ));
    return list;
  }

  int get _approvedDocs => _documents
    .where((d) => _docTypes.contains(d['docType']) && d['status'] == 'approved')
    .length;

  String _today() {
    const weekdays = ['Monday','Tuesday','Wednesday','Thursday',
                      'Friday','Saturday','Sunday'];
    const months   = ['January','February','March','April','May','June',
                      'July','August','September','October','November','December'];
    final d = DateTime.now();
    return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _sessionDate(String? iso) {
    if (iso == null) return '—';
    try {
      final d   = DateTime.parse(iso);
      final now = DateTime.now();
      final tod = DateTime(now.year, now.month, now.day);
      final tom = tod.add(const Duration(days: 1));
      if (DateTime(d.year,d.month,d.day) == tod) return 'Today';
      if (DateTime(d.year,d.month,d.day) == tom) return 'Tomorrow';
      const wd = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      const mo = ['Jan','Feb','Mar','Apr','May','Jun',
                  'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${wd[d.weekday-1]} ${mo[d.month-1]} ${d.day}';
    } catch (_) { return '—'; }
  }

  Color _scoreColor(int s) =>
    s >= 90 ? _C.green : s >= 75 ? _C.gold : _C.orange;

  // ── build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final doneItems = _checklist.where((c) => c.done).length;

    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Welcome header ────────────────────────────────
            Text('STUDENT PORTAL', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w800,
              color: _C.gold, letterSpacing: 1.4)),
            const SizedBox(height: 4),
            Text(
              _loading ? 'Welcome back...'
                       : 'Welcome back, $_firstName',
              style: const TextStyle(fontSize: 24,
                fontWeight: FontWeight.w800, color: _C.navy,
                fontFamily: 'Georgia')),
            const SizedBox(height: 4),
            Text(_today(), style: const TextStyle(
              fontSize: 13, color: _C.gray600)),
            const SizedBox(height: 20),

            // ── Onboarding banner ─────────────────────────────
            OnboardingBanner(
              documents: _documents,
              agreement: _agreement,
              loading:   _loading || _agreeLoad,
            ),

            // ── Agreement banner ──────────────────────────────
            AgreementBanner(
              agreement: _agreement,
              loading:   _agreeLoad,
            ),

            // ── Enrollment card ───────────────────────────────
            _EnrollmentCard(
              program:          _program,
              startDate:        _startDate,
              endDate:          _endDate,
              instructorName:   _instructorName,
              overallProgress:  _overallProgress,
              attendanceRate:   _attendanceRate,
              loading:          _loading,
            ),
            const SizedBox(height: 16),

            // ── Stat cards 2×2 ────────────────────────────────
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                _StatCard(
                  label: 'Training Days Left',
                  value: _loading ? '—' : '$_daysLeft',
                  icon:  Icons.calendar_today,
                  color: _C.gold,
                  sub:   _endDate != '—' ? 'Est. $_endDate' : 'No end date',
                  loading: _loading,
                ),
                _StatCard(
                  label: 'Avg. Test Score',
                  value: _loading ? '—'
                    : _avgScore != null ? '$_avgScore%' : 'N/A',
                  icon:  Icons.trending_up,
                  color: _C.green,
                  sub:   _avgScore != null
                    ? (_avgScore! >= 75
                      ? 'Above passing (75%)' : 'Below passing threshold')
                    : 'No scores yet',
                  loading: _loading,
                ),
                _StatCard(
                  label: 'Balance Due',
                  value: _loading ? '—'
                    : '\$${_tuitionBalance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                  icon:  Icons.attach_money,
                  color: _C.orange,
                  sub:   '\$$_tuitionPaid paid',
                  loading: _loading,
                ),
                _StatCard(
                  label: 'Documents',
                  value: _loading ? '—'
                    : '$_approvedDocs/${_docTypes.length}',
                  icon:  Icons.description_outlined,
                  color: _C.blue,
                  sub:   'Approved required docs',
                  loading: _loading,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Upcoming sessions ─────────────────────────────
            _SectionCard(
              title:       'Upcoming Sessions',
              subtitle:    'Your scheduled training',
              actionLabel: 'Full Schedule',
              child: _loading
                ? _Skeleton(height: 140)
                : _schedule.isEmpty
                  ? _EmptyState(
                      icon: Icons.calendar_today,
                      message: 'No upcoming sessions scheduled')
                  : Column(children:
                      List.generate(_schedule.length, (i) =>
                        _SessionRow(
                          session: _schedule[i],
                          isFirst: i == 0,
                          isLast:  i == _schedule.length - 1,
                          dateLabel: _sessionDate(_schedule[i]['date']),
                        ))),
            ),
            const SizedBox(height: 16),

            // ── Recent scores ─────────────────────────────────
            _SectionCard(
              title:       'Recent Scores',
              subtitle:    'Latest assessment results',
              actionLabel: 'Full Progress',
              child: _loading
                ? _Skeleton(height: 120)
                : _recentScores.isEmpty
                  ? _EmptyState(
                      icon: Icons.trending_up,
                      message: 'No scores recorded yet')
                  : Column(children:
                      List.generate(_recentScores.length, (i) {
                        final item  = _recentScores[i];
                        final score = (item['score'] as num?)?.toInt() ?? 0;
                        final date  = item['sessionDate'] != null
                          ? _fmtDate(item['sessionDate']) : '';
                        return _ScoreRow(
                          label:  item['label'] ?? item['type'] ?? '—',
                          score:  score,
                          date:   date,
                          isLast: i == _recentScores.length - 1,
                          color:  _scoreColor(score),
                        );
                      })),
            ),
            const SizedBox(height: 16),

            // ── Enrollment checklist ──────────────────────────
            _ChecklistCard(
              checklist:  _checklist,
              doneItems:  doneItems,
              loading:    _loading || _agreeLoad,
            ),
            const SizedBox(height: 16),

            // ── Tuition summary ───────────────────────────────
            _TuitionCard(
              total:   _tuitionTotal,
              paid:    _tuitionPaid,
              balance: _tuitionBalance,
              pct:     _tuitionPct,
              loading: _loading,
            ),
            const SizedBox(height: 16),

            // ── Quick links ───────────────────────────────────
            _QuickLinksCard(),
          ]),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────
// ENROLLMENT CARD
// ─────────────────────────────────────────────────────────────────
class _EnrollmentCard extends StatelessWidget {
  final String program, startDate, endDate, instructorName;
  final int    overallProgress, attendanceRate;
  final bool   loading;
  const _EnrollmentCard({
    required this.program, required this.startDate,
    required this.endDate, required this.instructorName,
    required this.overallProgress, required this.attendanceRate,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: Stack(children: [
      Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_C.navyDeep, _C.navySoft],
            begin: Alignment.centerLeft, end: Alignment.centerRight)),
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:        _C.gold,
              borderRadius: BorderRadius.circular(6)),
            child: Text(
              loading ? '...' : 'ACTIVE ENROLLMENT',
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                color: _C.navyDeep, letterSpacing: 1.2))),
          const SizedBox(height: 8),

          loading
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Skeleton(width: 200, height: 22),
                const SizedBox(height: 8),
                _Skeleton(width: 260, height: 14),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(program, style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800,
                  color: _C.white, fontFamily: 'Georgia')),
                const SizedBox(height: 4),
                Text(
                  '$startDate → $endDate'
                  '${instructorName != '—' ? '  ·  Instructor: $instructorName' : ''}',
                  style: TextStyle(fontSize: 12,
                    color: _C.white.withOpacity(.6))),
              ]),

          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _RingKpi(
                value: loading ? null : overallProgress,
                color: _C.gold,
                label: 'Overall Progress'),
              _RingKpi(
                value: loading ? null : attendanceRate,
                color: _C.olive,
                label: 'Attendance'),
            ],
          ),
        ]),
      ),
      // Decorative circles
      Positioned(top: -30, right: -30,
        child: Container(width: 120, height: 120,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: _C.gold.withOpacity(.12)))),
      Positioned(right: 50, bottom: -30,
        child: Container(width: 80, height: 80,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: _C.goldLight.withOpacity(.09)))),
    ]),
  );
}

// ── Ring KPI ──────────────────────────────────────────────────────
class _RingKpi extends StatelessWidget {
  final int?   value;
  final Color  color;
  final String label;
  const _RingKpi({required this.value, required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Column(children: [
    SizedBox(
      width: 80, height: 80,
      child: CustomPaint(
        painter: _RingPainter((value ?? 0) / 100, color),
        child: Center(child: Text(
          value != null ? '$value%' : '—',
          style: const TextStyle(fontSize: 16,
            fontWeight: FontWeight.w800, color: _C.white,
            fontFamily: 'Georgia'))))),
    const SizedBox(height: 6),
    Text(label.toUpperCase(), style: TextStyle(
      fontSize: 9, color: _C.white.withOpacity(.5),
      letterSpacing: .8, fontWeight: FontWeight.w700)),
  ]);
}

class _RingPainter extends CustomPainter {
  final double fraction; final Color color;
  const _RingPainter(this.fraction, this.color); 

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r  = min(cx, cy) - 6;
    canvas.drawCircle(Offset(cx, cy), r, Paint()
      ..color = _C.white.withOpacity(.12)
      ..style = PaintingStyle.stroke..strokeWidth = 8);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -pi / 2, 2 * pi * fraction.clamp(0, 1), false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke..strokeWidth = 8
        ..strokeCap = StrokeCap.round);
  }

  @override bool shouldRepaint(_RingPainter o) => o.fraction != fraction;
}

// ─────────────────────────────────────────────────────────────────
// STAT CARD
// ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value, sub;
  final IconData icon; final Color color; final bool loading;
  const _StatCard({
    required this.label, required this.value,
    required this.icon, required this.color,
    required this.sub, required this.loading,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
    decoration: BoxDecoration(
      color: _C.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _C.gray200),
      boxShadow: [BoxShadow(
        color: _C.navy.withOpacity(.05), blurRadius: 8)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(.1),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20)),
          const Icon(Icons.chevron_right, size: 14, color: _C.gray400),
        ]),
      const Spacer(),
      loading
        ? Container(height: 24, width: 70,
            decoration: BoxDecoration(
              color: _C.gray100, borderRadius: BorderRadius.circular(6)))
        : Text(value, style: const TextStyle(
            fontSize: 24, fontWeight: FontWeight.w800,
            color: _C.navy, fontFamily: 'Georgia', height: 1)),
      const SizedBox(height: 3),
      Text(label.toUpperCase(), style: const TextStyle(
        fontSize: 9, fontWeight: FontWeight.w700,
        color: _C.gray600, letterSpacing: .7)),
      const SizedBox(height: 2),
      Text(sub, style: const TextStyle(fontSize: 11, color: _C.gray400),
        maxLines: 1, overflow: TextOverflow.ellipsis),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────
// SECTION CARD
// ─────────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title, subtitle, actionLabel;
  final Widget child;
  const _SectionCard({
    required this.title, required this.subtitle,
    required this.actionLabel, required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _C.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _C.gray200),
      boxShadow: [BoxShadow(
        color: _C.navy.withOpacity(.05), blurRadius: 8)]),
    child: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
        child: Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700,
              color: _C.navy, fontFamily: 'Georgia')),
            Text(subtitle, style: const TextStyle(
              fontSize: 12, color: _C.gray600)),
          ])),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(actionLabel, style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: _C.gold)),
              const Icon(Icons.chevron_right, size: 14, color: _C.gold),
            ])),
        ])),
      const Divider(height: 1, color: _C.gray200),
      child,
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────
// SESSION ROW
// ─────────────────────────────────────────────────────────────────
class _SessionRow extends StatelessWidget {
  final Map<String, dynamic> session;
  final bool   isFirst, isLast;
  final String dateLabel;
  const _SessionRow({
    required this.session, required this.isFirst,
    required this.isLast, required this.dateLabel,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    decoration: BoxDecoration(
      border: isLast ? null
        : const Border(bottom: BorderSide(color: _C.gray100))),
    child: Row(children: [
      Container(
        width: 70,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isFirst ? _C.bronze : _C.gray100,
          borderRadius: BorderRadius.circular(8)),
        child: Column(children: [
          Text(dateLabel.toUpperCase(), style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.w800,
            color: isFirst
              ? _C.white.withOpacity(.76) : _C.gray600,
            letterSpacing: .5)),
          const SizedBox(height: 2),
          Text(session['startTime'] ?? '—', style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w800,
            color: isFirst ? _C.white : _C.navy)),
        ])),
      const SizedBox(width: 14),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(session['title'] ?? '—', style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700, color: _C.navy)),
        const SizedBox(height: 3),
        Row(children: [
          const Icon(Icons.location_on_outlined,
            size: 12, color: _C.gray400),
          const SizedBox(width: 3),
          Text(session['location'] ?? 'TBD', style: const TextStyle(
            fontSize: 12, color: _C.gray600)),
        ]),
      ])),
      if (isFirst)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _C.sand,
            borderRadius: BorderRadius.circular(20)),
          child: const Text('NEXT UP', style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.w800,
            color: _C.bronze, letterSpacing: .8))),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────
// SCORE ROW
// ─────────────────────────────────────────────────────────────────
class _ScoreRow extends StatelessWidget {
  final String label, date;
  final int    score;
  final bool   isLast;
  final Color  color;
  const _ScoreRow({
    required this.label, required this.date,
    required this.score, required this.isLast, required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
    decoration: BoxDecoration(
      border: isLast ? null
        : const Border(bottom: BorderSide(color: _C.gray100))),
    child: Row(children: [
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(label, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: _C.navy))),
            Row(children: [
              Text(date, style: const TextStyle(
                fontSize: 11, color: _C.gray400)),
              const SizedBox(width: 8),
              Text('$score%', style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: color,
                fontFamily: 'Georgia')),
            ]),
          ]),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: score / 100, minHeight: 5,
            backgroundColor: _C.gray100,
            valueColor: AlwaysStoppedAnimation(color))),
      ])),
      const SizedBox(width: 12),
      Icon(Icons.check_circle,
        size: 16,
        color: score >= 75 ? _C.green : _C.orange),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────
// CHECKLIST CARD
// ─────────────────────────────────────────────────────────────────
class _ChecklistCard extends StatelessWidget {
  final List<({String label, bool done})> checklist;
  final int  doneItems;
  final bool loading;
  const _ChecklistCard({
    required this.checklist, required this.doneItems, required this.loading});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _C.white, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _C.gray200),
      boxShadow: [BoxShadow(
        color: _C.navy.withOpacity(.05), blurRadius: 8)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Enrollment Checklist', style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w700,
          color: _C.navy, fontFamily: 'Georgia')),
        Text('$doneItems/${checklist.length}', style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700, color: _C.gold)),
      ]),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(
          value: checklist.isEmpty ? 0 : doneItems / checklist.length,
          minHeight: 5,
          backgroundColor: _C.gray100,
          valueColor: const AlwaysStoppedAnimation(_C.gold))),
      const SizedBox(height: 14),
      if (loading)
        _Skeleton(height: 120)
      else
        ...checklist.asMap().entries.map((e) {
          final i = e.key; final item = e.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: i < checklist.length - 1 ? 10 : 0),
            child: Row(children: [
              item.done
                ? const Icon(Icons.check_circle, size: 16, color: _C.green)
                : Container(
                    width: 16, height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _C.gray400, width: 2))),
              const SizedBox(width: 10),
              Expanded(child: Text(item.label, style: TextStyle(
                fontSize: 13,
                fontWeight: item.done ? FontWeight.w500 : FontWeight.w400,
                color: item.done ? _C.gray800 : _C.gray400))),
            ]),
          );
        }),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────
// TUITION CARD
// ─────────────────────────────────────────────────────────────────
class _TuitionCard extends StatelessWidget {
  final int total, paid, balance; final double pct; final bool loading;
  const _TuitionCard({
    required this.total, required this.paid,
    required this.balance, required this.pct, required this.loading});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [_C.navyDeep, _C.navySoft],
        begin: Alignment.centerLeft, end: Alignment.centerRight),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(
        color: _C.navy.withOpacity(.08), blurRadius: 20, offset: const Offset(0, 8))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Tuition Summary', style: TextStyle(
        fontSize: 15, fontWeight: FontWeight.w700,
        color: _C.white, fontFamily: 'Georgia')),
      const SizedBox(height: 14),
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(
          value: pct, minHeight: 8,
          backgroundColor: _C.white.withOpacity(.10),
          valueColor: const AlwaysStoppedAnimation(_C.gold))),
      const SizedBox(height: 14),
      if (loading)
        Column(children: List.generate(3, (_) =>
          Padding(padding: const EdgeInsets.only(bottom: 8),
            child: _Skeleton(height: 16))))
      else
        ...[
          (label: 'Total Tuition', value: '\$$total',   color: _C.white.withOpacity(.58)),
          (label: 'Amount Paid',   value: '\$$paid',    color: _C.greenLight),
          (label: 'Balance Due',   value: '\$$balance', color: _C.orangeLight),
        ].map((row) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(row.label, style: TextStyle(
              fontSize: 13, color: _C.white.withOpacity(.58))),
            Text(row.value, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: row.color)),
          ]))),

      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: _C.gold,
            foregroundColor: _C.navyDeep,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8))),
          child: const Text('Make a Payment',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)))),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────
// QUICK LINKS CARD
// ─────────────────────────────────────────────────────────────────
class _QuickLinksCard extends StatelessWidget {
  static const _links = [
    (label: 'View My Progress',        icon: Icons.trending_up,           color: _C.gold),
    (label: 'Upload Documents',        icon: Icons.description_outlined,   color: _C.blue),
    (label: 'Full Schedule',           icon: Icons.calendar_today,         color: _C.green),
    (label: 'Payment History',         icon: Icons.attach_money,           color: _C.orange),
    (label: 'Enrollment Agreement',    icon: Icons.draw_outlined,          color: _C.bronze),
  ];

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _C.white, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _C.gray200),
      boxShadow: [BoxShadow(
        color: _C.navy.withOpacity(.05), blurRadius: 8)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Quick Links', style: TextStyle(
        fontSize: 15, fontWeight: FontWeight.w700,
        color: _C.navy, fontFamily: 'Georgia')),
      const SizedBox(height: 12),
      ..._links.map((item) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 10),
            child: Row(children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(.12),
                  borderRadius: BorderRadius.circular(7)),
                child: Icon(item.icon, color: item.color, size: 15)),
              const SizedBox(width: 12),
              Expanded(child: Text(item.label, style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: _C.gray800))),
              const Icon(Icons.chevron_right,
                size: 14, color: _C.gray400),
            ]),
          ),
        ))),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String   message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Center(child: Column(children: [
      Icon(icon, size: 28, color: _C.gray200),
      const SizedBox(height: 8),
      Text(message, style: const TextStyle(
        fontSize: 13, color: _C.gray400)),
    ])),
  );
}

// ─────────────────────────────────────────────────────────────────
// SKELETON LOADER
// ─────────────────────────────────────────────────────────────────
class _Skeleton extends StatelessWidget {
  final double? width;
  final double  height;
  const _Skeleton({this.width, required this.height});

  @override
  Widget build(BuildContext context) => Container(
    width: width ?? double.infinity,
    height: height,
    decoration: BoxDecoration(
      color: _C.gray100, borderRadius: BorderRadius.circular(6)));
}