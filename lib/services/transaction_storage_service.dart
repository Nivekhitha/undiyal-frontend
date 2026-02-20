import '../models/transaction_model.dart';
import 'sms_expense_service.dart';
import 'expense_service.dart';
import 'auth_service.dart';
import 'dart:async';

/// Service to manage stored transactions
/// Provides unified access to transactions across the app
class TransactionStorageService {
  // Stream for notifying when a transaction is added locally
  static final StreamController<Transaction> _transactionAddedController =
      StreamController<Transaction>.broadcast();

  static Stream<Transaction> get onTransactionAdded =>
      _transactionAddedController.stream;

  // Stream for notifying when the stored transaction list changed (e.g., after remote sync)
  static final StreamController<void> _transactionsUpdatedController =
      StreamController<void>.broadcast();

  static Stream<void> get onTransactionsUpdated =>
      _transactionsUpdatedController.stream;

  static Future<List<Transaction>>? _inFlightRemoteFetch;
  static String? _inFlightRemoteFetchUserEmail;
  static String? _lastRemoteFetchUserEmail;
  static DateTime? _lastRemoteFetchAt;
  static const Duration _remoteFetchCooldown = Duration(seconds: 15);
  static const Duration _remoteFetchTimeout = Duration(seconds: 8);

  static String _dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static String _fingerprint(Transaction tx) {
    final merchant = tx.merchant.toLowerCase().trim();
    return '${tx.type}|${tx.amount.toStringAsFixed(2)}|$merchant|${_dateKey(tx.date)}';
  }

  /// Public helper for native or other services to notify when a transaction is added
  static void notifyTransactionAdded(Transaction transaction) {
    try {
      _transactionAddedController.add(transaction);
    } catch (_) {}
  }

  /// Get all transactions
  static Future<List<Transaction>> getAllTransactions() async {
    // 1. Get stored transactions (SMS + Manual Local)
    final allTransactions = await SmsExpenseService.getStoredTransactions();

    // 2. Kick off remote sync in background (do not block UI)
    unawaited(_startRemoteSyncIfNeededAsync());

    // Sort by date (newest first)
    allTransactions.sort((a, b) => b.date.compareTo(a.date));

    return allTransactions;
  }

  static Future<void> _startRemoteSyncIfNeededAsync() async {
    final userEmail = await AuthService.getUserEmail();
    if (userEmail == null || userEmail.trim().isEmpty) {
      return;
    }

    // If the account changed since last fetch, reset cache so we don't leak data.
    if (_lastRemoteFetchUserEmail != userEmail) {
      _lastRemoteFetchUserEmail = userEmail;
      _lastRemoteFetchAt = null;
      _inFlightRemoteFetch = null;
      _inFlightRemoteFetchUserEmail = null;
    }

    final now = DateTime.now();
    final canFetchRemote = _lastRemoteFetchAt == null ||
        now.difference(_lastRemoteFetchAt!) >= _remoteFetchCooldown;
    if (!canFetchRemote) return;
    if (_inFlightRemoteFetch != null) return;

    _lastRemoteFetchAt = now;
    final fetch = ExpenseService.getExpenses(userEmail: userEmail);
    _inFlightRemoteFetch = fetch;
    _inFlightRemoteFetchUserEmail = userEmail;
    unawaited(_completeRemoteSync(fetch, userEmail));
  }

  static Future<void> _completeRemoteSync(
    Future<List<Transaction>> fetch,
    String fetchUserEmail,
  ) async {
    try {
      final remoteTransactions = await fetch.timeout(_remoteFetchTimeout);
      if (remoteTransactions.isEmpty) return;

      // If user switched accounts while this request was in-flight, discard.
      final currentUserEmail = await AuthService.getUserEmail();
      if (currentUserEmail == null || currentUserEmail != fetchUserEmail) {
        return;
      }

      final localTransactions = await SmsExpenseService.getStoredTransactions();

      final Map<String, Transaction> merged = {};
      for (final tx in localTransactions) {
        merged[_fingerprint(tx)] = tx;
      }

      bool anyNewRemote = false;
      for (final tx in remoteTransactions) {
        final key = _fingerprint(tx);
        if (!merged.containsKey(key)) anyNewRemote = true;
        merged[key] = tx; // remote wins
      }

      if (!anyNewRemote && merged.length == localTransactions.length) {
        return;
      }

      final mergedList = merged.values.toList();
      mergedList.sort((a, b) => b.date.compareTo(a.date));

      await SmsExpenseService.saveTransactions(
        mergedList,
        emitEvents: false,
        updateWidget: false,
      );

      try {
        _transactionsUpdatedController.add(null);
      } catch (_) {}
    } catch (e) {
      // Ignore network errors; local cache remains usable.
      print('Error syncing transactions: $e');
    } finally {
      if (identical(_inFlightRemoteFetch, fetch) &&
          _inFlightRemoteFetchUserEmail == fetchUserEmail) {
        _inFlightRemoteFetch = null;
        _inFlightRemoteFetchUserEmail = null;
      }
    }
  }

  /// Add a new transaction (manual entry)
  static Future<void> addTransaction(Transaction transaction) async {
    // Backwards-compatible wrapper used by manual entry.
    // For receipt flows that need stronger guarantees, use addTransactionAndSync.
    await addTransactionAndSync(transaction);
  }

  /// Save a transaction locally (and notify listeners), without contacting backend.
  static Future<void> addTransactionLocal(Transaction transaction) async {
    await SmsExpenseService.saveTransactions([transaction]);
    // Also fire the full-list-updated event so any listener (e.g. HomeScreen)
    // does a complete reload from storage, not just an in-memory insert.
    try {
      _transactionsUpdatedController.add(null);
    } catch (_) {}
  }

  /// Add a transaction and attempt to sync it to backend.
  ///
  /// Returns whether the backend insert succeeded.
  static Future<bool> addTransactionAndSync(Transaction transaction) async {
    // 1) Local save first so the app never loses user input.
    await addTransactionLocal(transaction);

    // 2) Backend sync (best-effort). Backend only supports expenses right now.
    if (transaction.type.toLowerCase() != 'expense') return false;
    return ExpenseService.addExpense(transaction);
  }

  /// Update transaction category (for manual editing)
  static Future<void> updateTransactionCategory(
      String transactionId, String newCategory) async {
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
        type: tx.type,
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
