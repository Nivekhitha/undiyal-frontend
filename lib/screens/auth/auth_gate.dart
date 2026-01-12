import 'package:flutter/cupertino.dart';
import 'signup_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Show sign up screen first, user can navigate to login
    return const SignUpScreen();
  }
}

