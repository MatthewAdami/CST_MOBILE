// lib/screens/messages/components/chat_window.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../config/api_config.dart';

const _kPurple = Color(0xFF7C3AED);
const _kNavy   = Color(0xFF0B1F3A);

class ChatWindow extends StatefulWidget {
  final Map<String, dynamic> conversation;
  final dynamic              currentUser;
  final VoidCallback?        onBack;

  const ChatWindow({
    super.key,
    required this.conversation,
    required this.currentUser,
    this.onBack,
  });

  @override
  State<ChatWindow> createState() => _ChatWindowState();
}

class _ChatWindowState extends State<ChatWindow> {
  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool   _loading = true;
  bool   _sending = false;
  bool   _hasMore = false;
  int    _page    = 1;
  String _token   = '';
  String _myId    = '';
  String _error   = '';
  io.Socket? _socket;

  // Safely get conversation ID — handles both '_id' and 'id' keys
  String get _convId =>
      (widget.conversation['_id'] ?? widget.conversation['id'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token') ?? '';
    debugPrint('[ChatWindow] token: ${_token.isNotEmpty ? "present" : "MISSING"}');
    debugPrint('[ChatWindow] conversation keys: ${widget.conversation.keys.toList()}');
    debugPrint('[ChatWindow] convId resolved: $_convId');

    // ── Resolve current user ID from multiple possible sources ──────────────
    // Source 1: passed-in currentUser prop
    if (widget.currentUser is Map) {
      final cu = widget.currentUser as Map;
      _myId = (cu['_id'] ?? cu['id'] ?? '').toString();
    }

    // Source 2: SharedPreferences 'user' json
    if (_myId.isEmpty) {
      final raw = prefs.getString('user') ?? '{}';
      try {
        final user = jsonDecode(raw) as Map<String, dynamic>;
        _myId = (user['_id'] ?? user['id'] ?? '').toString();
      } catch (_) {}
    }

    // Source 3: decode from JWT token (last resort)
    if (_myId.isEmpty && _token.isNotEmpty) {
      try {
        final parts   = _token.split('.');
        if (parts.length == 3) {
          final payload = utf8.decode(
            base64Url.decode(base64Url.normalize(parts[1])));
          final data = jsonDecode(payload) as Map<String, dynamic>;
          _myId = (data['id'] ?? data['_id'] ?? data['sub'] ?? '').toString();
        }
      } catch (_) {}
    }

    debugPrint('[ChatWindow] myId resolved: "$_myId"');
    debugPrint('[ChatWindow] currentUser: ${widget.currentUser}');

    if (_convId.isEmpty) {
      setState(() {
        _error   = 'Invalid conversation ID.';
        _loading = false;
      });
      return;
    }

    await _fetchMessages();
    _markAsRead();
    _connectSocket();
  }

  // ── Fetch messages ────────────────────────────────────────────────────────
  Future<void> _fetchMessages({bool prepend = false}) async {
    if (!mounted) return;
    if (!prepend) setState(() { _loading = true; _error = ''; });

    try {
      final url = '${ApiConfig.messages(_convId)}?page=$_page&limit=50';
      debugPrint('[ChatWindow] GET $url');
      final res = await http
          .get(Uri.parse(url), headers: ApiConfig.authHeaders(_token))
          .timeout(ApiConfig.timeout);

      debugPrint('[ChatWindow] messages status=${res.statusCode}');
      debugPrint('[ChatWindow] messages body=${res.body}');

      if (!mounted) return;

      if (res.statusCode == 200) {
        final body       = jsonDecode(res.body) as Map<String, dynamic>;
        final msgs       = (body['messages'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        final pagination = body['pagination'] as Map<String, dynamic>? ?? {};

        setState(() {
          _messages = prepend ? [...msgs, ..._messages] : msgs;
          _hasMore  = pagination['hasMore'] as bool? ?? false;
          _error    = '';
        });

        if (!prepend) _scrollToBottom();
      } else if (res.statusCode == 401) {
        setState(() => _error = 'Session expired. Please log in again.');
      } else {
        setState(() => _error = 'Error ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      debugPrint('[ChatWindow] fetch error: $e');
      if (mounted) setState(() => _error = 'Could not load messages: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels <= 60 && _hasMore && !_loading) {
      _page++;
      _fetchMessages(prepend: true);
    }
  }

  Future<void> _markAsRead() async {
    try {
      await http
          .patch(Uri.parse(ApiConfig.conversationRead(_convId)),
                 headers: ApiConfig.authHeaders(_token))
          .timeout(ApiConfig.timeout);
    } catch (e) {
      debugPrint('[ChatWindow] markAsRead error: $e');
    }
  }

  // ── Socket.io ─────────────────────────────────────────────────────────────
  void _connectSocket() {
    try {
      // Must include 'polling' first — Socket.io does an HTTP upgrade handshake
      // before switching to websocket. Websocket-only skips it → 404.
      _socket = io.io(
        ApiConfig.socketUrl,
        io.OptionBuilder()
          .setTransports(['polling', 'websocket'])
          .setExtraHeaders({'Authorization': 'Bearer $_token'})
          .disableAutoConnect()
          .build(),
      );

      _socket!.connect();

      _socket!.onConnect((_) {
        debugPrint('[ChatWindow] socket connected, joining $_convId');
        _socket!.emit('join_conversation', _convId);
      });

      _socket!.onConnectError((e) =>
          debugPrint('[ChatWindow] socket connect error: $e'));

      _socket!.onError((e) =>
          debugPrint('[ChatWindow] socket error: $e'));

      _socket!.on('receive_message', (data) {
        debugPrint('[ChatWindow] receive_message: $data');
        final msg      = Map<String, dynamic>.from(data as Map);
        final senderId = _extractSenderId(msg);
        // Skip our own — already shown optimistically
        if (senderId == _myId) return;
        if (mounted) {
          setState(() => _messages.add(msg));
          _scrollToBottom();
        }
      });

      _socket!.on('message_deleted', (data) {
        final msgId = (data as Map)['messageId']?.toString();
        if (msgId != null && mounted) {
          setState(() => _messages.removeWhere((m) => m['_id'] == msgId));
        }
      });
    } catch (e) {
      debugPrint('[ChatWindow] socket init error: $e');
    }
  }

  // ── Send message ──────────────────────────────────────────────────────────
  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _msgCtrl.clear();

    // Optimistic bubble
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    setState(() => _messages.add({
      '_id':       tempId,
      'content':   text,
      'sender':    {'_id': _myId},
      'createdAt': DateTime.now().toIso8601String(),
      '_temp':     true,
    }));
    _scrollToBottom();

    try {
      debugPrint('[ChatWindow] POST ${ApiConfig.messages(_convId)}');
      final res = await http
          .post(Uri.parse(ApiConfig.messages(_convId)),
                headers: ApiConfig.authHeaders(_token),
                body: jsonEncode({'content': text}))
          .timeout(ApiConfig.timeout);

      debugPrint('[ChatWindow] send status=${res.statusCode} body=${res.body}');

      if (!mounted) return;

      if (res.statusCode == 201) {
        final real = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          final idx = _messages.indexWhere((m) => m['_id'] == tempId);
          if (idx != -1) _messages[idx] = real;
        });
      } else {
        setState(() => _messages.removeWhere((m) => m['_id'] == tempId));
        _showError('Failed to send (${res.statusCode}): ${res.body}');
      }
    } catch (e) {
      debugPrint('[ChatWindow] send error: $e');
      if (mounted) {
        setState(() => _messages.removeWhere((m) => m['_id'] == tempId));
        _showError('Network error: $e');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── Delete message ────────────────────────────────────────────────────────
  Future<void> _deleteMessage(String messageId) async {
    setState(() => _messages.removeWhere((m) => m['_id'] == messageId));
    try {
      final res = await http
          .delete(Uri.parse(ApiConfig.messageDelete(messageId)),
                  headers: ApiConfig.authHeaders(_token))
          .timeout(ApiConfig.timeout);
      if (res.statusCode != 200 && mounted) {
        _showError('Could not delete (${res.statusCode}).');
        _fetchMessages();
      }
    } catch (e) {
      debugPrint('[ChatWindow] delete error: $e');
      if (mounted) _showError('Network error: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _extractSenderId(Map<String, dynamic> msg) {
    final s = msg['sender'];
    if (s is Map) return (s['_id'] ?? s['id'] ?? '').toString();
    return s?.toString() ?? '';
  }

  bool _isFromMe(Map<String, dynamic> msg) {
    final senderId = _extractSenderId(msg);
    final result   = senderId == _myId;
    // Uncomment this line temporarily if bubbles still align wrong:
    // debugPrint('[ChatWindow] senderId="$senderId" myId="$_myId" fromMe=$result');
    return result;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients &&
          _scrollCtrl.position.hasContentDimensions) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red[700]));
  }

  @override
  void dispose() {
    try {
      _socket?.emit('leave_conversation', _convId);
      _socket?.dispose();
    } catch (_) {}
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Header helpers ────────────────────────────────────────────────────────
  Map<String, dynamic> get _otherParticipant {
    if (widget.conversation['otherParticipant'] is Map) {
      return Map<String, dynamic>.from(
          widget.conversation['otherParticipant'] as Map);
    }
    final parts = widget.conversation['participants'];
    if (parts is List) {
      for (final p in parts) {
        if (p is Map && p['_id']?.toString() != _myId) {
          return Map<String, dynamic>.from(p);
        }
      }
    }
    return {};
  }

  String get _otherName {
    final o = _otherParticipant;
    return '${o['firstName'] ?? ''} ${o['lastName'] ?? ''}'.trim();
  }

  String get _otherInitial {
    final n = _otherName;
    return n.isNotEmpty ? n[0].toUpperCase() : '?';
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => Column(
    children: [
      // ── Header ────────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              if (widget.onBack != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                    size: 18, color: _kNavy),
                  onPressed: widget.onBack,
                  padding: EdgeInsets.zero,
                ),
              CircleAvatar(
                radius: 18,
                backgroundColor: _kPurple.withOpacity(.15),
                child: Text(_otherInitial,
                  style: const TextStyle(color: _kPurple,
                    fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_otherName.isEmpty ? 'Conversation' : _otherName,
                  style: const TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kNavy, fontFamily: 'Inter')),
              ),
            ],
          ),
        ),
      ),

      // ── Error banner ──────────────────────────────────────────────────
      if (_error.isNotEmpty)
        Container(
          color: const Color(0xFFFEF2F2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.error_outline, size: 16, color: Color(0xFFEF4444)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_error,
                  style: const TextStyle(fontSize: 12,
                    color: Color(0xFFB91C1C)))),
              GestureDetector(
                onTap: () => _fetchMessages(),
                child: const Text('Retry',
                  style: TextStyle(fontSize: 12, color: _kPurple,
                    fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),

      // ── Messages ──────────────────────────────────────────────────────
      Expanded(
        child: _loading
          ? const Center(child: CircularProgressIndicator(color: _kPurple))
          : _messages.isEmpty
            ? const Center(
                child: Text('No messages yet. Say hello!',
                  style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))))
            : ListView.builder(
                controller:  _scrollCtrl,
                padding:     const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
                itemCount:   _messages.length,
                itemBuilder: (_, i) {
                  final msg    = _messages[i];
                  final fromMe = _isFromMe(msg);
                  return GestureDetector(
                    onLongPress: fromMe && msg['_temp'] != true
                        ? () => _confirmDelete(msg['_id'].toString())
                        : null,
                    child: _MessageBubble(msg: msg, fromMe: fromMe),
                  );
                },
              ),
      ),

      // ── Input ─────────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller:      _msgCtrl,
                  maxLines:        null,
                  keyboardType:    TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: const TextStyle(fontSize: 14, fontFamily: 'Inter'),
                  decoration: InputDecoration(
                    hintText:  'Type a message...',
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF),
                      fontSize: 13),
                    filled:    true,
                    fillColor: const Color(0xFFF3F4F6),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide:   BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendMessage,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _sending
                        ? _kPurple.withOpacity(.5)
                        : _kPurple,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded,
                        size: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  void _confirmDelete(String messageId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete message'),
        content: const Text(
          'This will remove the message for you. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMessage(messageId);
            },
            child: const Text('Delete',
              style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ── Message bubble ─────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool fromMe;
  const _MessageBubble({required this.msg, required this.fromMe});

  String get _time {
    final raw = msg['createdAt']?.toString();
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isTemp  = msg['_temp'] == true;
    final content = msg['content']?.toString() ?? '';

    return Align(
      alignment: fromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: fromMe ? _kPurple : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(16),
            topRight:    const Radius.circular(16),
            bottomLeft:  Radius.circular(fromMe ? 16 : 4),
            bottomRight: Radius.circular(fromMe ? 4  : 16),
          ),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(.06),
              blurRadius: 4,
              offset:     const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(content,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Inter',
                color: fromMe ? Colors.white : _kNavy,
              )),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_time,
                  style: TextStyle(
                    fontSize: 10,
                    color: fromMe
                        ? Colors.white.withOpacity(.6)
                        : const Color(0xFF9CA3AF),
                  )),
                if (fromMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isTemp ? Icons.schedule : Icons.done_all,
                    size: 12,
                    color: Colors.white.withOpacity(isTemp ? .4 : .7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}