import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import 'signup_screen.dart';
import '../../navigation/bottom_nav.dart';
import '../permissions/permission_request_screen.dart';
import '../onboarding/value_proposition_screen.dart';
import '../bank/bank_balance_setup_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<Map<String, dynamic>> _initFuture;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _initFuture = _checkAuthAndPermissions();
  }

  Future<Map<String, dynamic>> _checkAuthAndPermissions() async {
    final userId = await AuthService.getUserId();
    final prefs = await SharedPreferences.getInstance();
    final hasCompletedOnboarding = prefs.getBool('has_completed_onboarding') ?? false;
    final hasRequestedPermissions = prefs.getBool('has_requested_permissions') ?? false;
    final hasCompletedBankSetup = prefs.getBool('has_completed_bank_setup') ?? false;
    final biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    
    // Check if biometric auth is required
    bool requiresBiometric = false;
    if (userId != null && biometricEnabled) {
      requiresBiometric = await BiometricService.isAuthRequired();
    }
    
    return {
      'userId': userId,
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'hasRequestedPermissions': hasRequestedPermissions,
      'hasCompletedBankSetup': hasCompletedBankSetup,
      'requiresBiometric': requiresBiometric,
      'biometricEnabled': biometricEnabled,
    };
  }

  Future<void> _onPermissionsComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_requested_permissions', true);
    
    // Refresh the state to navigate to next screen
    if (mounted) {
      setState(() {
        _initFuture = _checkAuthAndPermissions();
      });
    }
  }

  Future<void> _onBankSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_bank_setup', true);
    
    // Refresh the state to navigate to home
    if (mounted) {
      setState(() {
        _initFuture = _checkAuthAndPermissions();
      });
    }
  }

  Future<void> _onBankSetupSkip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_bank_setup', true); // Mark as completed so we don't ask again
    await prefs.setBool('skipped_bank_setup', true); // Remember they skipped
    
    // Refresh the state to navigate to home
    if (mounted) {
      setState(() {
        _initFuture = _checkAuthAndPermissions();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _initFuture,
      builder: (context, snapshot) {
        // While checking, show a loading indicator
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CupertinoPageScaffold(
            child: Center(
              child: CupertinoActivityIndicator(),
            ),
          );
        }

        final data = snapshot.data;
        final userId = data?['userId'];
        final hasCompletedOnboarding = data?['hasCompletedOnboarding'] ?? false;
        final hasRequestedPermissions = data?['hasRequestedPermissions'] ?? false;
        final hasCompletedBankSetup = data?['hasCompletedBankSetup'] ?? false;
        final requiresBiometric = data?['requiresBiometric'] ?? false;
        final biometricEnabled = data?['biometricEnabled'] ?? false;

        // If no user, show sign up
        if (userId == null) {
          return const SignUpScreen();
        }

        // If biometric auth is required, show biometric auth screen
        if (biometricEnabled && requiresBiometric && !_isAuthenticated) {
          return _buildBiometricAuthScreen();
        }

        // If user exists but hasn't completed onboarding, show value proposition
        if (!hasCompletedOnboarding) {
          return const ValuePropositionScreen();
        }

        // If user completed onboarding but hasn't been asked for permissions, show permission screen
        if (!hasRequestedPermissions) {
          return PermissionRequestScreen(
            onComplete: _onPermissionsComplete,
          );
        }

        // If permissions granted but bank setup not completed, show bank setup screen
        if (!hasCompletedBankSetup) {
          return BankBalanceSetupScreen(
            onComplete: _onBankSetupComplete,
            onSkip: _onBankSetupSkip,
          );
        }

        // User is authenticated, permissions handled, and bank setup completed
        return const BottomNavigation();
      },
    );
  }

  Widget _buildBiometricAuthScreen() {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.lock_shield_fill,
                size: 80,
                color: CupertinoColors.systemGrey,
              ),
              const SizedBox(height: 24),
              const Text(
                'Authentication Required',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please authenticate to access Undiyal',
                style: TextStyle(
                  fontSize: 16,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              const SizedBox(height: 32),
              CupertinoButton.filled(
                onPressed: () async {
                  final result = await BiometricService.authenticate();
                  if (result['success']) {
                    setState(() {
                      _isAuthenticated = true;
                    });
                  } else {
                    // Show error
                    if (mounted) {
                      showCupertinoDialog(
                        context: context,
                        builder: (context) => CupertinoAlertDialog(
                          title: const Text('Authentication Failed'),
                          content: Text(result['message']),
                          actions: [
                            CupertinoDialogAction(
                              child: const Text('OK'),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      );
                    }
                  }
                },
                child: const Text('Authenticate'),
              ),
              const SizedBox(height: 16),
              CupertinoButton(
                onPressed: () async {
                  await AuthService.logout();
                  if (mounted) {
                    setState(() {
                      _initFuture = _checkAuthAndPermissions();
                    });
                  }
                },
                child: const Text('Log Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

