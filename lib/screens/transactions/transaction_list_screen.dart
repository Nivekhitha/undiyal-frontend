import 'package:flutter/cupertino.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/constants.dart';
import '../../models/transaction_model.dart';
import '../../widgets/expense_tile.dart';
import 'transaction_detail_screen.dart';
import '../../services/transaction_storage_service.dart';
import '../../services/sms_notification_listener.dart';
import 'dart:async';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  List<Transaction> _transactions = [];
  bool _isLoading = true;

  StreamSubscription<Transaction>? _expenseSub;
  StreamSubscription<Transaction>? _transactionAddedSub;

  final List<String> _filterOptions = [
    'All',
    'Food & Drink',
    'Shopping',
    'Transport',
    'Entertainment',
    'Groceries',
    'Bills',
  ];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    // Listen for real-time expense events so the history updates automatically
    _expenseSub = SmsNotificationListener.onExpenseUpdate.listen((tx) {
      final exists = _transactions.any((t) => t.id == tx.id);
      if (!exists) {
        setState(() {
          _transactions.insert(0, tx);
        });
      }
    });

    _transactionAddedSub = TransactionStorageService.onTransactionAdded.listen((tx) {
      final exists = _transactions.any((t) => t.id == tx.id);
      if (!exists) {
        setState(() {
          _transactions.insert(0, tx);
        });
      }
    });
  }

  Future<void> _loadTransactions() async {
    final transactions = await TransactionStorageService.getAllTransactions();
    setState(() {
      _transactions = transactions;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _expenseSub?.cancel();
    _transactionAddedSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const CupertinoPageScaffold(
        backgroundColor: AppColors.background,
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    // Apply filters
    List<Transaction> filteredTransactions = _transactions.where((transaction) {
      final matchesSearch = transaction.merchant
          .toLowerCase()
          .contains(_searchQuery.toLowerCase()) ||
          transaction.category.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesFilter = _selectedFilter == 'All' ||
          transaction.category == _selectedFilter;

      return matchesSearch && matchesFilter;
    }).toList();

    // Group by date
    final groupedTransactions = _groupTransactionsByDate(filteredTransactions);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.screenPadding,
                16,
                AppConstants.screenPadding,
                0,
              ),
              child: Row(
                children: [
                  Text(
                    'History',
                    style: AppTextStyles.h2,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.screenPadding,
              ),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: 'Search transactions',
                style: AppTextStyles.body,
                backgroundColor: CupertinoColors.white,
                borderRadius: BorderRadius.circular(12),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),

            const SizedBox(height: 16),

            // Filter chips
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.screenPadding,
                ),
                itemCount: _filterOptions.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = _filterOptions[index];
                  final isSelected = _selectedFilter == filter;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : CupertinoColors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : const Color(0xFFE0E0E0),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        filter,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Summary card
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.screenPadding,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Transactions',
                          style: AppTextStyles.cardBody.copyWith(
                            fontSize: 14,
                            color: AppColors.textOnCard.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${filteredTransactions.length}',
                          style: AppTextStyles.h2.copyWith(
                            color: AppColors.textOnCard,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Total Amount',
                          style: AppTextStyles.cardBody.copyWith(
                            fontSize: 14,
                            color: AppColors.textOnCard.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${_calculateTotal(filteredTransactions)}',
                          style: AppTextStyles.h2.copyWith(
                            color: AppColors.primary,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Transactions list
            Expanded(
              child: filteredTransactions.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.screenPadding,
                ),
                itemCount: groupedTransactions.length,
                itemBuilder: (context, index) {
                  final dateGroup = groupedTransactions[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date header
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: 12,
                          left: 4,
                        ),
                        child: Text(
                          dateGroup['date'] as String,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),

                      // Transactions for this date
                      ...List.generate(
                        (dateGroup['transactions'] as List<Transaction>)
                            .length,
                            (txIndex) {
                          final transaction = (dateGroup['transactions']
                          as List<Transaction>)[txIndex];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ExpenseTile(
                              transaction: transaction,
                              onTap: () {
                                Navigator.of(context).push(
                                  CupertinoPageRoute(
                                    builder: (context) =>
                                        TransactionDetailScreen(
                                          transaction: transaction,
                                        ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 12),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _groupTransactionsByDate(
      List<Transaction> transactions) {
    final grouped = <String, List<Transaction>>{};

    for (var transaction in transactions) {
      final dateKey = _formatDateHeader(transaction.date);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(transaction);
    }

    return grouped.entries.map((entry) {
      return {
        'date': entry.key,
        'transactions': entry.value,
      };
    }).toList();
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final transactionDate = DateTime(date.year, date.month, date.day);

    if (transactionDate == today) {
      return 'Today';
    } else if (transactionDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(transactionDate).inDays < 7) {
      final weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      return weekdays[date.weekday - 1];
    } else {
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

  String _calculateTotal(List<Transaction> transactions) {
    final total = transactions.fold(0.0, (sum, t) => sum + t.amount);
    return total.toStringAsFixed(2);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.search,
              size: 48,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No transactions found',
            style: AppTextStyles.h3,
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try adjusting your search'
                : 'Start adding expenses to see them here',
            style: AppTextStyles.bodySecondary,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}