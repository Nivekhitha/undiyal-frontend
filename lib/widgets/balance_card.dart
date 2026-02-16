import 'package:flutter/cupertino.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/constants.dart';

class BalanceCard extends StatelessWidget {
  final double balance;
  final double weeklySpent;
  final double weeklyCredits;
  final String? bankName;

  const BalanceCard({
    super.key,
    required this.balance,
    required this.weeklySpent,
    required this.weeklyCredits,
    this.bankName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                bankName != null && bankName!.isNotEmpty ? '$bankName Balance' : 'Wallet Balance',
                style: AppTextStyles.cardBody.copyWith(
                  fontSize: 14,
                  color: AppColors.textOnCard.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 6),
              // Info icon for zero balance
              if (balance == 0)
                GestureDetector(
                  onTap: () {
                    showCupertinoDialog(
                      context: context,
                      builder: (context) => CupertinoAlertDialog(
                        title: const Text('Bank Balance'),
                        content: const Text(
                          'Your bank balance will remain zero until you set up bank balance checking.\n\n'
                          'Tap the credit card icon at the top right to set it up anytime.',
                        ),
                        actions: [
                          CupertinoDialogAction(
                            child: const Text('OK'),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Icon(
                    CupertinoIcons.info_circle,
                    color: AppColors.textOnCard.withValues(alpha: 0.7),
                    size: 16,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${balance.toStringAsFixed(2)}',
            style: AppTextStyles.h1.copyWith(
              color: AppColors.textOnCard,
              fontSize: 36,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'This week: ',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textOnCard.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      '₹${weeklySpent.toStringAsFixed(0)}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}