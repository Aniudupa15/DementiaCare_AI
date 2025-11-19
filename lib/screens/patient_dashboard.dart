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
  final String patientUid = 'test_patient_123';
  final String caregiverUid = 'test_caregiver_123';

  late final ChatService _chatService;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final _db = FirebaseDatabase.instance.ref();

  Map<String, dynamic> _reminders = {};

  // STT
  late stt.SpeechToText _speech;
  bool _isListening = false;

  // TTS
  late FlutterTts _tts;
  bool _isBotSpeaking = false;
  String selectedLanguage = "en-US";
  String selectedGender = "female";

  String _lastSpokenMessage = ""; // prevents repeat reading

  @override
  void initState() {
    super.initState();

    _chatService = ChatService(patientUid: patientUid);
    _speech = stt.SpeechToText();
    _tts = FlutterTts();

    _initTTS();
    _listenForChatUpdates();
    _initializeReminders();
  }

  // ---------------- TTS ----------------
  Future<void> _initTTS() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(0.9);
    await _tts.setVolume(1.0);

    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isBotSpeaking = false);
    });

    setVoiceGender("female");
  }

  Future<void> setVoiceGender(String gender) async {
    selectedGender = gender;
    final voices = await _tts.getVoices;

    final selected = voices.firstWhere(
          (v) => v["name"].toString().toLowerCase().contains(gender),
      orElse: () => voices.isNotEmpty ? voices.first : {"name": "", "locale": "en-US"},
    );

    if (selected["name"] != null && selected["name"] != "") {
      await _tts.setVoice({
        "name": selected["name"],
        "locale": selected["locale"],
      });
    }
  }

  Future<void> changeLanguage(String lang) async {
    selectedLanguage = lang;
    await _tts.setLanguage(lang);
  }

  Future<void> _speak(String text) async {
    if (_lastSpokenMessage == text) return; // prevent duplicate speaking
    _lastSpokenMessage = text;

    await _tts.stop();
    setState(() => _isBotSpeaking = true);
    await _tts.speak(text);
  }

  // ---------------- STT ----------------
  void startListening() async {
    final ok = await _speech.initialize();
    if (!ok) return;

    setState(() => _isListening = true);

    _speech.listen(onResult: (result) {
      setState(() => _controller.text = result.recognizedWords);
    });
  }

  void stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  // ---------------- Listen for chat updates ----------------
  void _listenForChatUpdates() {
    _chatService.messagesStream.listen((msgs) {
      if (msgs.isNotEmpty) {
        final last = msgs.last;

        if (last.senderId != patientUid) {
          Future.delayed(const Duration(milliseconds: 300), () {
            _speak(last.text);
          });
        }
      }

      // Auto-scroll
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  // ---------------- Reminders ----------------
  void _initializeReminders() {
    ReminderService.init();
    ReminderService.requestPermissionIfNeeded();

    _db.child("reminders/$patientUid").onValue.listen((event) {
      final raw = event.snapshot.value;
      if (raw == null) {
        setState(() => _reminders = {});
        return;
      }

      final mapped = Map<String, dynamic>.from(raw as Map);

      setState(() => _reminders = mapped);

      // Schedule reminders
      for (var entry in mapped.entries) {
        final r = Map<String, dynamic>.from(entry.value as Map);
        final iso = r["timeIso"] as String?;

        if (iso != null) {
          final dt = DateTime.tryParse(iso);
          if (dt != null && dt.isAfter(DateTime.now())) {
            ReminderService.scheduleOneTime(
              title: "Reminder: ${r['title']}",
              body: "It's time for: ${r['title']}",
              when: dt,
            );
          }
        }
      }
    });
  }

  // ---------------- Send message ----------------
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    await _chatService.sendMessage(text);
  }

  // ---------------- Mark reminder completed ----------------
  Future<void> markCompleted(String reminderId, String title) async {
    try {
      // Update reminder status
      await _db.child("reminders/$patientUid/$reminderId").update({
        "status": "completed",
        "completedAt": DateTime.now().toIso8601String(),
      });

      // Notify caregiver (push notification entry in DB)
      await _db.child("caregivers/$caregiverUid/notifications").push().set({
        "message": "Patient completed: $title",
        "time": DateTime.now().toIso8601String(),
        "patientId": patientUid,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Marked "$title" as completed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark reminder: $e')),
        );
      }
    }
  }

  // ---------------- Dispose ----------------
  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    _tts.stop();
    _speech.cancel();
    super.dispose();
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final sortedReminders = _reminders.entries.toList()
      ..sort((a, b) {
        final t1 = a.value["timeIso"] ?? "";
        final t2 = b.value["timeIso"] ?? "";
        return t1.compareTo(t2);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text("Patient Dashboard"),
      ),
      body: Column(
        children: [
          _buildLanguageAndVoiceControls(),
          _buildReminders(sortedReminders),
          const Divider(),
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatService.messagesStream,
              builder: (_, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final msgs = snapshot.data!;

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(10),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) => _buildMessageBubble(msgs[i]),
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  // ---------------- Widgets ----------------

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
          onChanged: (v) => changeLanguage(v!),
        ),
        const SizedBox(width: 10),
        DropdownButton(
          value: selectedGender,
          items: const [
            DropdownMenuItem(value: "female", child: Text("Female Voice")),
            DropdownMenuItem(value: "male", child: Text("Male Voice")),
          ],
          onChanged: (v) => setVoiceGender(v!),
        ),
      ],
    );
  }

  Widget _buildReminders(List reminders) {
    return Container(
      padding: const EdgeInsets.all(10),
      color: Colors.teal.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Upcoming Reminders 🕒",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (reminders.isEmpty) const Text("No reminders available"),
          ...reminders.map((entry) {
            final reminder = Map<String, dynamic>.from(entry.value);
            final key = entry.key as String;

            return Card(
              child: ListTile(
                leading: const Icon(Icons.alarm, color: Colors.teal),
                title: Text(reminder["title"] ?? "Untitled"),
                subtitle: Text(reminder["timeIso"] ?? "--"),
                trailing: reminder["status"] == "completed"
                    ? const Text("Completed",
                    style: TextStyle(color: Colors.green))
                    : ElevatedButton(
                  onPressed: () =>
                      markCompleted(key, reminder["title"] ?? "Reminder"),
                  child: const Text("Done"),
                ),
              ),
            );
          })
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.senderId == patientUid;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue.shade100 : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(msg.text),
      ),
    );
  }

  Widget _buildMessageInput() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: "Type a message...",
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: _isListening ? Colors.red : Colors.grey,
                size: 26,
              ),
              onPressed: () => _isListening ? stopListening() : startListening(),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Colors.teal, size: 26),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}
