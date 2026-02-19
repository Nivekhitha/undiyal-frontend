import 'package:flutter/cupertino.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/constants.dart';
import '../../widgets/keypad.dart';
import '../../widgets/category_chip.dart';
import '../../models/transaction_model.dart';
import '../../services/transaction_storage_service.dart';
import '../../navigation/bottom_nav.dart';
import 'dart:math';

class ManualEntryScreen extends StatefulWidget {
  final double? initialAmount;
  final DateTime? initialDate;

  const ManualEntryScreen({
    super.key,
    this.initialAmount,
    this.initialDate,
  });

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  String _amount = '0';
  String _merchant = '';
  String _selectedCategory = 'Food & Drink';
  String _selectedPaymentMethod = 'Credit Card';
  DateTime _selectedDate = DateTime.now();

  final _merchantController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialAmount != null) {
      _amount = widget.initialAmount.toString();
      // Remove trailing .0 if present for cleaner display
      if (_amount.endsWith('.0')) {
        _amount = _amount.substring(0, _amount.length - 2);
      }
    }
    if (widget.initialDate != null) {
      _selectedDate = widget.initialDate!;
    }
  }

  @override
  void dispose() {
    _merchantController.dispose();
    super.dispose();
  }

  void _onNumberTap(String number) {
    setState(() {
      if (_amount == '0') {
        _amount = number;
      } else {
        _amount += number;
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_amount.isNotEmpty) {
        _amount = _amount.substring(0, _amount.length - 1);
        if (_amount.isEmpty) {
          _amount = '0';
        }
      }
    });
  }

  void _onDecimal() {
    setState(() {
      if (!_amount.contains('.')) {
        _amount += '.';
      }
    });
  }

  void _saveExpense() async {
    if (_amount == '0' || _amount.isEmpty) {
      _showAlert('Please enter an amount');
      return;
    }

    if (_merchant.isEmpty) {
      _showAlert('Please enter a merchant name');
      return;
    }

    // Create transaction object
    final newTransaction = Transaction(
      id: _generateId(),
      amount: double.parse(_amount),
      merchant: _merchant,
      category: _selectedCategory,
      date: _selectedDate,
      paymentMethod: _selectedPaymentMethod,
      isAutoDetected: false,
    );

    // Save to storage
    await TransactionStorageService.addTransaction(newTransaction);

    if (!mounted) return;

    // Show success and navigate back safely utilizing a hard reset to avoid stack errors
    if (!mounted) return;

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Success'),
        content: const Text('Expense added successfully!'),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              // CRITICAL FIX: Use pushAndRemoveUntil to safely reset to Home.
              // This avoids the "!_debugLocked" crash caused by multiple pops
              // and ensures the Home screen reloads the new transaction.
              Navigator.of(context).pushAndRemoveUntil(
                CupertinoPageRoute(
                  builder: (context) => const BottomNavigation(),
                ),
                (route) => false,
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _generateId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(10000);
    return 'manual_${now}_$random';
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
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.background,
        border: null,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(CupertinoIcons.back, color: AppColors.textPrimary),
        ),
        middle: Text(
          'Manual Entry',
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(AppConstants.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Amount Display
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Amount',
                            style: AppTextStyles.cardBody.copyWith(
                              fontSize: 14,
                              color: AppColors.textOnCard.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '₹$_amount',
                            style: AppTextStyles.h1.copyWith(
                              color: AppColors.textOnCard,
                              fontSize: 48,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Merchant Input
                    Text(
                      'Merchant',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    CupertinoTextField(
                      controller: _merchantController,
                      placeholder: 'e.g., Starbucks, Amazon',
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CupertinoColors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      style: AppTextStyles.body,
                      onChanged: (value) {
                        setState(() {
                          _merchant = value;
                        });
                      },
                    ),

                    const SizedBox(height: 24),

                    // Category Selector
                    Text(
                      'Category',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: AppConstants.categories.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final category = AppConstants.categories[index];
                          return CategoryChip(
                            label: category,
                            isSelected: _selectedCategory == category,
                            onTap: () {
                              setState(() {
                                _selectedCategory = category;
                              });
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Date Selector
                    Text(
                      'Date',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _showDatePicker(),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: CupertinoColors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDate(_selectedDate),
                              style: AppTextStyles.body,
                            ),
                            const Icon(
                              CupertinoIcons.calendar,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Payment Method
                    Text(
                      'Payment Method',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: AppConstants.paymentMethods.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final method = AppConstants.paymentMethods[index];
                          return CategoryChip(
                            label: method,
                            isSelected: _selectedPaymentMethod == method,
                            onTap: () {
                              setState(() {
                                _selectedPaymentMethod = method;
                              });
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Keypad
                    NumericKeypad(
                      onNumberTap: _onNumberTap,
                      onBackspace: _onBackspace,
                      onDecimal: _onDecimal,
                    ),

                    const SizedBox(height: 100), // Extra space for scrolling
                  ],
                ),
              ),
            ),

            // Save Button
            Padding(
              padding: const EdgeInsets.all(AppConstants.screenPadding),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                  onPressed: _saveExpense,
                  child: Text(
                    'Save Expense',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDatePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => Container(
        height: 300,
        color: CupertinoColors.white,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                CupertinoButton(
                  child: const Text('Done'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _selectedDate,
                maximumDate: DateTime.now(),
                onDateTimeChanged: (DateTime newDate) {
                  setState(() {
                    _selectedDate = newDate;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
