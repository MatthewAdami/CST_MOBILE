// lib/screens/messages/student_messages_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'components/inbox_drawer.dart';
import 'components/chat_window.dart';

const _kPurple = Color(0xFF7C3AED);
const _kNavy   = Color(0xFF0B1F3A);

class StudentMessagesScreen extends StatefulWidget {
  const StudentMessagesScreen({super.key});
  @override
  State<StudentMessagesScreen> createState() => _StudentMessagesScreenState();
}

class _StudentMessagesScreenState extends State<StudentMessagesScreen> {
  Map<String, dynamic>? _activeConvo;
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs    = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user') ?? '';
    if (userJson.isNotEmpty) {
      setState(() {
        _currentUser = jsonDecode(userJson);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width    = MediaQuery.of(context).size.width;
    final isMobile = width < 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: isMobile
          ? _mobileLayout()
          : _desktopLayout(),
    );
  }

  Widget _desktopLayout() => Row(
    children: [
      SizedBox(
        width: 300,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: InboxDrawer(
            currentUser:          _currentUser,
            activeConversation:   _activeConvo,
            onSelectConversation: (convo) => setState(() => _activeConvo = convo),
          ),
        ),
      ),
      Expanded(
        child: _activeConvo != null
            ? ChatWindow(conversation: _activeConvo!, currentUser: _currentUser)
            : const _EmptyState(),
      ),
    ],
  );

  Widget _mobileLayout() => _activeConvo != null
      ? ChatWindow(
          conversation: _activeConvo!,
          currentUser:  _currentUser,
          onBack: () => setState(() => _activeConvo = null),
        )
      : InboxDrawer(
          currentUser:          _currentUser,
          activeConversation:   _activeConvo,
          onSelectConversation: (convo) => setState(() => _activeConvo = convo),
        );
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color:        const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(32),
          ),
          child: const Icon(Icons.message_rounded, size: 28, color: _kPurple),
        ),
        const SizedBox(height: 12),
        const Text('Your Messages',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
            color: _kNavy, fontFamily: 'Inter')),
        const SizedBox(height: 6),
        const SizedBox(
          width: 260,
          child: Text(
            'Select a conversation from the left or start a new one to message your instructor.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontFamily: 'Inter'),
          ),
        ),
      ],
    ),
  );
}