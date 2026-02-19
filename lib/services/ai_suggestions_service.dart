import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

/// Fetches AI-generated financial suggestions from the backend
class AiSuggestionsService {
  static const String baseUrl = 'https://undiyal-backend-8zqj.onrender.com';

  /// Get AI suggestions for the logged-in user
  /// Returns the suggestions markdown string, or null on error
  static Future<String?> getSuggestions() async {
    try {
      final userEmail = await AuthService.getUserEmail();
      if (userEmail == null) {
        debugPrint('AiSuggestions: User email not found');
        return null;
      }

      final uri = Uri.parse('$baseUrl/ai/suggestions').replace(
        queryParameters: {'user_email': userEmail},
      );

      debugPrint('Fetching AI suggestions for: $userEmail');

      final response = await http.get(uri).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('AiSuggestions: Request timeout');
          throw Exception('Request timeout');
        },
      );

      debugPrint('AI Suggestions Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final suggestions = data['suggestions'];
        if (suggestions is String) {
          return suggestions;
        }
        return null;
      } else {
        debugPrint('AI Suggestions failed: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching AI suggestions: $e');
      return null;
    }
  }

  /// Test Gemini API endpoint (GET /test-gemini)
  static Future<Map<String, dynamic>?> testGemini() async {
    try {
      const baseUrl = 'https://undiyal-backend-8zqj.onrender.com';
      final uri = Uri.parse('$baseUrl/test-gemini');

      debugPrint('Testing Gemini API endpoint');

      final response = await http.get(uri).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('Test Gemini: Request timeout');
          throw Exception('Request timeout');
        },
      );

      debugPrint('Test Gemini Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is Map<String, dynamic> ? data : null;
      } else {
        debugPrint('Test Gemini failed: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error testing Gemini: $e');
      return null;
    }
  }
}
