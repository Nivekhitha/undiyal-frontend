import '../models/transaction_model.dart';
import 'sms_expense_service.dart';
import 'expense_service.dart';
import '../models/transaction_model.dart';
import 'dart:async';

/// Service to manage stored transactions
/// Provides unified access to transactions across the app
class TransactionStorageService {
  // Stream for notifying when a transaction is added locally
  static final StreamController<Transaction> _transactionAddedController =
      StreamController<Transaction>.broadcast();

  static Stream<Transaction> get onTransactionAdded => _transactionAddedController.stream;

  /// Get all transactions
  static Future<List<Transaction>> getAllTransactions() async {
    // 1. Get stored transactions (SMS + Manual Local)
    var allTransactions = await SmsExpenseService.getStoredTransactions();
    
    // 2. Fetch from Backend
    try {
      final remoteTransactions = await ExpenseService.getExpenses();
      if (remoteTransactions.isNotEmpty) {
        // Merge strategy: Remote overwrites local if ID matches
        final Map<String, Transaction> mergedMap = {};
        for (var tx in allTransactions) {
          mergedMap[tx.id] = tx;
        }
        for (var tx in remoteTransactions) {
          mergedMap[tx.id] = tx;
        }
        allTransactions = mergedMap.values.toList();
        
        // Update local storage with latest merged data
        // This ensures offline access has latest data next time
        await SmsExpenseService.saveTransactions(allTransactions);
      }
    } catch (e) {
      // Ignore network errors, show local data
      print('Error syncing transactions: $e');
    }
    
    // Sort by date (newest first)
    allTransactions.sort((a, b) => b.date.compareTo(a.date));
    
    return allTransactions;
  }

  /// Add a new transaction (manual entry)
  static Future<void> addTransaction(Transaction transaction) async {
    // 1. Save locally first (Optimistic UI)
    final existingTransactions = await SmsExpenseService.getStoredTransactions();
    existingTransactions.add(transaction);
    await SmsExpenseService.saveTransactions(existingTransactions);

    // Notify listeners that a transaction was added
    try {
      _transactionAddedController.add(transaction);
    } catch (_) {}

    // 2. Sync to backend
    await ExpenseService.addExpense(transaction);
  }

  /// Update transaction category (for manual editing)
  static Future<void> updateTransactionCategory(String transactionId, String newCategory) async {
    final allTransactions = await getAllTransactions();
    final index = allTransactions.indexWhere((tx) => tx.id == transactionId);
    
    if (index != -1) {
      final tx = allTransactions[index];
      final updatedTx = Transaction(
        id: tx.id,
        amount: tx.amount,
        merchant: tx.merchant,
        category: newCategory,
        date: tx.date,
        paymentMethod: tx.paymentMethod,
        status: tx.status,
        receiptUrl: tx.receiptUrl,
        isRecurring: tx.isRecurring,
        isAutoDetected: tx.isAutoDetected,
        referenceNumber: tx.referenceNumber,
        confidenceScore: tx.confidenceScore,
      );
      
      allTransactions[index] = updatedTx;
      
      // Save the updated transaction to storage
      await SmsExpenseService.saveTransactions([updatedTx]);
    }
  }

  /// ONE-TIME CLEANUP: clear all stored data
  static Future<void> clearAllData() async {
    await SmsExpenseService.clearAllData();
  }
}

