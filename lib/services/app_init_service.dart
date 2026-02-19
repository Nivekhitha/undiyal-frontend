import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import 'notification_service.dart';
import 'sms_expense_service.dart';
import 'transaction_storage_service.dart';
import '../services/sms_notification_listener.dart';
import 'notification_event_service.dart';

/// Service to initialize app and read SMS on launch
class AppInitService {
  /// Initialize app: Setup services without requesting permissions
  static Future<void> initialize() async {
    try {
      // PERFORM ONE-TIME CLEANUP (Migration to real data only)
      final prefs = await SharedPreferences.getInstance();
      final hasCleaned = prefs.getBool('has_cleaned_v2_data') ?? false;

      debugPrint('Checking cleanup status: has_cleaned_v2_data = $hasCleaned');
      
      if (!hasCleaned) {
        debugPrint('Performing one-time data cleanup...');
        await TransactionStorageService.clearAllData();
        await prefs.setBool('has_cleaned_v2_data', true);
        debugPrint('One-time cleanup complete.');
        
        // Verify the flag was set
        final verifyCleaned = prefs.getBool('has_cleaned_v2_data');
        debugPrint('Verification: has_cleaned_v2_data = $verifyCleaned');
      } else {
        debugPrint('One-time cleanup already completed, skipping...');
      }

      // Initialize Notifications (without requesting permission)
      await NotificationService.initialize();
      debugPrint('Notification service initialized');

      // Initialize SMS notification listener (don't force-enable or request permissions here)
      final smsListener = SmsNotificationListener();
      await smsListener.initialize();
      debugPrint('SMS notification listener initialized');

      // Start native EventChannel stream for in-app real-time notification events
      NotificationEventService.start();
      debugPrint('Notification EventChannel listener started');

      // Only run SMS detection if permission was already granted previously
      final smsPermissionGranted = await SmsExpenseService.hasSmsPermission();
      if (smsPermissionGranted) {
        debugPrint('SMS permission already granted, running inbox scan...');
        await AppInitService.initializeSmsDetection();
      } else {
        debugPrint('SMS permission not yet granted - will be requested via permission screen');
      }
    } catch (e) {
      debugPrint('Error initializing app services: $e');
    }
  }

  /// Initialize SMS detection after permissions are granted
  static Future<void> initializeSmsDetection() async {
    try {
      // Check if SMS permission is granted
      final hasPermission = await SmsExpenseService.hasSmsPermission();

      if (hasPermission) {
        debugPrint('SMS permission granted, detecting expenses...');

        // Calculate messages from current month for comprehensive analysis
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        final daysSinceStartOfMonth = now.difference(startOfMonth).inDays;

        debugPrint('Analyzing SMS from last $daysSinceStartOfMonth days (current month)');

        // Read SMS from current month
        final detectedTransactions =
            await SmsExpenseService.detectExpensesFromSms(
          since: Duration(days: daysSinceStartOfMonth),
          limit: 500, // Read more messages for comprehensive analysis
        );

        if (detectedTransactions.isNotEmpty) {
          debugPrint('Detected & Saved ${detectedTransactions.length} transactions from SMS');
        } else {
          debugPrint('No new transactions detected from SMS');
        }
      } else {
        debugPrint('SMS permission not granted');
      }
    } catch (e) {
      debugPrint('Error initializing SMS expense detection: $e');
    }
  }

  /// Periodic SMS check (can be called from background or periodically)
  static Future<void> checkForNewExpenses() async {
    try {
      if (await SmsExpenseService.hasSmsPermission()) {
        // Read SMS from last 24 hours
        final detectedTransactions =
            await SmsExpenseService.detectExpensesFromSms(
          since: const Duration(hours: 24),
          limit: 100,
        );

        if (detectedTransactions.isNotEmpty) {
          final List<Transaction> newTransactions = [];
          for (var tx in detectedTransactions) {
            final isDuplicate = await SmsExpenseService.isDuplicate(tx);
            if (!isDuplicate) {
              newTransactions.add(tx);
            }
          }

          if (newTransactions.isNotEmpty) {
            await SmsExpenseService.saveTransactions(newTransactions);
            debugPrint('Detected ${newTransactions.length} new expenses');
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking for new expenses: $e');
    }
  }
}
