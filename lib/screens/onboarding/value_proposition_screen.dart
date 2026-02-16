import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/sms_notification_listener.dart';
import '../auth/auth_gate.dart';

class ValuePropositionScreen extends StatefulWidget {
  const ValuePropositionScreen({super.key});

  @override
  State<ValuePropositionScreen> createState() => _ValuePropositionScreenState();
}

class _ValuePropositionScreenState extends State<ValuePropositionScreen> {
  bool _isLoading = false;
  bool _hasNotificationAccess = false;

  @override
  void initState() {
    super.initState();
    _checkNotificationAccess();
  }

  Future<void> _checkNotificationAccess() async {
    final hasListener = await SmsNotificationListener().isListenerEnabled();
    final hasPermission = await SmsNotificationListener.hasNotificationPermission();
    debugPrint('Onboarding: hasListener=$hasListener, hasPermission=$hasPermission');
    final access = hasListener || hasPermission;
    setState(() {
      _hasNotificationAccess = access;
    });
    // If access is granted, auto-navigate to AuthGate
    if (access && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_completed_onboarding', true);
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(
          builder: (context) => const AuthGate(),
        ),
      );
    }
  }

  Future<void> _onEnableNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await SmsNotificationListener().openNotificationSettings();
      
      // Wait for user to return from settings
      await Future.delayed(const Duration(seconds: 2));
      
      // Check if access was granted
      final hasAccess = await SmsNotificationListener().isListenerEnabled();
      
      if (hasAccess) {
        // Mark onboarding as complete
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_completed_onboarding', true);
        
        if (mounted) {
          Navigator.of(context).pushReplacement(
            CupertinoPageRoute(
              builder: (context) => const AuthGate(),
            ),
          );
        }
      } else {
        // Show error if access not granted
        if (mounted) {
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Notification Access Required'),
              content: const Text('To automatically track expenses from SMS notifications, please enable notification access in your device settings.'),
              actions: [
                CupertinoDialogAction(
                  child: const Text('Try Again'),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoDialogAction(
                  child: const Text('Skip'),
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('has_completed_onboarding', true);
                    if (mounted) {
                      Navigator.of(context).pushReplacement(
                        CupertinoPageRoute(
                          builder: (context) => const AuthGate(),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Unable to open settings: $e'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _onSkip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', true);
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(
          builder: (context) => const AuthGate(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              
              // Header
              const Text(
                'Welcome to Undiyal',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.label,
                ),
              ),
              
              const SizedBox(height: 16),
              
              const Text(
                'Your Smart Finance Companion',
                style: TextStyle(
                  fontSize: 18,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Value Propositions
              Expanded(
                child: ListView(
                  children: [
                    _buildFeatureCard(
                      icon: CupertinoIcons.money_dollar_circle,
                      title: 'Automatic Expense Tracking',
                      description: 'We automatically detect and categorize your expenses from SMS notifications, so you don\'t have to manually enter every transaction.',
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildFeatureCard(
                      icon: CupertinoIcons.chart_bar_alt_fill,
                      title: 'Real-time Balance Updates',
                      description: 'Get instant updates on your bank balances whenever you receive SMS notifications from your bank.',
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildFeatureCard(
                      icon: CupertinoIcons.bell_fill,
                      title: 'Smart Notifications',
                      description: 'Never miss important financial updates. We listen for banking SMS and provide timely insights.',
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildFeatureCard(
                      icon: CupertinoIcons.lock_shield_fill,
                      title: 'Privacy First',
                      description: 'Your data stays on your device. We only access SMS notifications to provide financial insights.',
                    ),
                  ],
                ),
              ),
              
              // Status Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _hasNotificationAccess 
                      ? CupertinoColors.systemGreen.withOpacity(0.1)
                      : CupertinoColors.systemOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _hasNotificationAccess 
                        ? CupertinoColors.systemGreen
                        : CupertinoColors.systemOrange,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _hasNotificationAccess 
                          ? CupertinoIcons.checkmark_circle_fill
                          : CupertinoIcons.exclamationmark_triangle_fill,
                      color: _hasNotificationAccess 
                          ? CupertinoColors.systemGreen
                          : CupertinoColors.systemOrange,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _hasNotificationAccess 
                            ? 'Notification access is enabled'
                            : 'Notification access is required for automatic expense tracking',
                        style: TextStyle(
                          color: _hasNotificationAccess 
                              ? CupertinoColors.systemGreen
                              : CupertinoColors.systemOrange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Action Buttons
              if (!_hasNotificationAccess) ...[
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: _isLoading ? null : _onEnableNotifications,
                    child: _isLoading 
                        ? const CupertinoActivityIndicator()
                        : const Text('Enable Notification Access'),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    onPressed: _onSkip,
                    child: const Text('Skip for Now'),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        CupertinoPageRoute(
                          builder: (context) => const AuthGate(),
                        ),
                      );
                    },
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.separator,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: CupertinoColors.systemBlue,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.secondaryLabel,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
