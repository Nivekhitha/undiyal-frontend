import '../models/transaction_model.dart';
import 'sms_expense_service.dart';

/// Service to manage stored transactions
/// Provides unified access to transactions across the app
class TransactionStorageService {
  /// Get all transactions
  static Future<List<Transaction>> getAllTransactions() async {
    // Get stored transactions (SMS + Manual)
    final storedTransactions = await SmsExpenseService.getStoredTransactions();
    
    // Sort by date (newest first)
    storedTransactions.sort((a, b) => b.date.compareTo(a.date));
    
    return storedTransactions;
  }

  /// Add a new transaction (manual entry)
  static Future<void> addTransaction(Transaction transaction) async {
    final existingTransactions = await SmsExpenseService.getStoredTransactions();
    existingTransactions.add(transaction);
    await SmsExpenseService.saveTransactions(existingTransactions);
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

