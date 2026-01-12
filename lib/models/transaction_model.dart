class Transaction {
  final String id;
  final double amount;
  final String merchant;
  final String category;
  final DateTime date;
  final String paymentMethod;
  final String status;
  final String? receiptUrl;
  final bool isRecurring;

  Transaction({
    required this.id,
    required this.amount,
    required this.merchant,
    required this.category,
    required this.date,
    required this.paymentMethod,
    this.status = 'completed',
    this.receiptUrl,
    this.isRecurring = false,
  });

  static List<Transaction> getDummyTransactions() {
    final now = DateTime.now();
    return [
      Transaction(
        id: '1',
        amount: 45.50,
        merchant: 'Starbucks',
        category: 'Food & Drink',
        date: now,
        paymentMethod: 'Credit Card',
      ),
      Transaction(
        id: '2',
        amount: 120.00,
        merchant: 'Nike Store',
        category: 'Shopping',
        date: now.subtract(const Duration(days: 1)),
        paymentMethod: 'Debit Card',
      ),
      Transaction(
        id: '3',
        amount: 12.99,
        merchant: 'Netflix',
        category: 'Entertainment',
        date: now.subtract(const Duration(days: 2)),
        paymentMethod: 'Credit Card',
        isRecurring: true,
      ),
      Transaction(
        id: '4',
        amount: 85.30,
        merchant: 'Target',
        category: 'Groceries',
        date: now.subtract(const Duration(days: 3)),
        paymentMethod: 'Cash',
      ),
      Transaction(
        id: '5',
        amount: 32.00,
        merchant: 'Uber',
        category: 'Transport',
        date: now.subtract(const Duration(days: 4)),
        paymentMethod: 'Credit Card',
      ),
    ];
  }
}