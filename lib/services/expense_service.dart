import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import 'auth_service.dart';

class ExpenseService {
  static const String baseUrl = 'https://undiyal-backend-8zqj.onrender.com';

  static const String _postedFingerprintsKey = 'expense_posted_fingerprints_v1';

  static String _twoDigits(int v) => v.toString().padLeft(2, '0');

  static String _formatInvoiceDate(DateTime date) {
    final yy = (date.year % 100);
    return '${_twoDigits(date.day)}-${_twoDigits(date.month)}-${_twoDigits(yy)}';
  }

  static String _normalizePaidStatus(String status) {
    final s = status.trim().toLowerCase();
    if (s.isEmpty) return 'Paid';
    if (s == 'paid') return 'Paid';
    if (s == 'unpaid') return 'Unpaid';
    if (s == 'pending') return 'Unpaid';
    if (s == 'completed' || s == 'success' || s == 'successful') return 'Paid';
    return status;
  }

  static String _normalizeSource(bool isAutoDetected) {
    return isAutoDetected ? 'SMS' : 'Manual';
  }

  static String _makeFingerprint({
    required String userEmail,
    required double amount,
    required String merchantName,
    required String invoiceDate,
  }) {
    final merchant = merchantName.toLowerCase().trim();
    final amt = amount.toStringAsFixed(2);
    return '$userEmail|$amt|$merchant|$invoiceDate';
  }

  static Future<bool> _alreadyPosted(String fingerprint) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_postedFingerprintsKey) ?? const [];
    return list.contains(fingerprint);
  }

  static Future<void> _markPosted(String fingerprint) async {
    final prefs = await SharedPreferences.getInstance();
    final list =
        (prefs.getStringList(_postedFingerprintsKey) ?? <String>[]).toList();
    if (!list.contains(fingerprint)) {
      list.add(fingerprint);
      if (list.length > 2000) {
        list.removeRange(0, list.length - 2000);
      }
      await prefs.setStringList(_postedFingerprintsKey, list);
    }
  }

  /// Add a new expense (POST /expenses)
  static Future<bool> addExpense(Transaction transaction) async {
    try {
      final userEmail = await AuthService.getUserEmail();
      if (userEmail == null) {
        debugPrint('User email not found');
        return false;
      }

      final invoiceDate = _formatInvoiceDate(transaction.date);
      final fingerprint = _makeFingerprint(
        userEmail: userEmail,
        amount: transaction.amount,
        merchantName: transaction.merchant,
        invoiceDate: invoiceDate,
      );

      if (await _alreadyPosted(fingerprint)) {
        debugPrint('Skipping backend POST (already posted): $fingerprint');
        return true;
      }

      final notes = (transaction.referenceNumber != null &&
              transaction.referenceNumber!.trim().isNotEmpty)
          ? 'Paid Trxn Id: ${transaction.referenceNumber}'
          : '';

      // Backend expects these fields.
      final body = <String, dynamic>{
        'user_email': userEmail,
        'amount': transaction.amount,
        'category': transaction.category,
        'merchant_name': transaction.merchant,
        'invoice_date': invoiceDate,
        'payment_mode': transaction.paymentMethod,
        'paid_status': _normalizePaidStatus(transaction.status),
        'notes': notes,
        'source': _normalizeSource(transaction.isAutoDetected),
      };

      debugPrint('Adding expense: ${jsonEncode(body)}');

      final response = await http.post(
        Uri.parse('$baseUrl/expenses'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      debugPrint(
          'Add Expense Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _markPosted(fingerprint);
        return true;
      } else {
        debugPrint('Failed to add expense: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error adding expense: $e');
      return false;
    }
  }

  /// Get expenses for the user (GET /expenses?user_email=...)
  static Future<List<Transaction>> getExpenses({String? userEmail}) async {
    try {
      final email = userEmail ?? await AuthService.getUserEmail();
      if (email == null) {
        debugPrint('User email not found');
        return [];
      }

      debugPrint('Fetching expenses for: $email');

      final response = await http
          .get(
        Uri.parse('$baseUrl/expenses')
            .replace(queryParameters: {'user_email': email}),
      )
          .timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          throw TimeoutException('GET /expenses timed out');
        },
      );

      debugPrint(
          'Get Expenses Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);

        List<dynamic> list = [];
        if (data is List) {
          list = data;
        } else if (data is Map && data.containsKey('expenses')) {
          list = data['expenses'];
        } else if (data is Map && data.containsKey('data')) {
          list = data['data'];
        }

        final transactions =
            list.map((json) => Transaction.fromJson(json)).toList();

        // Seed local "already posted" fingerprints from remote data.
        // This prevents duplicate POSTs if we later try to sync local cached SMS transactions.
        try {
          for (final tx in transactions) {
            final invoiceDate = _formatInvoiceDate(tx.date);
            final fingerprint = _makeFingerprint(
              userEmail: email,
              amount: tx.amount,
              merchantName: tx.merchant,
              invoiceDate: invoiceDate,
            );
            await _markPosted(fingerprint);
          }
        } catch (_) {
          // best-effort only
        }

        return transactions;
      } else {
        debugPrint('Failed to fetch expenses: ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching expenses: $e');
      return [];
    }
  }
}
