// Powered by Md. Atikur Rahman Mridha
// Author by Md. Atikur Rahman iiMridha (hidden)

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'reminder_service.dart';
import 'services/auth_service.dart';
import 'screens/root_shell.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }
  try {
    await ReminderService.instance.init();
  } catch (e) {
    debugPrint('ReminderService init error: $e');
  }
  runApp(const MoneRakhoApp());
}

class MoneRakhoApp extends StatelessWidget {
  const MoneRakhoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mone Rakho',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6200EE),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: AuthService.instance.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return const RootShell();
          }
          return LoginScreen(
            onAuthenticated: () {},
          );
        },
      ),
    );
  }
}
