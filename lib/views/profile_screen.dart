import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import 'staff_access_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>?> _profileFuture;
  late Future<List<Map<String, dynamic>>> _staffFuture;

  User? get _user =>
      Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final uid = _user?.uid;
    _profileFuture = uid == null
        ? Future.value(null)
        : FirestoreService.instance
              .fetchUserProfile(uid)
              .catchError((_) => null);
    _staffFuture = FirestoreService.instance.fetchWorkspaceMembers();
  }

  Widget _info(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value.isEmpty ? 'Not provided' : value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = FirestoreService.instance.isWorkspaceOwner;
    final user = _user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<Map<String, dynamic>?>(
            future: _profileFuture,
            builder: (context, snapshot) {
              final profile = snapshot.data;
              final name =
                  (profile?['name'] as String?)?.trim().isNotEmpty == true
                  ? profile!['name'] as String
                  : (user?.displayName ?? '');
              final phone = (profile?['phone'] as String?) ?? '';
              final email = user?.email ?? (profile?['email'] as String?) ?? '';
              return Card(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    CircleAvatar(
                      radius: 32,
                      child: Text(
                        (name.isNotEmpty ? name : email).isEmpty
                            ? '?'
                            : (name.isNotEmpty ? name : email)[0].toUpperCase(),
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _info(Icons.badge_outlined, 'Name', name),
                    _info(Icons.email_outlined, 'Email', email),
                    _info(Icons.phone_outlined, 'Phone', phone),
                    _info(
                      Icons.verified_user_outlined,
                      'Role',
                      isOwner ? 'Owner' : 'Billing staff',
                    ),
                  ],
                ),
              );
            },
          ),
          if (isOwner) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Staff under this account',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const StaffAccessScreen(),
                      ),
                    );
                    if (mounted) setState(_load);
                  },
                  icon: const Icon(Icons.group_add_rounded),
                  label: const Text('Manage'),
                ),
              ],
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _staffFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Text('Could not load staff: ${snapshot.error}');
                }
                final members = snapshot.data ?? const [];
                if (members.isEmpty) {
                  return const Card(
                    child: ListTile(
                      leading: Icon(Icons.group_outlined),
                      title: Text('No staff accounts linked'),
                    ),
                  );
                }
                return Card(
                  child: Column(
                    children: members.map((member) {
                      final name = (member['name'] as String?) ?? '';
                      final email =
                          (member['email'] as String?) ?? 'Staff account';
                      final phone = (member['phone'] as String?) ?? '';
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person_outline_rounded),
                        ),
                        title: Text(name.isNotEmpty ? name : 'Name not set'),
                        subtitle: Text(
                          phone.isNotEmpty ? '$email\n$phone' : email,
                        ),
                        isThreeLine: phone.isNotEmpty,
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
