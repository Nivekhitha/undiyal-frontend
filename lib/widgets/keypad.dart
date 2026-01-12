import 'package:flutter/cupertino.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class NumericKeypad extends StatelessWidget {
  final Function(String) onNumberTap;
  final VoidCallback onBackspace;
  final VoidCallback onDecimal;

  const NumericKeypad({
    super.key,
    required this.onNumberTap,
    required this.onBackspace,
    required this.onDecimal,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildRow(['1', '2', '3']),
        const SizedBox(height: 12),
        _buildRow(['4', '5', '6']),
        const SizedBox(height: 12),
        _buildRow(['7', '8', '9']),
        const SizedBox(height: 12),
        _buildRow(['.', '0', 'back']),
      ],
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) => _buildKey(key)).toList(),
    );
  }

  Widget _buildKey(String key) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        if (key == 'back') {
          onBackspace();
        } else if (key == '.') {
          onDecimal();
        } else {
          onNumberTap(key);
        }
      },
      child: Container(
        width: 80,
        height: 60,
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: key == 'back'
              ? const Icon(
            CupertinoIcons.delete_left,
            color: AppColors.textPrimary,
            size: 28,
          )
              : Text(
            key,
            style: AppTextStyles.h2.copyWith(
              fontSize: 28,
            ),
          ),
        ),
      ),
    );
  }
}