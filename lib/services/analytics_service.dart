import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import 'transaction_storage_service.dart';

class AnalyticsService {
  static const String _budgetKey = 'monthly_budget';

  /// Get comprehensive analytics data
  static Future<Map<String, dynamic>> getAnalyticsData() async {
    final transactions = await TransactionStorageService.getAllTransactions();
    final budget = await getBudget();
    final now = DateTime.now();

    // Filter for current month - ONLY expenses, not credits
    final thisMonthTransactions = transactions
        .where((t) =>
            t.type == 'expense' &&
            t.date.year == now.year &&
            t.date.month == now.month)
        .toList();

    // Current month credits as income
    final thisMonthCredits = transactions
        .where((t) =>
            t.type == 'credit' &&
            t.date.year == now.year &&
            t.date.month == now.month)
        .toList();

    final totalSpent =
        thisMonthTransactions.fold(0.0, (sum, t) => sum + t.amount);
    final incomeThisMonth =
        thisMonthCredits.fold(0.0, (sum, t) => sum + t.amount);

    // Burn rate metrics
    final dayOfMonth = now.day <= 0 ? 1 : now.day;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final dailyAvgSpend = totalSpent / dayOfMonth;
    final projectedMonthlySpend = dailyAvgSpend * daysInMonth;
    final expectedSavings = incomeThisMonth - projectedMonthlySpend;
    final burnRateSuggestion = _buildBurnRateSuggestion(expectedSavings);

    // Category Breakdown
    final categoryTotals = <String, double>{};
    for (var t in thisMonthTransactions) {
      categoryTotals[t.category] =
          (categoryTotals[t.category] ?? 0.0) + t.amount;
    }

    // Weekly Data (Last 7 days)
    final weeklyData = _getWeeklyData(transactions, now);

    // Monthly Data (Last 6 months)
    final monthlyData = _getMonthlyData(transactions, now);

    // Insights
    final insights =
        _generateInsights(categoryTotals, totalSpent, budget, transactions);

    return {
      'totalSpent': totalSpent,
      'incomeThisMonth': incomeThisMonth,
      'budget': budget,
      'dailyAvgSpend': dailyAvgSpend,
      'projectedMonthlySpend': projectedMonthlySpend,
      'expectedSavings': expectedSavings,
      'burnRateSuggestion': burnRateSuggestion,
      'categoryTotals': categoryTotals,
      'weeklyData': weeklyData,
      'monthlyData': monthlyData,
      'insights': insights,
    };
  }

  /// Get today's total spent (expenses only)
  static Future<double> getTodaySpent() async {
    final transactions = await TransactionStorageService.getAllTransactions();
    final now = DateTime.now();
    return transactions
        .where((t) =>
            t.type == 'expense' &&
            t.date.year == now.year &&
            t.date.month == now.month &&
            t.date.day == now.day)
        .fold<double>(0.0, (double sum, Transaction t) => sum + t.amount);
  }

  /// Get daily limit (Monthly Budget / 30)
  static Future<double> getDailyLimit() async {
    final budget = await getBudget();
    return budget / 30.0;
  }

  /// Get stored budget or default
  static Future<double> getBudget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_budgetKey) ?? 5000.0;
  }

  /// Save budget
  static Future<void> setBudget(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_budgetKey, amount);
  }

  static List<Map<String, dynamic>> _getWeeklyData(
      List<Transaction> transactions, DateTime now) {
    List<Map<String, dynamic>> data = [];
    final weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayTotal = transactions
          .where((t) =>
              t.type == 'expense' &&
              t.date.year == day.year &&
              t.date.month == day.month &&
              t.date.day == day.day)
          .fold<double>(0.0, (sum, t) => sum + (t.amount));

      data.add({
        'label': weekdays[day.weekday - 1],
        'amount': dayTotal,
        'isToday': i == 0,
      });
    }
    return data;
  }

  static List<Map<String, dynamic>> _getMonthlyData(
      List<Transaction> transactions, DateTime now) {
    final months = <Map<String, dynamic>>[];
    const labels = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    // Oldest -> newest (last 6 months)
    for (int i = 5; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final monthTotal = transactions
          .where((t) =>
              t.type == 'expense' &&
              t.date.year == monthDate.year &&
              t.date.month == monthDate.month)
          .fold<double>(0.0, (sum, t) => sum + t.amount);

      months.add({
        'label': labels[monthDate.month - 1],
        'amount': monthTotal,
        'isCurrentMonth': i == 0,
      });
    }
    return months;
  }

  static String _buildBurnRateSuggestion(double expectedSavings) {
    final absValue = expectedSavings.abs().round();
    if (expectedSavings.isNaN || expectedSavings.isInfinite) {
      return 'At this pace, your month-end savings projection will update as you add more data.';
    }
    if (expectedSavings >= 0) {
      return 'At this spending pace, you can save about ₹$absValue this month.';
    }
    return 'At this pace, you may be short by about ₹$absValue this month — a small adjustment can help.';
  }

  static List<String> _generateInsights(Map<String, double> categoryTotals,
      double totalSpent, double budget, List<Transaction> allTransactions) {
    final insights = <String>[];

    // 1. Highest Category
    if (categoryTotals.isNotEmpty) {
      final sorted = categoryTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topCat = sorted.first;
      insights.add(
          "You spent most on ${topCat.key} this month ${_getCategoryEmoji(topCat.key)}");
    }

    // 2. Budget Check
    if (totalSpent > budget) {
      insights.add("You've exceeded your monthly budget 😬");
    } else if (totalSpent > budget * 0.9) {
      insights.add("You're close to your budget limit! ⚠️");
    } else if (totalSpent < budget * 0.5 && DateTime.now().day > 15) {
      insights.add("Great saving! Under 50% of budget 💚");
    }

    // 3. Weekend Spender?
    final weekendSpend = allTransactions
        .where((t) =>
            t.date.weekday >= 6 && DateTime.now().difference(t.date).inDays < 7)
        .fold<double>(0.0, (double sum, Transaction t) => sum + t.amount);
    if (weekendSpend > totalSpent * 0.4 && totalSpent > 0) {
      insights.add("Weekend vibes! 40% spent this weekend 🎉");
    }

    // Default Fallback
    if (insights.isEmpty) {
      insights.add("Track more expenses to see insights! 📊");
    }

    return insights.take(3).toList();
  }

  static String _getCategoryEmoji(String category) {
    final map = {
      'Food & Drink': '🍔',
      'Shopping': '🛍️',
      'Transport': '🚕',
      'Entertainment': '🎬',
      'Groceries': '🍎',
      'Bills': '⚡',
      'Health': '💊',
      'Education': '📚',
    };
    return map[category] ?? '✨';
  }
}
