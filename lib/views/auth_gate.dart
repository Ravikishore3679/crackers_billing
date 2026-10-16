import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import 'app_shell.dart';
import 'sign_in_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseReady = Firebase.apps.isNotEmpty;

    if (!firebaseReady) {
      return const _FirebaseNotConfiguredScreen();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          return FutureBuilder<void>(
            future: FirestoreService.instance.prepareWorkspace(user),
            builder: (context, workspaceSnapshot) {
              if (workspaceSnapshot.connectionState != ConnectionState.done) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (workspaceSnapshot.hasError) {
                final error = workspaceSnapshot.error.toString();
                final message = error.contains('permission-denied')
                    ? 'Firestore blocked workspace access.\n\n$error\n\nIf rules were just deployed, sign out and sign back in to refresh your auth token.'
                    : 'Unable to load workspace access:\n\n$error';
                return Scaffold(
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(message),
                    ),
                  ),
                );
              }
              return const AppShell();
            },
          );
        }

        return const SignInScreen();
      },
    );
  }
}

class _FirebaseNotConfiguredScreen extends StatelessWidget {
  const _FirebaseNotConfiguredScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 64,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              Text(
                'Firebase is not configured yet',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'Add your Firebase project config (google-services.json or firebase_options.dart) to enable authentication.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
