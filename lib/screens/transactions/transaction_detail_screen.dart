import 'package:flutter/cupertino.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/constants.dart';
import '../../models/transaction_model.dart';
import '../../services/transaction_storage_service.dart';

class TransactionDetailScreen extends StatefulWidget {
  final Transaction transaction;

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
  });

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  bool _isRecurring = false;
  late String _currentCategory;

  @override
  void initState() {
    super.initState();
    _isRecurring = widget.transaction.isRecurring;
    _currentCategory = widget.transaction.category;
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
          'Transaction Details',
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: GestureDetector(
          onTap: () => _showActionSheet(context),
          child: const Icon(
            CupertinoIcons.ellipsis_circle,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 24),

              // Amount card
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.screenPadding,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getCategoryIcon(widget.transaction.category),
                          color: AppColors.textOnCard,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.transaction.merchant,
                        style: AppTextStyles.h2.copyWith(
                          color: AppColors.textOnCard,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentCategory,
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textOnCard.withOpacity(0.7),
                            ),
                          ),
                          if (widget.transaction.isAutoDetected) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Auto',
                                style: AppTextStyles.label.copyWith(
                                  fontSize: 11,
                                  color: AppColors.textOnCard,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (widget.transaction.isAutoDetected && widget.transaction.confidenceScore != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Confidence: ${(widget.transaction.confidenceScore! * 100).toStringAsFixed(0)}%',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textOnCard.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Text(
                        '-₹${widget.transaction.amount.toStringAsFixed(2)}',
                        style: AppTextStyles.h1.copyWith(
                          color: AppColors.primary,
                          fontSize: 42,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Transaction details
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.screenPadding,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Details',
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildDetailRow(
                        icon: CupertinoIcons.calendar,
                        label: 'Date',
                        value: _formatFullDate(widget.transaction.date),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        icon: CupertinoIcons.time,
                        label: 'Time',
                        value: _formatTime(widget.transaction.date),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        icon: CupertinoIcons.creditcard,
                        label: 'Payment Method',
                        value: widget.transaction.paymentMethod,
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        icon: CupertinoIcons.checkmark_seal,
                        label: 'Status',
                        value: _formatStatus(widget.transaction.status),
                        valueColor: _getStatusColor(widget.transaction.status),
                      ),
                      const SizedBox(height: 16),
                      // Category row with edit option for auto-detected transactions
                      Row(
                        children: [
                          const Icon(
                            CupertinoIcons.tag,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Category',
                                  style: AppTextStyles.caption,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _currentCategory,
                                        style: AppTextStyles.body.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (widget.transaction.isAutoDetected)
                                      CupertinoButton(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        onPressed: _showCategoryPicker,
                                        child: Text(
                                          'Edit',
                                          style: AppTextStyles.body.copyWith(
                                            color: AppColors.primary,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (widget.transaction.referenceNumber != null) ...[
                        const SizedBox(height: 16),
                        _buildDetailRow(
                          icon: CupertinoIcons.number,
                          label: 'Reference',
                          value: widget.transaction.referenceNumber!,
                        ),
                      ],
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        icon: CupertinoIcons.number,
                        label: 'Transaction ID',
                        value: widget.transaction.id.toUpperCase(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Receipt section
              if (widget.transaction.receiptUrl != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.screenPadding,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: CupertinoColors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Receipt',
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => _viewReceipt(context),
                          child: Container(
                            height: 150,
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemGrey6,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    CupertinoIcons.doc_text,
                                    size: 48,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Tap to view receipt',
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (widget.transaction.receiptUrl != null)
                const SizedBox(height: 24),

              // Auto-renew toggle
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.screenPadding,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _isRecurring
                              ? AppColors.primary.withOpacity(0.3)
                              : CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          CupertinoIcons.arrow_2_circlepath,
                          color: _isRecurring
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recurring Transaction',
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isRecurring
                                  ? 'This expense repeats monthly'
                                  : 'Mark as recurring',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      CupertinoSwitch(
                        value: _isRecurring,
                        activeTrackColor: AppColors.primary,
                        onChanged: (value) {
                          setState(() {
                            _isRecurring = value;
                          });
                          _showRecurringConfirmation(value);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Action buttons
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.screenPadding,
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                        onPressed: () => _editTransaction(context),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              CupertinoIcons.pencil,
                              color: AppColors.textPrimary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Edit Transaction',
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        onPressed: () => _deleteTransaction(context),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              CupertinoIcons.trash,
                              color: AppColors.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Delete Transaction',
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.textSecondary,
          size: 20,
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: AppTextStyles.body.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Food & Drink':
        return CupertinoIcons.bag;
      case 'Shopping':
        return CupertinoIcons.bag_fill;
      case 'Transport':
        return CupertinoIcons.car;
      case 'Entertainment':
        return CupertinoIcons.film;
      case 'Groceries':
        return CupertinoIcons.cart;
      case 'Bills':
        return CupertinoIcons.doc_text;
      case 'Health':
        return CupertinoIcons.heart;
      case 'Education':
        return CupertinoIcons.book;
      default:
        return CupertinoIcons.circle;
    }
  }

  String _formatFullDate(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatStatus(String status) {
    return status[0].toUpperCase() + status.substring(1);
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'failed':
        return AppColors.error;
      default:
        return AppColors.textPrimary;
    }
  }

  void _showActionSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text('Transaction Options'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _editTransaction(context);
            },
            child: Text('Edit Transaction'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _shareTransaction(context);
            },
            child: Text('Share Transaction'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _viewReceipt(context);
            },
            child: Text('View Receipt'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              _deleteTransaction(context);
            },
            child: const Text('Delete Transaction'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _editTransaction(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Edit Transaction'),
        content: Text('Transaction editing feature coming soon!'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _deleteTransaction(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Delete Transaction'),
        content: Text(
            'Are you sure you want to delete this transaction? This action cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to list
            },
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _shareTransaction(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Share Transaction'),
        content: Text(
          'Share: ${widget.transaction.merchant} - ₹${widget.transaction.amount.toStringAsFixed(2)}',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _viewReceipt(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Receipt',
                    style: AppTextStyles.h3,
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: AppColors.textSecondary,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: CupertinoColors.systemGrey6,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        CupertinoIcons.doc_text,
                        size: 80,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Receipt Preview',
                        style: AppTextStyles.h3,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Receipt image would appear here',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryPicker() {
    const categories = AppConstants.categories;
    
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Select Category'),
        actions: categories.map((category) {
          return CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _currentCategory = category;
              });
              // Update transaction category
              TransactionStorageService.updateTransactionCategory(
                widget.transaction.id,
                category,
              );
            },
            child: Text(
              category,
              style: TextStyle(
                fontWeight: _currentCategory == category ? FontWeight.w600 : FontWeight.normal,
                color: _currentCategory == category ? AppColors.primary : null,
              ),
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showRecurringConfirmation(bool isRecurring) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(isRecurring ? 'Recurring Enabled' : 'Recurring Disabled'),
        content: Text(
          isRecurring
              ? 'This transaction is now marked as recurring and will appear monthly.'
              : 'This transaction is no longer recurring.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}