import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_options.dart';
import 'views/auth_gate.dart';

const String googleWebClientId =
    '162682850132-pb5alb13lnmcvhagkfeu7t1l5mtoaocv.apps.googleusercontent.com';
const String googleIOSClientId =
    '162682850132-g5600hb6dshqullif2i200oki9k74nus.apps.googleusercontent.com';
const String googleServerClientId =
    '162682850132-pb5alb13lnmcvhagkfeu7t1l5mtoaocv.apps.googleusercontent.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await GoogleSignIn.instance.initialize();
  } else {
    await GoogleSignIn.instance.initialize(
      clientId: googleIOSClientId,
      serverClientId: googleServerClientId,
    );
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        library: 'Firebase initialization',
        context: ErrorDescription('Firebase could not be initialized with the project config.'),
      ),
    );
  }

  runApp(const CrackersBillingApp());
}

class CrackersBillingApp extends StatelessWidget {
  const CrackersBillingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crackers Sales & Invoices',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}
