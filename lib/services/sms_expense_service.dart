import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import 'home_widget_service.dart';
import 'expense_service.dart';
import 'auth_service.dart';
import 'balance_sms_parser.dart';
import 'transaction_storage_service.dart';

/// Service for automatically detecting expenses from SMS messages
/// Works fully offline, no backend connection required
class SmsExpenseService {
  static const String _processedSmsKey = 'processed_sms_references';
  static const String _legacyTransactionsKey = 'stored_transactions';
  static const String _transactionsKeyPrefix = 'stored_transactions_user_v1_';

  static String _sanitizeKeyPart(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9._\-]'), '_');
  }

  static Future<String> _transactionsKeyForCurrentUser(
    SharedPreferences prefs,
  ) async {
    final userEmail = await AuthService.getUserEmail();
    if (userEmail == null || userEmail.trim().isEmpty) {
      return _legacyTransactionsKey;
    }

    final userKey = '$_transactionsKeyPrefix${_sanitizeKeyPart(userEmail)}';

    // One-time migration: if legacy exists but userKey doesn't, move it.
    if (!prefs.containsKey(userKey) &&
        prefs.containsKey(_legacyTransactionsKey)) {
      final legacyJson = prefs.getString(_legacyTransactionsKey);
      if (legacyJson != null) {
        await prefs.setString(userKey, legacyJson);
      }
      await prefs.remove(_legacyTransactionsKey);
    }

    return userKey;
  }

  // ===== SENDER-BASED FILTERING =====

  // Known bank SMS sender patterns (case-insensitive partial match)
  // Indian banks send from senders like VM-BOBROI, AD-HDFCBK, BZ-SBIINB, etc.
  static const List<String> _bankSenderPatterns = [
    'bob',
    'hdfc',
    'sbi',
    'icici',
    'axis',
    'kotak',
    'idbi',
    'pnb',
    'cub',
    'iob',
    'canara',
    'union',
    'boi',
    'baroda',
    'indian',
    'yesbank',
    'indus',
    'rbl',
    'federal',
    'idfc',
    'bandhan',
    'dbs',
    'citi',
    'sc bank',
  ];

  // Known promotional/spam sender patterns to ALWAYS ignore
  static const List<String> _promoSenderPatterns = [
    'airtel', 'jiomkt', 'jio', 'vicare', 'vodafo', 'bsnl',
    'amazon', 'flipkr', 'myntra', 'nykaa', 'swiggy', 'zomato',
    'dream11', 'cred', 'groww', 'zerodha', 'angel', 'upstox',
    'ajio', 'tata', 'bigbsk', 'meesho', 'snapdl',
    'policybazaar', 'policyx', 'insure',
    'olacab', 'uber', 'rapido',
    'makemy', 'goibibo', 'ixigo', 'irctc',
    'hotstar', 'netflix', 'spotify', 'prime',
    'dominos', 'mcdonald', 'kfc', 'pizzahut',
    'lenskart', 'titan', 'tanishq', 'swiggyinsta', 'zomatodeal',

    // Travel deals
    'makemytrip', 'goibibo', 'ixigo',

    // OTT marketing
    'hotstar', 'netflix', 'spotifyoffers',

    // Gaming
    'dream11promo',

    // Insurance marketing IDs
    'policybazaar', 'policyx',
  ];

  // ===== TRANSACTION KEYWORD DETECTION =====

  // Regex patterns for precise keyword matching with word boundaries
  static final RegExp _debitRegex = RegExp(
    r'(?<!\w)(?:'
    r'dr\.?|dr\.?\s+from|'
    r'debit(?:ed)?|'
    r'paid|spent|withdrawn|deducted|charged|billed|'
    r'purchase|payment\s+of|auto[- ]debit|'
    r'imps\s*dr|neft\s*dr|upi\s*dr'
    r')(?!\w)',
    caseSensitive: false,
  );

  // STRICT keywords that indicate CREDIT transactions only - using word boundaries
  static final RegExp _creditRegex = RegExp(
    r'(?<!\w)(?:'
    r'cr\.?|cr\.?\s+(?:to|in)|'
    r'credit(?:ed)?|'
    r'received|money\s+received|'
    r'refund(?:ed)?|cashback|reversed|reversal|'
    r'deposited|deposit|salary|interest|'
    r'added\s+to|'
    r'neft\s*cr|imps\s*cr|upi\s*cr|'
    r'transfer(?:red)?\s+to\s+your'
    r')(?!\w)',
    caseSensitive: false,
  );

  // ===== STRUCTURAL VALIDATION PATTERNS =====

  // Patterns that indicate a REAL transactional SMS (not promotional)
  // Note: x+ (not x{2,}) to handle BOB's single-X format like "A/C X3587"
  static final RegExp _accountPattern = RegExp(
    r'(?:a/?c|acct?|account)\s*(?:no\.?\s*)?(?:x+|\*+)?\d{2,}',
    caseSensitive: false,
  );

  static final RegExp _upiTransactionPattern = RegExp(
    r'(?:upi|imps|neft|rtgs|ifsc|ref\s*(?:no|num|id)?[:\s]*[a-z0-9]{6,})',
    caseSensitive: false,
  );

  // ===== IGNORE / PROMOTIONAL DETECTION =====

  // Comprehensive keywords to ignore (OTP, promotional, marketing, recharge, etc.)
  static const List<String> _ignoreKeywords = [
    // OTP & verification
    'otp', 'verification', 'verify', 'one time password', 'one-time password',
    // Promotional / Marketing
    'promo', 'offer', 'discount', 'reward points', 'cashback offer',
    'win ', 'won ', 'winners', 'lucky draw', 'contest', 'coupon',
    'exclusive deal', 'limited time', 'hurry', 'expires', 'expiring',
    'use code', 'apply code', 'promo code', 'voucher', 'gift card',
    'flat rs', 'flat ₹', 'upto rs', 'upto ₹', 'up to rs', 'save rs', 'save ₹',
    'get rs', 'get ₹', 'earn rs', 'earn ₹', 'extra rs',
    '% off', 'percent off', '% cashback',
    'free delivery', 'free shipping', 'no cost emi',
    // Telecom / Recharge
    'recharge now', 'recharge your', 'pack at rs', 'available with pack',
    'data pack', 'talk time', 'talktime', 'validity',
    'watch every match', 'live on', 'jiohotstar', 'airtel xstream',
    'match-ready pack', 'subscription for', 'click i.airtel',
    'recharge now to enjoy', 'days and also get', 'months in rs',
    'recharge plan', 'prepaid', 'postpaid plan',
    'jiocinema', 'jiomart', 'jiotv',
    // URLs / Links (strong promo indicators)
    'http://', 'https://', 'bit.ly', 'goo.gl', 'click here',
    'download now', 'install now', 'update now', 'upgrade now',
    'app store', 'play store', 'playstore',
    // Loan / Insurance marketing
    'pre-approved', 'preapproved', 'instant loan', 'personal loan',
    'home loan', 'car loan', 'gold loan', 'apply now',
    'credit card offer', 'upgrade your card', 'limit increase',
    'insurance', 'premium due', 'policy',
    // Survey / Feedback
    'rate us', 'feedback', 'survey', 'review',
    // Subscription / Service promotions
    'subscribe', 'renew', 'renewal', 'membership',
    'trial', 'free trial', 'activate',
    // Common spam patterns
    'dear customer, exciting', 'congratulations', 'you have been selected',
    'claim your', 'collect your',
    // EMI / reminder marketing (not actual debits)
    'emi due', 'payment due', 'due date', 'reminder',
    'please pay', 'pay before', 'overdue',
    // Balance inquiry prompts (not actual transactions)
    'check your balance', 'know your balance', 'missed call to',
    'give a missed call', 'dial', 'sms bal',
  ];

  /// Check if sender appears to be a bank/financial institution
  // ignore: unused_element
  static bool _isBankSender(String sender) {
    final senderLower = sender.toLowerCase();
    // Indian bank SMS senders typically follow pattern: XX-BANKNAME (e.g., VM-BOBSMS)
    // Check against known bank patterns
    return _bankSenderPatterns.any((pattern) => senderLower.contains(pattern));
  }

  /// Check if sender is a known promotional sender
  static bool isPromoSender(String sender) {
    final senderLower = sender.toLowerCase();
    return _promoSenderPatterns.any((pattern) => senderLower.contains(pattern));
  }

  // ===== UNICODE NORMALIZATION =====

  /// Normalize Unicode Mathematical Alphanumeric Symbols to plain ASCII.
  /// Banks like BOB use fancy Unicode characters (e.g. 𝖣𝗋 for "Dr") in SMS.
  /// This converts ALL such variants (bold, italic, sans-serif, monospace,
  /// script, fraktur, double-struck, etc.) back to standard A-Z / a-z / 0-9
  /// so downstream regex matching works reliably.
  static String _normalizeUnicodeToAscii(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final ascii = _mathRuneToAscii(rune);
      buffer.writeCharCode(ascii ?? rune);
    }
    return buffer.toString();
  }

  /// Map a single Unicode Mathematical Alphanumeric codepoint to its ASCII
  /// equivalent.  Returns null when [cp] is outside every known math-alpha
  /// block (i.e. it is already plain ASCII or some other symbol).
  static int? _mathRuneToAscii(int cp) {
    // Each style block has 26 uppercase letters followed by 26 lowercase.
    const upperStarts = [
      0x1D400, // Bold
      0x1D434, // Italic
      0x1D468, // Bold Italic
      0x1D49C, // Script
      0x1D4D0, // Bold Script
      0x1D504, // Fraktur
      0x1D538, // Double-Struck
      0x1D56C, // Bold Fraktur
      0x1D5A0, // Sans-Serif  (BOB uses this)
      0x1D5D4, // Sans-Serif Bold
      0x1D608, // Sans-Serif Italic
      0x1D63C, // Sans-Serif Bold Italic
      0x1D670, // Monospace
    ];
    const lowerStarts = [
      0x1D41A,
      0x1D44E,
      0x1D482,
      0x1D4B6,
      0x1D4EA,
      0x1D51E,
      0x1D552,
      0x1D586,
      0x1D5BA,
      0x1D5EE,
      0x1D622,
      0x1D656,
      0x1D68A,
    ];
    for (final s in upperStarts) {
      if (cp >= s && cp < s + 26) return 0x41 + (cp - s); // 'A' + offset
    }
    for (final s in lowerStarts) {
      if (cp >= s && cp < s + 26) return 0x61 + (cp - s); // 'a' + offset
    }
    // Digit blocks (10 chars each)
    const digitStarts = [0x1D7CE, 0x1D7D8, 0x1D7E2, 0x1D7EC, 0x1D7F6];
    for (final s in digitStarts) {
      if (cp >= s && cp < s + 10) return 0x30 + (cp - s); // '0' + offset
    }
    return null;
  }

  // ===== SENDER ID → BANK NAME MAPPING =====

  /// Clean up raw SMS sender ID (e.g. "JM-CUBLTD-S", "CP-CUBANK-S") to a
  /// human-readable bank name.  Returns null if unrecognised.
  static String? _senderToBankName(String? sender) {
    if (sender == null || sender.isEmpty) return null;
    final s = sender.toLowerCase();

    // CUB (City Union Bank)
    if (s.contains('cubltd') || s.contains('cubank') || s.contains('cub')) {
      return 'CUB';
    }
    // BOB (Bank of Baroda)
    if (s.contains('bob') || s.contains('baroda')) return 'Bank of Baroda';
    // Indian Bank
    if (s.contains('indian') || s.contains('indbnk')) return 'Indian Bank';
    // IOB
    if (s.contains('iob')) return 'IOB';
    // SBI
    if (s.contains('sbi')) return 'SBI';
    // HDFC
    if (s.contains('hdfc')) return 'HDFC';
    // ICICI
    if (s.contains('icici')) return 'ICICI';
    // Axis
    if (s.contains('axis')) return 'Axis Bank';
    // Kotak
    if (s.contains('kotak')) return 'Kotak';
    // PNB
    if (s.contains('pnb')) return 'PNB';
    // Canara
    if (s.contains('canara')) return 'Canara Bank';

    return null;
  }

  /// Extract a short counterparty label from a CUB-style account reference
  /// like "XXXXXXXX0051" → "A/c ..0051" or "XXXXXXXXIPAY" → "A/c ..IPAY".
  static String _shortAccountLabel(String acctRaw) {
    // Take only the meaningful suffix (last 4–6 chars without leading X's)
    final stripped = acctRaw.replaceAll(RegExp(r'^[Xx*]+'), '');
    if (stripped.isNotEmpty) {
      return 'A/c ..$stripped';
    }
    // If fully masked, show last 4 chars
    final tail =
        acctRaw.length > 4 ? acctRaw.substring(acctRaw.length - 4) : acctRaw;
    return 'A/c ..$tail';
  }

  /// Extract a human-readable UPI name from a UPI ID like
  /// "zepto.payu@axisbank" → "Zepto", "9361234567@ptyes" → "UPI Transfer".
  static String _upiIdToMerchant(String upiId) {
    final parts = upiId.split('@');
    if (parts.isEmpty) return 'UPI Payment';
    String namePart = parts[0];
    if (namePart.contains('.')) namePart = namePart.split('.')[0];
    if (RegExp(r'^\d+$').hasMatch(namePart)) return 'UPI Transfer';
    if (namePart.isEmpty) return 'UPI Payment';
    return namePart[0].toUpperCase() + namePart.substring(1);
  }

  /// Validate that SMS has structural markers of a real bank transaction
  static bool _hasTransactionStructure(String body) {
    final bodyLower = body.toLowerCase();
    // Must have at least ONE of these structural elements:
    // 1. Account number pattern (A/C XX1234, Acct XX5678)
    // 2. UPI/IMPS/NEFT reference
    // 3. Balance mention after transaction
    // 4. Bank name in body

    bool hasAccountRef = _accountPattern.hasMatch(bodyLower);
    bool hasPaymentRef = _upiTransactionPattern.hasMatch(bodyLower);
    bool hasBalanceMention = RegExp(
            r'(?:avail|avl|available|clear|closing)\s*(?:bal|balance)',
            caseSensitive: false)
        .hasMatch(bodyLower);
    bool hasBankName = _bankSenderPatterns.any((b) => bodyLower.contains(b));

    return hasAccountRef || hasPaymentRef || hasBalanceMention || hasBankName;
  }

  /// Request SMS permission from user
  static Future<bool> requestSmsPermission() async {
    final status = await Permission.sms.status;
    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      debugPrint('SMS permission permanently denied.');
      return false;
    }

    debugPrint('Requesting SMS permission...');
    final result = await Permission.sms.request();
    debugPrint('SMS permission result: $result');
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
    int? limit = 500, // Increased default limit for past month
    Duration? since,
  }) async {
    debugPrint('=== SMS EXPENSE DETECTION STARTED ===');

    // 1. Check permissions
    if (!await hasSmsPermission()) {
      debugPrint('SMS permission not granted');
      // For demo, try to request it if not granted
      if (!await requestSmsPermission()) {
        debugPrint('SMS permission denied - aborting detection');
        return [];
      }
    }

    try {
      // Initialize SMS reader
      final SmsQuery query = SmsQuery();

      // 2. Read SMS from past month (or custom duration)
      final DateTime startDate = since != null
          ? DateTime.now().subtract(since)
          : DateTime.now()
              .subtract(const Duration(days: 30)); // Default: past 30 days

      debugPrint(
          'Reading SMS messages from ${startDate.toString()} (limit: ${limit ?? 500})...');

      List<SmsMessage> messages = await query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: limit ?? 500,
      );

      // Filter messages to only include those from the past month
      final filteredMessages = messages.where((message) {
        final messageDate = message.date;
        return messageDate != null && messageDate.isAfter(startDate);
      }).toList();

      debugPrint(
          'Found ${filteredMessages.length} SMS messages from past month to process (filtered from ${messages.length} total)');

      final existingTransactions = await getStoredTransactions();
      debugPrint('Found ${existingTransactions.length} existing transactions');

      // 3. Process messages - COLLECT ALL TRANSACTIONS
      List<Transaction> detectedTransactions = [];
      int processedCount = 0;
      int skippedCount = 0;
      int balanceCount = 0;
      int expenseCount = 0;

      for (var message in filteredMessages) {
        processedCount++;
        final body = message.body ?? '';
        final sender = message.address ?? 'Unknown';

        debugPrint(
            '--- Processing SMS ${processedCount}/${filteredMessages.length} ---');
        debugPrint('Sender: $sender');
        debugPrint('Body (first 100 chars): ${body.take(100)}...');

        // Check if this SMS was already processed
        final processedIds = await _getProcessedReferences();
        if (processedIds.contains(message.id.toString())) {
          debugPrint('Skipping already processed msg ID: ${message.id}');
          skippedCount++;
          continue;
        }

        // SENDER FILTER: Skip messages from known promo senders
        if (isPromoSender(sender)) {
          debugPrint('⚠ Skipping promotional sender: $sender');
          await _markSmsAsProcessed(message.id.toString());
          skippedCount++;
          continue;
        }

        // 4a. SKIP BALANCE-ONLY SMS (e.g. missed-call alerts).
        // Uses the strict check that REJECTS SMS containing transaction
        // keywords like "credited"/"debited", so real transactions still
        // pass through to the transaction parser below.
        if (BalanceSmsParser.isBalanceOnlySms(body)) {
          debugPrint(
              '⚠ Balance-only SMS detected, skipping (notification listener handles balance)');
          await _markSmsAsProcessed(message.id.toString());
          balanceCount++;
          continue;
        }

        // 4b. Parse the SMS for EXPENSE using robust logic (includes sender info)
        final parsedData = parseSmsForExpense(body, sender: sender);

        if (parsedData == null) {
          debugPrint('✗ Not a transaction SMS or ignored');
          await _markSmsAsProcessed(
              message.id.toString()); // Mark to avoid reprocessing
          skippedCount++;
          continue;
        }

        debugPrint('✓ Parsed transaction data: $parsedData');

        double amount = parsedData['amount'];
        String merchantName = parsedData['merchant'];
        String? refNumber = parsedData['reference'];
        String paymentMethod = parsedData['paymentMethod'];

        // LOW CONFIDENCE CHECK - only skip if truly unknown
        if (merchantName == 'Expense' || merchantName.isEmpty) {
          debugPrint('⚠ Generic expense detected - using default name');
          // Use default name and continue - don't skip
        }

        // 6. Check for duplicates (Prevent duplicates in storage)
        final isDuplicate = existingTransactions.any((tx) {
          if (refNumber != null && tx.referenceNumber == refNumber) return true;
          // Fuzzy match: same amount, same merchant, same day
          final sameDay = tx.date.year == (message.date?.year ?? 0) &&
              tx.date.month == (message.date?.month ?? 0) &&
              tx.date.day == (message.date?.day ?? 0);
          return tx.amount == amount && tx.merchant == merchantName && sameDay;
        });

        if (isDuplicate) {
          debugPrint('⚠ Skipping duplicate transaction for $merchantName');
          await _markSmsAsProcessed(message.id.toString());
          skippedCount++;
          continue;
        }

        // 5. Populate transaction fields
        final txType = parsedData['type'] ?? 'expense';
        final transaction = Transaction(
          id: _generateTransactionId(),
          amount: amount,
          merchant: merchantName,
          category: categorizeExpense(merchantName, amount,
              transactionType: txType)['category'],
          paymentMethod: paymentMethod,
          isAutoDetected: true,
          date: message.date ?? DateTime.now(),
          referenceNumber: refNumber,
          confidenceScore: 1.0,
          type: txType,
        );

        debugPrint(
            '✓ Auto-detected transaction: ${transaction.merchant} - ₹${transaction.amount} (${transaction.type})');

        // Add to collection instead of returning immediately
        detectedTransactions.add(transaction);
        expenseCount++;
        await _markSmsAsProcessed(message.id.toString());
      }

      // 6. Save ALL detected transactions at once
      if (detectedTransactions.isNotEmpty) {
        await saveTransactions(detectedTransactions);
        debugPrint(
            '✓ Saved ${detectedTransactions.length} transactions from SMS');

        // Sync to backend
        for (var transaction in detectedTransactions) {
          try {
            await ExpenseService.addExpense(transaction);
            debugPrint(
                '✓ Synced transaction to backend: ${transaction.merchant}');
          } catch (e) {
            debugPrint('✗ Failed to sync SMS transaction to backend: $e');
          }
        }
      }

      debugPrint('=== SMS DETECTION SUMMARY ===');
      debugPrint('Total messages processed: $processedCount');
      debugPrint('Balance messages found: $balanceCount');
      debugPrint('Expense transactions found: $expenseCount');
      debugPrint('Messages skipped: $skippedCount');
      debugPrint('Transactions saved: ${detectedTransactions.length}');
      debugPrint('=== SMS EXPENSE DETECTION COMPLETED ===');

      return detectedTransactions;
    } catch (e) {
      debugPrint('✗ Error reading SMS: $e');
      return [];
    }
  }

  /// Parse SMS message to extract expense information
  /// Returns map with amount, merchant, date, type, reference, paymentMethod
  /// Returns null if SMS is not a transactional expense
  ///
  /// Multi-layer filtering approach:
  /// 1. Sender validation (bank vs promo)
  /// 2. Comprehensive ignore keyword check
  /// 3. Transaction keyword detection with word boundaries
  /// 4. Structural validation (account numbers, payment refs)
  /// 5. Amount extraction with context validation
  static Map<String, dynamic>? parseSmsForExpense(String smsBody,
      {String? sender}) {
    debugPrint('Parsing SMS: ${smsBody.take(150)}...');

    // 1. NORMALIZE UNICODE → ASCII first, THEN lowercase.
    //    Banks like BOB embed Mathematical Sans-Serif characters for
    //    Dr/Cr/and/from/to.  _normalizeUnicodeToAscii converts ALL math-alpha
    //    codepoints (bold, italic, sans-serif, etc.) to plain ASCII so every
    //    downstream regex sees normal letters.
    String body = _normalizeUnicodeToAscii(smsBody).toLowerCase().trim();

    debugPrint('Normalized body: ${body.take(150)}...');

    // 2. CHECK IGNORE KEYWORDS FIRST (most important filter)
    final shouldIgnore =
        _ignoreKeywords.any((keyword) => body.contains(keyword));
    debugPrint('Should ignore based on keywords: $shouldIgnore');
    if (shouldIgnore) {
      debugPrint('✗ Ignoring promotional/OTP/marketing message');
      return null;
    }

    // 3. CHECK for transaction keywords using WORD BOUNDARY regex
    //    Neutralise "credit card" / "credit limit" compound nouns so the
    //    bare word "credit" doesn't trigger a false-positive credit match
    //    on what is really a debit SMS.
    final bodyForKw = body
        .replaceAll(RegExp(r'credit\s+card', caseSensitive: false), '_xcard_')
        .replaceAll(
            RegExp(r'credit\s+limit', caseSensitive: false), '_xlimit_');
    final hasExpenseKeyword = _debitRegex.hasMatch(bodyForKw);
    final hasCreditKeyword = _creditRegex.hasMatch(bodyForKw);
    debugPrint('Has expense keyword (regex): $hasExpenseKeyword');
    debugPrint('Has credit keyword (regex): $hasCreditKeyword');

    // Must have either expense or credit keyword
    if (!hasExpenseKeyword && !hasCreditKeyword) {
      debugPrint('✗ No transaction keywords found - not a transaction SMS');
      return null;
    }

    // 4. STRUCTURAL VALIDATION - must look like a real bank SMS
    if (!_hasTransactionStructure(body)) {
      debugPrint(
          '✗ No structural markers of bank transaction (no account/ref/balance)');
      return null;
    }

    // 5. Extract amount using regex patterns
    double? amount;
    String? amountStr;

    // Pattern: "Rs.300.00" or "Rs 105.00" or "₹105.00" or "INR 500.00"
    // Also handle comma-separated amounts: "Rs.8,500.00"
    final amountPattern = RegExp(r'(?:rs\.?|inr|₹)\s*([0-9,]+(?:\.\d{1,2})?)',
        caseSensitive: false);
    final amountMatch = amountPattern.firstMatch(body);
    if (amountMatch != null) {
      amountStr = amountMatch.group(1)?.replaceAll(',', '');
      amount = double.tryParse(amountStr ?? '');
    }

    debugPrint('Extracted amount: $amount from pattern: $amountStr');
    if (amount == null || amount <= 0) {
      debugPrint('✗ No valid amount found, aborting parse');
      return null;
    }

    // 6. Filter out suspiciously small amounts (likely not real transactions)
    if (amount < 1.0) {
      debugPrint(
          '✗ Amount too small (₹$amount), likely not a real transaction');
      return null;
    }

    // 7. Transaction type determination using position-based heuristic
    String transactionType = 'expense';
    String? creditSource;

    if (hasExpenseKeyword && !hasCreditKeyword) {
      // Only debit keywords → expense
      transactionType = 'expense';
      debugPrint('TYPE: Only debit keywords → EXPENSE');
    } else if (hasCreditKeyword && !hasExpenseKeyword) {
      // Only credit keywords → credit
      transactionType = 'credit';
      debugPrint('TYPE: Only credit keywords → CREDIT');
    } else if (hasExpenseKeyword && hasCreditKeyword) {
      // ── BOTH credit AND debit keywords present ──
      //
      // This is typical for Indian bank fund-transfer SMS such as:
      //   BOB debit:  "A/C X3587 debited by Rs.300 … and Cr. to zepto@upi"
      //   BOB credit: "A/C X3587 credited by Rs.2000 … and Dr. from person@upi"
      //
      // Grammar rule: the PRIMARY action (what happened to YOUR account)
      // is always in the first clause, before "and".  The part after "and"
      // describes the counterparty and must be IGNORED for type detection.
      //
      // Strategy:
      //   1. Split at the first "and" / "&" conjunction.
      //   2. Check the PRIMARY clause (before "and") for credit/debit.
      //   3. If both or neither in primary, use positional fallback.

      final andMatch =
          RegExp(r'\band\b|\b&\b', caseSensitive: false).firstMatch(body);
      final primaryClause =
          andMatch != null ? body.substring(0, andMatch.start) : body;

      final primaryHasDebit = _debitRegex.hasMatch(primaryClause);
      final primaryHasCredit = _creditRegex.hasMatch(
        primaryClause
            .replaceAll(
                RegExp(r'credit\s+card', caseSensitive: false), '_xcard_')
            .replaceAll(
                RegExp(r'credit\s+limit', caseSensitive: false), '_xlimit_'),
      );

      debugPrint(
          'TYPE: Both keywords. primaryClause="${primaryClause.take(80)}" '
          'primaryDebit=$primaryHasDebit primaryCredit=$primaryHasCredit');

      if (primaryHasCredit && !primaryHasDebit) {
        transactionType = 'credit';
        debugPrint('TYPE: Primary clause has CREDIT only → CREDIT');
      } else if (primaryHasDebit && !primaryHasCredit) {
        transactionType = 'expense';
        debugPrint('TYPE: Primary clause has DEBIT only → EXPENSE');
      } else {
        // Both or neither in primary clause – fall back to whichever
        // keyword appears FIRST in the full body.
        final debitPos =
            _debitRegex.firstMatch(bodyForKw)?.start ?? body.length;
        final creditPos =
            _creditRegex.firstMatch(bodyForKw)?.start ?? body.length;
        if (creditPos < debitPos) {
          transactionType = 'credit';
          debugPrint(
              'TYPE: Positional fallback – credit appears first → CREDIT');
        } else {
          transactionType = 'expense';
          debugPrint(
              'TYPE: Positional fallback – debit appears first → EXPENSE');
        }
      }
    }

    // Extract source for credit transactions
    if (transactionType == 'credit') {
      // Best signal: a UPI ID (contains @) after "from" or "dr. from"
      final upiSourcePattern = RegExp(
        r'(?:dr\.?\s+from|from|received\s+from)\s+(\w+(?:\.\w+)*@\w+)',
        caseSensitive: false,
      );
      final upiMatch = upiSourcePattern.firstMatch(body);
      if (upiMatch != null) {
        creditSource = upiMatch.group(1);
        debugPrint('Credit source (UPI): $creditSource');
      } else {
        // Fallback: any word after "from" that isn't an amount / account token
        final fallbackFrom = RegExp(
          r'(?:from|received\s+from)\s+([a-zA-Z][a-zA-Z0-9._]+)',
          caseSensitive: false,
        );
        final fbMatch = fallbackFrom.firstMatch(body);
        if (fbMatch != null) {
          final candidate = fbMatch.group(1) ?? '';
          // Skip if it looks like an amount prefix (rs, inr) or account token
          if (!RegExp(r'^(rs|inr|a|ac|a/c)$', caseSensitive: false)
              .hasMatch(candidate)) {
            creditSource = candidate;
            debugPrint('Credit source (fallback): $creditSource');
          }
        }
      }
    }

    // 8. Extract merchant / counterparty with smart defaults
    //    Priority order:
    //    ① UPI ID (from Cr./Dr. to <upi> or "to <upi>")
    //    ② Counterparty account (CUB-style "credited to a/c …" / "debited from a/c …")
    //    ③ Common merchant keyword in body
    //    ④ Cleaned-up bank name from sender
    //    ⑤ Type-appropriate default ("UPI Transfer" / "Bank Transfer")

    String merchant =
        transactionType == 'credit' ? 'Bank Transfer' : 'UPI Transfer';

    // ① UPI IDs ─ "Cr. to <UPI>" (BOB), "Dr. from <UPI>" or general "to/from <UPI>"
    final crToPattern = RegExp(r'cr\.\s*to\s+([^\s]+)', caseSensitive: false);
    final crToMatch = crToPattern.firstMatch(body);

    final drFromUpiPattern = RegExp(
      r'dr\.?\s+from\s+(\w+(?:\.\w+)*@\w+)',
      caseSensitive: false,
    );
    final drFromUpiMatch = drFromUpiPattern.firstMatch(body);

    final toUpiPattern = RegExp(
      r'(?:to|towards)\s+(\w+(?:\.\w+)*@\w+)',
      caseSensitive: false,
    );
    final toUpiMatch = toUpiPattern.firstMatch(body);

    debugPrint('Cr. to pattern match: ${crToMatch?.group(1)}');

    // For credit transactions, prefer a credit source UPI ID
    if (transactionType == 'credit' && creditSource != null) {
      if (creditSource.contains('@')) {
        merchant = _upiIdToMerchant(creditSource);
      } else {
        merchant = creditSource;
      }
      debugPrint('Using credit source as merchant: $merchant');
    } else if (crToMatch != null) {
      // BOB-style "Cr. to zepto.payu@axisbank" or "Cr. to XXXXXXXX0051"
      String rawMerchant = crToMatch.group(1) ?? '';
      if (rawMerchant.endsWith('.')) {
        rawMerchant = rawMerchant.substring(0, rawMerchant.length - 1);
      }
      if (rawMerchant.contains('@')) {
        merchant = _upiIdToMerchant(rawMerchant);
      } else if (RegExp(r'^[Xx*]+\d').hasMatch(rawMerchant)) {
        // Looks like a masked account number
        merchant = _shortAccountLabel(rawMerchant);
      } else if (rawMerchant.isNotEmpty) {
        merchant = rawMerchant;
      }
      debugPrint('Processed Cr. to merchant: $merchant');
    } else if (transactionType == 'credit' && drFromUpiMatch != null) {
      // Credit SMS with "Dr. from <upi_id>" in the counterparty clause
      merchant = _upiIdToMerchant(drFromUpiMatch.group(1)!);
      debugPrint('Credit source from Dr. from UPI: $merchant');
    } else if (toUpiMatch != null) {
      // General "to <UPI>" pattern
      merchant = _upiIdToMerchant(toUpiMatch.group(1)!);
      debugPrint('Found UPI merchant: $merchant');
    } else {
      // ② Counterparty account from "and" clause
      //    CUB debits:  "...and credited to a/c no. XXXXXXXX0051"
      //    CUB credits: "...and debited from a/c no. XXXXXXXX9695"
      debugPrint('Trying fallback merchant patterns...');

      final counterpartyAcctPattern = RegExp(
        r'(?:credited\s+to|debited\s+from|transferred\s+to)\s+(?:a/?c|acct?|account)\s*(?:no\.?\s*)?([Xx*]*\d{3,}[A-Za-z]*)',
        caseSensitive: false,
      );
      final counterpartyMatch = counterpartyAcctPattern.firstMatch(body);

      if (counterpartyMatch != null) {
        final acctId = counterpartyMatch.group(1) ?? '';
        merchant = _shortAccountLabel(acctId);
        debugPrint('Found counterparty account: $acctId → $merchant');
      } else {
        // ③ Common merchant keywords in body
        final merchantKeywords = [
          'amazon',
          'flipkart',
          'zomato',
          'swiggy',
          'uber',
          'ola',
          'rapido',
          'paytm',
          'phonepe',
          'gpay',
          'zepto',
          'blinkit',
          'bigbasket',
          'myntra',
          'nykaa',
          'meesho',
          'ajio',
        ];
        bool foundKeyword = false;
        for (var keyword in merchantKeywords) {
          if (body.contains(keyword)) {
            merchant =
                keyword.substring(0, 1).toUpperCase() + keyword.substring(1);
            debugPrint('Found merchant keyword: $keyword');
            foundKeyword = true;
            break;
          }
        }

        // ④ Cleaned-up bank name from sender
        if (!foundKeyword) {
          final bankName = _senderToBankName(sender);
          if (bankName != null) {
            merchant = transactionType == 'credit'
                ? '$bankName Transfer'
                : '$bankName Payment';
            debugPrint('Using bank name from sender: $merchant');
          }
          // ⑤ Type-appropriate default is already set above
        }
      }
    }

    // Capitalize first letter
    if (merchant.isNotEmpty) {
      merchant = merchant[0].toUpperCase() + merchant.substring(1);
    }

    // Guard against low-quality merchant names for credits
    if (transactionType == 'credit') {
      final lower = merchant.trim().toLowerCase();
      if (lower == 'expense' ||
          lower.length <= 1 ||
          lower == 'a' ||
          lower == 'ac' ||
          lower == 'a/c' ||
          lower.startsWith('a/c ') ||
          lower == 'unknown') {
        merchant = 'Bank Transfer';
      }
    }
    // Guard against raw sender IDs for debits (e.g. "JM-CUBLTD-S")
    if (transactionType == 'expense') {
      final lower = merchant.trim().toLowerCase();
      if (lower == 'expense' || lower == 'unknown') {
        merchant = 'UPI Transfer';
      }
      // If merchant still looks like a raw SMS sender ID (has dashes + suffix)
      if (RegExp(r'^[A-Z]{2}-\w+-[A-Z]$').hasMatch(merchant.trim())) {
        final bankName = _senderToBankName(merchant);
        merchant = bankName != null ? '$bankName Payment' : 'UPI Transfer';
      }
    }

    // 9. Extract reference information
    String? referenceNumber;
    // Handle patterns like: "Ref no 118709300587", "Ref: ABC123", "Txn 12345678"
    final refPattern = RegExp(
      r'(?:\bref\b|\breference\b|\btxn\b|\btransaction\b|\btxnid\b|\brrn\b|\butr\b|\bupi\s*ref\b|\bupi\s*rrn\b|\bimps\b|\bneft\b)(?:\s*(?:no\.?|num|id|number|ref))?[:\s#\-]+([A-Z0-9]{6,})',
      caseSensitive: false,
    );
    final refMatch = refPattern.firstMatch(body);
    if (refMatch != null) {
      referenceNumber = refMatch.group(1);
      debugPrint('Found reference number: $referenceNumber');
    }

    // 10. Extract Date from SMS content if available
    DateTime transactionDate = DateTime.now();

    // Pattern 1: (2026:01:29 08:17:19)
    final datePattern = RegExp(r'\((\d{4}:\d{2}:\d{2}\s+\d{2}:\d{2}:\d{2})\)');
    final dateMatch =
        datePattern.firstMatch(smsBody); // Use original body for case/format
    if (dateMatch != null) {
      try {
        final dateStr =
            dateMatch.group(1)?.replaceAll(':', '-'); // 2026-01-29 08-17-19
        // Fix time part back to colons: 2026-01-29 08:17:19
        if (dateStr != null) {
          final parts = dateStr.split(' ');
          if (parts.length == 2) {
            final timePart = parts[1].replaceAll('-', ':');
            transactionDate = DateTime.parse('${parts[0]} $timePart');
            debugPrint('Parsed transaction date: $transactionDate');
          }
        }
      } catch (e) {
        debugPrint('Error parsing date from SMS: $e');
      }
    } else {
      // Pattern 2: "on 15-02-2026" or "on 15/02/2026" (dd-mm-yyyy)
      final ddmmyyyyPattern = RegExp(
        r'on\s+(\d{1,2})[\-/](\d{1,2})[\-/](\d{4})',
        caseSensitive: false,
      );
      final ddmmyyyyMatch = ddmmyyyyPattern.firstMatch(smsBody);
      if (ddmmyyyyMatch != null) {
        try {
          final day = int.parse(ddmmyyyyMatch.group(1)!);
          final month = int.parse(ddmmyyyyMatch.group(2)!);
          final year = int.parse(ddmmyyyyMatch.group(3)!);
          transactionDate = DateTime(year, month, day);
          debugPrint('Parsed transaction date (dd-mm-yyyy): $transactionDate');
        } catch (e) {
          debugPrint('Error parsing dd-mm-yyyy date: $e');
        }
      }
    }

    String paymentMethod = 'UPI'; // Default for these bank alerts
    if (body.contains('card') || body.contains('debit card'))
      paymentMethod = 'Card';
    if (body.contains('neft')) paymentMethod = 'NEFT';
    if (body.contains('imps')) paymentMethod = 'IMPS';
    if (body.contains('rtgs')) paymentMethod = 'RTGS';

    final result = {
      'amount': amount,
      'merchant': merchant,
      'date': transactionDate,
      'type': transactionType,
      'reference': referenceNumber,
      'paymentMethod': paymentMethod,
    };

    debugPrint('✓ Final parsed result: $result');
    return result;
  }

  /// AI-style expense categorization using rule-based + heuristic logic
  /// Returns category and confidence score (0-1)
  /// When [transactionType] is 'credit', applies credit-specific categories
  static Map<String, dynamic> categorizeExpense(String merchant, double amount,
      {String transactionType = 'expense'}) {
    final merchantLower = merchant.toLowerCase();
    double confidence = 0.0;
    String category = 'Others';

    // Credit-specific categorization
    if (transactionType == 'credit') {
      final refundKeywords = [
        'refund',
        'cashback',
        'reversal',
        'reversed',
        'chargeback'
      ];
      if (refundKeywords.any((k) => merchantLower.contains(k))) {
        return {'category': 'Refund', 'confidence': 0.9};
      }
      final salaryKeywords = ['salary', 'payroll', 'stipend', 'wages'];
      if (salaryKeywords.any((k) => merchantLower.contains(k))) {
        return {'category': 'Salary', 'confidence': 0.9};
      }
      // Default credit category
      return {'category': 'Income', 'confidence': 0.6};
    }

    // Food & Drink category
    final foodKeywords = [
      'zomato',
      'swiggy',
      'uber eats',
      'food',
      'restaurant',
      'cafe',
      'starbucks',
      'mcdonald',
      'kfc',
      'pizza',
      'burger',
      'hotel'
    ];
    if (foodKeywords.any((keyword) => merchantLower.contains(keyword))) {
      category = 'Food & Drink';
      confidence = 0.9;
      return {'category': category, 'confidence': confidence};
    }

    // Transport category
    final transportKeywords = [
      'uber',
      'ola',
      'rapido',
      'taxi',
      'cab',
      'metro',
      'bus',
      'train',
      'railway',
      'flight',
      'airline'
    ];
    if (transportKeywords.any((keyword) => merchantLower.contains(keyword))) {
      category = 'Transport';
      confidence = 0.9;
      return {'category': category, 'confidence': confidence};
    }
    // Shopping category
    final shoppingKeywords = [
      'amazon',
      'flipkart',
      'myntra',
      'nykaa',
      'shop',
      'store',
      'mall',
      'market'
    ];
    if (shoppingKeywords.any((keyword) => merchantLower.contains(keyword))) {
      category = 'Shopping';
      confidence = 0.85;
      return {'category': category, 'confidence': confidence};
    }

    // Bills category
    final billsKeywords = [
      'airtel',
      'jio',
      'vi',
      'vodafone',
      'bsnl',
      'electricity',
      'water',
      'gas',
      'internet',
      'broadband',
      'dth',
      'cable'
    ];
    if (billsKeywords.any((keyword) => merchantLower.contains(keyword))) {
      category = 'Bills';
      confidence = 0.9;
      return {'category': category, 'confidence': confidence};
    }

    // Entertainment category
    final entertainmentKeywords = [
      'netflix',
      'spotify',
      'prime',
      'hotstar',
      'youtube',
      'movie',
      'cinema',
      'theater',
      'game'
    ];
    if (entertainmentKeywords
        .any((keyword) => merchantLower.contains(keyword))) {
      category = 'Entertainment';
      confidence = 0.85;
      return {'category': category, 'confidence': confidence};
    }

    // Education category
    final educationKeywords = [
      'university',
      'college',
      'school',
      'tuition',
      'course',
      'book',
      'stationery'
    ];
    if (educationKeywords.any((keyword) => merchantLower.contains(keyword))) {
      category = 'Education';
      confidence = 0.8;
      return {'category': category, 'confidence': confidence};
    }

    // Health category
    final healthKeywords = [
      'pharmacy',
      'medical',
      'hospital',
      'clinic',
      'doctor',
      'medicine',
      'apollo',
      'fortis'
    ];
    if (healthKeywords.any((keyword) => merchantLower.contains(keyword))) {
      category = 'Health';
      confidence = 0.85;
      return {'category': category, 'confidence': confidence};
    }

    // Groceries (heuristic: medium amounts, common grocery keywords)
    final groceryKeywords = [
      'grocery',
      'supermarket',
      'dmart',
      'big bazaar',
      'reliance'
    ];
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

  static String _dayKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _normalizeMerchantForDedupe(String merchant) {
    return merchant.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  static bool _isGenericMerchant(String merchant) {
    final m = merchant.trim().toLowerCase();
    return m.isEmpty ||
        m == 'expense' ||
        m == 'unknown' ||
        m == 'bank transfer' ||
        m == 'upi transfer' ||
        m == 'upi payment';
  }

  static bool _isDuplicateTransaction(Transaction a, Transaction b) {
    final aRef = a.referenceNumber?.trim();
    final bRef = b.referenceNumber?.trim();
    if (aRef != null && bRef != null && aRef.isNotEmpty && bRef.isNotEmpty) {
      if (aRef.toLowerCase() == bRef.toLowerCase()) return true;
    }

    // Fuzzy match for auto-detected transactions (both or either).
    // This also catches duplicates created when a local SMS transaction is
    // synced to the backend and then fetched back with isAutoDetected
    // potentially differing (cross-origin duplicates).
    if (a.isAutoDetected || b.isAutoDetected) {
      if ((a.amount - b.amount).abs() > 0.009) return false;
      if (_dayKey(a.date) != _dayKey(b.date)) return false;

      // Merchant can vary between ingestion paths (title vs body parsing).
      if (_isGenericMerchant(a.merchant) || _isGenericMerchant(b.merchant)) {
        return true;
      }

      final aM = _normalizeMerchantForDedupe(a.merchant);
      final bM = _normalizeMerchantForDedupe(b.merchant);
      if (aM.isEmpty || bM.isEmpty) return true;
      return aM == bM;
    }

    return false;
  }

  /// Save detected transactions to local storage
  static Future<void> saveTransactions(
    List<Transaction> transactions, {
    bool emitEvents = true,
    bool updateWidget = true,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingTransactions = await getStoredTransactions();

      // Merge with existing transactions, avoiding duplicates
      final Map<String, Transaction> transactionMap = {};

      // Add existing transactions, but also clean up any past duplicates that
      // may have been created by concurrent ingestion paths.
      for (final tx in existingTransactions) {
        if (transactionMap.containsKey(tx.id)) {
          transactionMap[tx.id] = tx;
          continue;
        }

        final isDup = transactionMap.values.any((existing) {
          return _isDuplicateTransaction(existing, tx);
        });

        if (!isDup) {
          transactionMap[tx.id] = tx;
        }
      }

      // Add new transactions (overwrite if same ID). If a different ID but the
      // same underlying transaction arrives (race between listeners), skip it.
      for (final tx in transactions) {
        if (transactionMap.containsKey(tx.id)) {
          transactionMap[tx.id] = tx;
          continue;
        }

        final isDup = transactionMap.values.any((existing) {
          return _isDuplicateTransaction(existing, tx);
        });

        if (!isDup) {
          transactionMap[tx.id] = tx;
        }
      }

      // Convert to JSON and save
      final transactionsJson =
          transactionMap.values.map((tx) => _transactionToJson(tx)).toList();
      final key = await _transactionsKeyForCurrentUser(prefs);
      await prefs.setString(key, jsonEncode(transactionsJson));

      // UPDATE HOME WIDGET
      if (updateWidget) {
        await HomeWidgetService.updateWidgetData();
      }

      // Emit events for UI live-updates
      if (emitEvents) {
        for (var tx in transactions) {
          try {
            TransactionStorageService.notifyTransactionAdded(tx);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Error saving transactions: $e');
    }
  }

  /// Save transactions locally and best-effort sync them to backend.
  ///
  /// Use this for newly detected SMS transactions (e.g., notification listener)
  /// so they don't remain local-only.
  static Future<void> saveTransactionsAndSyncBackend(
      List<Transaction> transactions) async {
    await saveTransactions(transactions);

    for (final tx in transactions) {
      // Backend only supports expenses right now.
      if (tx.type.toLowerCase() != 'expense') continue;

      try {
        final ok = await ExpenseService.addExpense(tx);
        if (!ok) {
          debugPrint(
              '✗ Backend sync failed for: ${tx.merchant} - ₹${tx.amount}');
        }
      } catch (e) {
        debugPrint('✗ Backend sync error for ${tx.merchant}: $e');
      }
    }
  }

  /// Attempt to sync locally stored SMS-detected transactions to backend.
  ///
  /// This is safe to call multiple times because `ExpenseService` dedupes using
  /// an on-device posted fingerprint list (also seeded from remote fetches).
  static Future<void> syncStoredSmsTransactionsToBackend(
      {int maxTransactions = 50}) async {
    try {
      final all = await getStoredTransactions();
      final smsExpenses = all
          .where(
              (tx) => tx.isAutoDetected && tx.type.toLowerCase() == 'expense')
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      int attempted = 0;
      int synced = 0;

      for (final tx in smsExpenses) {
        if (attempted >= maxTransactions) break;
        attempted++;

        final ok = await ExpenseService.addExpense(tx);
        if (ok) synced++;
      }

      debugPrint(
          '✅ SMS backend sync complete: attempted=$attempted synced=$synced');
    } catch (e) {
      debugPrint('❌ Error syncing stored SMS transactions to backend: $e');
    }
  }

  /// Get stored transactions from local storage
  static Future<List<Transaction>> getStoredTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _transactionsKeyForCurrentUser(prefs);
      final transactionsJson = prefs.getString(key);

      if (transactionsJson != null) {
        final List<dynamic> transactionsList = jsonDecode(transactionsJson);
        return transactionsList
            .map((json) => _transactionFromJson(json))
            .toList();
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
      'type': tx.type,
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
      confidenceScore: json['confidenceScore'] != null
          ? (json['confidenceScore'] as num).toDouble()
          : null,
      type: (json['type'] ??
              json['transaction_type'] ??
              json['transactionType']) as String? ??
          'expense',
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
      await prefs.remove(_legacyTransactionsKey);
      final keys = prefs.getKeys();
      for (final k in keys) {
        if (k.startsWith(_transactionsKeyPrefix)) {
          await prefs.remove(k);
        }
      }
      await prefs.remove(_processedSmsKey);
      debugPrint('All transaction data cleared.');
    } catch (e) {
      debugPrint('Error clearing data: $e');
    }
  }
}

/// Helper to take first N chars safely
extension StringExtension on String {
  String take(int n) => length > n ? substring(0, n) : this;
}
