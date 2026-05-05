import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chat_message.dart';
const Color kPurple = Color(0xFF6366F1);
const Color kTeal   = Color(0xFF2DD4BF);
const Color kNavy   = Color(0xFF091925);
class HistoryTab extends StatelessWidget {
  final List<ChatMessage> messages;
  final VoidCallback      onClearAll;
  final VoidCallback      onStartChat;

  const HistoryTab({
    super.key,
    required this.messages,
    required this.onClearAll,
    required this.onStartChat,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) return _buildEmpty();

    // Group messages by date
    final grouped = <String, List<(ChatMessage, int)>>{};
    for (var i = 0; i < messages.length; i++) {
      final msg  = messages[i];
      final date = msg.createdAt != null
          ? DateFormat('EEEE, MMMM d, y').format(msg.createdAt!)
          : 'This Session';
      grouped.putIfAbsent(date, () => []);
      grouped[date]!.add((msg, i));
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Conversation History',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kNavy),
        ),
        const SizedBox(height: 20),
        for (final entry in grouped.entries) ...[
          _dateDivider(entry.key),
          const SizedBox(height: 12),
          for (final pair in entry.value.where((p) => p.$1.role == 'user'))
            _QACard(
              question:   pair.$1,
              answer:     pair.$2 + 1 < messages.length ? messages[pair.$2 + 1] : null,
            ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        // Clear all button
        OutlinedButton.icon(
          onPressed: onClearAll,
          icon:      const Icon(Icons.delete_outline, size: 15),
          label:     const Text('Clear All History'),
          style:     OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFDC3545),
            side: const BorderSide(color: Color(0xFFF5C6CB)),
            backgroundColor: const Color(0xFFFDECEA),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history_rounded, size: 48, color: Color(0xFFE9ECEF)),
          const SizedBox(height: 14),
          const Text(
            'No conversation history yet.',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF6C757D)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Start chatting to build your study history!',
            style: TextStyle(fontSize: 13, color: Color(0xFFADB5BD)),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onStartChat,
            icon:      const Icon(Icons.chat_bubble_outline, size: 15),
            label:     const Text('Start Studying'),
            style:     ElevatedButton.styleFrom(
              backgroundColor: kPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateDivider(String label) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFE9ECEF))),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color:  const Color(0xFFF8F9FA),
            border: Border.all(color: const Color(0xFFE9ECEF)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: Color(0xFFADB5BD), letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: Color(0xFFE9ECEF))),
      ],
    );
  }
}

class _QACard extends StatelessWidget {
  final ChatMessage  question;
  final ChatMessage? answer;
  const _QACard({required this.question, this.answer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:     const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color:  Colors.white,
        border: Border.all(color: const Color(0xFFE9ECEF)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4, offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Question
          Container(
            padding:    const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF5F3FF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: const BoxDecoration(color: kPurple, shape: BoxShape.circle),
                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 14),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question.content,
                        style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: kNavy, height: 1.5,
                        ),
                      ),
                      if (question.createdAt != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          DateFormat.jm().format(question.createdAt!),
                          style: const TextStyle(fontSize: 10, color: Color(0xFFADB5BD)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Answer
          if (answer != null && answer!.role == 'assistant')
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [kPurple, kTeal]),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 14),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      answer!.content,
                      style: const TextStyle(
                        fontSize: 12, color: Color(0xFF374151), height: 1.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}