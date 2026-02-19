import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/savings_model.dart';
import '../../services/savings_storage_service.dart';
import '../../theme/app_colors.dart';

class CreateGoalScreen extends StatefulWidget {
  const CreateGoalScreen({super.key});

  @override
  State<CreateGoalScreen> createState() => _CreateGoalScreenState();
}

class _CreateGoalScreenState extends State<CreateGoalScreen> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime? _targetDate;
  final String _emoji = '🎯';

  final _storage = SavingsStorageService();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.background,
        border: null,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(CupertinoIcons.back, color: AppColors.textPrimary),
        ),
        middle: const Text('Create Savings Goal'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CupertinoTextField(
                  controller: _nameController,
                  placeholder: 'Goal Name',
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CupertinoTextField(
                  controller: _amountController,
                  placeholder: 'Target Amount',
                  keyboardType: TextInputType.number,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _targetDate == null
                            ? 'Pick Target Date'
                            : 'Target: ${_targetDate!.toLocal().toString().split(' ')[0]}',
                        style: TextStyle(
                          fontSize: 16,
                          color: _targetDate == null
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      const Icon(
                        CupertinoIcons.calendar,
                        color: Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: const Color(0xFF1B3A6B),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: _isSaving ? null : _createGoal,
                  child: _isSaving
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : const Text(
                          'Create Goal',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    await showCupertinoModalPopup(
      context: context,
      builder: (context) {
        DateTime tempDate = _targetDate ?? DateTime.now().add(const Duration(days: 30));
        return Container(
          height: 300,
          color: Colors.white,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  CupertinoButton(
                    child: const Text('Done'),
                    onPressed: () {
                      setState(() => _targetDate = tempDate);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: tempDate,
                  minimumDate: DateTime.now(),
                  maximumDate: DateTime(2035),
                  onDateTimeChanged: (date) {
                    tempDate = date;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createGoal() async {
    if (_nameController.text.isEmpty ||
        _amountController.text.isEmpty ||
        _targetDate == null) {
      return;
    }

    setState(() => _isSaving = true);

    await Future.delayed(const Duration(milliseconds: 400));

    final goal = SavingsGoal(
      id: const Uuid().v4(),
      name: _nameController.text,
      emoji: _emoji,
      targetAmount: double.parse(_amountController.text),
      savedAmount: 0,
      targetDate: _targetDate!.toLocal().toString().split(' ')[0],
      status: GoalStatus.onTrack,
      iconBg: '#EEF2FF',
      iconBorder: '#6366F1',
    );

    await _storage.saveSavingsGoal(goal);

    if (!mounted) return;
    Navigator.pop(context);
  }
}
