class ChatMessage {
  final String senderId;
  final String text;
  final String emotion;
  final DateTime timestamp;

  ChatMessage({
    required this.senderId,
    required this.text,
    required this.emotion,
    required this.timestamp,
  });

  /// ✅ Convert to Map for Firebase
  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'text': text,
      'emotion': emotion,
      'timestamp': timestamp.toIso8601String(), // convert DateTime → String
    };
  }

  /// ✅ Convert from Map (Firebase → ChatMessage)
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      senderId: json['senderId'] ?? '',
      text: json['text'] ?? '',
      emotion: json['emotion'] ?? 'neutral',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }
}
