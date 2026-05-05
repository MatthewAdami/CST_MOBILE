import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/ai_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/suggestion_card.dart';
import '../widgets/topic_pill.dart';
import '../widgets/history_tab.dart';

const kPurple = Color(0xFF7C3AED);
const kNavy   = Color(0xFF0B1F3A);
const kTeal   = Color(0xFF0E9F8E);

final _topics = [
  TopicData(label: 'Pre-Trip Inspection',  color: Color(0xFF3B82F6)),
  TopicData(label: 'Air Brakes',           color: Color(0xFFEF4444)),
  TopicData(label: 'HazMat',              color: Color(0xFFF59E0B)),
  TopicData(label: 'Hours of Service',    color: Color(0xFF10B981)),
  TopicData(label: 'General Knowledge',  color: Color(0xFF7C3AED)),
  TopicData(label: 'Combination Vehicles', color: Color(0xFF6366F1)),
];

final _suggestions = [
  'What are the steps for a pre-trip inspection?',
  'Explain how air brakes work',
  'What is the stopping distance for a loaded truck at 55 mph?',
  'What documents must a CDL driver carry?',
  'Explain Hours of Service regulations',
  'What are the CDL HazMat endorsement requirements?',
  'How do I do a proper coupling procedure?',
  'What is the difference between Class A and Class B CDL?',
];

class StudyAssistantScreen extends StatefulWidget {
  const StudyAssistantScreen({super.key});

  @override
  State<StudyAssistantScreen> createState() => _StudyAssistantScreenState();
}

class _StudyAssistantScreenState extends State<StudyAssistantScreen>
    with SingleTickerProviderStateMixin {
  final _messages    = <ChatMessage>[];
  final _controller  = TextEditingController();
  final _scrollCtrl  = ScrollController();
  final _focusNode   = FocusNode();
  late final TabController _tabController;

  String? _activeTopic;
  bool    _loading    = false;
  String  _error      = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ── API calls ──────────────────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    try {
      final msgs = await AiService.fetchHistory();
      if (msgs.isNotEmpty) setState(() => _messages.addAll(msgs));
    } catch (_) {}
  }

  Future<void> _sendMessage([String? override]) async {
    final text = (override ?? _controller.text).trim();
    if (text.isEmpty || _loading) return;

    _controller.clear();
    setState(() {
      _error = '';
      _messages.add(ChatMessage(role: 'user',      content: text));
      _messages.add(ChatMessage(role: 'assistant', content: '', isLoading: true));
      _loading = true;
    });
    _scrollToBottom();

    try {
      final reply = await AiService.sendMessage(text);
      setState(() {
        _messages.removeLast();
        _messages.add(ChatMessage(role: 'assistant', content: reply));
      });
    } catch (e) {
      setState(() {
        _messages.removeLast();
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() => _loading = false);
      _scrollToBottom();
      _focusNode.requestFocus();
    }
  }

  Future<void> _clearChat() async {
    try { await AiService.clearHistory(); } catch (_) {}
    setState(() {
      _messages.clear();
      _activeTopic = null;
      _error = '';
    });
  }

  void _onTopicTap(TopicData topic) {
    setState(() => _activeTopic = topic.label);
    _tabController.animateTo(0);
    _sendMessage(
      'I want to study ${topic.label}. '
      'Give me a quick overview and then ask me a practice question.',
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          _buildHeader(),
          _buildTopicPills(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildChatTab(),
                HistoryTab(
                  messages:    _messages,
                  onClearAll:  () { _clearChat(); _tabController.animateTo(0); },
                  onStartChat: () => _tabController.animateTo(0),
                ),
              ],
            ),
          ),
          // Input bar only on chat tab
          AnimatedBuilder(
            animation: _tabController,
            builder: (_, __) =>
                _tabController.index == 0 ? _buildInputBar() : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final userMsgCount = _messages.where((m) => m.role == 'user').length;
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  // Logo
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kPurple, kTeal],
                        begin: Alignment.topLeft,
                        end:   Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  // Title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CDL Study Assistant',
                          style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700,
                            color: kNavy,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981), shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'AI-powered · Available 24/7',
                              style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // New Chat
                  if (_messages.isNotEmpty && _tabController.index == 0)
                    TextButton.icon(
                      onPressed: _clearChat,
                      icon: const Icon(Icons.refresh_rounded, size: 14),
                      label: const Text('New Chat', style: TextStyle(fontSize: 13)),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF6C757D),
                        side: const BorderSide(color: Color(0xFFE9ECEF)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                ],
              ),
            ),
            // Tabs
            TabBar(
              controller: _tabController,
              labelColor: kPurple,
              unselectedLabelColor: const Color(0xFF6C757D),
              indicatorColor: kPurple,
              indicatorWeight: 2,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: [
                const Tab(text: 'Chat'),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('History'),
                      if (userMsgCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: kPurple,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$userMsgCount',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Topic Pills ────────────────────────────────────────────────────────────

  Widget _buildTopicPills() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          const Divider(height: 1, color: Color(0xFFF1F3F5)),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemCount: _topics.length,
              itemBuilder: (_, i) => TopicPill(
                topic:    _topics[i],
                isActive: _activeTopic == _topics[i].label,
                onTap:    () => _onTopicTap(_topics[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Chat Tab ───────────────────────────────────────────────────────────────

  Widget _buildChatTab() {
    return ListView(
      controller: _scrollCtrl,
      padding:    const EdgeInsets.all(16),
      children: [
        if (_messages.isEmpty) _buildEmptyState(),
        ..._messages.map((m) => Padding(
          padding:  const EdgeInsets.only(bottom: 12),
          child:    MessageBubble(message: m),
        )),
        if (_error.isNotEmpty) _buildErrorBanner(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFEDE9FE),
            border: Border.all(color: const Color(0xFFC4B5FD), width: 1.5),
          ),
          child: const Icon(Icons.smart_toy_rounded, color: kPurple, size: 32),
        ),
        const SizedBox(height: 14),
        const Text(
          'Ready to Study?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kNavy),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ask me anything about CDL exams — air brakes, pre-trip inspection, HazMat, Hours of Service, or practice questions.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Color(0xFF6C757D), height: 1.6),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Icon(Icons.lightbulb_outline, size: 14, color: kPurple),
            const SizedBox(width: 6),
            Text(
              'SUGGESTED QUESTIONS',
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: Colors.grey[600], letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics:    const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8, crossAxisSpacing: 8,
            childAspectRatio: 2.4,
          ),
          itemCount: _suggestions.length,
          itemBuilder: (_, i) => SuggestionCard(
            text:    _suggestions[i],
            onTap:   () => _sendMessage(_suggestions[i]),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin:  const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEA),
        border: Border.all(color: const Color(0xFFF5C6CB)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC3545), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_error, style: const TextStyle(fontSize: 13, color: Color(0xFF721C24))),
          ),
          GestureDetector(
            onTap: () => setState(() => _error = ''),
            child: const Icon(Icons.close, size: 16, color: Color(0xFFDC3545)),
          ),
        ],
      ),
    );
  }

  // ── Input Bar ──────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  border: Border.all(
                    color: _controller.text.isNotEmpty ? kPurple : const Color(0xFFE9ECEF),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller:  _controller,
                        focusNode:   _focusNode,
                        maxLines:    5,
                        minLines:    1,
                        style:       const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
                        decoration:  const InputDecoration(
                          hintText:  'Ask a CDL question...',
                          hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                          border:    InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _sendMessage(),
                        textInputAction: TextInputAction.send,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 8, 8),
                      child: GestureDetector(
                        onTap: _loading ? null : _sendMessage,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            gradient: (_controller.text.trim().isNotEmpty && !_loading)
                                ? const LinearGradient(
                                    colors: [kPurple, Color(0xFF9333EA)],
                                    begin: Alignment.topLeft,
                                    end:   Alignment.bottomRight,
                                  )
                                : null,
                            color: (_controller.text.trim().isEmpty || _loading)
                                ? const Color(0xFFE9ECEF)
                                : null,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: _loading
                              ? const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Color(0xFF9CA3AF),
                                  ),
                                )
                              : Icon(
                                  Icons.send_rounded,
                                  size: 17,
                                  color: _controller.text.trim().isNotEmpty
                                      ? Colors.white
                                      : const Color(0xFF9CA3AF),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Powered by Groq AI · Tap send or press Enter',
                style: TextStyle(fontSize: 11, color: Color(0xFFADB5BD)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}