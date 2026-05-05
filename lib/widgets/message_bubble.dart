import 'package:flutter/material.dart';
import '../models/chat_message.dart';
const Color kPurple = Color(0xFF6366F1);
const Color kTeal   = Color(0xFF2DD4BF);
const Color kNavy   = Color(0xFF091925);
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const MessageBubble({super.key, required this.message});

  bool get isUser => message.role == 'user';

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isUser) ...[
          _Avatar(isUser: false),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Container(
            padding:    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              gradient: isUser
                  ? const LinearGradient(
                      colors: [kPurple, Color(0xFF9333EA)],
                      begin: Alignment.topLeft,
                      end:   Alignment.bottomRight,
                    )
                  : null,
              color:   isUser ? null : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft:     const Radius.circular(18),
                topRight:    const Radius.circular(18),
                bottomLeft:  Radius.circular(isUser ? 18 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 18),
              ),
              border: isUser
                  ? null
                  : Border.all(color: const Color(0xFFE9ECEF)),
              boxShadow: [
                BoxShadow(
                  color: isUser
                      ? kPurple.withOpacity(0.25)
                      : Colors.black.withOpacity(0.06),
                  blurRadius: isUser ? 10 : 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: message.isLoading
                ? const _TypingDots()
                : Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 14,
                      height:   1.65,
                      color:    isUser ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
          ),
        ),
        if (isUser) ...[
          const SizedBox(width: 8),
          _Avatar(isUser: true),
        ],
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final bool isUser;
  const _Avatar({required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34, height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isUser ? null : const LinearGradient(
          colors: [kPurple, kTeal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        color: isUser ? kNavy : null,
      ),
      child: Icon(
        isUser ? Icons.person_rounded : Icons.smart_toy_rounded,
        color: Colors.white,
        size: 16,
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>>   _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync:    this,
        duration: const Duration(milliseconds: 600),
      )..repeat(reverse: true, period: Duration(milliseconds: 1200 + i * 200)),
    );
    _animations = _controllers
        .map((c) => Tween<double>(begin: 0, end: -6).animate(
              CurvedAnimation(parent: c, curve: Curves.easeInOut),
            ))
        .toList();

    for (var i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _animations[i],
            builder: (_, __) => Transform.translate(
              offset: Offset(0, _animations[i].value),
              child: Container(
                width: 6, height: 6,
                margin: const EdgeInsets.only(right: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFF9CA3AF), shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}