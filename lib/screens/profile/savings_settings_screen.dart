import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/constants.dart';
import '../../services/settings_service.dart';

/// Screen to set monthly savings target and per-category budgets.
/// Stored in SharedPreferences - same values show across all screens.
class SavingsSettingsScreen extends StatefulWidget {
  const SavingsSettingsScreen({super.key});

  @override
  State<SavingsSettingsScreen> createState() => _SavingsSettingsScreenState();
}

class _SavingsSettingsScreenState extends State<SavingsSettingsScreen> {
  double _monthlySavingsTarget = 0;
  final Map<String, double> _categoryBudgets = {};
  String _currencySymbol = '₹';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final target = await SettingsService.getMonthlySavingsTarget();
    final budgets = await SettingsService.getCategoryBudgets();
    final symbol = await SettingsService.getCurrencySymbol();
    if (mounted) {
      setState(() {
        _monthlySavingsTarget = target;
        _categoryBudgets.clear();
        for (final cat in AppConstants.categories) {
          _categoryBudgets[cat] = budgets[cat] ?? 0;
        }
        _currencySymbol = symbol;
      });
    }
  }

  Future<void> _saveSavingsTarget(double value) async {
    await SettingsService.setMonthlySavingsTarget(value);
    setState(() => _monthlySavingsTarget = value);
  }

  Future<void> _saveCategoryBudget(String category, double value) async {
    await SettingsService.setCategoryBudget(category, value);
    setState(() => _categoryBudgets[category] = value);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.background,
        border: null,
        middle: Text('Savings Settings', style: AppTextStyles.h3),
      ),
      child: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // Savings Target Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.screenPadding),
                child: Text(
                  'Monthly Savings Target',
                  style: AppTextStyles.h3.copyWith(fontSize: 18),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.screenPadding),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _buildMenuItem(
                    icon: CupertinoIcons.money_dollar_circle,
                    title: 'Target amount',
                    trailingText: '$_currencySymbol${_monthlySavingsTarget.toStringAsFixed(0)}',
                    onTap: () => _showSavingsTargetPicker(context),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // Category Budgets Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.screenPadding),
                child: Text(
                  'Per-category Budgets',
                  style: AppTextStyles.h3.copyWith(fontSize: 18),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.screenPadding),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: AppConstants.categories.asMap().entries.map((entry) {
                      final index = entry.key;
                      final category = entry.value;
                      final isFirst = index == 0;
                      final isLast = index == AppConstants.categories.length - 1;
                      final amount = _categoryBudgets[category] ?? 0;
                      return Column(
                        children: [
                          _buildMenuItem(
                            icon: _getCategoryIcon(category),
                            title: category,
                            trailingText: amount > 0 ? '$_currencySymbol${amount.toStringAsFixed(0)}' : 'Not set',
                            onTap: () => _showCategoryBudgetPicker(context, category),
                            isFirst: isFirst,
                            isLast: isLast,
                          ),
                          if (!isLast)
                            const Divider(height: 1, indent: 56, endIndent: 20, color: Color(0xFFEEEEEE)),
                        ],
                      );
                    }).toList(),
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

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Food & Drink': return CupertinoIcons.cart;
      case 'Shopping': return CupertinoIcons.bag;
      case 'Transport': return CupertinoIcons.car;
      case 'Entertainment': return CupertinoIcons.play_circle;
      case 'Groceries': return CupertinoIcons.cart;
      case 'Bills': return CupertinoIcons.doc_text;
      case 'Health': return CupertinoIcons.heart;
      case 'Education': return CupertinoIcons.book;
      default: return CupertinoIcons.tag;
    }
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

  void _showSavingsTargetPicker(BuildContext context) {
    double temp = _monthlySavingsTarget;
    final initialIndex = (temp / 500).round().clamp(0, 79);
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 280,
        color: CupertinoColors.white,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(ctx),
                ),
                Text('Savings Target', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                CupertinoButton(
                  child: const Text('Done'),
                  onPressed: () async {
                    await _saveSavingsTarget(temp);
                    if (mounted) Navigator.pop(ctx);
                  },
                ),
              ],
            ),
            Expanded(
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(initialItem: initialIndex),
                itemExtent: 40,
                onSelectedItemChanged: (index) => temp = (index + 1) * 500.0,
                children: List.generate(80, (i) => Center(child: Text('$_currencySymbol${(i + 1) * 500}'))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryBudgetPicker(BuildContext context, String category) {
    double temp = _categoryBudgets[category] ?? 0;
    if (temp <= 0) temp = 500;
    final initialIndex = ((temp / 500).round() - 1).clamp(0, 79);
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 280,
        color: CupertinoColors.white,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(ctx),
                ),
                Text('Budget: $category', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                CupertinoButton(
                  child: const Text('Done'),
                  onPressed: () async {
                    await _saveCategoryBudget(category, temp);
                    if (mounted) Navigator.pop(ctx);
                  },
                ),
              ],
            ),
            Expanded(
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(initialItem: initialIndex),
                itemExtent: 40,
                onSelectedItemChanged: (index) => temp = (index + 1) * 500.0,
                children: List.generate(80, (i) => Center(child: Text('$_currencySymbol${(i + 1) * 500}'))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
