// chat_service.dart — REST-based Gemini Chat (Production Ready)

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/chat_message.dart';

class ChatService {
  static const String apiKey = 'AIzaSyDcfZz19NIJe8Zy1mmm3J01cKUQgrllUeY';
  static const String baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent';

  final String patientUid;
  final List<ChatMessage> _messages = [];
  final StreamController<List<ChatMessage>> _messagesController =
  StreamController<List<ChatMessage>>.broadcast();

  ChatService({required this.patientUid}) {
    _addBotMessage(
        "Hello! I'm your health assistant. How can I support you today?");
  }

  Stream<List<ChatMessage>> get messagesStream =>
      _messagesController.stream;

  void dispose() {
    _messagesController.close();
  }

  // ---------------------------
  // INTERNAL HELPERS
  // ---------------------------

  void _addBotMessage(String text) {
    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: "bot",
      text: text,
      timestamp: DateTime.now(),
      isBot: true,
    );

    _messages.add(message);
    _messagesController.add(List.from(_messages));
  }

  void _addUserMessage(String text) {
    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: patientUid,
      text: text,
      timestamp: DateTime.now(),
      isBot: false,
    );

    _messages.add(message);
    _messagesController.add(List.from(_messages));
  }

  // ---------------------------
  // PUBLIC API
  // ---------------------------

  Future<void> sendMessage(String userMessage) async {
    _addUserMessage(userMessage);

    try {
      final reply = await _getBotResponse(userMessage);
      _addBotMessage(reply);
    } catch (e) {
      _addBotMessage(
          "I’m having trouble connecting right now. Please try again.");
    }
  }

  // ---------------------------
  // GEMINI REQUEST
  // ---------------------------

  Future<String> _getBotResponse(String userMsg) async {
    final history = _messages
        .map((m) => "${m.isBot ? 'Assistant' : 'User'}: ${m.text}")
        .join('\n');

    final prompt = '''
You are a medical support assistant.  
Provide clear, empathetic, medically accurate guidance.  
Do NOT give serious diagnosis or emergency advice.  
For emergencies: always recommend calling local emergency services.

CONVERSATION HISTORY:
$history

USER MESSAGE:
$userMsg

Respond clearly and concisely.
''';

    final response = await http.post(
      Uri.parse("$baseUrl?key=$apiKey"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.35,
          "maxOutputTokens": 500
        }
      }),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final text =
          body["candidates"][0]["content"]["parts"][0]["text"] ?? "";

      return text.trim();
    } else {
      print("Gemini error: ${response.body}");
      return "Sorry, I could not process that. Please try again.";
    }
  }
}
