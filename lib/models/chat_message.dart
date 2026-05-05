class ChatMessage {
  final String  role;       // 'user' | 'assistant'
  final String  content;
  final bool    isLoading;
  final DateTime? createdAt;

  const ChatMessage({
    required this.role,
    required this.content,
    this.isLoading = false,
    this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    role:      json['role'] as String,
    content:   json['content'] as String,
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'] as String)
        : null,
  );
}