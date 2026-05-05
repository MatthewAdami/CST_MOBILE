// lib/widgets/chatbot_widget.dart
//
// Drop-in Flutter equivalent of the web ChatbotWidget.
// Usage: just place <ChatbotWidget /> anywhere in your widget tree
// (typically as a Stack overlay in your Scaffold).

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ── Palette (mirrors web) ─────────────────────────────────────────
class _C {
  static const navy      = Color(0xFF1B2B4B);
  static const navyDark  = Color(0xFF101D33);
  static const gold      = Color(0xFFB8963E);
  static const goldLight = Color(0xFFD4AE5A);
  static const offWhite  = Color(0xFFF8F7F4);
  static const white     = Color(0xFFFFFFFF);
  static const border    = Color(0x1F1B2B4B);
  static const green     = Color(0xFF4ADE80);
  static const muted     = Color(0xFF9B9890);
}

const _kApiBase = 'http://10.0.2.2:5000'; // change to your prod URL

// ── Data models ───────────────────────────────────────────────────
class _ChatMessage {
  final String role; // 'user' | 'bot'
  final String text;
  final bool   showQuickReplies;
  const _ChatMessage({
    required this.role,
    required this.text,
    this.showQuickReplies = false,
  });
}

const _kWelcome = _ChatMessage(
  role: 'bot',
  text:
      'Welcome to California School of Trucking. I can help you with CDL '
      'programs, tuition, veteran benefits, enrollment, and more.\n\n'
      'What would you like to know?',
  showQuickReplies: true,
);

const _kQuickReplies = [
  ('CDL programs',     'What CDL programs do you offer?'),
  ('Tuition & cost',   'How much is tuition?'),
  ('Veteran benefits', 'Do you accept GI Bill?'),
  ('How to enroll',    'How do I enroll?'),
];

// ═════════════════════════════════════════════════════════════════
// Public widget — add to any Stack as an overlay
// ═════════════════════════════════════════════════════════════════
class ChatbotWidget extends StatefulWidget {
  const ChatbotWidget({super.key});

  @override
  State<ChatbotWidget> createState() => _ChatbotWidgetState();
}

class _ChatbotWidgetState extends State<ChatbotWidget>
    with SingleTickerProviderStateMixin {
  bool _open     = false;
  bool _expanded = false;
  bool _typing   = false;

  final List<_ChatMessage> _messages = [_kWelcome];
  final _inputCtrl  = TextEditingController();
  final _scrollCtrl = ScrollController();

  // FAB animation
  late final AnimationController _fabCtrl;
  late final Animation<double>    _fabScale;

  @override
  void initState() {
    super.initState();
    _fabCtrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180));
    _fabScale = CurvedAnimation(parent: _fabCtrl, curve: Curves.easeOut);
    _fabCtrl.forward();
  }

  @override
  void dispose() {
    _fabCtrl.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve:    Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _typing) return;

    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: trimmed));
      _inputCtrl.clear();
      _typing = true;
    });
    _scrollBottom();

    try {
      final history = _messages
          .map((m) => {'role': m.role, 'text': m.text})
          .toList();

      final res = await http
          .post(
            Uri.parse('$_kApiBase/api/chatbot'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'message': trimmed, 'history': history}),
          )
          .timeout(const Duration(seconds: 20));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        _messages.add(_ChatMessage(role: 'bot', text: data['reply'] as String));
        _typing = false;
      });
    } catch (_) {
      setState(() {
        _messages.add(const _ChatMessage(
          role: 'bot',
          text: "I'm having trouble connecting right now. "
                "Please call us at 1-888-498-2689 or visit caschooloftrucking.com.",
        ));
        _typing = false;
      });
    }
    _scrollBottom();
  }

  // ── Sizes ────────────────────────────────────────────────────────
  double get _chatWidth  => _expanded ? 360 : 300;
  double get _chatHeight => _expanded ? 500 : 340;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Chat window ──
        if (_open)
          Positioned(
            bottom: 88,
            right:  20,
            child: _buildWindow(),
          ),

        // ── FAB ──
        Positioned(
          bottom: 20,
          right:  20,
          child: ScaleTransition(
            scale: _fabScale,
            child: _buildFab(),
          ),
        ),
      ],
    );
  }

  // ── FAB button ────────────────────────────────────────────────
  Widget _buildFab() {
    return GestureDetector(
      onTap: () => setState(() => _open = !_open),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width:  60,
        height: 60,
        decoration: BoxDecoration(
          color:     _open ? _C.navyDark : _C.gold,
          shape:     BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.28),
              blurRadius: 14,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: _open
              ? const Icon(Icons.close_rounded, color: _C.white, size: 24)
              : const Icon(Icons.local_shipping_rounded,
                  color: _C.white, size: 26),
        ),
      ),
    );
  }

  // ── Chat window ───────────────────────────────────────────────
  Widget _buildWindow() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve:    Curves.easeOut,
      width:    _chatWidth,
      decoration: BoxDecoration(
        color:        _C.white,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.18),
            blurRadius: 32,
            offset:     const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildMessages(),
            _buildInput(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      color: _C.navy,
      child: Row(
        children: [
          // Avatar
          Container(
            width: 38, height: 38,
            decoration: const BoxDecoration(
              color: _C.gold, shape: BoxShape.circle),
            child: const Icon(Icons.local_shipping_rounded,
                color: _C.white, size: 20),
          ),
          const SizedBox(width: 10),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CST Admissions Assistant',
                  style: TextStyle(
                    color:      _C.white,
                    fontSize:   _expanded ? 14 : 13,
                    fontWeight: FontWeight.w600,
                  )),
                const SizedBox(height: 3),
                Row(children: [
                  Container(
                    width:  7, height: 7,
                    decoration: const BoxDecoration(
                      color: _C.green, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text('California School of Trucking',
                    style: TextStyle(
                      color:    _C.white.withOpacity(0.5),
                      fontSize: 10,
                    )),
                ]),
              ],
            ),
          ),
          // Expand toggle
          _HeaderBtn(
            icon: _expanded
                ? Icons.close_fullscreen_rounded
                : Icons.open_in_full_rounded,
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          const SizedBox(width: 4),
          // Close
          _HeaderBtn(
            icon:  Icons.close_rounded,
            onTap: () => setState(() => _open = false),
          ),
        ],
      ),
    );
  }

  // ── Messages list ─────────────────────────────────────────────
  Widget _buildMessages() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      height:   _chatHeight,
      color:    _C.offWhite,
      child: ListView.builder(
        controller:   _scrollCtrl,
        padding:      const EdgeInsets.all(14),
        itemCount:    _messages.length + (_typing ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (_typing && i == _messages.length) {
            return const Padding(
              padding: EdgeInsets.only(top: 8),
              child:   _TypingBubble(),
            );
          }
          final msg = _messages[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MessageBubble(msg: msg, expanded: _expanded),
                if (msg.showQuickReplies) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 36),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _kQuickReplies
                          .map((qr) => _QuickReplyChip(
                                label: qr.$1,
                                onTap: () => _send(qr.$2),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────
  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:  _C.white,
        border: Border(top: BorderSide(color: _C.border)),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller:  _inputCtrl,
            enabled:     !_typing,
            style: const TextStyle(fontSize: 13, color: _C.navy),
            decoration: InputDecoration(
              hintText:  'Ask about programs, tuition, enrollment...',
              hintStyle: TextStyle(
                  fontSize: 12, color: _C.muted.withOpacity(0.7)),
              filled:      true,
              fillColor:   _C.offWhite,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide:   BorderSide(color: _C.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide:   BorderSide(color: _C.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide:   const BorderSide(color: _C.gold),
              ),
            ),
            onSubmitted: _send,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _send(_inputCtrl.text),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width:  36,
            height: 36,
            decoration: BoxDecoration(
              color:  _typing ? _C.muted : _C.gold,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.send_rounded,
                color: _C.white, size: 16),
          ),
        ),
      ]),
    );
  }

  // ── Footer ────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      color: _C.white,
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Center(
        child: Text(
          'California School of Trucking · caschooloftrucking.com',
          style: TextStyle(
            fontSize:      10,
            color:         _C.navy.withOpacity(0.3),
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────

class _HeaderBtn extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onTap;
  const _HeaderBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, color: _C.white.withOpacity(0.5), size: 16),
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage msg;
  final bool         expanded;
  const _MessageBubble({required this.msg, required this.expanded});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    return Row(
      mainAxisAlignment:
          isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isUser) ...[
          // Bot avatar
          Container(
            width:  28, height: 28,
            decoration: const BoxDecoration(
                color: _C.navy, shape: BoxShape.circle),
            child: const Icon(Icons.local_shipping_rounded,
                color: _C.gold, size: 14),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 13, vertical: 10),
            constraints: BoxConstraints(
                maxWidth: expanded ? 260 : 200),
            decoration: BoxDecoration(
              color: isUser ? _C.navy : _C.white,
              borderRadius: BorderRadius.only(
                topLeft:     const Radius.circular(14),
                topRight:    const Radius.circular(14),
                bottomLeft:  Radius.circular(isUser ? 14 : 4),
                bottomRight: Radius.circular(isUser ? 4  : 14),
              ),
              border: isUser
                  ? null
                  : Border.all(color: _C.border),
            ),
            child: Text(
              msg.text,
              style: TextStyle(
                fontSize:   expanded ? 14 : 13,
                color:      isUser ? _C.white : _C.navy,
                height:     1.55,
              ),
            ),
          ),
        ),
        if (isUser) const SizedBox(width: 4),
      ],
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;
  late final List<Animation<double>>   _anims;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(3, (i) => AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true, period: Duration(milliseconds: 600 + i * 150)));
    _anims = _ctrls
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeInOut))
        .toList();
    // stagger
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _ctrls[1].forward();
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _ctrls[2].forward();
    });
    _ctrls[0].forward();
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Container(
        width:  28, height: 28,
        decoration: const BoxDecoration(
            color: _C.navy, shape: BoxShape.circle),
        child: const Icon(Icons.local_shipping_rounded,
            color: _C.gold, size: 14),
      ),
      const SizedBox(width: 8),
      Container(
        padding:     const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration:  BoxDecoration(
          color:        _C.white,
          border:       Border.all(color: _C.border),
          borderRadius: const BorderRadius.only(
            topLeft:     Radius.circular(14),
            topRight:    Radius.circular(14),
            bottomRight: Radius.circular(14),
            bottomLeft:  Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) => Padding(
            padding: EdgeInsets.only(right: i < 2 ? 4 : 0),
            child: AnimatedBuilder(
              animation: _anims[i],
              builder: (_, __) => Transform.translate(
                offset: Offset(0, -4 * _anims[i].value),
                child:  Container(
                  width:  6, height: 6,
                  decoration: const BoxDecoration(
                      color: _C.gold, shape: BoxShape.circle),
                ),
              ),
            ),
          )),
        ),
      ),
    ],
  );
}

class _QuickReplyChip extends StatefulWidget {
  final String       label;
  final VoidCallback onTap;
  const _QuickReplyChip({required this.label, required this.onTap});

  @override
  State<_QuickReplyChip> createState() => _QuickReplyChipState();
}

class _QuickReplyChipState extends State<_QuickReplyChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap:           widget.onTap,
    onTapDown:       (_) => setState(() => _hovered = true),
    onTapUp:         (_) => setState(() => _hovered = false),
    onTapCancel:     ()  => setState(() => _hovered = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:        _hovered ? _C.gold : _C.white,
        border:       Border.all(color: _C.gold),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        widget.label,
        style: TextStyle(
          fontSize:   11,
          fontWeight: FontWeight.w500,
          color:      _hovered ? _C.white : _C.gold,
        ),
      ),
    ),
  );
}