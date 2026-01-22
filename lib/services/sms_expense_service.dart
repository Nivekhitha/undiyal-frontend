import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import 'notification_service.dart';

/// Service for automatically detecting expenses from SMS messages
/// Works fully offline, no backend connection required
class SmsExpenseService {
  static const String _processedSmsKey = 'processed_sms_references';
  static const String _transactionsKey = 'stored_transactions';
  
  // Keywords that indicate transactional SMS (debit/expense)
  static const List<String> _transactionKeywords = [
    'dr', 'debit', 'debited', 'paid', 'spent', 'upi', 'txn', 'transaction',
    'withdrawn', 'deducted', 'rs.', 'inr', 'rupees', 'credited to'
  ];
  
  // Keywords to ignore (OTP, promotional, credit)
  static const List<String> _ignoreKeywords = [
    'otp', 'verification', 'promo', 'offer', 'discount', 'cr', 'credit',
    'credited', 'received', 'deposit', 'balance', 'statement'
  ];

  /// Request SMS permission from user
  static Future<bool> requestSmsPermission() async {
    final status = await Permission.sms.status;
    if (status.isGranted) {
      return true;
    }
    
    final result = await Permission.sms.request();
    return result.isGranted;
  }

  /// Check if SMS permission is granted
  static Future<bool> hasSmsPermission() async {
    final status = await Permission.sms.status;
    return status.isGranted;
  }

  /// DEMO: Read and parse SMS messages for expense detection
  /// Returns list of detected transactions
  static Future<List<Transaction>> detectExpensesFromSms({
    int? limit = 5,
    Duration? since,
  }) async {
    // 1. Check permissions
    if (!await hasSmsPermission()) {
      debugPrint('SMS permission not granted');
      // For demo, try to request it if not granted
      if (!await requestSmsPermission()) {
        return [];
      }
    }

    try {
      // Initialize SMS reader
      final SmsQuery query = SmsQuery();
      
      // 2. Read recent SMS (Last 1-5 messages is enough)
      List<SmsMessage> messages = await query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: limit ?? 5,
      );

      debugPrint('Found ${messages.length} messages');

      final existingTransactions = await getStoredTransactions();
      
      // 3. Process messages
      for (var message in messages) {
        final body = message.body ?? '';
        
        // Check if this SMS was already processed (either saved OR notified)
        final processedIds = await _getProcessedReferences();
        if (processedIds.contains(message.id.toString())) {
          continue;
        }

        // 4. Process ONLY debit transactions (must contain "Dr.")
        if (!body.toLowerCase().contains('dr.')) {
          continue;
        }

        // 5. Detect UPI peer-to-peer transfers (must contain "@ok")
        final upiPattern = RegExp(r'([a-zA-Z0-9]+)@ok[a-zA-Z]+', caseSensitive: false);
        final match = upiPattern.firstMatch(body);

        if (match != null) {
          // 4. From the UPI ID: Extract string BEFORE '@', remove digits, capitalize
          String rawId = match.group(1) ?? '';
          String merchantName = rawId.replaceAll(RegExp(r'[0-9]'), ''); // Remove digits
          if (merchantName.isNotEmpty) {
             merchantName = merchantName[0].toUpperCase() + merchantName.substring(1).toLowerCase();
          } else {
            merchantName = 'Unknown';
          }

          // Extract amount
          double amount = 0.0;
          final amountPattern = RegExp(r'(?:rs\.?|inr|₹)\s*(\d+(?:\.\d{2})?)', caseSensitive: false);
          final amountMatch = amountPattern.firstMatch(body);
          if (amountMatch != null) {
            amount = double.tryParse(amountMatch.group(1) ?? '0') ?? 0.0;
          }

          // Extract Reference
          String? refNumber;
          final refPattern = RegExp(r'(?:Ref:|Reference:|txn)\s*(\d+)', caseSensitive: false);
          final refMatch = refPattern.firstMatch(body);
          if (refMatch != null) {
            refNumber = refMatch.group(1);
          }

          // LOW CONFIDENCE / UNKNOWN MERCHANT CHECK
          if (merchantName == 'Unknown' || merchantName.isEmpty) {
             debugPrint('Low confidence transaction detected. Triggering notification.');
             await NotificationService.showExpenseNotification(
               amount: amount,
               date: message.date ?? DateTime.now(),
             );
             // Mark as processed so we don't notify again
             await _markSmsAsProcessed(message.id.toString());
             continue; // Do NOT save automatically
          }

          // 6. Check for duplicates (Prevent duplicates in storage)
          final isDuplicate = existingTransactions.any((tx) {
             if (refNumber != null && tx.referenceNumber == refNumber) return true;
             return tx.amount == amount && tx.merchant == merchantName; 
          });

          if (isDuplicate) {
            debugPrint('Skipping duplicate transaction for $merchantName');
            await _markSmsAsProcessed(message.id.toString());
            continue; 
          }

          // 5. Populate transaction fields
          final transaction = Transaction(
            id: _generateTransactionId(),
            amount: amount,
            merchant: merchantName,
            category: 'Transfers',
            paymentMethod: 'UPI',
            isAutoDetected: true,
            date: message.date ?? DateTime.now(),
            referenceNumber: refNumber,
            confidenceScore: 1.0, 
          );

          debugPrint('Auto-detected transaction: ${transaction.merchant} - ${transaction.amount}');

          // 6. Save ONLY ONE auto-detected transaction
          await saveTransactions([transaction]);
          await _markSmsAsProcessed(message.id.toString());
          
          return [transaction]; // Return immediately after processing one
        }
      }

      return [];
    } catch (e) {
      debugPrint('Error reading SMS: $e');
      return [];
    }
  }

  /// Parse SMS message to extract expense information
  /// Returns map with amount, merchant, date, type, reference, paymentMethod
  /// Returns null if SMS is not a transactional expense
  static Map<String, dynamic>? _parseSmsForExpense(String smsBody) {
    final body = smsBody.toLowerCase().trim();
    
    // Check if SMS contains transaction keywords
    final hasTransactionKeyword = _transactionKeywords.any((keyword) => body.contains(keyword));
    if (!hasTransactionKeyword) {
      return null;
    }

    // Check if SMS should be ignored (OTP, promotional, credit)
    final shouldIgnore = _ignoreKeywords.any((keyword) => body.contains(keyword));
    if (shouldIgnore) {
      // Double check: if it's a credit transaction, ignore it
      if (body.contains('cr') || body.contains('credit') || body.contains('credited')) {
        return null;
      }
    }

    // Extract amount using regex patterns
    double? amount;
    String? amountStr;
    
    // Pattern 1: "Rs.105.00" or "Rs 105.00" or "₹105.00"
    final pattern1 = RegExp(r'(?:rs\.?|inr|₹)\s*(\d+(?:\.\d{2})?)', caseSensitive: false);
    final match1 = pattern1.firstMatch(body);
    if (match1 != null) {
      amountStr = match1.group(1);
      amount = double.tryParse(amountStr ?? '');
    }

    // Pattern 2: "105.00 Dr" or "105.00 debited"
    if (amount == null) {
      final pattern2 = RegExp(r'(\d+(?:\.\d{2})?)\s*(?:dr|debit|debited)', caseSensitive: false);
      final match2 = pattern2.firstMatch(body);
      if (match2 != null) {
        amountStr = match2.group(1);
        amount = double.tryParse(amountStr ?? '');
      }
    }

    // Pattern 3: "Paid Rs.299" or "spent 299"
    if (amount == null) {
      final pattern3 = RegExp(r'(?:paid|spent)\s*(?:rs\.?|inr|₹)?\s*(\d+(?:\.\d{2})?)', caseSensitive: false);
      final match3 = pattern3.firstMatch(body);
      if (match3 != null) {
        amountStr = match3.group(1);
        amount = double.tryParse(amountStr ?? '');
      }
    }

    if (amount == null || amount <= 0) {
      return null; // No valid amount found
    }

    // Determine transaction type (debit/credit)
    String transactionType = 'debit';
    if (body.contains('cr') || body.contains('credit') || body.contains('credited')) {
      transactionType = 'credit';
    } else if (body.contains('dr') || body.contains('debit') || body.contains('debited') || 
               body.contains('paid') || body.contains('spent')) {
      transactionType = 'debit';
    }

    // Extract merchant/UPI ID
    String merchant = 'Unknown Merchant';
    
    // Pattern 1: UPI ID (e.g., "9042309728@ptyes" or "merchant@upi")
    final upiPattern = RegExp(r'(\w+(?:\.\w+)*@\w+)', caseSensitive: false);
    final upiMatch = upiPattern.firstMatch(body);
    if (upiMatch != null) {
      merchant = upiMatch.group(1) ?? 'UPI Payment';
    }

    // Pattern 2: "to MerchantName" or "from MerchantName"
    final toPattern = RegExp(r'(?:to|from)\s+([A-Z][A-Za-z\s&]+)', caseSensitive: false);
    final toMatch = toPattern.firstMatch(smsBody); // Use original case
    if (toMatch != null && merchant == 'Unknown Merchant') {
      merchant = toMatch.group(1)?.trim() ?? 'Unknown Merchant';
    }

    // Pattern 3: Common merchant names in SMS
    final merchantKeywords = [
      'amazon', 'flipkart', 'zomato', 'swiggy', 'uber', 'ola', 'rapido',
      'paytm', 'phonepe', 'gpay', 'airtel', 'jio', 'vi', 'vodafone'
    ];
    for (var keyword in merchantKeywords) {
      if (body.contains(keyword)) {
        merchant = keyword.substring(0, 1).toUpperCase() + keyword.substring(1);
        break;
      }
    }

    // Extract reference number
    String? referenceNumber;
    final refPattern = RegExp(r'(?:ref|reference|txn|transaction)[\s:]*([A-Z0-9]{6,})', caseSensitive: false);
    final refMatch = refPattern.firstMatch(body);
    if (refMatch != null) {
      referenceNumber = refMatch.group(1);
    }

    // Extract date (default to current time if not found)
    DateTime transactionDate = DateTime.now();
    
    // Try to parse date from SMS (format: "on DD/MM/YYYY" or "at HH:MM")
    // For simplicity, we'll use SMS received date
    // In production, you could parse date from SMS body if available

    // Determine payment method
    String paymentMethod = 'UPI';
    if (body.contains('upi')) {
      paymentMethod = 'UPI';
    } else if (body.contains('card') || body.contains('debit card') || body.contains('credit card')) {
      paymentMethod = 'Card';
    } else if (body.contains('account') || body.contains('a/c')) {
      paymentMethod = 'Bank Transfer';
    }

    return {
      'amount': amount,
      'merchant': merchant,
      'date': transactionDate,
      'type': transactionType,
      'reference': referenceNumber,
      'paymentMethod': paymentMethod,
    };
  }

  /// AI-style expense categorization using rule-based + heuristic logic
  /// Returns category and confidence score (0-1)
  static Map<String, dynamic> _categorizeExpense(String merchant, double amount) {
    final merchantLower = merchant.toLowerCase();
    double confidence = 0.0;
    String category = 'Others';

    // Food & Drink category
    final foodKeywords = ['zomato', 'swiggy', 'uber eats', 'food', 'restaurant', 'cafe', 
                          'starbucks', 'mcdonald', 'kfc', 'pizza', 'burger', 'hotel'];
    if (foodKeywords.any((keyword) => merchantLower.contains(keyword))) {
      category = 'Food & Drink';
      confidence = 0.9;
      return {'category': category, 'confidence': confidence};
    }

    // Transport category
    final transportKeywords = ['uber', 'ola', 'rapido', 'taxi', 'cab', 'metro', 'bus', 
                               'train', 'railway', 'flight', 'airline'];
    if (transportKeywords.any((keyword) => merchantLower.contains(keyword))) {
      category = 'Transport';
      confidence = 0.9;
      return {'category': category, 'confidence': confidence};
    }

    // Shopping category
    final shoppingKeywords = ['amazon', 'flipkart', 'myntra', 'nykaa', 'shop', 'store', 
                               'mall', 'market'];
    if (shoppingKeywords.any((keyword) => merchantLower.contains(keyword))) {
      category = 'Shopping';
      confidence = 0.85;
      return {'category': category, 'confidence': confidence};
    }

    // Bills category
    final billsKeywords = ['airtel', 'jio', 'vi', 'vodafone', 'bsnl', 'electricity', 
                           'water', 'gas', 'internet', 'broadband', 'dth', 'cable'];
    if (billsKeywords.any((keyword) => merchantLower.contains(keyword))) {
      category = 'Bills';
      confidence = 0.9;
      return {'category': category, 'confidence': confidence};
    }

    // Entertainment category
    final entertainmentKeywords = ['netflix', 'spotify', 'prime', 'hotstar', 'youtube', 
                                   'movie', 'cinema', 'theater', 'game'];
    if (entertainmentKeywords.any((keyword) => merchantLower.contains(keyword))) {
      category = 'Entertainment';
      confidence = 0.85;
      return {'category': category, 'confidence': confidence};
    }

    // Education category
    final educationKeywords = ['university', 'college', 'school', 'tuition', 'course', 
                               'book', 'stationery'];
    if (educationKeywords.any((keyword) => merchantLower.contains(keyword))) {
      category = 'Education';
      confidence = 0.8;
      return {'category': category, 'confidence': confidence};
    }

    // Health category
    final healthKeywords = ['pharmacy', 'medical', 'hospital', 'clinic', 'doctor', 
                            'medicine', 'apollo', 'fortis'];
    if (healthKeywords.any((keyword) => merchantLower.contains(keyword))) {
      category = 'Health';
      confidence = 0.85;
      return {'category': category, 'confidence': confidence};
    }

    // Groceries (heuristic: medium amounts, common grocery keywords)
    final groceryKeywords = ['grocery', 'supermarket', 'dmart', 'big bazaar', 'reliance'];
    if (groceryKeywords.any((keyword) => merchantLower.contains(keyword)) ||
        (amount >= 100 && amount <= 2000 && merchantLower.contains('store'))) {
      category = 'Groceries';
      confidence = 0.7;
      return {'category': category, 'confidence': confidence};
    }

    // Default to Others with low confidence
    confidence = 0.3;
    return {'category': category, 'confidence': confidence};
  }

  /// Get list of already processed SMS message IDs
  static Future<Set<String>> _getProcessedReferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refsJson = prefs.getString(_processedSmsKey);
      if (refsJson != null) {
        final List<dynamic> refsList = jsonDecode(refsJson);
        return refsList.map((e) => e.toString()).toSet();
      }
    } catch (e) {
      debugPrint('Error reading processed references: $e');
    }
    return {};
  }

  /// Mark SMS message as processed to avoid duplicates
  static Future<void> _markSmsAsProcessed(String smsId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final processedRefs = await _getProcessedReferences();
      processedRefs.add(smsId);
      
      final refsList = processedRefs.toList();
      await prefs.setString(_processedSmsKey, jsonEncode(refsList));
    } catch (e) {
      debugPrint('Error marking SMS as processed: $e');
    }
  }

  /// Generate unique transaction ID
  static String _generateTransactionId() {
    return 'sms_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  /// Save detected transactions to local storage
  static Future<void> saveTransactions(List<Transaction> transactions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingTransactions = await getStoredTransactions();
      
      // Merge with existing transactions, avoiding duplicates
      final Map<String, Transaction> transactionMap = {};
      
      // Add existing transactions
      for (var tx in existingTransactions) {
        transactionMap[tx.id] = tx;
      }
      
      // Add new transactions (will overwrite if same ID)
      for (var tx in transactions) {
        transactionMap[tx.id] = tx;
      }
      
      // Convert to JSON and save
      final transactionsJson = transactionMap.values.map((tx) => _transactionToJson(tx)).toList();
      await prefs.setString(_transactionsKey, jsonEncode(transactionsJson));
    } catch (e) {
      debugPrint('Error saving transactions: $e');
    }
  }

  /// Get stored transactions from local storage
  static Future<List<Transaction>> getStoredTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final transactionsJson = prefs.getString(_transactionsKey);
      
      if (transactionsJson != null) {
        final List<dynamic> transactionsList = jsonDecode(transactionsJson);
        return transactionsList.map((json) => _transactionFromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error reading stored transactions: $e');
    }
    return [];
  }

  /// Convert Transaction to JSON
  static Map<String, dynamic> _transactionToJson(Transaction tx) {
    return {
      'id': tx.id,
      'amount': tx.amount,
      'merchant': tx.merchant,
      'category': tx.category,
      'date': tx.date.toIso8601String(),
      'paymentMethod': tx.paymentMethod,
      'status': tx.status,
      'receiptUrl': tx.receiptUrl,
      'isRecurring': tx.isRecurring,
      'isAutoDetected': tx.isAutoDetected,
      'referenceNumber': tx.referenceNumber,
      'confidenceScore': tx.confidenceScore,
    };
  }

  /// Convert JSON to Transaction
  static Transaction _transactionFromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      merchant: json['merchant'] as String,
      category: json['category'] as String,
      date: DateTime.parse(json['date'] as String),
      paymentMethod: json['paymentMethod'] as String,
      status: json['status'] as String? ?? 'completed',
      receiptUrl: json['receiptUrl'] as String?,
      isRecurring: json['isRecurring'] as bool? ?? false,
      isAutoDetected: json['isAutoDetected'] as bool? ?? false,
      referenceNumber: json['referenceNumber'] as String?,
      confidenceScore: json['confidenceScore'] != null ? (json['confidenceScore'] as num).toDouble() : null,
    );
  }

  /// Check for duplicate transactions based on reference number and amount
  static Future<bool> isDuplicate(Transaction transaction) async {
    if (transaction.referenceNumber == null) {
      return false; // Can't check duplicates without reference
    }
    
    final existingTransactions = await getStoredTransactions();
    return existingTransactions.any((tx) =>
        tx.referenceNumber == transaction.referenceNumber &&
        tx.amount == transaction.amount &&
        tx.date.difference(transaction.date).abs().inDays < 1);
  }

  /// Clear all stored transactions and processed references
  static Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_transactionsKey);
      await prefs.remove(_processedSmsKey);
      debugPrint('All transaction data cleared.');
    } catch (e) {
      debugPrint('Error clearing data: $e');
    }
  }
}

