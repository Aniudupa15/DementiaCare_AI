import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:dementia_assist_app/services/auth_service.dart';

class CaregiverDashboard extends StatefulWidget {
  const CaregiverDashboard({super.key});

  @override
  State<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends State<CaregiverDashboard> {
  final _db = FirebaseDatabase.instance.ref();

  final _patientIdCtrl = TextEditingController(text: 'test_patient_123');
  final _titleCtrl = TextEditingController();

  DateTime _when = DateTime.now().add(const Duration(minutes: 1));

  @override
  void dispose() {
    _patientIdCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  // ----------------------- ADD REMINDER -----------------------
  Future<void> _addReminder() async {
    final pid = _patientIdCtrl.text.trim();

    if (pid.isEmpty || _titleCtrl.text.trim().isEmpty) return;

    final id = _db.child('reminders/$pid').push().key!;

    await _db.child('reminders/$pid/$id').set({
      'title': _titleCtrl.text.trim(),
      'timeIso': _when.toIso8601String(),
      'createdBy': FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
      'status': 'scheduled',
    });

    _titleCtrl.clear();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reminder added successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pid = _patientIdCtrl.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caregiver Dashboard'),
        actions: [
          IconButton(
            onPressed: () => AuthService().signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),

      // -------------------------- BODY --------------------------
      body: Column(
        children: [
          // ------------------- Create a Reminder -------------------
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _patientIdCtrl,
                  decoration: const InputDecoration(labelText: 'Patient UID'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reminder title (e.g., Take medication)',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'When: ${_when.toString().split(".").first}',
                      ),
                    ),
                    TextButton(
                      child: const Text('Pick time'),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _when,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );

                        if (date == null) return;

                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(_when),
                        );

                        if (time == null) return;

                        setState(() {
                          _when = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      },
                    ),
                    ElevatedButton(
                      onPressed: _addReminder,
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(),

          // ------------------ NOTIFICATION STREAM ------------------
          Container(
            padding: const EdgeInsets.all(10),
            alignment: Alignment.centerLeft,
            child: const Text(
              "Patient Activity Notifications 🔔",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),

          SizedBox(
            height: 150,
            child: StreamBuilder(
              stream: _db
                  .child('caregivers/test_caregiver_123/notifications')
                  .onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData ||
                    snapshot.data!.snapshot.value == null) {
                  return const Center(child: Text("No notifications yet"));
                }

                final data =
                    (snapshot.data!.snapshot.value as Map).values.toList();

                return ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (_, i) {
                    final n = data[i];
                    return ListTile(
                      leading:
                          const Icon(Icons.check_circle, color: Colors.green),
                      title: Text(n["message"]),
                      subtitle: Text(n["time"]),
                    );
                  },
                );
              },
            ),
          ),

          const Divider(),

          // ------------------- REMINDERS LIST -------------------
          Expanded(
            child: StreamBuilder(
              stream: _db.child('reminders/$pid').onValue,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = (snap.data?.snapshot.value as Map?) ?? {};
                final items = data.entries
                    .map((e) => {'id': e.key, ...(e.value as Map)})
                    .toList()
                  ..sort((a, b) => (a['timeIso'] as String)
                      .compareTo(b['timeIso'] as String));

                if (items.isEmpty) {
                  return const Center(child: Text('No reminders yet'));
                }

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final r = items[i];
                    return ListTile(
                      leading: const Icon(Icons.alarm, color: Colors.teal),
                      title: Text(r['title']),
                      subtitle: Text('Time: ${r['timeIso']}'),
                      trailing: Text(r['status'] ?? ''),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
