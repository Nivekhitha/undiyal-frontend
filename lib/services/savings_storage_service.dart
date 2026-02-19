import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/savings_model.dart';

class SavingsStorageService {
  static const String _savingsGoalsKey = 'savings_goals';

  Future<void> saveSavingsGoal(SavingsGoal goal) async {
    final prefs = await SharedPreferences.getInstance();
    final goals = await getSavingsGoals();
    goals.add(goal);
    final goalsJson = goals.map((g) => g.toJson()).toList();
    await prefs.setString(_savingsGoalsKey, jsonEncode(goalsJson));
  }

  Future<List<SavingsGoal>> getSavingsGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final goalsString = prefs.getString(_savingsGoalsKey);
    if (goalsString == null) return [];
    final List<dynamic> goalsJson = jsonDecode(goalsString);
    return goalsJson.map((json) => SavingsGoal.fromJson(json)).toList();
  }

  Future<void> updateSavingsGoal(String id, SavingsGoal updatedGoal) async {
    final prefs = await SharedPreferences.getInstance();
    final goals = await getSavingsGoals();
    final index = goals.indexWhere((g) => g.id == id);
    if (index != -1) {
      goals[index] = updatedGoal;
      final goalsJson = goals.map((g) => g.toJson()).toList();
      await prefs.setString(_savingsGoalsKey, jsonEncode(goalsJson));
    }
  }

  Future<void> deleteSavingsGoal(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final goals = await getSavingsGoals();
    goals.removeWhere((g) => g.id == id);
    final goalsJson = goals.map((g) => g.toJson()).toList();
    await prefs.setString(_savingsGoalsKey, jsonEncode(goalsJson));
  }
}
