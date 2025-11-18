import 'package:firebase_database/firebase_database.dart';
import '../models/chat_message.dart';

class ChatService {
  final String patientUid;
  final DatabaseReference _chatRef;

  ChatService({required this.patientUid})
      : _chatRef = FirebaseDatabase.instance.ref('chats/$patientUid/messages') {
    // 👇 use emulator for local testing
    //FirebaseDatabase.instance.useDatabaseEmulator('127.0.0.1', 9000);
  }

  /// Send patient message to Firebase
  Future<void> sendPatientMessage(String text) async {
    final message = ChatMessage(
      senderId: patientUid,
      text: text,
      emotion: 'neutral',
      timestamp: DateTime.now(),
    );
    await _chatRef.push().set(message.toJson());
  }

  /// Stream messages in real time
  Stream<List<ChatMessage>> getMessagesStream() {
    return _chatRef.onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return [];

      final Map<dynamic, dynamic> messagesMap = data as Map<dynamic, dynamic>;

      final messages = messagesMap.entries.map((entry) {
        final value = Map<String, dynamic>.from(entry.value);
        return ChatMessage.fromJson(value);
      }).toList();

      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    });
  }
}
