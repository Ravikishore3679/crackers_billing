import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class StaffAccessScreen extends StatefulWidget {
  const StaffAccessScreen({super.key});

  @override
  State<StaffAccessScreen> createState() => _StaffAccessScreenState();
}

class _StaffAccessScreenState extends State<StaffAccessScreen> {
  final TextEditingController _emailController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _membersFuture;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _membersFuture = FirestoreService.instance.fetchWorkspaceMembers();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _invite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid staff email address.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirestoreService.instance.inviteBillingStaff(email);
      _emailController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Invite saved. Staff can sign in with this email to join.',
          ),
        ),
      );
      setState(() {
        _membersFuture = FirestoreService.instance.fetchWorkspaceMembers();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not invite staff: $error')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _revoke(String uid) async {
    try {
      await FirestoreService.instance.revokeWorkspaceMember(uid);
      if (!mounted) return;
      setState(() {
        _membersFuture = FirestoreService.instance.fetchWorkspaceMembers();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Staff access revoked.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not revoke access: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff access')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Staff email',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _invite,
              icon: _isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Invite billing staff'),
            ),
          ),
          const SizedBox(height: 24),
          Text('Current staff', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _membersFuture,
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
                return const ListTile(
                  leading: Icon(Icons.group_outlined),
                  title: Text('No staff accounts linked'),
                );
              }
              return Column(
                children: members.map((member) {
                  final uid = member['uid'] as String? ?? '';
                  final email = member['email'] as String? ?? 'Staff account';
                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline_rounded),
                    ),
                    title: Text(email),
                    subtitle: const Text('Billing, expenses, and reports'),
                    trailing: IconButton(
                      tooltip: 'Revoke staff access',
                      onPressed: uid.isEmpty ? null : () => _revoke(uid),
                      icon: const Icon(Icons.person_remove_alt_1_rounded),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
