import 'dart:async';
import 'package:flutter/services.dart';
import 'sms_expense_service.dart';
import '../models/transaction_model.dart';

class NotificationEventService {
  static const EventChannel _channel = EventChannel('undiyal/notification_events');
  static StreamSubscription? _sub;

  static void start() {
    _sub ??= _channel.receiveBroadcastStream().listen((event) async {
      try {
        if (event is Map) {
          final text = event['text']?.toString() ?? '';
          final sender = event['package']?.toString() ?? '';
          final postedTime = event['postedTime'];

          final isLikelySmsNotification = sender.contains('messaging') ||
              sender.contains('sms') ||
              sender == 'com.android.mms' ||
              sender == 'com.google.android.apps.messaging';

          if (!isLikelySmsNotification || text.trim().isEmpty) {
            return;
          }

          // Try to parse SMS/notification text for transaction
          final parsed = SmsExpenseService.parseSmsForExpense(text, sender: sender);
          if (parsed != null) {
            final amount = parsed['amount'] as double;
            final merchant = parsed['merchant'] as String? ?? 'Expense';
            final ref = parsed['reference'] as String?;
            final paymentMethod = parsed['paymentMethod'] as String? ?? 'Other';
            final type = parsed['type'] as String? ?? 'expense';
            final date = postedTime is int
                ? DateTime.fromMillisecondsSinceEpoch(postedTime)
                : (parsed['date'] as DateTime? ?? DateTime.now());

            final existingTransactions =
                await SmsExpenseService.getStoredTransactions();
            final isDuplicate = existingTransactions.any((tx) {
              if (ref != null && tx.referenceNumber == ref) return true;
              return tx.amount == amount &&
                  tx.merchant == merchant &&
                  tx.date.year == date.year &&
                  tx.date.month == date.month &&
                  tx.date.day == date.day;
            });

            if (isDuplicate) {
              return;
            }

            final tx = Transaction(
              id: 'evt_${DateTime.now().millisecondsSinceEpoch}',
              amount: amount,
              merchant: merchant,
              category: SmsExpenseService.categorizeExpense(merchant, amount, transactionType: type)['category'],
              date: date,
              paymentMethod: paymentMethod,
              isAutoDetected: true,
              referenceNumber: ref,
              confidenceScore: 1.0,
              type: type,
            );

            // Save locally (this also emits UI update via TransactionStorageService)
            await SmsExpenseService.saveTransactions([tx]);
          }
        }
      } catch (e) {
        // ignore parse errors
      }
    });
  }

  static void stop() {
    _sub?.cancel();
    _sub = null;
  }
}
