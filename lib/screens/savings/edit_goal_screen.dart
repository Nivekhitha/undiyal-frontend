import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/savings_model.dart';
import '../../services/savings_storage_service.dart';

class EditGoalScreen extends StatefulWidget {
  final SavingsGoal goal;

  const EditGoalScreen({super.key, required this.goal});

  @override
  State<EditGoalScreen> createState() => _EditGoalScreenState();
}

class _EditGoalScreenState extends State<EditGoalScreen> {
  final SavingsStorageService _storageService = SavingsStorageService();
  late TextEditingController _savedAmountController;
  late TextEditingController _targetAmountController;
  late TextEditingController _nameController;
  late String _targetDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _savedAmountController = TextEditingController(
      text: widget.goal.savedAmount.toStringAsFixed(0),
    );
    _targetAmountController = TextEditingController(
      text: widget.goal.targetAmount.toStringAsFixed(0),
    );
    _nameController = TextEditingController(text: widget.goal.name);
    _targetDate = widget.goal.targetDate;
  }

  @override
  void dispose() {
    _savedAmountController.dispose();
    _targetAmountController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_isSaving) return;

    final savedAmount = double.tryParse(_savedAmountController.text);
    final targetAmount = double.tryParse(_targetAmountController.text);
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      _showAlert('Please enter a goal name');
      return;
    }

    if (savedAmount == null || savedAmount < 0) {
      _showAlert('Please enter a valid saved amount');
      return;
    }

    if (targetAmount == null || targetAmount <= 0) {
      _showAlert('Please enter a valid target amount');
      return;
    }

    if (savedAmount > targetAmount) {
      _showAlert('Saved amount cannot exceed target amount');
      return;
    }

    setState(() => _isSaving = true);

    final updatedGoal = SavingsGoal(
      id: widget.goal.id,
      name: name,
      targetAmount: targetAmount,
      savedAmount: savedAmount,
      targetDate: _targetDate,
      emoji: widget.goal.emoji,
      status: widget.goal.status,
      iconBg: widget.goal.iconBg,
      iconBorder: widget.goal.iconBorder,
    );

    await _storageService.updateSavingsGoal(widget.goal.id, updatedGoal);

    if (!mounted) return;

    Navigator.of(context).pop(true); // Return true to indicate changes were made
  }

  void _showAlert(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Invalid Input'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color(0xFFF4F6F8),
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        middle: const Text('Edit Goal'),
        trailing: _isSaving
            ? const CupertinoActivityIndicator()
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _saveChanges,
                child: const Text('Save'),
              ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Goal Icon and Title
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _parseColor(widget.goal.iconBg),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        widget.goal.emoji,
                        style: const TextStyle(fontSize: 40),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  CupertinoTextField(
                    controller: _nameController,
                    placeholder: 'Goal Name',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F6F8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Saved Amount
            _buildInputSection(
              title: 'Saved Amount',
              controller: _savedAmountController,
              prefix: 'Rs ',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),

            const SizedBox(height: 16),

            // Target Amount
            _buildInputSection(
              title: 'Target Amount',
              controller: _targetAmountController,
              prefix: 'Rs ',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),

            const SizedBox(height: 16),

            // Target Date
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Target Date',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _showDatePicker,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F6F8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDate(_targetDate),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Icon(
                            CupertinoIcons.calendar,
                            color: Color(0xFF6B7280),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Progress Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Progress',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      Text(
                        '${((double.tryParse(_savedAmountController.text) ?? 0) / (double.tryParse(_targetAmountController.text) ?? 1) * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (double.tryParse(_savedAmountController.text) ?? 0) /
                          (double.tryParse(_targetAmountController.text) ?? 1),
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: AlwaysStoppedAnimation<Color>(_parseColor(widget.goal.iconBorder)),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection({
    required String title,
    required TextEditingController controller,
    required String prefix,
    required TextInputType keyboardType,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: controller,
            prefix: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                prefix,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            keyboardType: keyboardType,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F8),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }

  void _showDatePicker() {
    DateTime initialDate;
    try {
      initialDate = DateTime.parse(_targetDate);
    } catch (e) {
      initialDate = DateTime.now().add(const Duration(days: 365));
    }

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => Container(
        height: 300,
        color: Colors.white,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                CupertinoButton(
                  child: const Text('Done'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: initialDate,
                minimumDate: DateTime.now(),
                onDateTimeChanged: (DateTime newDate) {
                  setState(() {
                    _targetDate = newDate.toIso8601String().split('T')[0]; // Store as YYYY-MM-DD
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    // Assuming the date is stored as a string like "2024-12-31"
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateStr; // Return as-is if parsing fails
    }
  }

  Color _parseColor(String colorStr) {
    // Parse color from hex string like "#FF5733"
    try {
      return Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
    } catch (e) {
      return const Color(0xFF6366F1); // Default color
    }
  }
}
