// lib/screens/student/student_tribe_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cst_mobile/config/api_config.dart';

// ── Palette ───────────────────────────────────────────────────
const _accent = Color(0xFF7C3AED);
const _navy   = Color(0xFF0B1F3A);
const _gold   = Color(0xFFC9A84C);
const _green  = Color(0xFF0E9F8E);
const _white  = Color(0xFFFFFFFF);
const _gray50 = Color(0xFFF8F9FA);
const _gray100= Color(0xFFF3F4F6);
const _gray200= Color(0xFFE9ECEF);
const _gray400= Color(0xFFADB5BD);
const _gray600= Color(0xFF6C757D);
const _gray700= Color(0xFF495057);
// _red removed (unused duplicate)

// ── 25 Mission Statements ─────────────────────────────────────
const _missionStatements = [
  "Built on discipline. We train drivers who refuse to settle for average.",
  "Train Hard, Drive Safe. Never accept mediocrity.",
  "Great mindset — every mile is driven with purpose and precision.",
  "No shortcuts, no compromises. Just drivers trained at their best.",
  "Service-driven values shape drivers with discipline and confidence.",
  "We bring the mindset of training into real-world performance.",
  "Train with purpose, drive with confidence, and leave mediocrity behind.",
  "Effort turns into excellence behind the wheel.",
  "From first lesson to final test, the goal is simple: be better than average.",
  "Discipline from service meets real-world training to produce confident drivers.",
  "Road-ready drivers turned road-ready professionals.",
  "Strong values and hard training lead to drivers who stand above the rest.",
  "Built through discipline, proven on the road, driven by high standards.",
  "We lead the way in setting the standard for professional driving.",
  "Where discipline meets safety, drivers perform with confidence and control.",
  "A commitment to service creates drivers who stay focused under pressure.",
  "Train harder, think sharper, and drive with purpose every mile.",
  "We set the bar — our drivers rise to meet it every day.",
  "Every lesson, every mile, every driver committed to doing it right.",
  "With leadership, we don't just train — we build dependable professionals.",
  "Service teaches discipline. Training turns it into skill and confidence.",
  "From discipline to execution — every step pushes drivers beyond average.",
  "Veterans know preparation matters. That's what separates good from great drivers.",
  "Hard work earns it, discipline proves it, and performance defines it.",
  "Guided by service, driven by standards, and committed to excellence.",
];

String _getWeeklyStatement() {
  final weekNumber = DateTime.now().millisecondsSinceEpoch ~/ (7 * 24 * 60 * 60 * 1000);
  return _missionStatements[weekNumber % _missionStatements.length];
}

int _getStatementNumber() {
  final weekNumber = DateTime.now().millisecondsSinceEpoch ~/ (7 * 24 * 60 * 60 * 1000);
  return (weekNumber % _missionStatements.length) + 1;
}

// ── Helpers ───────────────────────────────────────────────────
String _fmtDate(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '';
  try {
    final d = DateTime.parse(dateStr).toLocal();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  } catch (e) {
    return '';
  }
}

String _fmtTime(String? t) {
  if (t == null || t.isEmpty) return '';
  final parts = t.split(':');
  if (parts.length < 2) return t;
  final hr = int.tryParse(parts[0]) ?? 0;
  final min = parts[1];
  final period = hr >= 12 ? 'PM' : 'AM';
  final displayHr = hr > 12 ? hr - 12 : (hr == 0 ? 12 : hr);
  return '$displayHr:$min $period';
}

Future<String> _getToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('token') ?? '';
}

// ── Badge widget ──────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color  color;
  const _Badge({required this.label, this.color = _accent});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color:        color.withValues(alpha: 0.09),
      border:       Border.all(color: color.withValues(alpha: 0.28)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 9, fontWeight: FontWeight.w700,
        letterSpacing: 0.8, color: color),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// MAIN SCREEN
// ══════════════════════════════════════════════════════════════
class StudentTribeScreen extends StatefulWidget {
  const StudentTribeScreen({super.key});

  @override
  State<StudentTribeScreen> createState() => _StudentTribeScreenState();
}

class _StudentTribeScreenState extends State<StudentTribeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _tabs = const ['community', 'events', 'blog', 'veterans'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _gray50,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            backgroundColor:  _navy,
            foregroundColor:  _white,
            pinned:           true,
            floating:         true,
            expandedHeight:   220,
            elevation:        0,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: _HeaderBanner(
                weeklyStatement: _getWeeklyStatement(),
                statementNum:    _getStatementNumber(),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: Container(
                color: _navy,
                child: TabBar(
                  controller:           _tabCtrl,
                  indicatorColor:       _accent,
                  indicatorWeight:      3,
                  labelColor:           _white,
                  unselectedLabelColor: _white.withValues(alpha: 0.45),
                  labelStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500),
                  tabs: const [
                    Tab(icon: Icon(Icons.group_outlined,    size: 16), text: 'Community'),
                    Tab(icon: Icon(Icons.event_outlined,    size: 16), text: 'Events'),
                    Tab(icon: Icon(Icons.menu_book_outlined,size: 16), text: 'Newsletter'),
                    Tab(icon: Icon(Icons.shield_outlined,   size: 16), text: 'Veterans'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: const [
            _CommunityTab(),
            _EventsTab(),
            _BlogTab(),
            _VeteransTab(),
          ],
        ),
      ),
    );
  }
}

// ── Header Banner ─────────────────────────────────────────────
class _HeaderBanner extends StatelessWidget {
  final String weeklyStatement;
  final int    statementNum;
  const _HeaderBanner({
    required this.weeklyStatement,
    required this.statementNum,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [_navy, Color(0xFF1a2f52)],
        begin:  Alignment.topLeft,
        end:    Alignment.bottomRight,
      ),
    ),
    padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment:  MainAxisAlignment.end,
      children: [
        // Title row
        Row(children: [
          const Icon(Icons.group_outlined, size: 20, color: _accent),
          const SizedBox(width: 8),
          const Text('CST Tribe',
            style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w800,
              color: _white)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color:        _accent.withValues(alpha: 0.18),
              border:       Border.all(color: _accent.withValues(alpha: 0.35)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('COMMUNITY',
              style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w700,
                color: _accent, letterSpacing: 1.0)),
          ),
        ]),
        const SizedBox(height: 4),
        Text('Welcome to the tribe. Every student, their family, their neighbors.',
          style: TextStyle(fontSize: 12, color: _white.withValues(alpha: 0.55))),
        const SizedBox(height: 14),

        // Weekly Mission
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:        _white.withValues(alpha: 0.06),
            border:       Border.all(color: _white.withValues(alpha: 0.1)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.local_fire_department_outlined, size: 13, color: _gold),
              const SizedBox(width: 6),
              Text(
                'THIS WEEK\'S MOTIVATION · STATEMENT $statementNum OF 25',
                style: const TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: _gold, letterSpacing: 0.8),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              '"$weeklyStatement"',
              style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: _white, fontStyle: FontStyle.italic, height: 1.4),
            ),
            const SizedBox(height: 6),
            Text('— California School of Trucking',
              style: TextStyle(fontSize: 10, color: _white.withValues(alpha: 0.35))),
          ]),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// COMMUNITY TAB
// ══════════════════════════════════════════════════════════════
class _CommunityTab extends StatefulWidget {
  const _CommunityTab();
  @override State<_CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends State<_CommunityTab> {
  List   _posts     = [];
  bool   _loading   = true;
  bool   _submitting= false;
  String _content   = '';
  String _type      = 'general';

  final _ctrl = TextEditingController();

  final _typeOptions = [
    {'value': 'general',   'label': '💬 General',  'color': _accent},
    {'value': 'shoutout',  'label': '🎉 Shoutout', 'color': _gold  },
    {'value': 'milestone', 'label': '🏆 Milestone','color': _green },
    {'value': 'question',  'label': '❓ Question', 'color': _navy  },
  ];

  final _typeColor = {
    'general':   _accent,
    'shoutout':  _gold,
    'milestone': _green,
    'question':  _navy,
  };

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final token = await _getToken();
      final r = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/tribe/posts'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final d = jsonDecode(r.body);
      setState(() => _posts = d is List ? d : []);
    } catch (e) {
      setState(() => _posts = []);
    }
    setState(() => _loading = false);
  }

  Future<void> _submit() async {
    if (_content.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      final token = await _getToken();
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/tribe/posts'),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'content': _content, 'type': _type}),
      );
      _ctrl.clear();
      setState(() { _content = ''; _type = 'general'; });
      _load();
    } catch (e) {
      // handle silently
    }
    setState(() => _submitting = false);
  }

  Future<void> _likePost(String id) async {
    try {
      final token = await _getToken();
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/tribe/posts/$id/like'),
        headers: {'Authorization': 'Bearer $token'},
      );
      _load();
    } catch (e) {
      // handle silently
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: _accent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Composer
          _card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Share with the Tribe',
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _navy)),
              const SizedBox(height: 12),

              // Type chips
              Wrap(spacing: 8, runSpacing: 8, children: _typeOptions.map((opt) {
                final isActive = _type == opt['value'];
                final color = opt['color'] as Color;
                return GestureDetector(
                  onTap: () => setState(() => _type = opt['value'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color:        isActive ? color.withValues(alpha: 0.1) : _white,
                      border:       Border.all(
                        color: isActive ? color : _gray200),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(opt['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                        color: isActive ? color : _gray600)),
                  ),
                );
              }).toList()),
              const SizedBox(height: 12),

              TextField(
                controller: _ctrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Share an update, shout someone out, or ask a question...',
                  hintStyle: const TextStyle(fontSize: 13, color: _gray400),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _gray200)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _gray200)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _accent)),
                ),
                style: const TextStyle(fontSize: 14, color: _navy),
                onChanged: (v) => setState(() => _content = v),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _content.trim().isNotEmpty && !_submitting
                      ? _submit : null,
                  icon: const Icon(Icons.send_outlined, size: 13),
                  label: Text(_submitting ? 'Posting...' : 'Post to Tribe'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: _white,
                    disabledBackgroundColor: _gray200,
                    disabledForegroundColor: _gray400,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                    textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          if (_loading)
            const Center(child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: _accent, strokeWidth: 2.5),
            ))
          else if (_posts.isEmpty)
            _emptyState(Icons.group_outlined, 'No posts yet. Be the first to post!')
          else
            ..._posts.map((post) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PostCard(
                post:      post,
                typeColor: _typeColor,
                onLike:    () => _likePost(post['_id']?.toString() ?? ''),
              ),
            )),
        ],
      ),
    );
  }
}

// ── Post Card ─────────────────────────────────────────────────
class _PostCard extends StatelessWidget {
  final Map          post;
  final Map<String, Color> typeColor;
  final VoidCallback onLike;
  const _PostCard({
    required this.post,
    required this.typeColor,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    final author    = post['author'] as Map? ?? {};
    final firstName = author['firstName']?.toString() ?? '';
    final lastName  = author['lastName']?.toString()  ?? '';
    final initials  = '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}';
    final type      = post['type']?.toString() ?? 'general';
    final color     = typeColor[type] ?? _accent;

    return _card(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Avatar
        Container(
          width: 38, height: 38,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [_accent, Color(0xFF9F67FA)],
              begin:  Alignment.topLeft,
              end:    Alignment.bottomRight,
            ),
          ),
          alignment: Alignment.center,
          child: Text(initials,
            style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: _white)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('$firstName $lastName',
                  style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: _navy)),
                _Badge(label: type, color: color),
                Text(_fmtDate(post['createdAt']?.toString()),
                  style: const TextStyle(fontSize: 11, color: _gray400)),
              ],
            ),
            const SizedBox(height: 6),
            Text(post['content']?.toString() ?? '',
              style: const TextStyle(
                fontSize: 14, color: _gray700, height: 1.5)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onLike,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.favorite_border_outlined,
                  size: 14, color: _gray400),
                const SizedBox(width: 4),
                Text('${post['likes'] ?? 0} likes',
                  style: const TextStyle(fontSize: 12, color: _gray400)),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// EVENTS TAB
// ══════════════════════════════════════════════════════════════
class _EventsTab extends StatefulWidget {
  const _EventsTab();
  @override State<_EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<_EventsTab> {
  List   _events  = [];
  bool   _loading = true;
  String _filter  = 'upcoming';

  final _typeColor = {
    'webinar':    _accent,
    'in-person':  _green,
    'virtual':    Color(0xFF0EA5E9),
    'nationwide': _gold,
    'community':  Color(0xFFF59E0B),
  };

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final token = await _getToken();
      final r = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/tribe/events?filter=$_filter'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final d = jsonDecode(r.body);
      setState(() => _events = d is List ? d : []);
    } catch (e) {
      setState(() => _events = []);
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: _accent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Filter
          Row(children: ['upcoming', 'past'].map((f) {
            final active = f == _filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () { setState(() => _filter = f); _load(); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color:        active ? _accent : _white,
                    border:       Border.all(
                      color: active ? _accent : _gray200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    f[0].toUpperCase() + f.substring(1),
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: active ? _white : _gray600)),
                ),
              ),
            );
          }).toList()),
          const SizedBox(height: 16),

          if (_loading)
            const Center(child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: _accent, strokeWidth: 2.5),
            ))
          else if (_events.isEmpty)
            _emptyState(Icons.event_outlined, 'No $_filter events right now.')
          else
            ..._events.map((ev) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _EventCard(ev: ev, typeColor: _typeColor),
            )),
        ],
      ),
    );
  }
}

// ── Event Card ────────────────────────────────────────────────
class _EventCard extends StatelessWidget {
  final Map                ev;
  final Map<String, Color> typeColor;
  const _EventCard({required this.ev, required this.typeColor});

  @override
  Widget build(BuildContext context) {
    DateTime? d;
    try { d = DateTime.parse(ev['date']?.toString() ?? ''); } catch (e) {}
    final type  = ev['type']?.toString() ?? 'event';
    final color = typeColor[type] ?? _accent;

    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];

    return Container(
      decoration: BoxDecoration(
        color:        _white,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _gray200),
        boxShadow:    [BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 6, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Date block
        Container(
          width: 72,
          color: _navy,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (d != null) ...[
                Text(months[d.month - 1].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: _gold, letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Text('${d.day}',
                  style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w800,
                    color: _white, height: 1.0)),
                const SizedBox(height: 2),
                Text('${d.year}',
                  style: TextStyle(
                    fontSize: 10, color: _white.withValues(alpha: 0.4))),
              ] else
                const Icon(Icons.event_outlined, color: _gray400, size: 24),
            ],
          ),
        ),

        // Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(ev['title']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: _navy)),
                  ),
                  const SizedBox(width: 8),
                  _Badge(label: type, color: color),
                ],
              ),
              if ((ev['description']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(ev['description'].toString(),
                  style: const TextStyle(
                    fontSize: 13, color: _gray600, height: 1.5),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 10),
              Wrap(spacing: 14, runSpacing: 6, children: [
                if ((ev['location']?.toString() ?? '').isNotEmpty)
                  _MetaChip(
                    icon: Icons.location_on_outlined,
                    label: ev['location'].toString()),
                if ((ev['startTime']?.toString() ?? '').isNotEmpty)
                  _MetaChip(
                    icon: Icons.access_time_outlined,
                    label: _fmtTime(ev['startTime'].toString())),
                if (ev['isVirtual'] == true)
                  _MetaChip(
                    icon:  Icons.language_outlined,
                    label: 'Virtual',
                    color: const Color(0xFF0EA5E9)),
              ]),
              if ((ev['link']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse(ev['link'].toString());
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Learn more',
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: _accent)),
                    SizedBox(width: 4),
                    Icon(Icons.open_in_new_outlined,
                      size: 11, color: _accent),
                  ]),
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _MetaChip({
    required this.icon,
    required this.label,
    this.color = _gray600,
  });

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 12, color: _gray400),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(fontSize: 12, color: color)),
  ]);
}

// ══════════════════════════════════════════════════════════════
// NEWSLETTER / BLOG TAB
// ══════════════════════════════════════════════════════════════
class _BlogTab extends StatefulWidget {
  const _BlogTab();
  @override State<_BlogTab> createState() => _BlogTabState();
}

class _BlogTabState extends State<_BlogTab> {
  List    _posts    = [];
  bool    _loading  = true;
  String? _expanded;

  final _categoryColor = {
    'newsletter':    _accent,
    'announcement':  _gold,
    'motivation':    _green,
    'industry':      _navy,
    'tips':          Color(0xFFF59E0B),
  };

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final token = await _getToken();
      final r = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/tribe/newsletter'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final d = jsonDecode(r.body);
      setState(() => _posts = d is List ? d : []);
    } catch (e) {
      setState(() => _posts = []);
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: _accent,
      child: _loading
          ? const Center(child: CircularProgressIndicator(
              color: _accent, strokeWidth: 2.5))
          : _posts.isEmpty
              ? _emptyState(Icons.menu_book_outlined,
                  'No newsletters published yet.')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount:      _posts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final post = _posts[i];
                    final id   = post['_id']?.toString() ?? '$i';
                    final isOpen = _expanded == id;
                    final cat  = post['category']?.toString() ?? 'newsletter';
                    final color = _categoryColor[cat] ?? _accent;

                    return _BlogCard(
                      post:     post,
                      isOpen:   isOpen,
                      catColor: color,
                      onToggle: () => setState(() =>
                        _expanded = isOpen ? null : id),
                    );
                  },
                ),
    );
  }
}

// ── Blog Card ─────────────────────────────────────────────────
class _BlogCard extends StatefulWidget {
  final Map          post;
  final bool         isOpen;
  final Color        catColor;
  final VoidCallback onToggle;
  const _BlogCard({
    required this.post,
    required this.isOpen,
    required this.catColor,
    required this.onToggle,
  });
  @override State<_BlogCard> createState() => _BlogCardState();
}

class _BlogCardState extends State<_BlogCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _expand;

  @override
  void initState() {
    super.initState();
    _ctrl   = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 250));
    _expand = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    if (widget.isOpen) _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(_BlogCard old) {
    super.didUpdateWidget(old);
    if (widget.isOpen != old.isOpen) {
      widget.isOpen ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final post     = widget.post;
    final cat      = post['category']?.toString() ?? 'newsletter';
    final dateStr  = post['publishedAt']?.toString() ?? post['createdAt']?.toString();
    final summary  = post['summary']?.toString() ?? '';
    final body     = post['body']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color:        _white,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(
          color: widget.isOpen
              ? widget.catColor.withValues(alpha: 0.3) : _gray200),
        boxShadow: [BoxShadow(
          color: widget.isOpen
              ? widget.catColor.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          blurRadius: widget.isOpen ? 12 : 5,
          offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        // Header
        InkWell(
          onTap:        widget.onToggle,
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(12),
            bottom: widget.isOpen
                ? Radius.zero : const Radius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _Badge(label: cat, color: widget.catColor),
                      const SizedBox(width: 8),
                      Text(_fmtDate(dateStr),
                        style: const TextStyle(
                          fontSize: 11, color: _gray400)),
                    ]),
                    const SizedBox(height: 8),
                    Text(post['title']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700,
                        color: _navy)),
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(summary,
                        style: const TextStyle(
                          fontSize: 13, color: _gray600)),
                    ],
                  ],
                )),
                const SizedBox(width: 12),
                AnimatedRotation(
                  turns:    widget.isOpen ? 0.25 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: const Icon(Icons.chevron_right,
                    size: 18, color: _gray400),
                ),
              ],
            ),
          ),
        ),

        // Expanded body
        SizeTransition(
          sizeFactor: _expand,
          child: Column(children: [
            const Divider(height: 1, color: _gray100),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Text(body,
                style: const TextStyle(
                  fontSize: 14, color: _gray700,
                  height: 1.7)),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// VETERANS TAB
// ══════════════════════════════════════════════════════════════
class _VeteransTab extends StatelessWidget {
  const _VeteransTab();

  static const _resources = [
    {
      'title':       'Road Ready Program™',
      'description': 'Our certified program built specifically for veterans. Industry-standard training that meets all federal requirements — and gets you negotiating a better starting salary.',
      'icon':        '🚛',
      'color':       _green,
      'link':        null,
    },
    {
      'title':       'DD214 Document Upload',
      'description': 'Upload your DD214 for military service verification during enrollment. This validates your discipline and experience to potential employers.',
      'icon':        '📋',
      'color':       _accent,
      'link':        '/student/documents',
      'linkLabel':   'Go to Documents →',
    },
    {
      'title':       'VA Benefits & Funding',
      'description': 'You may be eligible for VA education benefits to cover your CDL training. Our admissions team will walk you through what you qualify for.',
      'icon':        '🎖️',
      'color':       _gold,
      'link':        null,
    },
    {
      'title':       'Employer Validation Portal',
      'description': 'Future employers can log into our public portal and verify exactly what you learned — no misleading resumes, just facts. 53-footer, mountain driving, all of it.',
      'icon':        '🏢',
      'color':       _navy,
      'link':        null,
    },
    {
      'title':       'Veteran Salary Negotiation',
      'description': 'Students graduating from CST are positioned to negotiate a better starting salary than average. Your military discipline is your advantage — we help you prove it.',
      'icon':        '💰',
      'color':       Color(0xFF059669),
      'link':        null,
    },
    {
      'title':       'Amazon & Box Driver Opportunities',
      'description': 'Not ready for an 18-wheeler? We also train for box driver positions — one of the fastest-growing opportunities nationwide with Amazon and other major carriers.',
      'icon':        '📦',
      'color':       Color(0xFFF59E0B),
      'link':        null,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Hero banner
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_navy, Color(0xFF1a2f52)],
              begin:  Alignment.topLeft,
              end:    Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🎖️', style: TextStyle(fontSize: 48)),
              const SizedBox(width: 16),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SPECIAL SECTION',
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: _gold, letterSpacing: 1.2)),
                  const SizedBox(height: 4),
                  const Text('For Our Veterans',
                    style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800,
                      color: _white)),
                  const SizedBox(height: 8),
                  Text(
                    'Your service doesn\'t end when you take off that uniform — it evolves. CST is built to put veterans back in motion with the tools, training, and career validation you deserve.',
                    style: TextStyle(
                      fontSize: 13, color: _white.withValues(alpha: 0.65),
                      height: 1.5)),
                ],
              )),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Resource cards
        ..._resources.map((r) {
          final color = r['color'] as Color;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  top:    BorderSide(color: color, width: 3),
                  right:  const BorderSide(color: _gray200),
                  bottom: const BorderSide(color: _gray200),
                  left:   const BorderSide(color: _gray200),
                ),
                boxShadow: [BoxShadow(
                  color:      Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6, offset: const Offset(0, 2))],
              ),
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r['icon']?.toString() ?? '',
                    style: const TextStyle(fontSize: 28)),
                  const SizedBox(height: 8),
                  Text(r['title']?.toString() ?? '',
                    style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: _navy)),
                  const SizedBox(height: 6),
                  Text(r['description']?.toString() ?? '',
                    style: const TextStyle(
                      fontSize: 13, color: _gray600, height: 1.5)),
                  if ((r['link']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(r['linkLabel']?.toString() ?? '',
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: color)),
                  ],
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 4),

        // Quote
        Container(
          decoration: BoxDecoration(
            color:        _gold.withValues(alpha: 0.08),
            border:       Border.all(color: _gold.withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('"',
                style: TextStyle(
                  fontSize: 40, color: _gold,
                  height: 0.8, fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "You've served with discipline. Now drive with purpose.",
                    style: TextStyle(
                      fontSize: 15, fontStyle: FontStyle.italic,
                      color: _navy, height: 1.6)),
                  const SizedBox(height: 8),
                  const Text('— California School of Trucking',
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: _gold, letterSpacing: 0.8)),
                ],
              )),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SHARED HELPERS
// ══════════════════════════════════════════════════════════════
Widget _card({required Widget child}) => Container(
  margin: EdgeInsets.zero,
  padding: const EdgeInsets.all(18),
  decoration: BoxDecoration(
    color:        _white,
    borderRadius: BorderRadius.circular(12),
    border:       Border.all(color: _gray200),
    boxShadow:    [BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 6, offset: const Offset(0, 2))],
  ),
  child: child,
);

Widget _emptyState(IconData icon, String message) => Container(
  margin: const EdgeInsets.only(top: 8),
  padding: const EdgeInsets.all(48),
  decoration: BoxDecoration(
    color: _white, borderRadius: BorderRadius.circular(12),
    border: Border.all(color: _gray200)),
  child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 40, color: _gray200),
    const SizedBox(height: 12),
    Text(message,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 14, color: _gray400)),
  ]),
);