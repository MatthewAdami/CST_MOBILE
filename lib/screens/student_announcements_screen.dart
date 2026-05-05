import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:cst_mobile/config/api_config.dart'; // ← add this import

// ── Constants ─────────────────────────────────────────────────────────────────
const kNavy   = Color(0xFF0B1F3A);
const kGold   = Color(0xFFC9A84C);
const kPurple = Color(0xFF7C3AED);

// ── Type config ───────────────────────────────────────────────────────────────
class TypeConfig {
  final String label;
  final Color  color;
  final Color  bg;
  final IconData icon;
  const TypeConfig({ required this.label, required this.color, required this.bg, required this.icon });
}

const Map<String, TypeConfig> kTypeConfig = {
  'general':  TypeConfig(label: 'General',  color: Color(0xFF6C757D), bg: Color(0xFFF8F9FA), icon: Icons.notifications_outlined),
  'urgent':   TypeConfig(label: 'Urgent',   color: Color(0xFFDC3545), bg: Color(0xFFFFF5F5), icon: Icons.warning_amber_rounded),
  'schedule': TypeConfig(label: 'Schedule', color: Color(0xFF0D6EFD), bg: Color(0xFFEFF6FF), icon: Icons.calendar_today_outlined),
  'holiday':  TypeConfig(label: 'Holiday',  color: Color(0xFF16A34A), bg: Color(0xFFF0FDF4), icon: Icons.event_outlined),
  'course':   TypeConfig(label: 'Course',   color: Color(0xFF7C3AED), bg: Color(0xFFF5F3FF), icon: Icons.menu_book_outlined),
  'payment':  TypeConfig(label: 'Payment',  color: Color(0xFFD97706), bg: Color(0xFFFFFBEB), icon: Icons.attach_money),
  'reminder': TypeConfig(label: 'Reminder', color: Color(0xFF0891B2), bg: Color(0xFFECFEFF), icon: Icons.access_time_outlined),
};

TypeConfig typeConfigFor(String? type) =>
    kTypeConfig[type] ?? kTypeConfig['general']!;

// ── Model ─────────────────────────────────────────────────────────────────────
class Announcement {
  final String  id;
  final String  title;
  final String  body;
  final String  type;
  final String  priority;
  final bool    pinned;
  bool          isRead;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.priority,
    required this.pinned,
    required this.isRead,
    this.createdAt,
    this.expiresAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
    id:       j['_id']     ?? '',
    title:    j['title']   ?? '',
    body:     j['body']    ?? '',
    type:     j['type']    ?? 'general',
    priority: j['priority'] ?? 'normal',
    pinned:   j['pinned']  ?? false,
    isRead:   j['isRead']  ?? false,
    createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt']) : null,
    expiresAt: j['expiresAt'] != null ? DateTime.tryParse(j['expiresAt']) : null,
  );
}

// ── Relative time helper ──────────────────────────────────────────────────────
String relativeTime(DateTime? dt) {
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60)  return 'Just now';
  if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
  if (diff.inHours < 24)    return '${diff.inHours}h ago';
  if (diff.inDays < 7)      return '${diff.inDays}d ago';
  return DateFormat('MMM d, yyyy').format(dt);
}

// ── API service ───────────────────────────────────────────────────────────────
class AnnouncementsService {
  final String token;
  AnnouncementsService(this.token);

  Map<String, String> get _headers => ApiConfig.authHeaders(token);

  Future<List<Announcement>> fetchAll() async {
    final res = await http
        .get(Uri.parse(ApiConfig.announcements), headers: _headers)
        .timeout(ApiConfig.timeout);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Announcement.fromJson(e)).toList();
    }
    throw Exception('Failed to load announcements: ${res.statusCode}');
  }

  Future<void> markRead(String id) async {
    await http
        .patch(Uri.parse(ApiConfig.announcementRead(id)), headers: _headers)
        .timeout(ApiConfig.timeout);
  }

  Future<void> markAllRead() async {
    await http
        .patch(Uri.parse(ApiConfig.announcementsReadAll), headers: _headers)
        .timeout(ApiConfig.timeout);
  }
}
// ── Main Screen ───────────────────────────────────────────────────────────────
class StudentAnnouncementsScreen extends StatefulWidget {
  final String authToken;
  const StudentAnnouncementsScreen({ super.key, required this.authToken });

  @override
  State<StudentAnnouncementsScreen> createState() => _StudentAnnouncementsScreenState();
}

class _StudentAnnouncementsScreenState extends State<StudentAnnouncementsScreen> {
  late final AnnouncementsService _svc;
  List<Announcement> _all    = [];
  bool   _loading = true;
  String _search  = '';
  String _filter  = 'all'; // all | unread | pinned

  @override
  void initState() {
    super.initState();
    _svc = AnnouncementsService(widget.authToken);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _svc.fetchAll();
      setState(() => _all = list);
    } catch (e) {
      debugPrint('Error loading announcements: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _svc.markAllRead();
      setState(() {
        for (final a in _all) { a.isRead = true; }
      });
    } catch (e) { debugPrint(e.toString()); }
  }

  void _handleRead(String id) {
    setState(() {
      final idx = _all.indexWhere((a) => a.id == id);
      if (idx != -1) _all[idx].isRead = true;
    });
  }

  int get _unreadCount => _all.where((a) => !a.isRead).length;

  List<Announcement> get _filtered {
    final q = _search.toLowerCase();
    return _all.where((a) {
      final matchSearch = q.isEmpty ||
          a.title.toLowerCase().contains(q) ||
          a.body.toLowerCase().contains(q);
      final matchFilter = _filter == 'all'    ? true
          : _filter == 'unread' ? !a.isRead
          : _filter == 'pinned' ? a.pinned
          : true;
      return matchSearch && matchFilter;
    }).toList()
      ..sort((a, b) {
        if (a.pinned && !b.pinned) return -1;
        if (!a.pinned && b.pinned) return 1;
        return (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: kPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kPurple.withOpacity(0.25)),
              ),
              child: const Icon(Icons.campaign_outlined, color: kPurple, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Announcements', style: TextStyle(
                  fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.w800,
                  color: kNavy,
                )),
                Text(
                  _unreadCount > 0
                      ? '$_unreadCount unread announcement${_unreadCount > 1 ? 's' : ''}'
                      : "You're all caught up!",
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6C757D),
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: TextButton.icon(
                onPressed: _markAllRead,
                icon: const Icon(Icons.done_all, size: 14, color: kPurple),
                label: const Text('Mark all read', style: TextStyle(
                  color: kPurple, fontSize: 12, fontWeight: FontWeight.w700,
                )),
                style: TextButton.styleFrom(
                  backgroundColor: kPurple.withOpacity(0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: kPurple.withOpacity(0.3)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE9ECEF)),
        ),
      ),
      body: RefreshIndicator(
        color: kPurple,
        onRefresh: _load,
        child: Column(
          children: [
            // ── Filter bar ──────────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: [
                  // Search
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFDEE2E6)),
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Search announcements…',
                        hintStyle: TextStyle(color: Color(0xFFADB5BD), fontSize: 13),
                        prefixIcon: Icon(Icons.search, color: Color(0xFFADB5BD), size: 18),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 11),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Filter chips
                  Row(
                    children: [
                      _FilterChip(label: 'All',    value: 'all',    current: _filter, onTap: (v) => setState(() => _filter = v)),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: _unreadCount > 0 ? 'Unread ($_unreadCount)' : 'Unread',
                        value: 'unread', current: _filter,
                        onTap: (v) => setState(() => _filter = v),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(label: '📌 Pinned', value: 'pinned', current: _filter, onTap: (v) => setState(() => _filter = v)),
                    ],
                  ),
                ],
              ),
            ),
            Container(height: 1, color: const Color(0xFFE9ECEF)),

            // ── List ────────────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: kPurple))
                  : _filtered.isEmpty
                      ? _EmptyState(filter: _filter)
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) => AnnouncementCard(
                            ann: _filtered[i],
                            onRead: _handleRead,
                            service: _svc,
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label, value, current;
  final void Function(String) onTap;
  const _FilterChip({ required this.label, required this.value, required this.current, required this.onTap });

  @override
  Widget build(BuildContext context) {
    final selected = value == current;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? kPurple : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? kPurple : const Color(0xFFDEE2E6)),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? Colors.white : const Color(0xFF6C757D),
          fontSize: 12, fontWeight: FontWeight.w600,
        )),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String filter;
  const _EmptyState({ required this.filter });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.campaign_outlined, size: 48, color: Color(0xFFADB5BD)),
          const SizedBox(height: 12),
          Text(
            filter == 'unread' ? 'No unread announcements' : 'No announcements yet',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                color: Color(0xFF6C757D)),
          ),
          const SizedBox(height: 6),
          const Text('Check back later for updates from your school',
              style: TextStyle(fontSize: 13, color: Color(0xFFADB5BD))),
        ],
      ),
    );
  }
}

// ── Announcement Card ─────────────────────────────────────────────────────────
class AnnouncementCard extends StatefulWidget {
  final Announcement       ann;
  final void Function(String) onRead;
  final AnnouncementsService  service;

  const AnnouncementCard({
    super.key,
    required this.ann,
    required this.onRead,
    required this.service,
  });

  @override
  State<AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends State<AnnouncementCard> {
  bool _expanded = false;
  static const int _truncateAt = 180;

  bool get _isLong => widget.ann.body.length > _truncateAt;

  Future<void> _handleExpand() async {
    setState(() => _expanded = !_expanded);
    if (!widget.ann.isRead && !_expanded) {
      try {
        await widget.service.markRead(widget.ann.id);
        widget.onRead(widget.ann.id);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final ann = widget.ann;
    final cfg = typeConfigFor(ann.type);
    final isCritical = ann.priority == 'critical';
    final isHigh     = ann.priority == 'high';

    final borderColor = ann.pinned
        ? kGold.withOpacity(0.4)
        : isCritical
            ? const Color(0xFFFECACA)
            : ann.isRead
                ? const Color(0xFFE9ECEF)
                : kPurple.withOpacity(0.2);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: ann.pinned
                ? kGold.withOpacity(0.10)
                : ann.isRead
                    ? Colors.black.withOpacity(0.03)
                    : kPurple.withOpacity(0.07),
            blurRadius: ann.pinned ? 20 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            // Priority stripe
            if (isCritical || isHigh || ann.pinned)
              Container(
                height: 3,
                color: isCritical
                    ? const Color(0xFFDC3545)
                    : isHigh
                        ? const Color(0xFFD97706)
                        : kGold,
              ),

            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type icon
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: cfg.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cfg.color.withOpacity(0.2)),
                    ),
                    child: Icon(cfg.icon, color: cfg.color, size: 16),
                  ),
                  const SizedBox(width: 14),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tags row
                        Wrap(
                          spacing: 6, runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (ann.pinned)
                              _Tag(label: '📌 PINNED', color: kGold, bg: kGold.withOpacity(0.12)),
                            _Tag(label: cfg.label, color: cfg.color, bg: cfg.bg),
                            if (!ann.isRead)
                              Container(
                                width: 7, height: 7,
                                decoration: BoxDecoration(
                                  color: kPurple,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: kPurple.withOpacity(0.3), blurRadius: 4)],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Title
                        Text(ann.title, style: TextStyle(
                          fontSize: 15,
                          fontWeight: ann.isRead ? FontWeight.w600 : FontWeight.w800,
                          color: ann.isRead ? const Color(0xFF495057) : kNavy,
                          fontFamily: 'Georgia',
                          height: 1.3,
                        )),
                        const SizedBox(height: 6),

                        // Body
                        Text(
                          _expanded || !_isLong
                              ? ann.body
                              : '${ann.body.substring(0, _truncateAt)}…',
                          style: const TextStyle(
                            fontSize: 13, color: Color(0xFF6C757D), height: 1.65,
                          ),
                        ),

                        // Read more
                        if (_isLong) ...[
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: _handleExpand,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _expanded ? Icons.expand_less : Icons.expand_more,
                                  size: 14, color: kPurple,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  _expanded ? 'Show less' : 'Read more',
                                  style: const TextStyle(
                                    color: kPurple, fontSize: 12, fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 10),

                        // Meta row
                        Wrap(
                          spacing: 8, runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(relativeTime(ann.createdAt),
                                style: const TextStyle(fontSize: 11, color: Color(0xFFADB5BD))),
                            if (ann.expiresAt != null)
                              Text('· Expires ${DateFormat('MMM d').format(ann.expiresAt!)}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFFADB5BD))),
                            if (ann.isRead)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.done_all, size: 11, color: Color(0xFF16A34A)),
                                  SizedBox(width: 3),
                                  Text('Read', style: TextStyle(fontSize: 11, color: Color(0xFF16A34A))),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tag widget ────────────────────────────────────────────────────────────────
class _Tag extends StatelessWidget {
  final String label;
  final Color  color, bg;
  const _Tag({ required this.label, required this.color, required this.bg });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(
        fontSize: 9, fontWeight: FontWeight.w800, color: color,
        letterSpacing: 0.3,
      )),
    );
  }
}