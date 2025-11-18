import 'package:flutter/material.dart';
import 'package:dementia_assist_app/services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  String _role = 'patient';
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    setState(() => _busy = true);
    _err = null;
    try {
      await AuthService()
          .signUp(email: _email.text.trim(), password: _pw.text, role: _role);
      if (mounted) Navigator.pop(context); // go back to auth gate
    } catch (e) {
      _err = e.toString();
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 8),
            TextField(
                controller: _pw,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password')),
            const SizedBox(height: 12),
            const Text('Select role'),
            DropdownButton<String>(
              value: _role,
              items: const [
                DropdownMenuItem(value: 'patient', child: Text('Patient')),
                DropdownMenuItem(value: 'caregiver', child: Text('Caregiver')),
              ],
              onChanged: (v) => setState(() => _role = v ?? 'patient'),
            ),
            if (_err != null)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child:
                      Text(_err!, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _busy ? null : _signup,
              child: _busy
                  ? const CircularProgressIndicator()
                  : const Text('Sign up'),
            ),
          ],
        ),
      ),
    );
  }
}
