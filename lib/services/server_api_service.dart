import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class ServerApiService {
  static const String baseUrl = 'https://undiyal-backend-8zqj.onrender.com';

  /// GET /user/profile?email=...
  /// Returns the decoded JSON map or null on failure
  static Future<Map<String, dynamic>?> getUserProfile({String? email}) async {
    final userEmail = email ?? await AuthService.getUserEmail();
    if (userEmail == null) return null;

    try {
      final uri = Uri.parse('$baseUrl/user/profile?email=$userEmail');
      final resp = await http.get(uri);
      debugPrint('Get Profile Response: ${resp.statusCode} - ${resp.body}');
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
    return null;
  }

  /// PUT /user/balance
  /// Body: { user_email: string, balance: number }
  static Future<bool> updateBalance({required double balance, String? email}) async {
    final userEmail = email ?? await AuthService.getUserEmail();
    if (userEmail == null) return false;

    try {
      final body = jsonEncode({'user_email': userEmail, 'balance': balance});
      final resp = await http.put(
        Uri.parse('$baseUrl/user/balance'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      debugPrint('Update Balance Response: ${resp.statusCode} - ${resp.body}');
      return resp.statusCode == 200 || resp.statusCode == 204;
    } catch (e) {
      debugPrint('Error updating balance: $e');
      return false;
    }
  }

  /// POST /budget
  /// Body: { user_email: string, amount: number }
  static Future<bool> setMonthlyBudget({required double amount, String? email}) async {
    final userEmail = email ?? await AuthService.getUserEmail();
    if (userEmail == null) return false;

    try {
      final body = jsonEncode({'user_email': userEmail, 'amount': amount});
      final resp = await http.post(
        Uri.parse('$baseUrl/budget'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      debugPrint('Set Budget Response: ${resp.statusCode} - ${resp.body}');
      return resp.statusCode == 200 || resp.statusCode == 201;
    } catch (e) {
      debugPrint('Error setting budget: $e');
      return false;
    }
  }

  /// GET /budget?user_email=...
  /// Returns budget amount or null
  static Future<double?> getMonthlyBudget({String? email}) async {
    final userEmail = email ?? await AuthService.getUserEmail();
    if (userEmail == null) return null;

    try {
      final uri = Uri.parse('$baseUrl/budget?user_email=$userEmail');
      final resp = await http.get(uri);
      debugPrint('Get Budget Response: ${resp.statusCode} - ${resp.body}');
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        // API might return { "budget": 5000 } or a plain number or { "amount": 5000 }
        if (data is num) return data.toDouble();
        if (data is Map) {
          if (data.containsKey('budget')) return (data['budget'] as num).toDouble();
          if (data.containsKey('amount')) return (data['amount'] as num).toDouble();
          if (data.containsKey('data') && data['data'] is Map && data['data'].containsKey('budget')) {
            return (data['data']['budget'] as num).toDouble();
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching budget: $e');
    }
    return null;
  }

  /// GET /test-gemini
  /// Optional query parameters can be provided.
  static Future<Map<String, dynamic>?> testGeminiGet({Map<String, String>? queryParams}) async {
    try {
      Uri uri = Uri.parse('$baseUrl/test-gemini');
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }
      final resp = await http.get(uri);
      debugPrint('Test Gemini GET: ${resp.statusCode} - ${resp.body}');
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error calling test-gemini GET: $e');
    }
    return null;
  }

  /// POST /test-gemini
  /// Sends JSON body and returns decoded response map or null
  static Future<Map<String, dynamic>?> testGeminiPost({Map<String, dynamic>? body}) async {
    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/test-gemini'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body ?? {}),
      );
      debugPrint('Test Gemini POST: ${resp.statusCode} - ${resp.body}');
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error calling test-gemini POST: $e');
    }
    return null;
  }
}
