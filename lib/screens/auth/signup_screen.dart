import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/constants.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../services/transaction_storage_service.dart';
import '../../services/sms_expense_service.dart';
import 'login_screen.dart';
import 'auth_gate.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _collegeController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _collegeController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  void _handleSignUp() async {
    // Simple validation
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _collegeController.text.isEmpty ||
        _cityController.text.isEmpty ||
        _stateController.text.isEmpty) {
      _showAlert('Please fill in all fields');
      return;
    }

    // Show loading
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CupertinoAlertDialog(
        content: Padding(
          padding: EdgeInsets.all(20),
          child: CupertinoActivityIndicator(),
        ),
      ),
    );

    try {
      // Call sign up API
      final result = await AuthService.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        college: _collegeController.text,
        city: _cityController.text,
        state: _stateController.text,
      );

      // Save user_id and email locally
      if (result['user_id'] != null && result['email'] != null) {
        await AuthService.saveUserData(result['user_id'], result['email']);
        
        // Clear all old local data for new user
        await TransactionStorageService.clearAllData();
        await SmsExpenseService.clearAllData();
        
        // Reset onboarding flow flags so new user goes through full setup
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('has_completed_onboarding');
        await prefs.remove('has_requested_permissions');
        await prefs.remove('has_completed_bank_setup');
        await prefs.remove('skipped_bank_setup');
        
        // Save Profile Name
        await ProfileService.saveProfile(
          name: _nameController.text,
          email: result['email'],
        );
      }

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Navigate to permission request screen for new user
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          CupertinoPageRoute(
            builder: (context) => const AuthGate(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      _showAlert('Sign up failed: ${e.toString()}');
    }
  }

  void _showAlert(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Required'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(AppConstants.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              // Logo/Icon
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.money_dollar_circle_fill,
                    size: 60,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // Title
              Text(
                'Create Account',
                style: AppTextStyles.h1.copyWith(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Sign up to get started',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
               // Name field
              Text(
                'Full Name',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _nameController,
                placeholder: 'Enter your full name',
                textCapitalization: TextCapitalization.words,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 20),
              // Email field
              Text(
                'Email',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _emailController,
                placeholder: 'Enter your email',
                keyboardType: TextInputType.emailAddress,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 20),
              // Password field
              Text(
                'Password',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _passwordController,
                placeholder: 'Enter your password',
                obscureText: _obscurePassword,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                style: AppTextStyles.body,
                suffix: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  child: Icon(
                    _obscurePassword
                        ? CupertinoIcons.eye_slash
                        : CupertinoIcons.eye,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // College field
              Text(
                'College',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _collegeController,
                placeholder: 'Enter your college',
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 20),
              // City field
              Text(
                'City',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _cityController,
                placeholder: 'Enter your city',
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 20),
              // State field
              Text(
                'State',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _stateController,
                placeholder: 'Enter your state',
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 32),
              // Sign up button
              CupertinoButton(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
                onPressed: _handleSignUp,
                child: Text(
                  'Sign Up',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Login link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        CupertinoPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Log In',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

