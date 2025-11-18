import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dementia_assist_app/auth/login_screen.dart';
import 'package:dementia_assist_app/services/auth_service.dart';
import 'package:dementia_assist_app/screens/patient_dashboard.dart';
import 'package:dementia_assist_app/screens/caregiver_dashboard.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authChanges(),
      builder: (context, snap) {
        // Not logged in → show login
        if (!snap.hasData) return const LoginScreen();

        // Logged in → load role then route
        final uid = snap.data!.uid;
        return FutureBuilder<String?>(
          future: AuthService().fetchRole(uid),
          builder: (context, roleSnap) {
            if (roleSnap.connectionState != ConnectionState.done) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }
            final role = roleSnap.data ?? 'patient';
            if (role == 'caregiver') return const CaregiverDashboard();
            return const PatientDashboard();
          },
        );
      },
    );
  }
}
