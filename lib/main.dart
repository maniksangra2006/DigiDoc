import 'package:digidoc/firebase_options.dart';
import 'package:digidoc/pages/rednder.dart';
import 'package:digidoc/firebase/auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await AuthService.restoreSession();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DigiDoc',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        fontFamily: 'sans-serif',
      ),
      // AuthGatePage listens to Firebase auth state:
      // → logged-in users go directly to HomePage
      // → logged-out users see StarterPage (role picker)
      home: const AuthGatePage(),
    );
  }
}