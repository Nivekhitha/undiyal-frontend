import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // Full import needed for Material, InkWell, CircleAvatar
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/constants.dart';
import '../../services/profile_service.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../../services/settings_service.dart';
import '../auth/auth_gate.dart';
import 'terms_screen.dart';
import 'privacy_screen.dart';
import 'support_screen.dart';
import 'savings_settings_screen.dart';
import '../settings/sms_notification_settings_screen.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Data (initial values overwritten by _loadData from real storage)
  double _monthlyBudget = 0;
  double _monthlySavingsTarget = 0;
  String _selectedCurrency = '₹ INR';
  bool _notificationsEnabled = true;
  bool _biometricEnabled = false;
  String? _biometricName = 'Biometric';
  bool _isBiometricAvailable = false;

  String _userName = '';
  String _userEmail = '';
  String? _profileImagePath;
  StreamSubscription<String>? _settingsSubscription;

  final List<String> _currencies = ['₹ INR', '\$ USD', '€ EUR', '£ GBP', '¥ JPY'];

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkBiometricAvailability();
    
    // Listen for settings changes and refresh
    _settingsSubscription = SettingsService.onSettingsChange.listen((settingKey) {
      if (settingKey == 'monthly_budget' || 
          settingKey == 'monthly_savings_target') {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    final isAvailable = await BiometricService.isDeviceSupported();
    final biometricName = await BiometricService.getPrimaryBiometricName();
    if (mounted) {
      setState(() {
        _isBiometricAvailable = isAvailable;
        _biometricName = biometricName;
      });
    }
  }

  Future<void> _loadData() async {
    final budget = await SettingsService.getMonthlyBudget();
    final savingsTarget = await SettingsService.getMonthlySavingsTarget();
    final currency = await SettingsService.getCurrency();
    final profile = await ProfileService.getProfile();
    final prefs = await ProfileService.getPreferences();
    
    if (mounted) {
      setState(() {
        _monthlyBudget = budget;
        _monthlySavingsTarget = savingsTarget;
        _selectedCurrency = currency;
        _userName = (profile['name'] as String?) ?? '';
        _userEmail = (profile['email'] as String?) ?? '';
        _profileImagePath = profile['imagePath'];
        
        _notificationsEnabled = prefs['notifications'];
        _biometricEnabled = prefs['biometric'];
      });
    }
  }

  Future<void> _savePreference(String key, dynamic value) async {
    await ProfileService.savePreference(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        middle: Text('My Profile', style: AppTextStyles.h3),
        backgroundColor: AppColors.background,
        border: null,
      ),
      child: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // 1. Profile Header (Card Style)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.screenPadding),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Large Profile Picture
                      GestureDetector(
                        onTap: () => _editProfile(context),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.2),
                            shape: BoxShape.circle,
                            image: _profileImagePath != null
                                ? DecorationImage(
                                    image: FileImage(File(_profileImagePath!)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _profileImagePath == null
                              ? Center(
                                  child: Text(
                                    _userName.isNotEmpty
                                        ? _userName.substring(0, 1).toUpperCase()
                                        : (_userEmail.isNotEmpty
                                            ? _userEmail.substring(0, 1).toUpperCase()
                                            : 'U'),
                                    style: AppTextStyles.h1.copyWith(
                                      color: AppColors.primary,
                                      fontSize: 32,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userName,
                              style: AppTextStyles.h3.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _userEmail,
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Edit Icon
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => _editProfile(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.pencil,
                            color: AppColors.textPrimary,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),

            // 2. General Section
            _buildSectionHeader('General'),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.screenPadding),
                child: Container(
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      _buildMenuItem(
                        icon: CupertinoIcons.money_dollar_circle,
                        title: 'Monthly Budget',
                        trailingText: '₹${_monthlyBudget.toStringAsFixed(0)}',
                        onTap: () => _showBudgetPicker(context),
                        isFirst: true,
                      ),
                      _buildDivider(),
                      _buildMenuItem(
                        icon: CupertinoIcons.money_dollar,
                        title: 'Currency',
                        trailingText: _selectedCurrency,
                        onTap: () => _showCurrencyPicker(context),
                      ),
                      _buildDivider(),
                      _buildMenuItem(
                        icon: CupertinoIcons.tray_full,
                        title: 'Savings Settings',
                        trailingText: _monthlySavingsTarget > 0 ? '₹${_monthlySavingsTarget.toStringAsFixed(0)}' : null,
                        onTap: () async {
                          await Navigator.of(context).push(
                            CupertinoPageRoute(builder: (context) => const SavingsSettingsScreen()),
                          );
                          // Reload data when returning from Savings Settings
                          _loadData();
                        },
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // 3. Preferences Section
            _buildSectionHeader('Preferences'),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.screenPadding),
                child: Container(
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      _buildSwitchItem(
                        icon: CupertinoIcons.bell,
                        title: 'Notifications',
                        value: _notificationsEnabled,
                        onChanged: (val) {
                          setState(() => _notificationsEnabled = val);
                          _savePreference('notifications_enabled', val);
                        },
                        isFirst: true,
                      ),
                      _buildDivider(),
                      _buildSwitchItem(
                        icon: CupertinoIcons.lock_shield,
                        title: _biometricName != null ? '$_biometricName Lock' : 'Biometric Lock',
                        value: _biometricEnabled && _isBiometricAvailable,
                        onChanged: (val) {
                          if (_isBiometricAvailable) {
                            _handleBiometricToggle(val);
                          }
                        },
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // 4. Support Section
            _buildSectionHeader('Support'),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.screenPadding),
                child: Container(
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      _buildMenuItem(
                        icon: CupertinoIcons.question_circle,
                        title: 'Need Help?',
                        onTap: () => Navigator.of(context).push(
                          CupertinoPageRoute(builder: (context) => const SupportScreen()),
                        ),
                        isFirst: true,
                      ),
                      _buildDivider(),
                      _buildMenuItem(
                        icon: CupertinoIcons.settings,
                        title: 'SMS Notifications',
                        onTap: () => Navigator.of(context).push(
                          CupertinoPageRoute(builder: (context) => const SmsNotificationSettingsScreen()),
                        ),
                      ),
                      _buildDivider(),
                      _buildMenuItem(
                        icon: CupertinoIcons.shield,
                        title: 'Privacy Policy',
                        onTap: () => Navigator.of(context).push(
                          CupertinoPageRoute(builder: (context) => const PrivacyScreen()),
                        ),
                      ),
                      _buildDivider(),
                      _buildMenuItem(
                        icon: CupertinoIcons.doc_text,
                        title: 'Terms of Service',
                        onTap: () => Navigator.of(context).push(
                          CupertinoPageRoute(builder: (context) => const TermsScreen()),
                        ),
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),

            // 5. Logout Button
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.screenPadding),
                child: CupertinoButton(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(16),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  onPressed: () => _logout(context),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(CupertinoIcons.arrow_right_square, color: AppColors.error),
                      const SizedBox(width: 8),
                      Text(
                        'Log Out', 
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.error, 
                          fontWeight: FontWeight.w600
                        )
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        ),
      ),
    );
  }

  // --- Widgets ---

  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppConstants.screenPadding, 0, AppConstants.screenPadding, 12),
        child: Text(
          title,
          style: AppTextStyles.h3.copyWith(fontSize: 18),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? trailingText,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(20) : Radius.zero,
          bottom: isLast ? const Radius.circular(20) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textPrimary, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
              ),
              if (trailingText != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    trailingText,
                    style: AppTextStyles.body.copyWith(color: AppColors.textSecondary, fontSize: 14),
                  ),
                ),
              const Icon(CupertinoIcons.chevron_right, color: AppColors.textSecondary, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textPrimary, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
          ),
          CupertinoSwitch(
            value: value,
            activeColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 56, endIndent: 20, color: Color(0xFFEEEEEE));
  }

  // --- Logic ---

  void _handleBiometricToggle(bool val) {
    if (val) {
      // Try to authenticate before enabling
      BiometricService.authenticate().then((result) async {
        if (result['success']) {
          setState(() => _biometricEnabled = true);
          await _savePreference('biometric_enabled', true);
          await BiometricService.setBiometricLock(true);
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
      });
    } else {
      // Disabling biometric - no auth needed
      setState(() => _biometricEnabled = false);
      _savePreference('biometric_enabled', false);
      BiometricService.setBiometricLock(false);
    }
  }

  void _editProfile(BuildContext context) {
    final nameController = TextEditingController(text: _userName);
    String? tempImagePath = _profileImagePath;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: 400,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: CupertinoColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Text('Edit Profile', style: AppTextStyles.h3),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Text('Save'),
                      onPressed: () async {
                        if (nameController.text.isNotEmpty) {
                          await ProfileService.saveProfile(
                            name: nameController.text,
                            imagePath: tempImagePath,
                          );
                          _loadData();
                          if (mounted) Navigator.of(context).pop();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                    if (pickedFile != null) {
                      final appDir = await getApplicationDocumentsDirectory();
                      final fileName = path.basename(pickedFile.path);
                      final savedImage = await File(pickedFile.path).copy('${appDir.path}/$fileName');
                      setModalState(() {
                        tempImagePath = savedImage.path;
                      });
                    }
                  },
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    backgroundImage: tempImagePath != null ? FileImage(File(tempImagePath!)) : null,
                    child: tempImagePath == null
                        ? const Icon(CupertinoIcons.camera, size: 40, color: AppColors.primary)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Tap to change photo'),
                const SizedBox(height: 24),
                CupertinoTextField(
                  controller: nameController,
                  placeholder: 'Full Name',
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showBudgetPicker(BuildContext context) {
    double tempBudget = _monthlyBudget;
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => Container(
        height: 280,
        color: CupertinoColors.white,
        child: Column(
          children: [
             Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
                Text('Set Budget', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                CupertinoButton(child: const Text('Done'), onPressed: () async {
                   await SettingsService.setMonthlyBudget(tempBudget);
                   setState(() => _monthlyBudget = tempBudget);
                   Navigator.pop(context);
                }),
              ],
            ),
            Expanded(
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(initialItem: (_monthlyBudget / 500).round() - 1),
                itemExtent: 40,
                onSelectedItemChanged: (index) => tempBudget = (index + 1) * 500.0,
                children: List.generate(40, (index) => Center(child: Text('₹${(index + 1) * 500}'))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => Container(
        height: 250,
        color: CupertinoColors.white,
        child: Column(
          children: [
             Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
                Text('Select Currency', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                CupertinoButton(child: const Text('Done'), onPressed: () => Navigator.pop(context)),
              ],
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 40,
                onSelectedItemChanged: (index) async {
                   final newCurrency = _currencies[index];
                   setState(() => _selectedCurrency = newCurrency);
                   await SettingsService.setCurrency(newCurrency);
                },
                children: _currencies.map((c) => Center(child: Text(c))).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _logout(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          CupertinoDialogAction(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Log Out'),
            onPressed: () async {
              await AuthService.logout();
              await ProfileService.clearAllData();
              if (mounted) {
                 Navigator.of(context).pushAndRemoveUntil(
                    CupertinoPageRoute(builder: (context) => const AuthGate()),
                    (route) => false,
                 );
              }
            },
          ),
        ],
      ),
    );
  }
}
