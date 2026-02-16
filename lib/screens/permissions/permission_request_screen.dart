import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/app_colors.dart';
import '../../services/app_init_service.dart';

class PermissionRequestScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const PermissionRequestScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<PermissionRequestScreen> createState() => _PermissionRequestScreenState();
}

class _PermissionRequestScreenState extends State<PermissionRequestScreen> {
  bool _smsGranted = false;
  bool _notificationGranted = false;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final smsStatus = await Permission.sms.status;
    final notifStatus = await Permission.notification.status;
    
    setState(() {
      _smsGranted = smsStatus.isGranted;
      _notificationGranted = notifStatus.isGranted;
    });
  }

  Future<void> _requestPermissions() async {
    setState(() => _isRequesting = true);

    // Request SMS permission
    if (!_smsGranted) {
      final smsStatus = await Permission.sms.request();
      setState(() => _smsGranted = smsStatus.isGranted);
      
      if (smsStatus.isPermanentlyDenied) {
        _showSettingsDialog('SMS');
        setState(() => _isRequesting = false);
        return;
      }
    }

    // Request notification permission
    if (!_notificationGranted) {
      final notifStatus = await Permission.notification.request();
      setState(() => _notificationGranted = notifStatus.isGranted);
      
      if (notifStatus.isPermanentlyDenied) {
        _showSettingsDialog('Notification');
        setState(() => _isRequesting = false);
        return;
      }
    }

    setState(() => _isRequesting = false);

    // Require both permissions to proceed
    if (_smsGranted && _notificationGranted) {
      // Automatically start SMS detection
      debugPrint('Permissions granted - starting SMS detection...');
      await AppInitService.initializeSmsDetection();

      widget.onComplete();
    }
  }

  void _showSettingsDialog(String permissionType) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('$permissionType Permission Required'),
        content: Text(
          'Please enable $permissionType permission in Settings to use this feature.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Open Settings'),
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
          ),
        ],
      ),
    );
  }

  void _skipPermissions() {
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final allGranted = _smsGranted && _notificationGranted; // Both required

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.lock_shield,
                size: 80,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              const Text(
                'Permissions Required',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Undiyal needs these permissions to automatically track your expenses and keep you informed',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 40),
              _buildPermissionItem(
                icon: CupertinoIcons.chat_bubble_text,
                title: 'SMS Access',
                description: 'Read transaction messages for automatic expense detection',
                isGranted: _smsGranted,
              ),
              const SizedBox(height: 20),
              _buildPermissionItem(
                icon: CupertinoIcons.bell,
                title: 'Notifications',
                description: 'Get alerts for undetected expenses',
                isGranted: _notificationGranted,
              ),
              const Spacer(),
              if (!allGranted)
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: _isRequesting ? null : _requestPermissions,
                    child: _isRequesting
                        ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                        : const Text('Grant Permissions'),
                  ),
                ),
              const SizedBox(height: 12),
              CupertinoButton(
                onPressed: _skipPermissions,
                child: Text(
                  allGranted ? 'Continue' : 'Skip for Now',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGranted ? AppColors.success : AppColors.border,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isGranted ? AppColors.success.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: isGranted ? AppColors.success : AppColors.primary,
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
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isGranted)
            const Icon(
              CupertinoIcons.check_mark_circled_solid,
              color: AppColors.success,
              size: 24,
            ),
        ],
      ),
    );
  }
}
