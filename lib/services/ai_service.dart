import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';

const _base = 'http://10.0.2.2:5000/api';

Future<Map<String, String>> _headers() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token') ?? '';
  return {
    'Content-Type':  'application/json',
    'Authorization': 'Bearer $token',
  };
}

class AiService {
  static Future<List<ChatMessage>> fetchHistory() async {
    final res = await http
        .get(Uri.parse('$_base/ai/history'), headers: await _headers())
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) throw Exception('Failed to load history');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = body['messages'] as List? ?? [];
    return list.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>)).toList();
  }

  static Future<String> sendMessage(String message) async {
    final res = await http
        .post(
          Uri.parse('$_base/ai/study'),
          headers: await _headers(),
          body:    jsonEncode({'message': message}),
        )
        .timeout(const Duration(seconds: 30));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['message'] ?? 'AI service error');
    }
    return body['reply'] as String;
  }

  static Future<void> clearHistory() async {
    await http
        .delete(Uri.parse('$_base/ai/history'), headers: await _headers())
        .timeout(const Duration(seconds: 10));
  }
}