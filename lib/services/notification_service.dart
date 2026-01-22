import 'dart:convert';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/globals.dart';
import '../screens/add_expense/manual_entry_screen.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'expense_alerts';
  static const String _channelName = 'Expense Alerts';
  static const String _channelDesc = 'Notifications for undetected expenses';

  // Friendly messages for ambiguous transactions
  static final List<String> _titles = [
    '💸 Did you just spend some money?',
    '👀 I saw a transaction!',
    '🤔 Help me categorize this',
    '🧾 New expense detected',
    '🤑 Cha-ching!',
    '🧐 Unknown purchase found'
  ];

  static final List<String> _bodies = [
    'Help me label it to keep your budget on track! 🚀',
    'Was that food, travel, or something else? Tap to tag it! 🍔✈️',
    'Quick check! Log this expense to stay organized. 📊',
    'Small logs lead to big savings! Tap to complete. 💰',
    'I couldn\'t figure out what this was. Can you help? 🤝',
    'Don\'t let this expense slip away! Log it now. 📝'
  ];

  /// Initialize notifications
  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create channel (required for Android 8.0+)
    await _createNotificationChannel();
  }

  static Future<void> _createNotificationChannel() async {
    final AndroidNotificationChannel channel = const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Request notification permission (Android 13+)
  static Future<void> requestPermission() async {
    final status = await Permission.notification.status;
    if (status.isDenied) {
      await Permission.notification.request();
    }
  }

  /// Show a friendly notification for an undetected expense
  static Future<void> showExpenseNotification({
    required double amount,
    required DateTime date,
  }) async {
    final random = Random();
    final title = _titles[random.nextInt(_titles.length)];
    final body = _bodies[random.nextInt(_bodies.length)];
    // Add amount to body for context
    final contextualBody = 'You spent ₹$amount. $body';

    final payload = jsonEncode({
      'amount': amount,
      'date': date.toIso8601String(),
    });

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      styleInformation: BigTextStyleInformation(''), 
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      DateTime.now().millisecond, // Unique ID based on time
      title,
      contextualBody,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        final amount = (data['amount'] as num).toDouble();
        final date = DateTime.parse(data['date']);

        // Navigate to Manual Entry Screen with pre-filled data
        if (navigatorKey.currentState != null) {
          navigatorKey.currentState!.push(
            CupertinoPageRoute(
              builder: (context) => ManualEntryScreen(
                initialAmount: amount,
                initialDate: date,
              ),
            ),
          );
        } else {
            debugPrint('Navigator state is null, cannot navigate');
        }
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }
}
