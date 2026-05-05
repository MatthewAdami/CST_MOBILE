// lib/screens/messages/components/inbox_drawer.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../config/api_config.dart';

const _kPurple = Color(0xFF7C3AED);
const _kNavy   = Color(0xFF0B1F3A);

class InboxDrawer extends StatefulWidget {
  final dynamic                currentUser;
  final Map<String, dynamic>?  activeConversation;
  final void Function(Map<String, dynamic>) onSelectConversation;

  const InboxDrawer({
    super.key,
    required this.currentUser,
    required this.activeConversation,
    required this.onSelectConversation,
  });

  @override
  State<InboxDrawer> createState() => _InboxDrawerState();
}

class _InboxDrawerState extends State<InboxDrawer> {
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _filtered      = [];
  bool   _loading = true;
  String _error   = '';
  String _search  = '';
  String _token   = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token') ?? '';
    debugPrint('[InboxDrawer] token: ${_token.isNotEmpty ? "present" : "MISSING"}');
    await _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = ''; });

    try {
      debugPrint('[InboxDrawer] GET ${ApiConfig.conversations}');
      final res = await http
          .get(Uri.parse(ApiConfig.conversations),
               headers: ApiConfig.authHeaders(_token))
          .timeout(ApiConfig.timeout);

      debugPrint('[InboxDrawer] status=${res.statusCode} body=${res.body}');
      if (!mounted) return;

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final List raw = decoded is List
            ? decoded
            : (decoded['conversations'] as List? ?? []);
        setState(() {
          _conversations = raw.cast<Map<String, dynamic>>();
          _applySearch(_search);
        });
      } else if (res.statusCode == 401) {
        setState(() => _error = 'Session expired. Please log in again.');
      } else {
        setState(() => _error = 'Server error ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('[InboxDrawer] fetch error: $e');
      if (mounted) setState(() => _error = 'Connection failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applySearch(String q) {
    _search = q;
    if (q.isEmpty) {
      _filtered = List.from(_conversations);
      return;
    }
    final lower = q.toLowerCase();
    _filtered = _conversations.where((c) {
      final other = _otherParticipant(c);
      final name  = '${other['firstName'] ?? ''} ${other['lastName'] ?? ''}'.toLowerCase();
      final lm    = c['lastMessage'];
      final last  = (lm is Map ? lm['content']?.toString() : '') ?? '';
      return name.contains(lower) || last.toLowerCase().contains(lower);
    }).toList();
  }

  // Resolves the "other" participant regardless of whether the server
  // returns otherParticipant directly or just a participants array.
  Map<String, dynamic> _otherParticipant(Map<String, dynamic> convo) {
    if (convo['otherParticipant'] is Map) {
      return Map<String, dynamic>.from(convo['otherParticipant'] as Map);
    }
    final myId = _myUserId();
    final parts = convo['participants'];
    if (parts is List) {
      for (final p in parts) {
        if (p is Map && p['_id']?.toString() != myId) {
          return Map<String, dynamic>.from(p);
        }
      }
    }
    return {};
  }

  String _myUserId() {
    if (widget.currentUser is Map) {
      return widget.currentUser['_id']?.toString() ?? '';
    }
    return '';
  }

  Future<void> _showNewConversation() async {
    try {
      debugPrint('[InboxDrawer] GET ${ApiConfig.availableContacts}');
      final res = await http
          .get(Uri.parse(ApiConfig.availableContacts),
               headers: ApiConfig.authHeaders(_token))
          .timeout(ApiConfig.timeout);

      debugPrint('[InboxDrawer] contacts status=${res.statusCode} body=${res.body}');
      if (!mounted) return;

      if (res.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load contacts (${res.statusCode})')));
        return;
      }

      final decoded = jsonDecode(res.body);
      final List raw = decoded is List ? decoded : [];
      final contacts = raw.cast<Map<String, dynamic>>();

      if (contacts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No available contacts found.')));
        return;
      }

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => _ContactPickerSheet(
          contacts: contacts,
          onSelect: (c) async {
            Navigator.pop(context);
            await _startOrGetConversation(c['_id'].toString());
          },
        ),
      );
    } catch (e) {
      debugPrint('[InboxDrawer] contacts error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading contacts: $e')));
      }
    }
  }

  Future<void> _startOrGetConversation(String participantId) async {
    try {
      debugPrint('[InboxDrawer] POST ${ApiConfig.conversations} participantId=$participantId');
      final res = await http
          .post(Uri.parse(ApiConfig.conversations),
                headers: ApiConfig.authHeaders(_token),
                body: jsonEncode({'participantId': participantId}))
          .timeout(ApiConfig.timeout);

      debugPrint('[InboxDrawer] create status=${res.statusCode} body=${res.body}');
      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        final convo = jsonDecode(res.body) as Map<String, dynamic>;
        await _fetchConversations();
        widget.onSelectConversation(convo);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error ${res.statusCode}: ${res.body}')));
      }
    } catch (e) {
      debugPrint('[InboxDrawer] create convo error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      // ── Header ──────────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: Row(
          children: [
            const Text('Messages',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                color: _kNavy, fontFamily: 'Inter')),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: _kPurple),
              onPressed: _showNewConversation,
              tooltip: 'New message',
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18, color: _kPurple),
              onPressed: _fetchConversations,
              tooltip: 'Refresh',
            ),
          ],
        ),
      ),

      // ── Search ──────────────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          style: const TextStyle(fontSize: 14, fontFamily: 'Inter'),
          onChanged: (q) => setState(() => _applySearch(q)),
          decoration: InputDecoration(
            hintText:  'Search conversations...',
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF9CA3AF)),
            filled:    true,
            fillColor: const Color(0xFFF3F4F6),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:   BorderSide.none,
            ),
          ),
        ),
      ),

      // ── Error banner ────────────────────────────────────────────────────
      if (_error.isNotEmpty)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, size: 16, color: Color(0xFFEF4444)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_error,
                  style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)))),
              GestureDetector(
                onTap: _fetchConversations,
                child: const Text('Retry',
                  style: TextStyle(fontSize: 12, color: _kPurple,
                    fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),

      // ── List ────────────────────────────────────────────────────────────
      Expanded(
        child: _loading
          ? const Center(child: CircularProgressIndicator(color: _kPurple))
          : _filtered.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.chat_bubble_outline,
                      size: 40, color: Color(0xFFD1D5DB)),
                    const SizedBox(height: 12),
                    Text(
                      _search.isEmpty ? 'No conversations yet.' : 'No results.',
                      style: const TextStyle(fontSize: 13,
                        color: Color(0xFF9CA3AF))),
                  ],
                ),
              )
            : RefreshIndicator(
                color: _kPurple,
                onRefresh: _fetchConversations,
                child: ListView.builder(
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final convo    = _filtered[i];
                    final other    = _otherParticipant(convo);
                    final isActive = widget.activeConversation?['_id'] == convo['_id'];
                    return _ConvoTile(
                      convo:    convo,
                      other:    other,
                      isActive: isActive,
                      onTap:    () => widget.onSelectConversation(convo),
                    );
                  },
                ),
              ),
      ),
    ],
  );
}

// ─── Conversation tile ────────────────────────────────────────────────────────
class _ConvoTile extends StatelessWidget {
  final Map<String, dynamic> convo;
  final Map<String, dynamic> other;
  final bool         isActive;
  final VoidCallback onTap;

  const _ConvoTile({
    required this.convo,
    required this.other,
    required this.isActive,
    required this.onTap,
  });

  String get _initials {
    final f = other['firstName'] as String? ?? '';
    final l = other['lastName']  as String? ?? '';
    return '${f.isNotEmpty ? f[0] : ''}${l.isNotEmpty ? l[0] : ''}'.toUpperCase();
  }

  String get _name =>
      '${other['firstName'] ?? ''} ${other['lastName'] ?? ''}'.trim();

  String get _lastMsg {
    final lm = convo['lastMessage'];
    if (lm is Map) return lm['content']?.toString() ?? 'No messages yet';
    return 'No messages yet';
  }

  String get _timestamp {
    final lm = convo['lastMessage'];
    if (lm is! Map) return '';
    final ts = lm['timestamp']?.toString();
    if (ts == null) return '';
    final dt = DateTime.tryParse(ts)?.toLocal();
    if (dt == null) return '';
    final now    = DateTime.now();
    final today  = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    if (msgDay == today) {
      return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    }
    final diff = today.difference(msgDay).inDays;
    if (diff == 1) return 'Yesterday';
    if (diff < 7)  return ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][dt.weekday - 1];
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  int get _unread => (convo['unreadCount'] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isActive ? const Color(0xFFEEF2FF) : Colors.transparent,
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _kPurple.withOpacity(.15),
            child: Text(
              _initials.isEmpty ? '?' : _initials,
              style: const TextStyle(color: _kPurple, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _name.isEmpty ? 'Unknown' : _name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _unread > 0 ? FontWeight.w700 : FontWeight.w600,
                          color: _kNavy,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    Text(_timestamp,
                      style: const TextStyle(fontSize: 11,
                        color: Color(0xFF9CA3AF))),
                  ],
                ),
                const SizedBox(height: 3),
                Text(_lastMsg,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: _unread > 0 ? FontWeight.w600 : FontWeight.normal,
                    color: _unread > 0 ? _kNavy : const Color(0xFF6B7280),
                    fontFamily: 'Inter',
                  )),
              ],
            ),
          ),
          if (_unread > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _kPurple,
                borderRadius: BorderRadius.circular(12)),
              child: Text('$_unread',
                style: const TextStyle(fontSize: 11, color: Colors.white,
                  fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    ),
  );
}

// ─── Contact picker bottom sheet ──────────────────────────────────────────────
class _ContactPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> contacts;
  final void Function(Map<String, dynamic>) onSelect;
  const _ContactPickerSheet({required this.contacts, required this.onSelect});

  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _q.isEmpty
        ? widget.contacts
        : widget.contacts.where((c) {
            final name = '${c['firstName'] ?? ''} ${c['lastName'] ?? ''}'.toLowerCase();
            return name.contains(_q.toLowerCase());
          }).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 12),
          const Text('New Message',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
              color: _kNavy, fontFamily: 'Inter')),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText:   'Search contacts...',
                prefixIcon: const Icon(Icons.search, size: 18),
                filled:     true,
                fillColor:  const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:   BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 300,
            child: filtered.isEmpty
                ? const Center(child: Text('No contacts found.'))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final c    = filtered[i];
                      final name = '${c['firstName'] ?? ''} ${c['lastName'] ?? ''}'.trim();
                      final role = c['role'] as String? ?? '';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _kPurple.withOpacity(.15),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(color: _kPurple,
                              fontWeight: FontWeight.w700),
                          ),
                        ),
                        title: Text(name,
                          style: const TextStyle(fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _kNavy, fontFamily: 'Inter')),
                        subtitle: Text(role,
                          style: const TextStyle(fontSize: 12,
                            color: Color(0xFF6B7280))),
                        onTap: () => widget.onSelect(c),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}