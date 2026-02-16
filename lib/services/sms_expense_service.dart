import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import 'home_widget_service.dart';
import 'expense_service.dart';
import 'balance_sms_parser.dart';

/// Service for automatically detecting expenses from SMS messages
/// Works fully offline, no backend connection required
class SmsExpenseService {
  static const String _processedSmsKey = 'processed_sms_references';
  static const String _transactionsKey = 'stored_transactions';
  
  // ===== SENDER-BASED FILTERING =====
  
  // Known bank SMS sender patterns (case-insensitive partial match)
  // Indian banks send from senders like VM-BOBROI, AD-HDFCBK, BZ-SBIINB, etc.
  static const List<String> _bankSenderPatterns = [
    'bob', 'hdfc', 'sbi', 'icici', 'axis', 'kotak', 'idbi', 'pnb',
    'cub', 'iob', 'canara', 'union', 'boi', 'baroda', 'indian',
    'yesbank', 'indus', 'rbl', 'federal', 'idfc', 'bandhan',
    'dbs', 'citi', 'sc bank', 
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
    r'\b(?:dr\.?\s+from|debit(?:ed)?|paid|spent|withdrawn|deducted|charged|billed|purchase|payment\s+of|auto[- ]debit)\b',
    caseSensitive: false,
  );
  
  // STRICT keywords that indicate CREDIT transactions only - using word boundaries
  static final RegExp _creditRegex = RegExp(
    r'\b(?:cr\.?\s+to|credit(?:ed)?|received|refund(?:ed)?|cashback)\b',
    caseSensitive: false,
  );
  
  // ===== STRUCTURAL VALIDATION PATTERNS =====
  
  // Patterns that indicate a REAL transactional SMS (not promotional)
  static final RegExp _accountPattern = RegExp(
    r'(?:a/?c|acct?|account)\s*(?:no\.?\s*)?(?:xx|x{2,}|\*{2,})?\d{2,}',
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
    bool hasBalanceMention = RegExp(r'(?:avail|avl|available|clear|closing)\s*(?:bal|balance)', caseSensitive: false).hasMatch(bodyLower);
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
          : DateTime.now().subtract(const Duration(days: 30)); // Default: past 30 days

      debugPrint('Reading SMS messages from ${startDate.toString()} (limit: ${limit ?? 500})...');

      List<SmsMessage> messages = await query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: limit ?? 500,
      );

      // Filter messages to only include those from the past month
      final filteredMessages = messages.where((message) {
        final messageDate = message.date;
        return messageDate != null && messageDate.isAfter(startDate);
      }).toList();

      debugPrint('Found ${filteredMessages.length} SMS messages from past month to process (filtered from ${messages.length} total)');

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
        
        debugPrint('--- Processing SMS ${processedCount}/${filteredMessages.length} ---');
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
        
        // 4a. SKIP BALANCE SMS - ONLY notification listener should handle this
        final balanceData = BalanceSmsParser.parseBalanceSms(body, sender);
        if (balanceData != null) {
          debugPrint('⚠ Balance SMS detected but SKIPPING - only notification listener should handle balance');
          await _markSmsAsProcessed(message.id.toString());
          skippedCount++;
          continue;
        }
        
        // 4b. Parse the SMS for EXPENSE using robust logic (includes sender info)
        final parsedData = parseSmsForExpense(body, sender: sender);
        
        if (parsedData == null) {
           debugPrint('✗ Not a transaction SMS or ignored');
           await _markSmsAsProcessed(message.id.toString()); // Mark to avoid reprocessing
           skippedCount++;
           continue;
        }

        debugPrint('✓ Parsed transaction data: $parsedData');
        
        double amount = parsedData['amount'];
        String merchantName = parsedData['merchant'];
        String? refNumber = parsedData['reference'];
        String paymentMethod = parsedData['paymentMethod'];

        // LOW CONFIDENCE CHECK - only skip if truly unknown
        if (merchantName == 'Expense' && merchantName.isEmpty) {
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
        final transaction = Transaction(
          id: _generateTransactionId(),
          amount: amount,
          merchant: merchantName,
          category: categorizeExpense(merchantName, amount)['category'],
          paymentMethod: paymentMethod,
          isAutoDetected: true,
          date: message.date ?? DateTime.now(),
          referenceNumber: refNumber,
          confidenceScore: 1.0,
          type: parsedData['type'] ?? 'expense',
        );

        debugPrint('✓ Auto-detected transaction: ${transaction.merchant} - ₹${transaction.amount} (${transaction.type})');

        // Add to collection instead of returning immediately
        detectedTransactions.add(transaction);
        expenseCount++;
        await _markSmsAsProcessed(message.id.toString());
      }
      
      // 6. Save ALL detected transactions at once
      if (detectedTransactions.isNotEmpty) {
        await saveTransactions(detectedTransactions);
        debugPrint('✓ Saved ${detectedTransactions.length} transactions from SMS');
        
        // Sync to backend
        for (var transaction in detectedTransactions) {
          try {
            await ExpenseService.addExpense(transaction);
            debugPrint('✓ Synced transaction to backend: ${transaction.merchant}');
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
  static Map<String, dynamic>? parseSmsForExpense(String smsBody, {String? sender}) {
    debugPrint('Parsing SMS: ${smsBody.take(150)}...');
    
    // 1. NORMALIZE UNICODE CHARACTERS TO ASCII
    // Bank of Baroda and others sometimes use specialized fonts
    String body = smsBody.toLowerCase().trim();
    body = body.replaceAll('𝖣𝗋', 'dr')
               .replaceAll('𝖿𝗋𝗈𝗆', 'from')
               .replaceAll('𝖺𝗇𝖽', 'and')
               .replaceAll('𝖢𝗋', 'cr')
               .replaceAll('𝗍𝗈', 'to');

    debugPrint('Normalized body: ${body.take(150)}...');

    // 2. CHECK IGNORE KEYWORDS FIRST (most important filter)
    final shouldIgnore = _ignoreKeywords.any((keyword) => body.contains(keyword));
    debugPrint('Should ignore based on keywords: $shouldIgnore');
    if (shouldIgnore) {
      debugPrint('✗ Ignoring promotional/OTP/marketing message');
      return null;
    }

    // 3. CHECK for transaction keywords using WORD BOUNDARY regex
    final hasExpenseKeyword = _debitRegex.hasMatch(body);
    final hasCreditKeyword = _creditRegex.hasMatch(body);
    debugPrint('Has expense keyword (regex): $hasExpenseKeyword');
    debugPrint('Has credit keyword (regex): $hasCreditKeyword');
    
    // Must have either expense or credit keyword
    if (!hasExpenseKeyword && !hasCreditKeyword) {
      debugPrint('✗ No transaction keywords found - not a transaction SMS');
      return null;
    }

    // 4. STRUCTURAL VALIDATION - must look like a real bank SMS
    if (!_hasTransactionStructure(body)) {
      debugPrint('✗ No structural markers of bank transaction (no account/ref/balance)');
      return null;
    }

    // 5. Extract amount using regex patterns
    double? amount;
    String? amountStr;
    
    // Pattern: "Rs.300.00" or "Rs 105.00" or "₹105.00" or "INR 500.00"
    // Also handle comma-separated amounts: "Rs.8,500.00"
    final amountPattern = RegExp(r'(?:rs\.?|inr|₹)\s*([0-9,]+(?:\.\d{1,2})?)', caseSensitive: false);
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
      debugPrint('✗ Amount too small (₹$amount), likely not a real transaction');
      return null;
    }

    // 7. STRICT transaction type determination using regex
    String transactionType = 'expense';
    String? creditSource;
    
    // EXPLICIT DEBIT PATTERNS - check first since they're more specific
    if (_debitRegex.hasMatch(body)) {
      transactionType = 'expense';
      debugPrint('STRICT: Identified as EXPENSE/DEBIT transaction');
    }
    
    // Check for credit - but "cr. to" is actually a debit destination
    if (hasCreditKeyword && !body.contains('cr. to') && !body.contains('cr to')) {
      // Verify it's a genuine credit and not part of a debit message
      if (!hasExpenseKeyword) {
        transactionType = 'credit';
        debugPrint('STRICT: Identified as CREDIT transaction');
        
        // Try to extract source for credits
        final creditFromPattern = RegExp(r'(?:from|credited by|received from)\s+([a-zA-Z0-9\.@]+)', caseSensitive: false);
        final creditMatch = creditFromPattern.firstMatch(body);
        if (creditMatch != null) {
          creditSource = creditMatch.group(1);
          debugPrint('Credit source: $creditSource');
        }
      }
    }

    // 8. Extract merchant/UPI ID with DEFAULT fallback
    String merchant = 'Expense'; // DEFAULT merchant name
    
    // Pattern for user's SMS: "and Cr. to <merchant>."
    // e.g. "and Cr. to dharini1463@okicici." or "and Cr. to zepto.payu@axisbank."
    final crToPattern = RegExp(r'cr\.\s*to\s+([^\s]+)', caseSensitive: false);
    final crToMatch = crToPattern.firstMatch(body);
    
    debugPrint('Cr. to pattern match: ${crToMatch?.group(1)}');
    
    // For credit transactions, use the source as merchant
    if (transactionType == 'credit' && creditSource != null) {
      merchant = creditSource;
      debugPrint('Using credit source as merchant: $merchant');
    } else if (crToMatch != null) {
      String rawMerchant = crToMatch.group(1) ?? '';
      debugPrint('Raw merchant from Cr. to pattern: $rawMerchant');
      // Clean up trailing dots or generic text
      if (rawMerchant.endsWith('.')) rawMerchant = rawMerchant.substring(0, rawMerchant.length - 1);
      
      // If it looks like a UPI ID (contains @), try to make it readable
      if (rawMerchant.contains('@')) {
         final parts = rawMerchant.split('@');
         if (parts.isNotEmpty) {
           String namePart = parts[0];
           // Heuristic: If it has dots like "zepto.payu", take the first part
           if (namePart.contains('.')) {
              namePart = namePart.split('.')[0];
           }
           // Remove numbers if it looks like a phone number UPI (9361...)
           if (RegExp(r'^\d+$').hasMatch(namePart)) {
             merchant = 'UPI Transfer'; // fallback for raw phone numbers
           } else {
             merchant = namePart; // Use the name part (e.g., "zepto", "dharini")
           }
         }
      } else {
        merchant = rawMerchant;
      }
      debugPrint('Processed merchant name: $merchant');
    } else {
        // Fallback patterns
        debugPrint('Trying fallback merchant patterns...');
        
        // Pattern: "to <UPI_ID>" in body
        final toUpiPattern = RegExp(r'(?:to|towards)\s+(\w+(?:\.\w+)*@\w+)', caseSensitive: false);
        final toUpiMatch = toUpiPattern.firstMatch(body);
        if (toUpiMatch != null) {
           final upiId = toUpiMatch.group(1) ?? '';
           final parts = upiId.split('@');
           if (parts.isNotEmpty) {
             String namePart = parts[0];
             if (namePart.contains('.')) namePart = namePart.split('.')[0];
             if (RegExp(r'^\d+$').hasMatch(namePart)) {
               merchant = 'UPI Transfer';
             } else {
               merchant = namePart;
             }
           } else {
             merchant = 'UPI Payment';
           }
           debugPrint('Found UPI merchant: $merchant');
        } else {
          // Pattern: "credited to a/c no. XXXXXXXX9695" (account-to-account transfer)
          final acctTransferPattern = RegExp(
            r'(?:credited\s+to|transferred\s+to)\s+(?:a/?c|acct?|account)\s*(?:no\.?\s*)?([Xx*]+\d{3,})',
            caseSensitive: false,
          );
          final acctMatch = acctTransferPattern.firstMatch(body);
          if (acctMatch != null) {
            // Instead of 'A/c XXXX', use sender name from notification header
            merchant = sender ?? 'Unknown';
            debugPrint('Found account transfer merchant, using sender: $merchant');
          } else {
            // Pattern: Common merchant names in body
            final merchantKeywords = [
              'amazon', 'flipkart', 'zomato', 'swiggy', 'uber', 'ola', 'rapido',
              'paytm', 'phonepe', 'gpay', 'zepto', 'blinkit', 'bigbasket',
              'myntra', 'nykaa', 'meesho', 'ajio',
            ];
            for (var keyword in merchantKeywords) {
              if (body.contains(keyword)) {
                merchant = keyword.substring(0, 1).toUpperCase() + keyword.substring(1);
              debugPrint('Found merchant keyword: $keyword');
              break;
              }
            }
          }
        }
    }

    // Capitalize first letter
    if (merchant.isNotEmpty) {
       merchant = merchant[0].toUpperCase() + merchant.substring(1);
    }

    // 9. Extract reference information
    String? referenceNumber;
    // Handle patterns like: "Ref no 118709300587", "Ref: ABC123", "Txn 12345678"
    final refPattern = RegExp(
      r'(?:ref|reference|txn|transaction)(?:\s*(?:no\.?|num|id|number))?[:\s]+([A-Z0-9]{6,})',
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
    final dateMatch = datePattern.firstMatch(smsBody); // Use original body for case/format
    if (dateMatch != null) {
      try {
        final dateStr = dateMatch.group(1)?.replaceAll(':', '-'); // 2026-01-29 08-17-19
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
    if (body.contains('card') || body.contains('debit card')) paymentMethod = 'Card';
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
  static Map<String, dynamic> categorizeExpense(String merchant, double amount) {
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

      // UPDATE HOME WIDGET
      await HomeWidgetService.updateWidgetData();
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
      confidenceScore: json['confidenceScore'] != null ? (json['confidenceScore'] as num).toDouble() : null,
      type: json['type'] as String? ?? 'expense',
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


/// Helper to take first N chars safely
extension StringExtension on String {
  String take(int n) => length > n ? substring(0, n) : this;
}