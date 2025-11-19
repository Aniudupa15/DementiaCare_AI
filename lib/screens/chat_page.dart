import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';

import '../models/chat_message.dart';
import '../services/chat_service.dart';

class ChatPage extends StatefulWidget {
  final String patientUid;

  const ChatPage({super.key, required this.patientUid});

  @override
  ChatPageState createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> {
  late ChatService _chatService;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Speech-to-text
  late stt.SpeechToText _speech;
  bool _isListening = false;

  // Text-to-speech
  late FlutterTts _flutterTts;
  bool _autoSpeak = true;
  bool _isSpeaking = false;

  String _lastBotMessage = "";  // prevent repeated speaking

  @override
  void initState() {
    super.initState();

    _chatService = ChatService(patientUid: widget.patientUid);
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();

    _initTTS();
  }

  // ---------------------- TTS Setup ----------------------
  void _initTTS() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setVolume(1.0);

    // avoid unnecessary high pitch for a health assistant
    await _flutterTts.setPitch(0.95);

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isSpeaking = false);
      }
    });
  }

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;

    if (_lastBotMessage == text) return; // avoid repeated speaking
    _lastBotMessage = text;

    await _flutterTts.stop();
    setState(() => _isSpeaking = true);

    await _flutterTts.speak(text);
  }

  // ---------------------- SPEECH PERMISSION ----------------------
  Future<bool> _ensureMicPermission() async {
    var status = await Permission.microphone.status;

    if (status.isGranted) return true;

    status = await Permission.microphone.request();

    return status.isGranted;
  }

  // ---------------------- Speech to Text ----------------------
  void _startListening() async {
    final hasPermission = await _ensureMicPermission();
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission required')),
      );
      return;
    }

    final available = await _speech.initialize(
      onError: (e) {
        debugPrint("STT ERROR: $e");
        if (mounted) setState(() => _isListening = false);
      },
      onStatus: (status) {
        if (status == "notListening" && mounted) {
          setState(() => _isListening = false);
        }
      },
    );

    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech-to-Text unavailable')),
      );
      return;
    }

    if (!mounted) return;

    setState(() => _isListening = true);

    _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() => _controller.text = result.recognizedWords);
      },
      listenFor: const Duration(seconds: 25),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
    );
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  // ---------------------- Send Message ----------------------
  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    await _chatService.sendMessage(text);

    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _chatService.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _speech.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  // ---------------------- UI ----------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Health Assistant"),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_autoSpeak ? Icons.volume_up : Icons.volume_off),
            onPressed: () {
              setState(() => _autoSpeak = !_autoSpeak);
            },
          )
        ],
      ),

      body: Column(
        children: [
          // ---------------- Chat List ----------------
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatService.messagesStream,
              builder: (_, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;

                // Auto speak bot response (ONLY once)
                if (_autoSpeak && messages.isNotEmpty) {
                  final last = messages.last;
                  if (last.isBot && !_isSpeaking) {
                    Future.delayed(const Duration(milliseconds: 350), () {
                      _speak(last.text);
                    });
                  }
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (_, index) {
                    final msg = messages[index];
                    final isUser = !msg.isBot;

                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: msg.isBot ? () => _speak(msg.text) : null,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? Colors.blue.shade600
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.text,
                                style: TextStyle(
                                  color: isUser ? Colors.white : Colors.black87,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat("HH:mm").format(msg.timestamp),
                                style: TextStyle(
                                  color: isUser ? Colors.white70 : Colors.black54,
                                  fontSize: 11,
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ---------------- Listening Indicator ----------------
          if (_isListening)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.red.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mic, color: Colors.red.shade700),
                  const SizedBox(width: 6),
                  Text(
                    "Listening...",
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                ],
              ),
            ),

          // ---------------- Input Area ----------------
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: "Type a message...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide:
                          BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Mic Button
                  CircleAvatar(
                    backgroundColor:
                    _isListening ? Colors.red.shade100 : Colors.blue.shade50,
                    child: IconButton(
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening ? Colors.red : Colors.blue.shade700,
                      ),
                      onPressed: () {
                        _isListening ? _stopListening() : _startListening();
                      },
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Send Button
                  CircleAvatar(
                    backgroundColor: Colors.green.shade50,
                    child: IconButton(
                      icon: Icon(Icons.send, color: Colors.green.shade700),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
