import 'package:flutter/material.dart';
import 'package:dementia_assist_app/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _busy = true);
    _err = null;
    try {
      await AuthService().signIn(email: _email.text.trim(), password: _pw.text);
    } catch (e) {
      _err = e.toString();
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 8),
            TextField(
                controller: _pw,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password')),
            if (_err != null)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child:
                      Text(_err!, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _busy ? null : _login,
              child: _busy
                  ? const CircularProgressIndicator()
                  : const Text('Sign in'),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/signup'),
              child: const Text('Create account'),
            )
          ],
        ),
      ),
    );
  }
}
