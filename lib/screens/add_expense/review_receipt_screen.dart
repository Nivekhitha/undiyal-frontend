import 'dart:io';
import 'dart:convert';
import 'package:flutter/cupertino.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/constants.dart';
import '../../widgets/category_chip.dart';
import '../../models/transaction_model.dart';
import '../../services/transaction_storage_service.dart';
import '../../services/receipt_scan_service.dart';
import '../../services/sms_expense_service.dart';
import '../../navigation/bottom_nav.dart';
import 'dart:math';

class ReviewReceiptScreen extends StatefulWidget {
  final String? imagePath;
  const ReviewReceiptScreen({super.key, this.imagePath});

  @override
  State<ReviewReceiptScreen> createState() => _ReviewReceiptScreenState();
}

class _ReviewReceiptScreenState extends State<ReviewReceiptScreen> {
  // Extracted fields
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  String _selectedCategory = 'Others';
  String _selectedPaymentMethod = 'Cash';
  DateTime _selectedDate = DateTime.now();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.imagePath != null) {
      _processReceipt(widget.imagePath!);
    }
  }

  Future<void> _processReceipt(String path) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final file = File(path);
      final resp = await ReceiptScanService.scanReceiptFromFile(file);

      if (resp['success'] == true && resp['data'] != null) {
        // Attempt to extract model text output (first choice text) or parse JSON
        String modelText = '';
        final data = resp['data'];
        if (data is Map<String, dynamic>) {
          // Common OpenAI-style response: choices[0].message.content or choices[0].text
          if (data.containsKey('choices')) {
            final choices = data['choices'];
            if (choices is List && choices.isNotEmpty) {
              final c0 = choices[0];
              if (c0 is Map && c0.containsKey('message')) {
                final msg = c0['message'];
                if (msg is Map && msg.containsKey('content')) modelText = msg['content'].toString();
              } else if (c0 is Map && c0.containsKey('text')) {
                modelText = c0['text'].toString();
              }
            }
          } else if (data.containsKey('text') && data['text'] is String) {
            modelText = data['text'];
          } else {
            modelText = data.toString();
          }
        } else if (data is String) {
          modelText = data;
        }

        // Try to find JSON object in modelText
        Map<String, dynamic>? jsonObj;
        try {
          final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(modelText);
          if (jsonMatch != null) {
            final jsonStr = jsonMatch.group(0)!;
            jsonObj = jsonDecode(jsonStr) as Map<String, dynamic>;
          } else {
            // Try direct parse
            jsonObj = jsonDecode(modelText) as Map<String, dynamic>;
          }
        } catch (_) {
          jsonObj = null;
        }

        String ocrText = modelText;

        if (jsonObj != null) {
          // Fill fields from JSON if present
          if (jsonObj.containsKey('amount')) {
            final rawAmt = jsonObj['amount'].toString();
            final cleaned = rawAmt.replaceAll(RegExp(r'[^0-9\.]'), '');
            final val = double.tryParse(cleaned) ?? 0.0;
            if (val > 0) _amountController.text = val.toStringAsFixed(2);
          }
          if (jsonObj.containsKey('merchant')) _merchantController.text = jsonObj['merchant'].toString();
          if (jsonObj.containsKey('date')) {
            try {
              final d = DateTime.parse(jsonObj['date'].toString());
              _selectedDate = d;
            } catch (_) {}
          }
          if (jsonObj.containsKey('raw_text')) ocrText = jsonObj['raw_text'].toString();
        } else {
          // Fallback: simple heuristics on modelText
          final amtRegex = RegExp(r'(?:₹|rs\.?|inr)?\s*([0-9]{1,3}(?:[,\s][0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)', caseSensitive: false);
          final m = amtRegex.firstMatch(ocrText);
          if (m != null) {
            final amtStr = m.group(1) ?? '';
            final cleaned = amtStr.replaceAll(RegExp(r'[ ,]'), '');
            final amt = double.tryParse(cleaned) ?? 0.0;
            if (amt > 0) _amountController.text = amt.toStringAsFixed(2);
          }

          final lines = ocrText.split(RegExp(r'\r?\n')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          for (var line in lines) {
            if (line.length > 3 && !RegExp(r'^[₹Rsrsinr0-9\s\.,]+\$?', caseSensitive: false).hasMatch(line)) {
              _merchantController.text = line;
              break;
            }
          }
        }
      } else {
        // Not successful - leave fields for manual edit
      }
    } catch (e) {
      debugPrint('Receipt scanning error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  void _saveExpense() async {
    // Basic Validation
    if (_amountController.text.isEmpty) {
       // Ideally show alert, but for now just return or handle safely
       return; 
    }

    final amountVal = double.tryParse(_amountController.text) ?? 0.0;

    // Create transaction object
    final newTransaction = Transaction(
      id: _generateId(),
      amount: amountVal,
      merchant: _merchantController.text.isEmpty ? 'Unknown Receipt' : _merchantController.text,
      category: _selectedCategory,
      date: _selectedDate,
      paymentMethod: _selectedPaymentMethod,
      isAutoDetected: false, 
      // In a real app, you'd save the receipt image path here too
    );

    // Save to storage
    await TransactionStorageService.addTransaction(newTransaction);

    if (!mounted) return;

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Success'),
        content: const Text('Receipt expense saved!'),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              // CRITICAL FIX: Safe reset to Home
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
    return 'receipt_${now}_$random';
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
          child: const Icon(
            CupertinoIcons.back,
            color: AppColors.textPrimary,
          ),
        ),
        middle: Text(
          'Review & Edit',
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: SafeArea(
        child: _isLoading 
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CupertinoActivityIndicator(radius: 20),
                const SizedBox(height: 16),
                Text('Analyzing Receipt...', style: AppTextStyles.body),
              ],
            ),
          )
        : Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(AppConstants.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Success message
                    if (widget.imagePath != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            CupertinoIcons.checkmark_circle_fill,
                            color: AppColors.success,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Receipt analyzed successfully',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Receipt preview
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey5,
                        borderRadius: BorderRadius.circular(16),
                        image: widget.imagePath != null 
                          ? DecorationImage(
                              image: FileImage(File(widget.imagePath!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                      ),
                      child: widget.imagePath == null ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              CupertinoIcons.doc_text,
                              size: 48,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No Receipt Image',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ) : null,
                    ),

                    const SizedBox(height: 24),

                    // Extracted fields header
                    Row(
                      children: [
                        Text(
                          'Extracted Details',
                          style: AppTextStyles.h3,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Edit if needed',
                            style: AppTextStyles.label.copyWith(
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Amount
                    Text(
                      'Amount',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CupertinoTextField(
                      controller: _amountController,
                      prefix: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          '₹',
                          style: AppTextStyles.body,
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CupertinoColors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      style: AppTextStyles.body,
                      keyboardType: TextInputType.number,
                    ),

                    const SizedBox(height: 16),

                    // Merchant
                    Text(
                      'Merchant',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CupertinoTextField(
                      controller: _merchantController,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CupertinoColors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      style: AppTextStyles.body,
                    ),

                    const SizedBox(height: 16),

                    // Category
                    Text(
                      'Category',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: AppConstants.categories.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 8),
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

                    const SizedBox(height: 16),

                    // Date
                    Text(
                      'Date',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
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

                    const SizedBox(height: 16),

                    // Payment Method
                    Text(
                      'Payment Method',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AppConstants.paymentMethods.map((method) {
                        return CategoryChip(
                          label: method,
                          isSelected: _selectedPaymentMethod == method,
                          onTap: () {
                            setState(() {
                              _selectedPaymentMethod = method;
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(AppConstants.screenPadding),
              child: Column(
                children: [
                  SizedBox(
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
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      color: CupertinoColors.white,
                      borderRadius: BorderRadius.circular(16),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'Scan Again',
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
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
      'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}