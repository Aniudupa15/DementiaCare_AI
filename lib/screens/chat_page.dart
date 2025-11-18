import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/chat_service.dart';
import '../models/chat_message.dart';

class ChatPage extends StatefulWidget {
  final String patientUid;

  const ChatPage({super.key, required this.patientUid});

  @override
  ChatPageState createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> {
  late ChatService _chatService;
  final TextEditingController _controller = TextEditingController();

  // 🎤 Speech
  late stt.SpeechToText speech;
  bool isListening = false;

  @override
  void initState() {
    super.initState();

    _chatService = ChatService(patientUid: widget.patientUid);
    speech = stt.SpeechToText();
  }

  void startListening() async {
    bool available = await speech.initialize();

    if (!mounted) return; // ✔ safety

    if (available) {
      setState(() => isListening = true);

      speech.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _controller.text = result.recognizedWords;
          });
        },
      );
    }
  }

  void stopListening() {
    speech.stop();
    setState(() => isListening = false);
  }

  void sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _chatService.sendPatientMessage(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Chatbot")),
      body: Column(
        children: [
          // ---------------- Chat Messages ----------------
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatService.getMessagesStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isPatient = msg.senderId == widget.patientUid;

                    return Align(
                      alignment: isPatient
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: isPatient
                              ? Colors.blue.shade100
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(msg.text),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ---------------- Input + Mic + Send ----------------
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: Colors.white,
            child: Row(
              children: [
                // Text input
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                // 🎤 Mic button
                IconButton(
                  icon: Icon(
                    isListening ? Icons.mic : Icons.mic_none,
                    color: Colors.red,
                  ),
                  onPressed: () =>
                      isListening ? stopListening() : startListening(),
                ),

                // Send button
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.green),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
