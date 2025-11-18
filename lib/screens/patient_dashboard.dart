import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

import '../services/reminder_service.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  final String patientUid = 'test_patient_123'; // temporary
  final String caregiverUid = 'test_caregiver_123'; // temporary

  late final ChatService _chatService;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _db = FirebaseDatabase.instance.ref();

  Map<String, dynamic> _reminders = {};

  // 🎤 Speech-to-Text
  late stt.SpeechToText speech;
  bool isListening = false;

  // 🔊 Text-to-Speech
  late FlutterTts flutterTts;

  String selectedLanguage = "en-US";
  String selectedGender = "female";

  @override
  void initState() {
    super.initState();

    // Chat + Reminders
    _chatService = ChatService(patientUid: patientUid);
    _initializeReminders();
    _autoScrollMessages();

    // Initialize STT
    speech = stt.SpeechToText();

    // Initialize TTS
    _initTTS();
  }

  // --------------------- TTS Initialization ---------------------
  Future<void> _initTTS() async {
    flutterTts = FlutterTts();

    await flutterTts.setLanguage("en-US");
    await flutterTts.setPitch(0.9);
    await flutterTts.setSpeechRate(0.45);
    await flutterTts.setVolume(1.0);

    await setVoiceGender("female");
  }

  Future<void> changeLanguage(String langCode) async {
    setState(() => selectedLanguage = langCode);
    await flutterTts.setLanguage(langCode);
    await flutterTts.setPitch(0.9);
    await flutterTts.setSpeechRate(0.45);
  }

  Future<void> setVoiceGender(String gender) async {
    selectedGender = gender;

    var voices = await flutterTts.getVoices;
    var selected = voices.firstWhere(
      (v) => v["name"].toString().toLowerCase().contains(gender),
      orElse: () => voices.first,
    );

    await flutterTts.setVoice({
      "name": selected["name"],
      "locale": selected["locale"],
    });
  }

  Future<void> speak(String text) async {
    await flutterTts.stop();
    await flutterTts.speak(text);
  }

  // --------------------- Speech Recognition ---------------------
  void startListening() async {
    bool available = await speech.initialize();

    if (available) {
      setState(() => isListening = true);

      speech.listen(
        onResult: (result) {
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

  // --------------------- Reminder Initialization ---------------------
  void _initializeReminders() {
    ReminderService.init();
    ReminderService.requestPermissionIfNeeded();

    _db.child('reminders/$patientUid').onValue.listen((event) {
      final data = (event.snapshot.value as Map?) ?? {};

      setState(() {
        _reminders = data.map(
          (key, val) => MapEntry(key, Map<String, dynamic>.from(val)),
        );
      });

      for (var entry in _reminders.entries) {
        final reminder = entry.value;
        final iso = reminder['timeIso'] as String?;
        if (iso == null) continue;

        final when = DateTime.tryParse(iso);
        if (when == null || !when.isAfter(DateTime.now())) continue;

        ReminderService.scheduleOneTime(
          title: "Reminder: ${reminder['title']}",
          body: "It’s time for: ${reminder['title']}",
          when: when,
        );
      }
    });
  }

  // --------------------- Auto Scroll Chat ---------------------
  void _autoScrollMessages() {
    _chatService.getMessagesStream().listen((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  // --------------------- Mark Reminder Completed ---------------------
  Future<void> markCompleted(String reminderId, String title) async {
    await _db.child("reminders/$patientUid/$reminderId").update({
      "status": "completed",
      "completedAt": DateTime.now().toIso8601String(),
    });

    await _db.child("caregivers/$caregiverUid/notifications").push().set({
      "message": "Patient completed: $title",
      "time": DateTime.now().toIso8601String(),
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      _chatService.sendPatientMessage(text);
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    flutterTts.stop();
    super.dispose();
  }

  // ----------------------------- UI -----------------------------
  @override
  Widget build(BuildContext context) {
    final remindersList = _reminders.entries.toList()
      ..sort((a, b) =>
          (a.value['timeIso'] ?? '').compareTo(b.value['timeIso'] ?? ''));

    return Scaffold(
      appBar: AppBar(title: const Text('Patient Dashboard')),
      body: Column(
        children: [
          _buildLanguageAndVoiceControls(),

          // ---------------- Reminders ----------------
          _buildReminders(remindersList),

          const Divider(),

          // ---------------- Chat ----------------
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatService.getMessagesStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(10),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];

                    // 🔊 Speak AI responses
                    if (msg.senderId != patientUid) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        speak(msg.text);
                      });
                    }

                    return _buildMessageBubble(msg);
                  },
                );
              },
            ),
          ),

          _buildMessageInput(),
        ],
      ),
    );
  }

  // ---------------- UI Widgets ----------------

  Widget _buildLanguageAndVoiceControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        DropdownButton(
          value: selectedLanguage,
          items: const [
            DropdownMenuItem(value: "en-US", child: Text("English")),
            DropdownMenuItem(value: "hi-IN", child: Text("Hindi")),
            DropdownMenuItem(value: "te-IN", child: Text("Telugu")),
            DropdownMenuItem(value: "ta-IN", child: Text("Tamil")),
          ],
          onChanged: (lang) => changeLanguage(lang!),
        ),
        const SizedBox(width: 12),
        DropdownButton(
          value: selectedGender,
          items: const [
            DropdownMenuItem(value: "female", child: Text("Female Voice")),
            DropdownMenuItem(value: "male", child: Text("Male Voice")),
          ],
          onChanged: (gender) => setVoiceGender(gender!),
        ),
      ],
    );
  }

  Widget _buildReminders(List remindersList) {
    return Container(
      color: Colors.teal.shade50,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upcoming Reminders 🕒',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          if (remindersList.isEmpty) const Text('No reminders yet'),
          ...remindersList.map((r) {
            final reminder = r.value;

            return Card(
              child: ListTile(
                leading: const Icon(Icons.alarm, color: Colors.teal),
                title: Text(reminder['title']),
                subtitle: Text(reminder['timeIso']),
                trailing: reminder['status'] == 'completed'
                    ? const Text(
                        "Completed",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : ElevatedButton(
                        onPressed: () => markCompleted(
                          r.key,
                          reminder['title'],
                        ),
                        child: const Text("Done"),
                      ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.senderId == patientUid;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue.shade100 : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(message.text),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),

          const SizedBox(width: 6),

          // 🎤 Microphone
          IconButton(
            icon: Icon(
              isListening ? Icons.mic : Icons.mic_none,
              color: isListening ? Colors.red : Colors.grey,
              size: 26,
            ),
            onPressed: () {
              isListening ? stopListening() : startListening();
            },
          ),

          // Send
          IconButton(
            icon: const Icon(Icons.send, color: Colors.teal, size: 26),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
