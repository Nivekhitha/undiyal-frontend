import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to parse bank balance SMS messages
class BalanceSmsParser {
  /// Stream controller for balance updates
  static final StreamController<Map<String, dynamic>> _balanceUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream that emits when a new balance is detected
  static Stream<Map<String, dynamic>> get onBalanceUpdate =>
      _balanceUpdateController.stream;

  /// Bank patterns for balance detection - improved regex for various SMS formats
  static final Map<String, RegExp> _bankPatterns = {
    'BOB': RegExp(
      r'(?:Clear\s*Bal|Balance).*?(?:Rs\.?|INR)\s*([0-9,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ),
    'CUB': RegExp(
      r'(?:Available\s*Balance|Avail\s*Bal|A\/c\s*Balance).*?(?:INR|Rs\.?)\s*([0-9,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ),
    'IOB': RegExp(
      r'(?:Available\s*Balance|Avail\s*Bal|A\/c\s*Balance).*?(?:INR|Rs\.?)\s*([0-9,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ),
    'HDFC': RegExp(
      r'(?:avl\.?\s*bal|available\s*bal(?:ance)?)\s*(?:is)?\s*(?:₹|rs\.?|inr)\s*([0-9,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ),
    'AXIS': RegExp(
      r'(?:avail(?:able)?\s*bal(?:ance)?)\s*(?:is)?\s*(?:₹|rs\.?|inr)\s*([0-9,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ),
    'SBI': RegExp(
      r'(?:avl\.?\s*bal|a\/c\s*bal)\s*(?:in\s*a\/c\s*\w+)?\s*(?:is)?\s*(?:₹|rs\.?|inr)\s*([0-9,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ),
  };

  /// Bank identifiers in SMS sender or body
  static final Map<String, List<String>> _bankIdentifiers = {
    'BOB': ['Bank of Baroda', 'BOB', 'MConnect+'],
    'CUB': ['City Union Bank', 'CUB'],
    'IOB': ['Indian Overseas Bank', 'IOB'],
    'HDFC': ['HDFC Bank', 'HDFC'],
    'AXIS': ['Axis Bank', 'AXIS'],
    'SBI': ['SBI', 'State Bank'],
  };

  static final RegExp _transactionActionRegex = RegExp(
    r'\b(?:debited|credited|spent|paid|withdrawn|deducted|charged|purchase|upi\s*txn|imps\s*txn|neft\s*txn)\b',
    caseSensitive: false,
  );

  /// Strict check for balance-only SMS (used in Balance Setup Mode)
  static bool isBalanceOnlySms(String body) {
    final normalizedBody = body.toLowerCase();

    final hasBalanceKeyword = normalizedBody.contains('available balance') ||
        normalizedBody.contains('avail bal') ||
        normalizedBody.contains('avl bal') ||
        normalizedBody.contains('a/c bal') ||
        normalizedBody.contains('account balance') ||
        normalizedBody.contains('clear bal') ||
        normalizedBody.contains('closing balance') ||
        normalizedBody.contains('balance is');

    if (!hasBalanceKeyword) return false;

    return !_transactionActionRegex.hasMatch(normalizedBody);
  }

  /// Check if SMS is a balance message and extract amount using keyword matching
  static Map<String, dynamic>? parseBalanceSms(String body, String? sender) {
    // Normalize text for better matching
    final normalizedBody = body.toLowerCase();
    final normalizedSender = sender?.toLowerCase() ?? '';

    // Keywords that indicate a balance SMS
    final balanceKeywords = [
      // Standard
      'available balance',
      'avail balance',
      'avail bal',
      'avl bal',
      'avlbal',
      'avl bal:',
      'avl bal is',

      // Account variations
      'a/c bal',
      'a/c balance',
      'account balance',
      'acct balance',
      'ac balance',

      // Short formats
      'bal:',
      'bal :',
      'bal is',
      'bal amt',
      'bal amount',

      // Banking terms
      'clear bal',
      'cleared balance',
      'closing bal',
      'closing balance',

      'current bal',
      'current balance',
      'net bal',

      // SMS style compact forms
      'avl.bal',
      'avl_bal',
      'availbal',
      'avbl bal',

      // Sentences banks use
      'is your available balance',
      'has an available balance of',
      'your account balance is',
      'balance in your account is',
      'remaining balance is'
    ];

    // Check if this is a balance message
    bool isBalanceMessage = false;
    for (final keyword in balanceKeywords) {
      if (normalizedBody.contains(keyword)) {
        isBalanceMessage = true;
        break;
      }
    }

    if (!isBalanceMessage) {
      // Check sender patterns too
      final bankSenders = ['sbi', 'hdfc', 'axis', 'bob', 'iob', 'cub', 'bank'];
      bool isBankSender = false;
      for (final bank in bankSenders) {
        if (normalizedSender.contains(bank)) {
          isBankSender = true;
          break;
        }
      }
      if (!isBankSender) return null;
    }

    // Determine bank from sender or body
    String? detectedBank;
    for (final entry in _bankIdentifiers.entries) {
      for (final identifier in entry.value) {
        if (normalizedBody.contains(identifier.toLowerCase()) ||
            normalizedSender.contains(identifier.toLowerCase())) {
          detectedBank = entry.key;
          break;
        }
      }
      if (detectedBank != null) break;
    }

    // If no bank detected, check all patterns
    if (detectedBank == null) {
      for (final entry in _bankPatterns.entries) {
        final match = entry.value.firstMatch(body);
        if (match != null) {
          detectedBank = entry.key;
          break;
        }
      }
    }

    // Generic balance extraction if no specific bank detected but keywords present
    if (detectedBank == null && isBalanceMessage) {
      // Try generic balance pattern
      final genericPattern = RegExp(
        r'(?:balance|bal).*?(?:rs\.?|inr)\s*([0-9,]+(?:\.\d{1,2})?)',
        caseSensitive: false,
      );
      final match = genericPattern.firstMatch(body);
      if (match != null) {
        final amountStr = match.group(1) ?? '0';
        final amount = double.tryParse(amountStr.replaceAll(',', '')) ?? 0.0;
        if (amount > 0) {
          return {
            'bank': 'Unknown',
            'balance': amount,
            'rawAmount': amountStr,
          };
        }
      }
      return null;
    }

    // If still no bank, not a balance message
    if (detectedBank == null) return null;

    // Try to extract balance using bank-specific pattern
    final pattern = _bankPatterns[detectedBank];
    if (pattern == null) return null;

    final match = pattern.firstMatch(body);
    if (match != null) {
      final amountStr = match.group(1) ?? '0';
      final amount = double.tryParse(amountStr.replaceAll(',', '')) ?? 0.0;
      if (amount > 0) {
        return {
          'bank': detectedBank,
          'balance': amount,
          'rawAmount': amountStr,
        };
      }
    }

    // Fallback: try to find any amount near balance keywords
    // ONLY if balance keywords were actually found in the message.
    // Without this guard, debit/credit transaction SMS from bank senders
    // would be falsely detected as balance updates.
    if (!isBalanceMessage) return null;

    final fallbackPattern = RegExp(
      r'(?:rs\.?|inr)\s*([0-9,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    final fallbackMatch = fallbackPattern.firstMatch(body);
    if (fallbackMatch != null) {
      final amountStr = fallbackMatch.group(1) ?? '0';
      final amount = double.tryParse(amountStr.replaceAll(',', '')) ?? 0.0;
      if (amount > 0) {
        return {
          'bank': detectedBank,
          'balance': amount,
          'rawAmount': amountStr,
        };
      }
    }

    return null;
  }

  /// Store balance in SharedPreferences and notify listeners
  static Future<void> storeBalance(String bank, double balance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('bank_balance_$bank', balance);
    await prefs.setString('bank_balance_last_bank', bank);
    await prefs.setInt(
        'bank_balance_timestamp', DateTime.now().millisecondsSinceEpoch);

    // Notify listeners about the new balance
    _balanceUpdateController.add({
      'bank': bank,
      'balance': balance,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Get stored balance
  static Future<double?> getBalance(String bank) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('bank_balance_$bank');
  }

  /// Get the last detected bank balance
  static Future<Map<String, dynamic>?> getLastBalance() async {
    final prefs = await SharedPreferences.getInstance();
    final bank = prefs.getString('bank_balance_last_bank');
    if (bank == null) return null;

    final balance = prefs.getDouble('bank_balance_$bank');
    final timestamp = prefs.getInt('bank_balance_timestamp');

    if (balance == null) return null;

    return {
      'bank': bank,
      'balance': balance,
      'timestamp': timestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(timestamp)
          : null,
    };
  }

  /// Get all stored balances
  static Future<Map<String, double>> getAllBalances() async {
    final prefs = await SharedPreferences.getInstance();
    final balances = <String, double>{};

    for (final bank in _bankPatterns.keys) {
      final balance = prefs.getDouble('bank_balance_$bank');
      if (balance != null) {
        balances[bank] = balance;
      }
    }

    return balances;
  }

  /// Clear all stored balances
  static Future<void> clearAllBalances() async {
    final prefs = await SharedPreferences.getInstance();
    for (final bank in _bankPatterns.keys) {
      await prefs.remove('bank_balance_$bank');
    }
    await prefs.remove('bank_balance_last_bank');
    await prefs.remove('bank_balance_timestamp');
  }

  // /// Debug function to test balance parsing with sample SMS
  // static Future<void> testBalanceParsing() async {
  //   final testSmsMessages = [
  //     // HDFC Bank
  //     {'body': 'HDFC Bank: Your A/c XX1234 debited by Rs.500.00 on 15/01/24. Avl Bal Rs.5,000.00. Call 18002586161 for queries.', 'sender': 'HDFC'},
  //     {'body': 'HDFC Bank: Your A/c XX1234 credited by Rs.1,000.00 on 16/01/24. Avl Bal Rs.6,000.00. Call 18002586161 for queries.', 'sender': 'HDFC'},

  //     // SBI Bank
  //     {'body': 'SBI: Acct XX5678 debited Rs.250.00 on 15/01/24 Avl Bal Rs.10,500.00 CR. SMS BLOCK 9223000333', 'sender': 'SBI'},
  //     {'body': 'SBI: Acct XX5678 credited Rs.500.00 on 16/01/24 Avl Bal Rs.11,000.00 CR. SMS BLOCK 9223000333', 'sender': 'SBI'},

  //     // ICICI Bank
  //     {'body': 'ICICI Bank: Rs.300.00 debited from A/c XX9012 on 15/01/24. Avl Bal Rs.8,700.00. For queries, call 18002662.', 'sender': 'ICICI'},
  //     {'body': 'ICICI Bank: Rs.1,200.00 credited to A/c XX9012 on 16/01/24. Avl Bal Rs.9,900.00. For queries, call 18002662.', 'sender': 'ICICI'},

  //     // Axis Bank
  //     {'body': 'AXIS: Acct XX3456 debited INR 450.00 on 15/01/24. Avl Bal INR 15,550.00. Call 18605005555 for balance info.', 'sender': 'AXIS'},
  //     {'body': 'AXIS: Acct XX3456 credited INR 800.00 on 16/01/24. Avl Bal INR 16,350.00. Call 18605005555 for balance info.', 'sender': 'AXIS'},

  //     // Bank of Baroda
  //     {'body': 'BOB: Clear Bal Rs.12,000.00 in A/c XX7890 as on 15/01/24. MConnect+ for more details.', 'sender': 'BOB'},
  //     {'body': 'BOB: Ac XX7890 credited Rs.2,000.00 on 16/01/24. Clear Bal Rs.14,000.00. MConnect+ for more details.', 'sender': 'BOB'},
  //   ];

  //   debugPrint('=== BALANCE SMS PARSING TEST ===');
  //   for (var i = 0; i < testSmsMessages.length; i++) {
  //     final sms = testSmsMessages[i];
  //     final body = sms['body'] as String;
  //     final sender = sms['sender'] as String;

  //     debugPrint('\n--- Test SMS ${i + 1} ---');
  //     debugPrint('Sender: $sender');
  //     debugPrint('Body: $body');

  //     final result = parseBalanceSms(body, sender);
  //     if (result != null) {
  //       debugPrint('✅ DETECTED: Bank=${result['bank']}, Balance=₹${result['balance']}');

  //       // Test storage
  //       await storeBalance(result['bank'] as String, result['balance'] as double);
  //       debugPrint('✅ STORED: Balance saved for ${result['bank']}');
  //     } else {
  //       debugPrint('❌ NOT DETECTED: Not a balance SMS');
  //     }
  //   }

  //   // Test retrieval
  //   debugPrint('\n--- TESTING BALANCE RETRIEVAL ---');
  //   final allBalances = await getAllBalances();
  //   debugPrint('Stored balances: $allBalances');

  //   final lastBalance = await getLastBalance();
  //   if (lastBalance != null) {
  //     debugPrint('Last balance: ${lastBalance['bank']} - ₹${lastBalance['balance']}');
  //   }

  //   debugPrint('=== BALANCE SMS PARSING TEST COMPLETED ===');
  // }

  /// Format bank code to full name
  static String getBankFullName(String code) {
    final names = {
      'BOB': 'Bank of Baroda',
      'CUB': 'City Union Bank',
      'IOB': 'Indian Overseas Bank',
      'HDFC': 'HDFC Bank',
      'AXIS': 'Axis Bank',
      'SBI': 'State Bank of India',
    };
    return names[code] ?? code;
  }
}
