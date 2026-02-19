import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

/// Service for user profile and balance management
class UserService {
  static const String baseUrl = 'https://undiyal-backend-8zqj.onrender.com';

  /// Get user profile including balance (GET /user/profile?email=...)
  static Future<Map<String, dynamic>?> getProfile(String email) async {
    try {
      final uri = Uri.parse('$baseUrl/user/profile').replace(
        queryParameters: {'email': email},
      );

      debugPrint('Fetching profile for: $email');

      final response = await http.get(uri).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('Get Profile: Request timeout');
          throw Exception('Request timeout');
        },
      );

      debugPrint('Get Profile Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is Map<String, dynamic> ? data : null;
      } else {
        debugPrint('Failed to fetch profile: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      return null;
    }
  }

  /// Update user balance (simulate SMS) (PUT /user/balance)
  static Future<bool> updateBalance({
    required String email,
    required double balance,
    String? bank,
  }) async {
    try {
      final body = {
        'email': email,
        'balance': balance,
        if (bank != null) 'bank': bank,
      };

      debugPrint('Updating balance: ${jsonEncode(body)}');

      final response = await http.put(
        Uri.parse('$baseUrl/user/balance'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('Update Balance: Request timeout');
          throw Exception('Request timeout');
        },
      );

      debugPrint('Update Balance Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        debugPrint('Failed to update balance: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error updating balance: $e');
      return false;
    }
  }
}