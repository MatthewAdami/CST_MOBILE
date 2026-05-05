import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cst_mobile/config/api_config.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _navy    = Color(0xFF0B1F3A);
const _accent  = Color(0xFF7C3AED);
const _aiCol   = Color(0xFF0EA5E9);
const _green   = Color(0xFF10B981);
const _red     = Color(0xFFEF4444);
const _amber   = Color(0xFFF59E0B);
const _blue    = Color(0xFF3B82F6);
const _white   = Color(0xFFFFFFFF);
const _gray50  = Color(0xFFF9FAFB);
const _gray100 = Color(0xFFF3F4F6);
const _gray200 = Color(0xFFE9ECEF);
const _gray400 = Color(0xFF9CA3AF);
const _gray600 = Color(0xFF6B7280);
const _gray800 = Color(0xFF374151);

// ── Urgency detection ─────────────────────────────────────────────────────────
const _urgencyKw = [
  'urgent','emergency','asap','immediately','critical',
  'broken','down','error','not working',
];
bool _isUrgentText(String t) {
  final l = t.toLowerCase();
  return _urgencyKw.any((k) => l.contains(k));
}

// ── Category config ───────────────────────────────────────────────────────────
class _Cat {
  final String label; final Color color, bg;
  const _Cat(this.label, this.color, this.bg);
}
const _cats = [
  _Cat('Technical Issue', Color(0xFFEF4444), Color(0xFFFEF2F2)),
  _Cat('Billing',         Color(0xFFF59E0B), Color(0xFFFFFBEB)),
  _Cat('Enrollment',      Color(0xFF3B82F6), Color(0xFFEFF6FF)),
  _Cat('Schedule',        Color(0xFF8B5CF6), Color(0xFFF5F3FF)),
  _Cat('General Inquiry', Color(0xFF6B7280), Color(0xFFF9FAFB)),
];
_Cat _catFor(String l) =>
    _cats.firstWhere((c) => c.label == l, orElse: () => _cats.last);

// ── FAQs ──────────────────────────────────────────────────────────────────────
const _faqs = [
  ('How do I check my training schedule?',
   'Go to Schedule in your sidebar to view all upcoming sessions and your assigned instructor.'),
  ('How do I view my progress?',
   'Click "My Progress" in the sidebar to see your completed hours, skills, and range performance.'),
  ('How do I get my enrollment documents?',
   'Visit the Documents section to download your enrollment agreement and other files.'),
  ('How do I pay my tuition balance?',
   'Go to Finances to view your balance and payment history, or contact the billing team.'),
  ('How do I contact my instructor?',
   'Use the Messages section to send a direct message to your assigned instructor.'),
];

// ── AI Suggestions ────────────────────────────────────────────────────────────
const _aiSuggestions = [
  "I can't log in to the portal",
  'How do I check my training schedule?',
  'Where can I find my enrollment documents?',
  'How do I view my tuition balance?',
  'What happens if I miss a session?',
  'How do I contact my instructor?',
  'When will I receive my certificate?',
  'How do I check my completion status?',
];

// ── Models ────────────────────────────────────────────────────────────────────
class ChatMsg {
  final String id, from, text;
  final bool urgent;
  final DateTime time;
  ChatMsg({required this.id, required this.from, required this.text,
    required this.urgent, required this.time});
  bool get isMe => from == 'student' || from == 'user';
  factory ChatMsg.fromJson(Map<String, dynamic> j) => ChatMsg(
    id: j['_id'] ?? UniqueKey().toString(), from: j['from'] ?? 'admin',
    text: j['text'] ?? '', urgent: j['urgent'] == true,
    time: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now());
  factory ChatMsg.welcome() => ChatMsg(
    id: 'w', from: 'admin',
    text: 'Hi! How can we help you today?',
    urgent: false, time: DateTime.now());
}

class AiMsg {
  final String role, text;
  final DateTime time;
  AiMsg({required this.role, required this.text, required this.time});
  bool get isUser => role == 'user';
}

class SupportTicket {
  final String id, subject, category, status;
  final bool urgent;
  final DateTime createdAt;
  SupportTicket({required this.id, required this.subject,
    required this.category, required this.status,
    required this.urgent, required this.createdAt});
  factory SupportTicket.fromJson(Map<String, dynamic> j) => SupportTicket(
    id: j['_id'] ?? '', subject: j['subject'] ?? '',
    category: j['category'] ?? '', status: j['status'] ?? 'open',
    urgent: j['urgent'] == true,
    createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now());
}

// ── API ───────────────────────────────────────────────────────────────────────
class _Api {
  final String token, userId, userName;
  _Api({required this.token, required this.userId, required this.userName});
  Map<String, String> get _h =>
      {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  String get _b => '${ApiConfig.baseUrl}/api/support';
  String get _ai => '${ApiConfig.baseUrl}/api/ai';

  Future<List<ChatMsg>> fetchMessages() async {
    try {
      final r = await http.get(
          Uri.parse('$_b/messages?userId=${Uri.encodeComponent(userId)}'),
          headers: _h).timeout(ApiConfig.timeout);
      if (r.statusCode == 200) {
        final List d = jsonDecode(r.body);
        return d.isEmpty ? [ChatMsg.welcome()] : d.map((e) => ChatMsg.fromJson(e)).toList();
      }
    } catch (_) {}
    return [ChatMsg.welcome()];
  }

  Future<ChatMsg?> sendMessage(String text, bool urgent) async {
    try {
      final r = await http.post(Uri.parse('$_b/messages'), headers: _h,
        body: jsonEncode({'from': 'student', 'text': text, 'urgent': urgent,
          'userId': userId, 'userName': userName, 'userRole': 'student'}))
          .timeout(ApiConfig.timeout);
      if (r.statusCode == 200 || r.statusCode == 201)
        return ChatMsg.fromJson(jsonDecode(r.body));
    } catch (_) {}
    return null;
  }

  Future<List<SupportTicket>> fetchTickets() async {
    try {
      final r = await http.get(
          Uri.parse('$_b/tickets?userId=${Uri.encodeComponent(userId)}'),
          headers: _h).timeout(ApiConfig.timeout);
      if (r.statusCode == 200) {
        final List d = jsonDecode(r.body);
        return d.map((e) => SupportTicket.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<SupportTicket?> submitTicket(
      {required String subject, required String category,
       required String detail,  required bool urgent}) async {
    try {
      final r = await http.post(Uri.parse('$_b/tickets'), headers: _h,
        body: jsonEncode({'subject': subject, 'category': category,
          'detail': detail, 'urgent': urgent,
          'createdBy': userId, 'createdByName': userName, 'createdByRole': 'student'}))
          .timeout(ApiConfig.timeout);
      if (r.statusCode == 200 || r.statusCode == 201)
        return SupportTicket.fromJson(jsonDecode(r.body));
    } catch (_) {}
    return null;
  }

  // ── AI endpoints ──────────────────────────────────────────────────────────
  Future<List<AiMsg>> fetchAiHistory() async {
    try {
      final r = await http.get(
          Uri.parse('$_ai/history?type=support'),
          headers: _h).timeout(ApiConfig.timeout);
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        final List msgs = data['messages'] ?? [];
        return msgs.map((m) => AiMsg(
          role: m['role'] ?? 'assistant',
          text: m['content'] ?? '',
          time: DateTime.now(),
        )).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<String?> sendAiMessage(String message) async {
    try {
      final r = await http.post(Uri.parse('$_ai/chat'), headers: _h,
        body: jsonEncode({'message': message}))
          .timeout(const Duration(seconds: 30));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        return data['reply'] as String?;
      }
    } catch (_) {}
    return null;
  }

  Future<void> clearAiHistory() async {
    try {
      await http.delete(
          Uri.parse('$_ai/history?type=support'),
          headers: _h).timeout(ApiConfig.timeout);
    } catch (_) {}
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
String _relTime(DateTime dt) {
  final d = DateTime.now().difference(dt);
  if (d.inSeconds < 60)  return 'Just now';
  if (d.inMinutes < 60)  return '${d.inMinutes}m ago';
  if (d.inHours < 24)    return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}
String _fmtTime(DateTime dt) {
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m ${dt.hour >= 12 ? "PM" : "AM"}';
}

// ══════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class StudentSupportScreen extends StatefulWidget {
  final String authToken, firstName, lastName;
  const StudentSupportScreen({
    super.key,
    required this.authToken,
    required this.firstName,
    required this.lastName,
  });

  @override
  State<StudentSupportScreen> createState() => _StudentSupportScreenState();
}

class _StudentSupportScreenState extends State<StudentSupportScreen> {
  // 0=Home 1=Live Chat 2=AI Support 3=Ticket 4=History
  int _tab = 0;

  List<ChatMsg>       _messages    = [];
  List<SupportTicket> _tickets     = [];
  List<AiMsg>         _aiMessages  = [];

  final _draftCtrl   = TextEditingController();
  final _aiDraftCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _detailCtrl  = TextEditingController();
  final _scrollCtrl  = ScrollController();
  final _aiScrollCtrl = ScrollController();

  bool   _isUrgent       = false;
  bool   _flaggedUrgent  = false;
  bool   _sending        = false;
  bool   _aiLoading      = false;
  bool   _aiFetching     = true;
  bool   _aiClearing     = false;
  bool   _showSuggestions = true;
  String _selCat         = '';
  bool   _ticketUrgent   = false;
  bool   _submitting     = false;
  bool   _submitted      = false;

  late final _Api _api;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _api = _Api(
      token:    widget.authToken,
      userId:   '${widget.firstName} ${widget.lastName}'.trim(),
      userName: '${widget.firstName} ${widget.lastName}'.trim(),
    );
    _init();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_tab == 1) _fetchMessages();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _draftCtrl.dispose();
    _aiDraftCtrl.dispose();
    _subjectCtrl.dispose();
    _detailCtrl.dispose();
    _scrollCtrl.dispose();
    _aiScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await Future.wait([_fetchMessages(), _fetchTickets(), _loadAiHistory()]);
  }

  Future<void> _fetchMessages() async {
    final msgs = await _api.fetchMessages();
    if (!mounted) return;
    setState(() => _messages = msgs);
    _scrollBottom(_scrollCtrl);
  }

  Future<void> _fetchTickets() async {
    final t = await _api.fetchTickets();
    if (!mounted) return;
    setState(() => _tickets = t);
  }

  Future<void> _loadAiHistory() async {
    setState(() => _aiFetching = true);
    final history = await _api.fetchAiHistory();
    if (!mounted) return;
    if (history.isNotEmpty) {
      setState(() { _aiMessages = history; _showSuggestions = false; _aiFetching = false; });
    } else {
      setState(() {
        _aiMessages = [AiMsg(
          role: 'assistant',
          text: 'Hi ${widget.firstName}! 👋 I\'m your CST Support Assistant. I can help you with questions about your schedule, enrollment, billing, portal access, and more. What can I help you with today?',
          time: DateTime.now(),
        )];
        _showSuggestions = true;
        _aiFetching = false;
      });
    }
    _scrollBottom(_aiScrollCtrl);
  }

  void _scrollBottom(ScrollController ctrl) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ctrl.hasClients) {
        ctrl.animateTo(ctrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _draftCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    final urgent = _isUrgentText(text);
    _draftCtrl.clear();
    setState(() {
      _sending = true; _isUrgent = false;
      if (urgent) _flaggedUrgent = true;
      _messages.add(ChatMsg(
        id: DateTime.now().toString(), from: 'student',
        text: text, urgent: urgent, time: DateTime.now()));
    });
    _scrollBottom(_scrollCtrl);
    await _api.sendMessage(text, urgent);
    if (!mounted) return;
    setState(() => _sending = false);
    _fetchMessages();
  }

  Future<void> _sendAi([String? quickText]) async {
    final text = (quickText ?? _aiDraftCtrl.text).trim();
    if (text.isEmpty || _aiLoading) return;
    _aiDraftCtrl.clear();
    setState(() {
      _aiLoading = true;
      _showSuggestions = false;
      _aiMessages.add(AiMsg(role: 'user', text: text, time: DateTime.now()));
    });
    _scrollBottom(_aiScrollCtrl);

    final reply = await _api.sendAiMessage(text);
    if (!mounted) return;
    setState(() {
      _aiLoading = false;
      _aiMessages.add(AiMsg(
        role: 'assistant',
        text: reply ?? 'Sorry, I could not generate a response. Please try again.',
        time: DateTime.now(),
      ));
    });
    _scrollBottom(_aiScrollCtrl);
  }

  Future<void> _clearAiHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Conversation'),
        content: const Text('This will delete your entire AI chat history. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: _red))),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _aiClearing = true);
    await _api.clearAiHistory();
    if (!mounted) return;
    setState(() {
      _aiClearing = false;
      _aiMessages = [AiMsg(
        role: 'assistant',
        text: 'Conversation cleared. How can I help you today?',
        time: DateTime.now(),
      )];
      _showSuggestions = true;
    });
  }

  Future<void> _submitTicket() async {
    if (_subjectCtrl.text.trim().isEmpty || _selCat.isEmpty) return;
    setState(() => _submitting = true);
    final t = await _api.submitTicket(
      subject:  _subjectCtrl.text.trim(),
      category: _selCat,
      detail:   _detailCtrl.text.trim(),
      urgent:   _ticketUrgent,
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (t != null) { _tickets.insert(0, t); _submitted = true; }
    });
  }

  void _resetTicket() {
    _subjectCtrl.clear(); _detailCtrl.clear();
    setState(() { _selCat = ''; _ticketUrgent = false; _submitted = false; });
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _appBar() {
    final titles = ['Help Center', 'Live Chat', 'AI Support', 'Submit Ticket', 'My Tickets'];
    return AppBar(
      backgroundColor: _tab == 2 ? const Color(0xFF0284C7) : _navy,
      foregroundColor: _white,
      elevation: 0,
      title: Row(mainAxisSize: MainAxisSize.min, children: [
        if (_tab == 2) ...[
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_aiCol, Color(0xFF6366F1)]),
              shape: BoxShape.circle),
            child: const Icon(Icons.smart_toy_outlined, size: 15, color: _white)),
          const SizedBox(width: 8),
        ],
        Text(titles[_tab], style: const TextStyle(
          fontSize: 17, fontWeight: FontWeight.w800, color: _white)),
        if (_tab == 2) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10)),
            child: const Text('AI', style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w800, color: _white,
              letterSpacing: 0.5))),
        ],
      ]),
      actions: [
        if (_tab == 1 && _flaggedUrgent)
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _red.withOpacity(0.5))),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.warning_amber_rounded, size: 13, color: _red),
              SizedBox(width: 4),
              Text('Urgent', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: _red)),
            ]),
          ),
        if (_tab == 2)
          _aiClearing
              ? const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _white)))
              : IconButton(
                  icon: const Icon(Icons.delete_outline, color: _white, size: 20),
                  tooltip: 'Clear history',
                  onPressed: _clearAiHistory),
        if (_tab == 4)
          IconButton(
            icon: const Icon(Icons.add, color: _white),
            onPressed: () => setState(() { _tab = 3; _resetTicket(); })),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _gray100,
      appBar: _appBar(),
      body: IndexedStack(
        index: _tab,
        children: [
          // 0 — Help Center
          _HomeTab(
            firstName: widget.firstName,
            onGoChat:    () => setState(() => _tab = 1),
            onGoAi:      () => setState(() => _tab = 2),
            onGoTicket:  () => setState(() => _tab = 3),
            onGoHistory: () => setState(() => _tab = 4)),

          // 1 — Live Chat
          _ChatTab(
            messages: _messages, draftCtrl: _draftCtrl,
            isUrgent: _isUrgent, sending: _sending,
            scrollCtrl: _scrollCtrl,
            firstName: widget.firstName, lastName: widget.lastName,
            onChanged: (v) => setState(() => _isUrgent = _isUrgentText(v)),
            onSend: _send),

          // 2 — AI Support
          _AiChatTab(
            messages:       _aiMessages,
            draftCtrl:      _aiDraftCtrl,
            loading:        _aiLoading,
            fetching:       _aiFetching,
            showSuggestions: _showSuggestions,
            scrollCtrl:     _aiScrollCtrl,
            firstName:      widget.firstName,
            lastName:       widget.lastName,
            onChanged:      (_) => setState(() {}),
            onSend:         _sendAi,
            onSuggestion:   (s) => _sendAi(s),
          ),

          // 3 — Submit Ticket
          _TicketTab(
            subjectCtrl: _subjectCtrl, detailCtrl: _detailCtrl,
            selCat: _selCat, urgent: _ticketUrgent,
            submitting: _submitting, submitted: _submitted,
            onCat: (c) => setState(() => _selCat = c),
            onUrgent: (v) => setState(() => _ticketUrgent = v),
            onSubmit: _submitTicket,
            onViewTickets: () { _resetTicket(); setState(() => _tab = 4); }),

          // 4 — My Tickets
          _HistoryTab(
            tickets: _tickets,
            onNew: () => setState(() { _tab = 3; _resetTicket(); })),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: _white,
        indicatorColor: _tab == 2 ? _aiCol.withOpacity(0.15) : _accent.withOpacity(0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.help_outline),
            selectedIcon: Icon(Icons.help, color: _accent),
            label: 'Help'),
          const NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble, color: _accent),
            label: 'Live Chat'),
          NavigationDestination(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _aiCol.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _aiCol.withOpacity(0.3))),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.smart_toy_outlined, size: 16, color: _aiCol),
                SizedBox(width: 3),
                Text('AI', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _aiCol)),
              ])),
            selectedIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _aiCol.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.smart_toy, size: 16, color: _aiCol),
                SizedBox(width: 3),
                Text('AI', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _aiCol)),
              ])),
            label: 'AI Support'),
          const NavigationDestination(
            icon: Icon(Icons.mail_outline),
            selectedIcon: Icon(Icons.mail, color: _accent),
            label: 'Ticket'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _tickets.isNotEmpty,
              label: Text('${_tickets.length}'),
              child: const Icon(Icons.inbox_outlined)),
            selectedIcon: const Icon(Icons.inbox, color: _accent),
            label: 'History'),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — HELP CENTER
// ══════════════════════════════════════════════════════════════════════════════
class _HomeTab extends StatefulWidget {
  final String firstName;
  final VoidCallback onGoChat, onGoAi, onGoTicket, onGoHistory;
  const _HomeTab({required this.firstName,
    required this.onGoChat, required this.onGoAi,
    required this.onGoTicket, required this.onGoHistory});
  @override State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  int? _openFaq;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Hero
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_navy, Color(0xFF1A3A6B)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.help_outline, color: _accent, size: 28),
            const SizedBox(height: 10),
            Text('Hi ${widget.firstName}, how can we help?',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _white)),
            const SizedBox(height: 6),
            const Text('Chat with our support team or get instant AI help.',
              style: TextStyle(fontSize: 13, color: Colors.white60, height: 1.4)),
            const SizedBox(height: 18),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _HeroBtn(label: 'Live Chat',   icon: Icons.headset_mic_outlined, onTap: widget.onGoChat),
              _HeroBtn(label: 'AI Support',  icon: Icons.smart_toy_outlined,   onTap: widget.onGoAi,    isAi: true),
              _HeroBtn(label: 'Submit Ticket', icon: Icons.mail_outline,       onTap: widget.onGoTicket),
            ]),
          ]),
        ),
        const SizedBox(height: 14),

        // AI Support promo card
        GestureDetector(
          onTap: widget.onGoAi,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_aiCol.withOpacity(0.08), const Color(0xFF6366F1).withOpacity(0.06)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _aiCol.withOpacity(0.25))),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_aiCol, Color(0xFF6366F1)]),
                  shape: BoxShape.circle),
                child: const Icon(Icons.smart_toy_outlined, color: _white, size: 22)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Text('AI Support Assistant', style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _aiCol.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                    child: const Text('24/7', style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w800, color: _aiCol))),
                ]),
                const SizedBox(height: 3),
                const Text('Instant answers — no waiting required.',
                  style: TextStyle(fontSize: 12, color: _gray600, height: 1.3)),
              ])),
              const Icon(Icons.arrow_forward_ios, size: 14, color: _gray400),
            ]),
          ),
        ),
        const SizedBox(height: 14),

        // Contact cards
        Row(children: [
          _ContactCard(icon: Icons.phone_outlined, color: _blue,
            label: 'Call Us', val: '(02) 8123-4567', sub: 'Mon–Fri 8am–6pm'),
          const SizedBox(width: 10),
          _ContactCard(icon: Icons.mail_outline, color: _green,
            label: 'Email', val: 'support@cst.edu', sub: 'Within 24hrs'),
        ]),
        const SizedBox(height: 16),

        // FAQ
        Container(
          decoration: BoxDecoration(
            color: _white, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _gray200),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
          child: Column(children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(children: [
                Icon(Icons.quiz_outlined, color: _accent, size: 16),
                SizedBox(width: 8),
                Text('Frequently Asked Questions', style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
              ]),
            ),
            const Divider(height: 1, color: _gray100),
            ..._faqs.asMap().entries.map((e) {
              final i = e.key; final faq = e.value;
              final open = _openFaq == i;
              return Column(children: [
                GestureDetector(
                  onTap: () => setState(() => _openFaq = open ? null : i),
                  child: Container(
                    color: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    child: Row(children: [
                      Expanded(child: Text(faq.$1, style: TextStyle(
                        fontSize: 13,
                        fontWeight: open ? FontWeight.w700 : FontWeight.w600,
                        color: open ? _navy : _gray800, height: 1.3))),
                      AnimatedRotation(
                        turns: open ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.expand_more,
                          color: open ? _navy : _gray400, size: 18)),
                    ]),
                  ),
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    color: _gray50,
                    child: Text(faq.$2, style: const TextStyle(
                      fontSize: 12, color: _gray600, height: 1.6))),
                  crossFadeState: open
                      ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200)),
                if (i < _faqs.length - 1) const Divider(height: 1, color: _gray100),
              ]);
            }),
          ]),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _HeroBtn extends StatelessWidget {
  final String label; final IconData icon; final VoidCallback onTap;
  final bool isAi;
  const _HeroBtn({required this.label, required this.icon,
    required this.onTap, this.isAi = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: isAi ? _aiCol.withOpacity(0.25) : Colors.white.withOpacity(0.12),
        border: Border.all(color: isAi ? _aiCol.withOpacity(0.6) : Colors.white.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: _white),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: _white)),
      ]),
    ),
  );
}

class _ContactCard extends StatelessWidget {
  final IconData icon; final Color color;
  final String label, val, sub;
  const _ContactCard({required this.icon, required this.color,
    required this.label, required this.val, required this.sub});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gray200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
      child: Row(children: [
        Container(width: 32, height: 32,
          decoration: BoxDecoration(color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 15)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 9, color: _gray400, fontWeight: FontWeight.w600)),
          Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _navy),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(sub, style: const TextStyle(fontSize: 10, color: _gray600)),
        ])),
      ]),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — LIVE CHAT
// ══════════════════════════════════════════════════════════════════════════════
class _ChatTab extends StatelessWidget {
  final List<ChatMsg> messages;
  final TextEditingController draftCtrl;
  final bool isUrgent, sending;
  final ScrollController scrollCtrl;
  final String firstName, lastName;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  const _ChatTab({
    required this.messages, required this.draftCtrl,
    required this.isUrgent, required this.sending,
    required this.scrollCtrl, required this.firstName,
    required this.lastName, required this.onChanged, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: _white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Container(width: 36, height: 36,
            decoration: const BoxDecoration(color: _accent, shape: BoxShape.circle),
            child: const Center(child: Text('CS', style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w800, color: _white)))),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('CST Support Team', style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
            Row(children: [
              Container(width: 6, height: 6,
                decoration: const BoxDecoration(color: _green, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              const Text('Online', style: TextStyle(
                fontSize: 11, color: _green, fontWeight: FontWeight.w600)),
            ]),
          ]),
          const Spacer(),
          const Icon(Icons.headset_mic_outlined, color: _gray400, size: 20),
        ]),
      ),
      Container(height: 1, color: _gray200),
      Expanded(
        child: Container(
          color: _gray50,
          child: messages.isEmpty
              ? const Center(child: Text('No messages yet.',
                  style: TextStyle(color: _gray400)))
              : ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg = messages[i];
                    final initials = msg.isMe
                        ? '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
                        : 'CS';
                    return _Bubble(msg: msg, initials: initials,
                      name: msg.isMe ? '$firstName $lastName' : 'CST Support');
                  }),
        ),
      ),
      Container(
        color: _white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        child: Row(children: [
          const Icon(Icons.info_outline, size: 11, color: _gray400),
          const SizedBox(width: 5),
          const Expanded(child: Text(
            'Keywords like "broken" or "emergency" auto-flag urgent.',
            style: TextStyle(fontSize: 10, color: _gray400))),
        ]),
      ),
      Container(
        color: _white,
        padding: EdgeInsets.only(
          left: 12, right: 12, top: 10,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12),
        child: Row(children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: _gray50, borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isUrgent ? _red : _gray200, width: isUrgent ? 1.5 : 1)),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: draftCtrl, onChanged: onChanged,
                    onSubmitted: (_) => onSend(),
                    style: const TextStyle(fontSize: 14, color: _navy),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(fontSize: 14, color: _gray400),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                  ),
                ),
                if (isUrgent) const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.warning_amber_rounded, size: 14, color: _red)),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: sending ? _gray400 : _accent, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: _accent.withOpacity(0.3),
                  blurRadius: 8, offset: const Offset(0, 3))]),
              child: sending
                  ? const Padding(padding: EdgeInsets.all(11),
                      child: CircularProgressIndicator(strokeWidth: 2, color: _white))
                  : const Icon(Icons.send_rounded, color: _white, size: 18)),
          ),
        ]),
      ),
    ]);
  }
}

class _Bubble extends StatelessWidget {
  final ChatMsg msg; final String initials, name;
  const _Bubble({required this.msg, required this.initials, required this.name});

  @override
  Widget build(BuildContext context) {
    final isMe = msg.isMe;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: isMe ? [
              Text(name, style: const TextStyle(fontSize: 11, color: _gray600, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Container(width: 24, height: 24,
                decoration: BoxDecoration(color: _accent.withOpacity(0.15), shape: BoxShape.circle),
                child: Center(child: Text(initials, style: const TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w700, color: _accent)))),
            ] : [
              Container(width: 24, height: 24,
                decoration: const BoxDecoration(color: _navy, shape: BoxShape.circle),
                child: Center(child: Text(initials, style: const TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w700, color: _white)))),
              const SizedBox(width: 6),
              Text(name, style: const TextStyle(fontSize: 11, color: _gray600, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe) const SizedBox(width: 30),
              Flexible(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? _accent : _white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16)),
                  border: isMe ? null : Border.all(color: _gray200),
                  boxShadow: [BoxShadow(
                    color: msg.urgent ? _red.withOpacity(0.15) : Colors.black.withOpacity(0.05),
                    blurRadius: 6, spreadRadius: msg.urgent ? 1 : 0)]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (msg.urgent) Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.warning_amber_rounded, size: 10, color: _red),
                      const SizedBox(width: 3),
                      Text('Urgent', style: TextStyle(
                        fontSize: 10, color: isMe ? Colors.white70 : _red,
                        fontWeight: FontWeight.w700)),
                    ])),
                  Text(msg.text, style: TextStyle(
                    fontSize: 14, color: isMe ? _white : _navy, height: 1.4)),
                ]),
              )),
              if (isMe) const SizedBox(width: 30),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(_fmtTime(msg.time),
              style: const TextStyle(fontSize: 10, color: _gray400))),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — AI SUPPORT CHAT
// ══════════════════════════════════════════════════════════════════════════════
class _AiChatTab extends StatelessWidget {
  final List<AiMsg> messages;
  final TextEditingController draftCtrl;
  final bool loading, fetching, showSuggestions;
  final ScrollController scrollCtrl;
  final String firstName, lastName;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final ValueChanged<String> onSuggestion;

  const _AiChatTab({
    required this.messages, required this.draftCtrl,
    required this.loading, required this.fetching,
    required this.showSuggestions, required this.scrollCtrl,
    required this.firstName, required this.lastName,
    required this.onChanged, required this.onSend,
    required this.onSuggestion});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // AI status bar
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _white,
          border: Border(bottom: BorderSide(color: _gray200))),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_aiCol, Color(0xFF6366F1)]),
              shape: BoxShape.circle),
            child: const Icon(Icons.smart_toy_outlined, color: _white, size: 18)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('CST AI Support Assistant', style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
            Row(children: [
              const Icon(Icons.bolt, size: 11, color: _aiCol),
              const SizedBox(width: 3),
              Text('Powered by AI · Instant replies',
                style: const TextStyle(fontSize: 11, color: _aiCol, fontWeight: FontWeight.w600)),
            ]),
          ]),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
            child: const Text('24/7', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w800, color: _green))),
        ]),
      ),

      // Messages
      Expanded(
        child: Container(
          color: _gray50,
          child: fetching
              ? const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(color: _aiCol, strokeWidth: 2),
                    SizedBox(height: 12),
                    Text('Loading history...', style: TextStyle(fontSize: 13, color: _gray400)),
                  ]))
              : ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: messages.length + (loading ? 1 : 0) + (showSuggestions ? 1 : 0),
                  itemBuilder: (ctx, i) {
                    // Suggestions at the end after messages
                    if (showSuggestions && i == messages.length) {
                      return _SuggestionsWidget(onTap: onSuggestion);
                    }
                    // Typing indicator
                    if (loading && i == messages.length + (showSuggestions ? 1 : 0)) {
                      return _TypingIndicator();
                    }
                    if (loading && !showSuggestions && i == messages.length) {
                      return _TypingIndicator();
                    }
                    final msg = messages[i];
                    return _AiBubble(
                      msg: msg,
                      firstName: firstName,
                      lastName: lastName);
                  }),
        ),
      ),

      // Disclaimer
      Container(
        color: _white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(children: [
          Icon(Icons.info_outline, size: 11, color: _aiCol.withOpacity(0.6)),
          const SizedBox(width: 5),
          const Expanded(child: Text(
            'For urgent issues, submit a support ticket or call us.',
            style: TextStyle(fontSize: 10, color: _gray400))),
        ]),
      ),

      // Input
      Container(
        color: _white,
        padding: EdgeInsets.only(
          left: 12, right: 12, top: 10,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12),
        child: Row(children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: _gray50, borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: draftCtrl.text.isNotEmpty ? _aiCol : _gray200,
                  width: draftCtrl.text.isNotEmpty ? 1.5 : 1)),
              child: TextField(
                controller: draftCtrl, onChanged: onChanged,
                onSubmitted: (_) => onSend(),
                enabled: !loading,
                style: const TextStyle(fontSize: 14, color: _navy),
                decoration: const InputDecoration(
                  hintText: 'Ask about schedule, billing, enrollment...',
                  hintStyle: TextStyle(fontSize: 13, color: _gray400),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: loading ? null : onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: draftCtrl.text.isNotEmpty && !loading
                    ? const LinearGradient(colors: [_aiCol, Color(0xFF6366F1)])
                    : null,
                color: draftCtrl.text.isEmpty || loading ? _gray200 : null,
                shape: BoxShape.circle,
                boxShadow: draftCtrl.text.isNotEmpty && !loading ? [
                  BoxShadow(color: _aiCol.withOpacity(0.35),
                    blurRadius: 8, offset: const Offset(0, 3))] : null),
              child: loading
                  ? const Padding(padding: EdgeInsets.all(11),
                      child: CircularProgressIndicator(strokeWidth: 2, color: _white))
                  : Icon(Icons.send_rounded,
                      color: draftCtrl.text.isNotEmpty ? _white : _gray400, size: 18)),
          ),
        ]),
      ),
    ]);
  }
}

class _AiBubble extends StatelessWidget {
  final AiMsg msg;
  final String firstName, lastName;
  const _AiBubble({required this.msg, required this.firstName, required this.lastName});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.isUser;
    final initials = isUser
        ? '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
        : '🤖';
    final name = isUser ? '$firstName $lastName' : 'AI Support';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: isUser ? [
              Text(name.trim(), style: const TextStyle(
                fontSize: 11, color: _gray600, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Container(width: 26, height: 26,
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.15), shape: BoxShape.circle),
                child: Center(child: Text(initials, style: const TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w700, color: _accent)))),
            ] : [
              Container(width: 26, height: 26,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [_aiCol, Color(0xFF6366F1)]),
                  shape: BoxShape.circle),
                child: const Center(child: Icon(Icons.smart_toy_outlined,
                  size: 13, color: _white))),
              const SizedBox(width: 6),
              Text(name, style: const TextStyle(
                fontSize: 11, color: _gray600, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: _aiCol.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6)),
                child: const Text('AI', style: TextStyle(
                  fontSize: 8, fontWeight: FontWeight.w800, color: _aiCol))),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isUser) const SizedBox(width: 32),
              Flexible(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: isUser ? _accent : _white,
                  gradient: !isUser ? null : null,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isUser ? 18 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 18)),
                  border: isUser ? null : Border.all(color: _gray200),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.06), blurRadius: 6)]),
                child: Text(msg.text, style: TextStyle(
                  fontSize: 14, color: isUser ? _white : _navy, height: 1.55)),
              )),
              if (isUser) const SizedBox(width: 32),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(_fmtTime(msg.time),
              style: const TextStyle(fontSize: 10, color: _gray400))),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  @override State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 26, height: 26,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [_aiCol, Color(0xFF6366F1)]),
            shape: BoxShape.circle),
          child: const Center(child: Icon(Icons.smart_toy_outlined, size: 13, color: _white))),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18), topRight: Radius.circular(18),
              bottomLeft: Radius.circular(4), bottomRight: Radius.circular(18)),
            border: Border.all(color: _gray200),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)]),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
              ...List.generate(3, (i) {
                final delay = i * 0.33;
                final val = (_ctrl.value - delay).clamp(0.0, 1.0);
                final bounce = (val < 0.5 ? val * 2 : (1 - val) * 2);
                return Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 4 : 0),
                  child: Transform.translate(
                    offset: Offset(0, -5 * bounce),
                    child: Container(width: 7, height: 7,
                      decoration: BoxDecoration(color: _aiCol.withOpacity(0.7),
                        shape: BoxShape.circle))));
              }),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _SuggestionsWidget extends StatelessWidget {
  final ValueChanged<String> onTap;
  const _SuggestionsWidget({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.help_outline, size: 13, color: _aiCol),
          const SizedBox(width: 6),
          const Text('Common questions', style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: _gray600)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8,
          children: _aiSuggestions.map((s) => GestureDetector(
            onTap: () => onTap(s),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _gray200),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)]),
              child: Text(s, style: const TextStyle(
                fontSize: 12, color: _gray800))),
          )).toList()),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 4 — SUBMIT TICKET
// ══════════════════════════════════════════════════════════════════════════════
class _TicketTab extends StatelessWidget {
  final TextEditingController subjectCtrl, detailCtrl;
  final String selCat;
  final bool urgent, submitting, submitted;
  final ValueChanged<String> onCat;
  final ValueChanged<bool> onUrgent;
  final VoidCallback onSubmit, onViewTickets;

  const _TicketTab({
    required this.subjectCtrl, required this.detailCtrl,
    required this.selCat, required this.urgent,
    required this.submitting, required this.submitted,
    required this.onCat, required this.onUrgent,
    required this.onSubmit, required this.onViewTickets});

  @override
  Widget build(BuildContext context) {
    if (submitted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 64, height: 64,
              decoration: BoxDecoration(
                color: _green.withOpacity(0.1), shape: BoxShape.circle,
                border: Border.all(color: _green.withOpacity(0.3), width: 2)),
              child: const Icon(Icons.check_circle_outline, color: _green, size: 32)),
            const SizedBox(height: 16),
            const Text('Ticket Submitted!', style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800, color: _navy)),
            const SizedBox(height: 8),
            const Text("Our team will get back to you within 24 hours.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: _gray600, height: 1.5)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onViewTickets,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent, foregroundColor: _white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('View My Tickets',
                style: TextStyle(fontWeight: FontWeight.w700))),
          ]),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('What do you need help with?', style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 4),
        const Text('Fill in the details and our team will respond shortly.',
          style: TextStyle(fontSize: 13, color: _gray600)),
        const SizedBox(height: 20),
        const _FLabel('Subject'),
        const SizedBox(height: 6),
        _TField(ctrl: subjectCtrl, hint: 'Brief description of your issue'),
        const SizedBox(height: 16),
        const _FLabel('Category'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8,
          children: _cats.map((c) {
            final sel = selCat == c.label;
            return GestureDetector(
              onTap: () => onCat(c.label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? c.bg : _white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? c.color : _gray200, width: sel ? 2 : 1)),
                child: Text(c.label, style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: c.color))),
            );
          }).toList()),
        const SizedBox(height: 16),
        const _FLabel('Details (optional)'),
        const SizedBox(height: 6),
        _TField(ctrl: detailCtrl, hint: 'Describe the issue in more detail…', maxLines: 4),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _red.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _red.withOpacity(0.2))),
          child: Row(children: [
            const Icon(Icons.flag_outlined, color: _red, size: 16),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Mark as Urgent', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: _red)),
              const Text('Only for critical issues needing immediate attention.',
                style: TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
            ])),
            Switch(value: urgent, onChanged: onUrgent, activeColor: _red),
          ]),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (subjectCtrl.text.isNotEmpty && selCat.isNotEmpty && !submitting)
                ? onSubmit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              disabledBackgroundColor: _gray200,
              foregroundColor: _white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            child: submitting
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _white))
                : const Text('Submit Ticket')),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _FLabel extends StatelessWidget {
  final String text;
  const _FLabel(this.text);
  @override Widget build(BuildContext context) => Text(text, style: const TextStyle(
    fontSize: 12, fontWeight: FontWeight.w700, color: _navy, letterSpacing: 0.3));
}

class _TField extends StatelessWidget {
  final TextEditingController ctrl; final String hint; final int maxLines;
  const _TField({required this.ctrl, required this.hint, this.maxLines = 1});
  @override Widget build(BuildContext context) => TextField(
    controller: ctrl, maxLines: maxLines,
    style: const TextStyle(fontSize: 14, color: _navy),
    decoration: InputDecoration(
      hintText: hint, hintStyle: const TextStyle(fontSize: 14, color: _gray400),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _gray200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _gray200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _accent, width: 1.5)),
      filled: true, fillColor: _gray50));
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 5 — MY TICKETS
// ══════════════════════════════════════════════════════════════════════════════
class _HistoryTab extends StatelessWidget {
  final List<SupportTicket> tickets;
  final VoidCallback onNew;
  const _HistoryTab({required this.tickets, required this.onNew});

  Color _sc(String s) => s == 'open' ? _red : s == 'pending' ? _amber : _green;

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inbox_outlined, size: 48, color: _gray400.withOpacity(0.5)),
          const SizedBox(height: 12),
          const Text('No tickets yet', style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, color: _navy)),
          const SizedBox(height: 6),
          const Text('Submit a ticket and we\'ll get back to you.',
            style: TextStyle(fontSize: 13, color: _gray600)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onNew,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New Ticket'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent, foregroundColor: _white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
        ]),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: tickets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final t = tickets[i];
        final cat = _catFor(t.category);
        final sc  = _sc(t.status);
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _white, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.urgent ? _red.withOpacity(0.35) : _gray200),
            boxShadow: [BoxShadow(
              color: t.urgent ? _red.withOpacity(0.1) : Colors.black.withOpacity(0.04),
              blurRadius: 8)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (t.urgent) ...[
                const Icon(Icons.warning_amber_rounded, color: _red, size: 14),
                const SizedBox(width: 6),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: cat.bg, borderRadius: BorderRadius.circular(20)),
                child: Text(t.category, style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: cat.color))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sc.withOpacity(0.3))),
                child: Text(t.status[0].toUpperCase() + t.status.substring(1),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: sc))),
            ]),
            const SizedBox(height: 8),
            Text(t.subject, style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
            const SizedBox(height: 6),
            Row(children: [
              Text('#${t.id.length > 6 ? t.id.substring(t.id.length - 6).toUpperCase() : t.id.toUpperCase()}',
                style: const TextStyle(fontSize: 11, color: _gray400, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(_relTime(t.createdAt),
                style: const TextStyle(fontSize: 11, color: _gray400)),
            ]),
          ]),
        );
      },
    );
  }
}