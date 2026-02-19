import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../../services/sms_notification_listener.dart';
import '../auth/auth_gate.dart';

/// Screen shown right after the splash screen to request
/// the system-level Notification Listener permission.
/// This is a special Android permission that allows the app to
/// read notifications from other apps (e.g. banking SMS notifications).
class NotificationListenerPermissionScreen extends StatefulWidget {
  const NotificationListenerPermissionScreen({super.key});

  @override
  State<NotificationListenerPermissionScreen> createState() =>
      _NotificationListenerPermissionScreenState();
}

class _NotificationListenerPermissionScreenState
    extends State<NotificationListenerPermissionScreen> with WidgetsBindingObserver {
  bool _isLoading = false;
  bool _hasListenerAccess = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check permission when the user returns from system settings
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAccess();
    }
  }

  Future<void> _checkAccess() async {
    final hasAccess = await SmsNotificationListener().isListenerEnabled() ||
        await SmsNotificationListener.hasNotificationPermission();
    if (mounted) {
      setState(() => _hasListenerAccess = hasAccess);
    }
  }

  Future<void> _onEnableAccess() async {
    setState(() => _isLoading = true);
    try {
      await SmsNotificationListener().openNotificationSettings();
      // Access is re-checked automatically in didChangeAppLifecycleState
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _proceed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_listener_permission', true);

    if (_hasListenerAccess) {
      // Enable the listener so it starts working immediately
      await SmsNotificationListener().setListenerEnabled(true);
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(builder: (_) => const AuthGate()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.bell_solid,
                  size: 64,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: 32),

              // Title
              const Text(
                'Notification Access',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 16),

              // Description
              const Text(
                'Undiyal needs access to your notifications to '
                'automatically detect bank transactions from your SMS. '
                'This lets us track expenses in real-time without you '
                'lifting a finger.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 32),

              // How it works section
              _buildInfoCard(
                icon: CupertinoIcons.shield_lefthalf_fill,
                title: 'Privacy First',
                description:
                    'We only read banking SMS notifications. Your personal messages are never accessed.',
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                icon: CupertinoIcons.device_phone_portrait,
                title: 'Stays On-Device',
                description:
                    'All data is processed locally on your phone. Nothing is sent to external servers.',
              ),

              const SizedBox(height: 24),

              // Status indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _hasListenerAccess
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _hasListenerAccess ? AppColors.success : AppColors.warning,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _hasListenerAccess
                          ? CupertinoIcons.checkmark_circle_fill
                          : CupertinoIcons.exclamationmark_triangle_fill,
                      color: _hasListenerAccess ? AppColors.success : AppColors.warning,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _hasListenerAccess
                            ? 'Notification access is enabled'
                            : 'Notification access is not yet enabled',
                        style: TextStyle(
                          color: _hasListenerAccess ? AppColors.success : AppColors.warning,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // Buttons
              if (!_hasListenerAccess) ...[
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: _isLoading ? null : _onEnableAccess,
                    child: _isLoading
                        ? const CupertinoActivityIndicator(
                            color: CupertinoColors.white)
                        : const Text(
                            'Enable Notification Access',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    onPressed: _proceed,
                    child: const Text(
                      'Skip for Now',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: _proceed,
                    child: const Text(
                      'Continue',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
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
