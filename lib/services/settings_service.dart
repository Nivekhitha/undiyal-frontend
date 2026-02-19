import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

/// Global settings service to make budget, savings target, category budgets and currency available throughout the app
class SettingsService {
  /// Stream controller for settings changes
  static final StreamController<String> _settingsChangeController = 
      StreamController<String>.broadcast();
  
  /// Stream that emits when settings change (emits the setting key that changed)
  static Stream<String> get onSettingsChange => _settingsChangeController.stream;
  static const String _keyMonthlyBudget = 'monthly_budget';
  static const String _keyMonthlySavingsTarget = 'monthly_savings_target';
  static const String _keyCategoryBudgets = 'category_budgets';
  static const String _keyCurrency = 'currency';
  static const String _keyCurrencySymbol = 'currency_symbol';

  /// Default values
  static const double defaultBudget = 5000.0;
  static const double defaultSavingsTarget = 2000.0;
  static const String defaultCurrency = '₹ INR';
  static const String defaultCurrencySymbol = '₹';

  /// Currency symbols map
  static const Map<String, String> currencySymbols = {
    '₹ INR': '₹',
    '\$ USD': '\$',
    '€ EUR': '€',
    '£ GBP': '£',
    '¥ JPY': '¥',
  };

  /// Get monthly budget (tries backend first, falls back to local)
  static Future<double> getMonthlyBudget({bool syncFromBackend = false}) async {
    // Try backend first if requested
    if (syncFromBackend) {
      final backendBudget = await getMonthlyBudgetFromBackend();
      if (backendBudget != null) {
        return backendBudget;
      }
    }
    
    // Fall back to local storage
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyMonthlyBudget) ?? defaultBudget;
  }

  /// Set monthly budget (syncs with backend)
  static Future<void> setMonthlyBudget(double budget) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyMonthlyBudget, budget);
    
    // Notify listeners
    _settingsChangeController.add(_keyMonthlyBudget);
    
    // Sync with backend
    try {
      final userEmail = await AuthService.getUserEmail();
      if (userEmail != null) {
        await _syncBudgetToBackend(userEmail, budget);
      }
    } catch (e) {
      debugPrint('Error syncing budget to backend: $e');
      // Continue even if backend sync fails - local storage is primary
    }
  }

  /// Sync budget to backend (POST /budget)
  static Future<bool> _syncBudgetToBackend(String userEmail, double budget) async {
    try {
      const baseUrl = 'https://undiyal-backend-8zqj.onrender.com';
      final body = {
        'user_email': userEmail,
        'budget': budget,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/budget'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('Sync Budget: Request timeout');
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Budget synced to backend: $budget');
        return true;
      } else {
        debugPrint('Failed to sync budget: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error syncing budget: $e');
      return false;
    }
  }

  /// Get monthly budget from backend (GET /budget?user_email=...)
  static Future<double?> getMonthlyBudgetFromBackend() async {
    try {
      final userEmail = await AuthService.getUserEmail();
      if (userEmail == null) return null;

      const baseUrl = 'https://undiyal-backend-8zqj.onrender.com';
      final uri = Uri.parse('$baseUrl/budget').replace(
        queryParameters: {'user_email': userEmail},
      );

      final response = await http.get(uri).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('Get Budget: Request timeout');
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Handle different response formats
        double? budget;
        if (data is Map) {
          budget = data['budget'] != null ? (data['budget'] as num).toDouble() : null;
          if (budget == null && data['monthly_budget'] != null) {
            budget = (data['monthly_budget'] as num).toDouble();
          }
        }
        if (budget != null) {
          // Update local storage
          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble(_keyMonthlyBudget, budget);
          debugPrint('Budget fetched from backend: $budget');
        }
        return budget;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching budget from backend: $e');
      return null;
    }
  }

  /// Get monthly savings target
  static Future<double> getMonthlySavingsTarget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyMonthlySavingsTarget) ?? defaultSavingsTarget;
  }

  /// Set monthly savings target
  static Future<void> setMonthlySavingsTarget(double target) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyMonthlySavingsTarget, target);
    
    // Notify listeners
    _settingsChangeController.add(_keyMonthlySavingsTarget);
  }

  /// Get per-category budgets (category name -> budget limit)
  static Future<Map<String, double>> getCategoryBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyCategoryBudgets);
    if (json == null) return {};
    try {
      final Map<String, dynamic> decoded = jsonDecode(json);
      return decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      return {};
    }
  }

  /// Set per-category budgets
  static Future<void> setCategoryBudgets(Map<String, double> budgets) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(budgets.map((k, v) => MapEntry(k, v)));
    await prefs.setString(_keyCategoryBudgets, encoded);
    
    // Notify listeners
    _settingsChangeController.add(_keyCategoryBudgets);
  }

  /// Set a single category budget
  static Future<void> setCategoryBudget(String category, double budget) async {
    final current = await getCategoryBudgets();
    current[category] = budget;
    await setCategoryBudgets(current);
  }

  /// Get currency string (e.g., "₹ INR")
  static Future<String> getCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCurrency) ?? defaultCurrency;
  }

  /// Set currency
  static Future<void> setCurrency(String currency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrency, currency);
    // Also update the symbol
    await prefs.setString(_keyCurrencySymbol, currencySymbols[currency] ?? defaultCurrencySymbol);
  }

  /// Get currency symbol only (e.g., "₹")
  static Future<String> getCurrencySymbol() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCurrencySymbol) ?? defaultCurrencySymbol;
  }

  /// Format amount with current currency symbol
  static Future<String> formatAmount(double amount) async {
    final symbol = await getCurrencySymbol();
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  /// Format amount with symbol inline (for simple cases)
  static String formatAmountWithSymbol(double amount, String symbol) {
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  /// Get all settings at once
  static Future<Map<String, dynamic>> getAllSettings() async {
    return {
      'monthlyBudget': await getMonthlyBudget(),
      'monthlySavingsTarget': await getMonthlySavingsTarget(),
      'categoryBudgets': await getCategoryBudgets(),
      'currency': await getCurrency(),
      'currencySymbol': await getCurrencySymbol(),
    };
  }

  /// Clear all settings (logout)
  static Future<void> clearSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyMonthlyBudget);
    await prefs.remove(_keyMonthlySavingsTarget);
    await prefs.remove(_keyCategoryBudgets);
    await prefs.remove(_keyCurrency);
    await prefs.remove(_keyCurrencySymbol);
  }
}
