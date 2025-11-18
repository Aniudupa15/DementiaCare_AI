import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'auth/auth_gate.dart';
import 'auth/signup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // (Optional) connect to emulators here if you want
  // FirebaseDatabase.instance.useDatabaseEmulator('127.0.0.1', 9000);

  runApp(const DementiaAssistApp());
}

class DementiaAssistApp extends StatelessWidget {
  const DementiaAssistApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dementia Assist',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const AuthGate(),
      routes: {
        '/signup': (_) => const SignupScreen(),
      },
    );
  }
}
