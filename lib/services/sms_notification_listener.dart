import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'sms_expense_service.dart';
import 'balance_sms_parser.dart';
import 'balance_detection_mode_service.dart';
import 'notification_service.dart';
import '../models/transaction_model.dart';

/// Service for listening to SMS notifications in real-time
/// More battery efficient than constant SMS scanning
@pragma('vm:entry-point')
class SmsNotificationListener {
  /// Check notification access permission directly
  static Future<bool> hasNotificationPermission() async {
    try {
      return await NotificationsListener.hasPermission ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Stream controller for real-time expense updates
  static final StreamController<Transaction> _expenseUpdateController =
      StreamController<Transaction>.broadcast();

  /// Stream that emits when a new expense is detected
  static Stream<Transaction> get onExpenseUpdate =>
      _expenseUpdateController.stream;
  static const String _listenerEnabledKey = 'sms_listener_enabled';
  static bool _isProcessingBalanceMessage = false;

  @pragma('vm:entry-point')
  static final SmsNotificationListener _instance =
      SmsNotificationListener._internal();

  final _smsController = StreamController<Map<String, dynamic>>.broadcast();
  StreamSubscription<dynamic>? _subscription;
  bool _isListening = false;

  @pragma('vm:entry-point')
  factory SmsNotificationListener() => _instance;

  @pragma('vm:entry-point')
  SmsNotificationListener._internal();

  /// Static callback handler with pragma annotation to prevent tree-shaking
  /// This is REQUIRED for the callback to work in release/profile mode
  @pragma('vm:entry-point')
  static void _callback(NotificationEvent event) {
    debugPrint('=== _callback invoked (entry-point) ===');
    _instance._handleNotificationEvent(event);
  }

  /// Instance method to handle the notification event
  @pragma('vm:entry-point')
  void _handleNotificationEvent(NotificationEvent event) {
    debugPrint('=== _handleNotificationEvent called ===');
    _onNotificationReceived(event);
  }

  /// Stream of SMS notifications
  Stream<Map<String, dynamic>> get smsStream => _smsController.stream;

  /// Check if notification listener is enabled
  Future<bool> isListenerEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_listenerEnabledKey) ?? false;
    } catch (e) {
      debugPrint('Error checking listener status: $e');
      return false;
    }
  }

  /// Enable or disable SMS notification listener
  Future<bool> setListenerEnabled(bool enabled) async {
    try {
      // Save preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_listenerEnabledKey, enabled);

      debugPrint(
          'SMS notification listener ${enabled ? "enabled" : "disabled"}');

      if (enabled) {
        return await startListener();
      } else {
        await stopListener();
        return true;
      }
    } catch (e) {
      debugPrint('Error setting listener: $e');
      return false;
    }
  }

  /// Start listening for SMS notifications
  Future<bool> startListener() async {
    debugPrint('=== startListener() called, _isListening=$_isListening ===');
    if (_isListening) {
      debugPrint('Already listening, returning true');
      return true;
    }

    try {
      debugPrint('=== STARTING NOTIFICATION LISTENER ===');

      // Initialize the notification listener with our static callback.
      // The @pragma('vm:entry-point') annotation ensures this works in release mode.
      NotificationsListener.initialize(callbackHandle: _callback);
      debugPrint('✅ NotificationsListener initialized with _callback');

      // Set up the listener on the plugin's built-in receivePort
      _subscription?.cancel();
      final port = NotificationsListener.receivePort;
      debugPrint('receivePort: $port (null=${port == null})');
      _subscription = port?.listen((event) {
        debugPrint('📩 Event received on receivePort: ${event.runtimeType}');
        if (event is NotificationEvent) {
          _onNotificationReceived(event);
        }
      });
      debugPrint(
          '✅ Listening on NotificationsListener.receivePort, subscription=$_subscription');

      // Check and request permission
      final hasPermission = await NotificationsListener.hasPermission ?? false;
      debugPrint('Notification permission status: $hasPermission');

      if (!hasPermission) {
        debugPrint('❌ Notification access permission NOT granted');
        await NotificationsListener.openPermissionSettings();
        return false;
      }

      // Start service if not already running
      final isRunning = await NotificationsListener.isRunning;
      debugPrint('Notification service running: $isRunning');

      if (!isRunning!) {
        await NotificationsListener.startService();
        debugPrint('✅ Notification service started');
      }

      await _requestNotificationPermission();

      _isListening = true;
      debugPrint('✅ SMS notification listener started successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error starting SMS notification listener: $e');
      return false;
    }
  }

  /// Stop listening for SMS notifications
  Future<void> stopListener() async {
    if (!_isListening) return;

    try {
      await _subscription?.cancel();
      _subscription = null;
      _isListening = false;

      // Note: We don't stop the service here as it might be used by other parts of the app
      debugPrint('SMS notification listener stopped');
    } catch (e) {
      debugPrint('Error stopping SMS notification listener: $e');
    }
  }

  /// Check if notification listener is active and working
  static Future<Map<String, dynamic>> getListenerStatus() async {
    final listener = SmsNotificationListener();
    final isEnabled = await listener.isListenerEnabled();
    final hasPermission = await NotificationsListener.hasPermission ?? false;
    final isRunning = await NotificationsListener.isRunning ?? false;

    return {
      'enabled': isEnabled,
      'hasPermission': hasPermission,
      'isRunning': isRunning,
      'isActive': isEnabled && hasPermission && isRunning,
    };
  }

  /// Open app notification settings for user
  Future<void> openNotificationSettings() async {
    await NotificationsListener.openPermissionSettings();
  }

  /// Initialize: listener service
  /// Auto-starts if notification access permission is granted,
  /// even if the user never toggled the setting manually.
  Future<void> initialize() async {
    debugPrint('=== SmsNotificationListener.initialize() called ===');

    final enabled = await isListenerEnabled();
    debugPrint('Listener preference enabled: $enabled');

    if (enabled) {
      // User explicitly enabled it before — start it
      await startListener();
      return;
    }

    // Even if preference is not set, auto-enable if permission is already granted.
    // This handles the case where the user granted notification access
    // (e.g. during onboarding) but the preference was never saved.
    try {
      final hasPermission = await NotificationsListener.hasPermission ?? false;
      debugPrint('Notification access permission: $hasPermission');
      if (hasPermission) {
        debugPrint(
            'Permission granted but preference not set — auto-enabling listener');
        await setListenerEnabled(true);
      } else {
        debugPrint('No notification access permission — listener not started');
      }
    } catch (e) {
      debugPrint('Error checking permission during initialize: $e');
    }
  }

  /// Handle notification events from the plugin
  void _onNotificationReceived(NotificationEvent event) {
    debugPrint('=== NOTIFICATION EVENT RECEIVED ===');
    debugPrint('Package: ${event.packageName}');
    debugPrint('Title: ${event.title}');
    debugPrint('Text: ${event.text?.take(100)}...');

    if (isSmsNotification(event)) {
      final smsData = extractSmsData(event);
      if (smsData != null) {
        debugPrint('✅ SMS notification detected and extracted');
        _smsController.add(smsData);
        _processSmsNotification(smsData);
      } else {
        debugPrint('❌ Failed to extract SMS data from notification');
      }
    } else {
      debugPrint('❌ Not an SMS notification, ignoring');
    }
  }

  /// Check if the notification is from an SMS app
  bool isSmsNotification(NotificationEvent event) {
    final smsPackages = [
      'com.android.mms',
      'com.google.android.apps.messaging',
      'com.samsung.android.messaging',
      'com.android.messaging',
      'com.motorola.messaging'
    ];
    final packageName = event.packageName ?? '';
    return smsPackages.contains(packageName) ||
        packageName.contains('sms') ||
        packageName.contains('messaging');
  }

  /// Extract SMS data from notification event
  Map<String, dynamic>? extractSmsData(NotificationEvent event) {
    try {
      final title = event.title ?? '';
      final text = event.text ?? '';
      final body = text;

      // Extract both merchant and SMS type from title
      final extracted = _extractMerchantAndTypeFromTitle(title);
      final sender = extracted['merchant'];
      final smsType = extracted['type'];

      return {
        'body': body,
        'sender': sender,
        'smsType': smsType, // Include SMS type for filtering
        'title': title,
        'timestamp': event.timestamp ?? DateTime.now().millisecondsSinceEpoch,
      };
    } catch (e) {
      debugPrint('Error extracting SMS data: $e');
      return null;
    }
  }

  /// Extract merchant name and SMS type from title
  Map<String, String> _extractMerchantAndTypeFromTitle(String title) {
    String merchant = title;
    String smsType = 'Service'; // Default to Service

    // Remove common prefixes
    final prefixes = ['CP-', 'VM-', 'AD-', 'DM-', 'TD-', 'QP-', 'JK-'];
    for (final prefix in prefixes) {
      if (merchant.startsWith(prefix)) {
        merchant = merchant.substring(prefix.length);
        break;
      }
    }

    // Detect SMS type based on suffix
    if (merchant.endsWith('-S')) {
      smsType = 'Service'; // Transactional
      merchant = merchant.substring(0, merchant.length - 2);
    } else if (merchant.endsWith('-P')) {
      smsType = 'Promotional';
      merchant = merchant.substring(0, merchant.length - 2);
    } else if (merchant.endsWith('-G')) {
      smsType = 'Government';
      merchant = merchant.substring(0, merchant.length - 2);
    } else if (merchant.endsWith('-T')) {
      smsType = 'Transactional'; // Older format
      merchant = merchant.substring(0, merchant.length - 2);
    } else if (merchant.endsWith('-D') ||
        merchant.endsWith('-A') ||
        merchant.endsWith('-R')) {
      // These are also transactional but use different suffixes
      smsType = 'Service';
      merchant = merchant.substring(0, merchant.length - 2);
    }

    // Clean up remaining dashes and make readable
    merchant = merchant.replaceAll('-', ' ');

    // Capitalize each word
    final words = merchant.split(' ');
    merchant = words.map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');

    return {
      'merchant': merchant.isNotEmpty ? merchant : 'Bank Transfer',
      'type': smsType,
    };
  }

  /// Process SMS notification data
  Future<void> _processSmsNotification(Map<String, dynamic> smsData) async {
    try {
      final body = smsData['body'] as String? ?? '';
      final sender = smsData['sender'] as String? ?? '';
      final smsType = smsData['smsType'] as String? ?? 'Service';
      final timestamp = smsData['timestamp'] as int?;

      debugPrint('=== PROCESSING NOTIFICATION ===');
      debugPrint('Sender: $sender');
      debugPrint('SMS Type: $smsType');
      debugPrint('Body: ${body.take(100)}...');
      debugPrint('Timestamp: $timestamp');

      // Skip promotional SMS
      if (smsType == 'Promotional') {
        debugPrint('❌ Promotional SMS detected, ignoring');
        return;
      }

      // Balance updates: if it's a balance-only message, store balance and stop.
      // This keeps balance alerts from being misclassified as transactions.
      if (BalanceSmsParser.isBalanceOnlySms(body)) {
        final balanceData = BalanceSmsParser.parseBalanceSms(body, sender);
        if (balanceData != null) {
          final detectedBank = (balanceData['bank'] as String?) ?? 'Unknown';
          final balance = balanceData['balance'] as double;
          await BalanceSmsParser.storeBalance(detectedBank, balance);
          debugPrint(
              '✅ Balance stored from notification: $detectedBank - ₹$balance');
          return;
        }
      }

      // Balance Setup Mode (user-triggered): attempt BALANCE-ONLY parse
      // while still allowing normal transaction parsing to continue.
      final waitingSession =
          await BalanceDetectionModeService.getActiveSession();
      if (waitingSession != null && BalanceSmsParser.isBalanceOnlySms(body)) {
        if (_isProcessingBalanceMessage) {
          debugPrint(
              '⏳ Balance detection already in progress, skipping balance-only event');
          return;
        }

        final balanceData = BalanceSmsParser.parseBalanceSms(body, sender);
        if (balanceData != null) {
          final detectedBank = balanceData['bank'] as String? ?? '';
          if (detectedBank != 'Unknown' &&
              detectedBank != waitingSession.bankCode) {
            debugPrint(
                'ℹ️ Waiting for ${waitingSession.bankCode}, received $detectedBank. Ignored.');
          } else {
            _isProcessingBalanceMessage = true;
            try {
              final balance = balanceData['balance'] as double;
              final fingerprint =
                  '${waitingSession.bankCode}|$balance|${body.hashCode}|${sender.toLowerCase()}';
              final shouldProcess =
                  await BalanceDetectionModeService.tryMarkProcessedFingerprint(
                fingerprint,
              );

              if (!shouldProcess) {
                debugPrint('ℹ️ Duplicate balance event ignored');
                return;
              }

              await BalanceSmsParser.storeBalance(
                  waitingSession.bankCode, balance);
              await NotificationService.showBalanceNotification(
                bank: waitingSession.bankCode,
                balance: balance,
              );

              await BalanceDetectionModeService.stopWaitingForBalance();
              debugPrint(
                  '✅ Balance stored for ${waitingSession.bankCode}; waiting mode reset');
              return;
            } finally {
              _isProcessingBalanceMessage = false;
            }
          }
        }
        // If balance-only SMS couldn't be parsed, fall through.
      }

      // Transaction Mode (default): parse only transaction details.
      // Ignore any available balance values in these messages.
      final parsedData =
          SmsExpenseService.parseSmsForExpense(body, sender: sender);
      if (parsedData != null) {
        debugPrint(
            '✅ EXPENSE SMS: ${parsedData['merchant']} - Rs.${parsedData['amount']}');

        // Check for duplicates
        final existingTransactions =
            await SmsExpenseService.getStoredTransactions();
        final isDuplicate = existingTransactions.any((tx) {
          final refNumber = parsedData['reference'] as String?;
          if (refNumber != null && tx.referenceNumber == refNumber) return true;

          // Fuzzy match: same amount, same merchant, same day
          final smsDate = timestamp != null
              ? DateTime.fromMillisecondsSinceEpoch(timestamp)
              : DateTime.now();
          final sameDay = tx.date.year == smsDate.year &&
              tx.date.month == smsDate.month &&
              tx.date.day == smsDate.day;
          return tx.amount == parsedData['amount'] &&
              tx.merchant == parsedData['merchant'] &&
              sameDay;
        });

        if (!isDuplicate) {
          // Create and save transaction instantly
          final transaction = Transaction(
            id: 'txn_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond % 1000}',
            amount: parsedData['amount'],
            merchant: parsedData['merchant'],
            category: SmsExpenseService.categorizeExpense(
                parsedData['merchant'], parsedData['amount'],
                transactionType: parsedData['type'] ?? 'expense')['category'],
            paymentMethod: parsedData['paymentMethod'],
            isAutoDetected: true,
            date: timestamp != null
                ? DateTime.fromMillisecondsSinceEpoch(timestamp)
                : DateTime.now(),
            referenceNumber: parsedData['reference'],
            confidenceScore: 1.0,
            type: parsedData['type'] ?? 'expense',
          );

          await SmsExpenseService.saveTransactionsAndSyncBackend([transaction]);

          // Emit real-time expense event
          _expenseUpdateController.add(transaction);

          // Show notification for new transaction
          await NotificationService.showExpenseNotification(
            amount: parsedData['amount'],
            date: timestamp != null
                ? DateTime.fromMillisecondsSinceEpoch(timestamp)
                : DateTime.now(),
          );

          debugPrint(
              '✅ Transaction saved and event emitted: ${transaction.merchant} - ₹${transaction.amount}');
        } else {
          debugPrint('❌ Duplicate transaction detected, skipping');
        }
      } else {
        debugPrint('❌ Not a transaction SMS, ignoring');
      }
    } catch (e) {
      debugPrint('❌ Error in instant SMS processing: $e');
    }
  }

  /// Request necessary permissions
  Future<void> _requestNotificationPermission() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // Request notification listener permission
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }
}
