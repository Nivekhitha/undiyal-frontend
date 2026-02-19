import 'package:flutter/cupertino.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/constants.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  int _selectedPlan = 0; // 0: Monthly, 1: Yearly

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.background,
        border: null,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(
            CupertinoIcons.back,
            color: AppColors.textPrimary,
          ),
        ),
        middle: Text(
          'Subscription',
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Upgrade to Premium',
                style: AppTextStyles.h1.copyWith(
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Unlock all features and get the most out of Undiyal',
                style: AppTextStyles.bodySecondary,
              ),

              const SizedBox(height: 32),

              // Plan selector
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildPlanToggle('Monthly', 0),
                    ),
                    Expanded(
                      child: _buildPlanToggle('Yearly', 1, badge: 'Save 20%'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Price card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primaryAccent,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '₹',
                          style: AppTextStyles.h2.copyWith(
                            fontSize: 24,
                          ),
                        ),
                        Text(
                          _selectedPlan == 0 ? '99' : '949',
                          style: AppTextStyles.h1.copyWith(
                            fontSize: 56,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _selectedPlan == 0 ? 'per month' : 'per year',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textPrimary.withValues(alpha: 0.7),
                      ),
                    ),
                    if (_selectedPlan == 1) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: CupertinoColors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '₹79/month',
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Features list
              Text(
                'Premium Features',
                style: AppTextStyles.h3,
              ),
              const SizedBox(height: 16),
              _buildFeature(
                icon: CupertinoIcons.infinite,
                title: 'Unlimited Transactions',
                description: 'Track as many expenses as you want',
              ),
              const SizedBox(height: 16),
              _buildFeature(
                icon: CupertinoIcons.chart_bar_circle,
                title: 'Advanced Analytics',
                description: 'Detailed insights and spending reports',
              ),
              const SizedBox(height: 16),
              _buildFeature(
                icon: CupertinoIcons.cloud,
                title: 'Cloud Sync',
                description: 'Access your data from any device',
              ),
              const SizedBox(height: 16),
              _buildFeature(
                icon: CupertinoIcons.doc_text_search,
                title: 'Smart Receipt Scanning',
                description: 'AI-powered receipt extraction',
              ),
              const SizedBox(height: 16),
              _buildFeature(
                icon: CupertinoIcons.arrow_down_circle,
                title: 'Export Reports',
                description: 'Download PDF and CSV reports',
              ),
              const SizedBox(height: 16),
              _buildFeature(
                icon: CupertinoIcons.bell_fill,
                title: 'Budget Alerts',
                description: 'Get notified when you exceed limits',
              ),

              const SizedBox(height: 32),

              // Current plan info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.info_circle,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Current Plan: Free',
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• 50 transactions per month\n• Basic analytics\n• Manual entry only',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Subscribe button
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                  onPressed: () => _subscribe(context),
                  child: Text(
                    'Subscribe Now',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Terms
              Center(
                child: Text(
                  'Auto-renews. Cancel anytime.',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanToggle(String label, int index, {String? badge}) {
    final isSelected = _selectedPlan == index;

    return GestureDetector(
        onTap: () {
          setState(() {
            _selectedPlan = index;
          });
        },
        child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : CupertinoColors.transparent,
                borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
                children: [
                Text(
                label,
                style: AppTextStyles.body.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                ),
                ),
                  if (badge != null && isSelected) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge,
                        style: AppTextStyles.label.copyWith(
                          fontSize: 10,
                          color: CupertinoColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
            ),
        ),
    );
  }

  Widget _buildFeature({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppColors.textPrimary,
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
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _subscribe(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Subscription'),
        content: Text(
          'Subscribe to ${_selectedPlan == 0 ? 'Monthly' : 'Yearly'} Premium plan?',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(context).pop();
              _showSubscriptionSuccess(context);
            },
            child: const Text('Subscribe'),
          ),
        ],
      ),
    );
  }

  void _showSubscriptionSuccess(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Success!'),
        content: const Text(
          'You are now subscribed to Premium. Enjoy all features!',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
