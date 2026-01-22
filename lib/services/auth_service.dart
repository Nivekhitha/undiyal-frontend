import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Base URL for the deployed backend
  static const String baseUrl = 'https://undiyal-backend-8zqj.onrender.com';

  /// Sign up a new user (POST /auth/register)
  static Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String college,
    required String city,
    required String state,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
          'college': college,
          'city': city,
          'state': state,
        }),
      );

      final data = jsonDecode(response.body);
      
      // API returns 200 for both success and error, check message field
      if (data['message'] == 'success') {
        return {
          'success': true,
          'message': data['message'],
          'user_id': data['user_id'],
          'email': data['email'],
        };
      } else {
        // Error response (e.g., "User already exists")
        throw Exception(data['message'] ?? 'Sign up failed');
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  /// Login user (POST /auth/login)
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);
      
      // API returns 200 for both success and error, check message field
      if (data['message'] == 'success') {
        return {
          'success': true,
          'message': data['message'],
          'user_id': data['user_id'],
          'email': data['email'],
        };
      } else {
        // Error response (e.g., "Invalid email or password")
        throw Exception(data['message'] ?? 'Login failed');
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  /// Save user ID locally
  static Future<void> saveUserId(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', userId);
  }

  /// Get saved user ID
  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id');
  }

  /// Logout user
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
  }
}


