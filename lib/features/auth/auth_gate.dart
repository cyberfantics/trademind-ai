import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_shell.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'verify_email_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? _introSeen;

  static const _introSeenKey = 'trademind_intro_seen';

  @override
  void initState() {
    super.initState();
    _loadIntroStatus();
  }

  Future<void> _loadIntroStatus() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _introSeen = prefs.getBool(_introSeenKey) ?? false;
    });
  }

  Future<void> _finishIntro() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_introSeenKey, true);

    if (!mounted) return;

    setState(() {
      _introSeen = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_introSeen == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          if (_introSeen == false) {
            return OnboardingScreen(
              onFinished: _finishIntro,
            );
          }

          return const LoginScreen();
        }

        if (!user.emailVerified) {
          return const VerifyEmailScreen();
        }

        return const HomeShell();
      },
    );
  }
}
