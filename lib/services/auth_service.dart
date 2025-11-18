import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseDatabase.instance.ref();

  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String role, // 'patient' | 'caregiver'
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _db.child('users/${cred.user!.uid}').set({
      'email': email,
      'role': role,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return cred;
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<void> signOut() => _auth.signOut();

  Stream<User?> authChanges() => _auth.authStateChanges();

  Future<String?> fetchRole(String uid) async {
    final snap = await _db.child('users/$uid/role').get();
    return snap.exists ? (snap.value as String) : null;
  }
}
