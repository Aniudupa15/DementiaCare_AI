// lib/services/background_service.dart
import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

/// Call this during app startup (before runApp)
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
      autoStartOnBoot: true,
    ),
    iosConfiguration: IosConfiguration(
      // auto start not supported on iOS the same way
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  // Start the service (Android)
  service.startService();
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  // iOS background behavior is limited. Keep minimal work here.
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  // Required for Android foreground
  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: "Dementia Assist",
      content: "Background voice service is running",
    );
  }

  final FlutterTts tts = FlutterTts();

  // Set some default voice parameters
  tts.setVolume(1.0);
  tts.setSpeechRate(0.45);
  tts.setPitch(0.9);

  // Listen for "speak" events
  service.on('speak').listen((event) async {
    try {
      final text = (event as Map?)?['text']?.toString() ?? '';
      if (text.isNotEmpty) {
        await tts.stop();
        await tts.speak(text);
      }
    } catch (e) {
      // ignore errors in background
    }
  });

  // Optional: keep service alive by sending periodic heartbeat
  Timer.periodic(const Duration(minutes: 15), (timer) {
    service
        .invoke('heartbeat', {'timestamp': DateTime.now().toIso8601String()});
  });
}
