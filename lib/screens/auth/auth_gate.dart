import 'package:flutter/cupertino.dart';
import '../../services/auth_service.dart';
import 'signup_screen.dart';
import '../../navigation/bottom_nav.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // Use a FutureBuilder to check auth status
  late Future<int?> _userIdFuture;

  @override
  void initState() {
    super.initState();
    _userIdFuture = AuthService.getUserId();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int?>(
      future: _userIdFuture,
      builder: (context, snapshot) {
        // While checking, show a loading indicator
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CupertinoPageScaffold(
            child: Center(
              child: CupertinoActivityIndicator(),
            ),
          );
        }

        // If user ID exists, go to Home
        if (snapshot.hasData && snapshot.data != null) {
          return const BottomNavigation();
        }

        // Otherwise, show Sign Up
        return const SignUpScreen();
      },
    );
  }
}

