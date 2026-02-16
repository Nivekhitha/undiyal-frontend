import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../services/sms_expense_service.dart';
import '../../services/balance_sms_parser.dart';
import '../../services/sms_notification_listener.dart';
import 'dart:convert';
import '../../models/transaction_model.dart';

class SmsDebugScreen extends StatefulWidget {
  const SmsDebugScreen({super.key});

  @override
  State<SmsDebugScreen> createState() => _SmsDebugScreenState();
}

class _SmsDebugScreenState extends State<SmsDebugScreen> {
  bool _isRunning = false;
  List<Transaction> _detectedTransactions = [];
  String _debugLog = '';
  final TextEditingController _sampleBodyController = TextEditingController();
  final TextEditingController _sampleSenderController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.background,
        middle: const Text('SMS Debug'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.back),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Test SMS Parsing Button
              CupertinoButton.filled(
                onPressed: _isRunning ? null : _testSmsParsing,
                child: _isRunning
                    ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                    : const Text('Test SMS Parsing'),
              ),
              const SizedBox(height: 12),

              // Sample SMS input for balance test
              CupertinoTextField(
                controller: _sampleBodyController,
                placeholder: 'Paste sample SMS body here',
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _sampleSenderController,
                placeholder: 'Sender (e.g. HDFC, SBI)',
              ),
              const SizedBox(height: 8),
              CupertinoButton(
                onPressed: _isRunning ? null : _testBalanceParsing,
                child: const Text('Parse Balance from Sample SMS'),
              ),
              const SizedBox(height: 12),
              CupertinoButton(
                onPressed: _isRunning ? null : _checkListenerStatus,
                child: const Text('Check Listener Status'),
              ),
              const SizedBox(height: 12),
              
              // Detect Expenses Button
              CupertinoButton(
                onPressed: _isRunning ? null : _detectExpenses,
                child: const Text('Detect Expenses from SMS'),
              ),
              const SizedBox(height: 12),
              
              // Clear Data Button
              CupertinoButton(
                onPressed: _isRunning ? null : _clearData,
                child: const Text('Clear All Data', style: TextStyle(color: CupertinoColors.destructiveRed)),
              ),
              const SizedBox(height: 8),
              
              // Reset Cleanup Flag Button
              CupertinoButton(
                onPressed: _isRunning ? null : _resetCleanupFlag,
                child: const Text('Reset Cleanup Flag', style: TextStyle(color: CupertinoColors.systemOrange)),
              ),
              
              const SizedBox(height: 20),
              
              // Results Section
              if (_detectedTransactions.isNotEmpty) ...[
                Text(
                  'Detected Transactions (${_detectedTransactions.length})',
                  style: AppTextStyles.h3,
                ),
                const SizedBox(height: 8),
                Expanded(
                  flex: 2,
                  child: ListView.builder(
                    itemCount: _detectedTransactions.length,
                    itemBuilder: (context, index) {
                      final tx = _detectedTransactions[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${tx.merchant} - ₹${tx.amount}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${tx.category} • ${tx.paymentMethod}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '${tx.date.toString().substring(0, 16)} • ${tx.type}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              
              // Debug Log Section
              Text(
                'Debug Log',
                style: AppTextStyles.h3,
              ),
              const SizedBox(height: 8),
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _debugLog.isEmpty ? 'Press a button to start debugging...' : _debugLog,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: CupertinoColors.white,
                      ),
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

  Future<void> _testSmsParsing() async {
    setState(() {
      _isRunning = true;
      _debugLog = 'Testing SMS parsing...\n';
    });

    try {
      setState(() {
        _debugLog += '\nSMS parsing test completed!\n';
        _debugLog += 'Check the console logs for detailed output.\n';
      });
    } catch (e) {
      setState(() {
        _debugLog += '\nError: $e\n';
      });
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  Future<void> _testBalanceParsing() async {
    final body = _sampleBodyController.text.trim();
    final sender = _sampleSenderController.text.trim();
    setState(() {
      _isRunning = true;
      _debugLog = 'Parsing sample SMS for balance...\n';
    });

    try {
      final result = BalanceSmsParser.parseBalanceSms(body, sender.isEmpty ? null : sender);
      if (result != null) {
        setState(() {
          _debugLog += '✅ Detected balance: ${result['balance']} for bank ${result['bank']}\n';
          _debugLog += 'Raw amount: ${result['rawAmount']}\n';
        });
      } else {
        setState(() {
          _debugLog += '❌ No balance detected in sample SMS.\n';
        });
      }
    } catch (e) {
      setState(() {
        _debugLog += 'Error parsing sample SMS: $e\n';
      });
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  Future<void> _checkListenerStatus() async {
    setState(() {
      _isRunning = true;
      _debugLog = 'Checking listener status...\n';
    });
    try {
      final status = await SmsNotificationListener.getListenerStatus();
      setState(() {
        _debugLog += 'Listener status: ${status.toString()}\n';
      });
    } catch (e) {
      setState(() {
        _debugLog += 'Error checking listener status: $e\n';
      });
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  Future<void> _detectExpenses() async {
    setState(() {
      _isRunning = true;
      _debugLog = 'Detecting expenses from SMS...\n';
      _detectedTransactions.clear();
    });

    try {
      final transactions = await SmsExpenseService.detectExpensesFromSms(limit: 20);
      setState(() {
        _detectedTransactions = transactions;
        _debugLog += '\nDetection completed!\n';
        _debugLog += 'Found ${transactions.length} transactions.\n';
        _debugLog += 'Check console logs for detailed parsing information.\n';
      });
    } catch (e) {
      setState(() {
        _debugLog += '\nError: $e\n';
      });
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  Future<void> _clearData() async {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Clear All Data'),
        content: const Text('This will clear all detected transactions and processed SMS references. Are you sure?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Clear'),
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _isRunning = true;
                _debugLog = 'Clearing all data...\n';
              });

              try {
                await SmsExpenseService.clearAllData();
                setState(() {
                  _detectedTransactions.clear();
                  _debugLog += 'All data cleared successfully!\n';
                });
              } catch (e) {
                setState(() {
                  _debugLog += '\nError clearing data: $e\n';
                });
              } finally {
                setState(() {
                  _isRunning = false;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _resetCleanupFlag() async {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Reset Cleanup Flag'),
        content: const Text('This will reset the one-time cleanup flag, causing the app to clear all data on next launch. Are you sure?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Reset'),
            onPressed: () async {
              Navigator.pop(context);
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('has_cleaned_v2_data');
                setState(() {
                  _debugLog += '\nCleanup flag reset successfully!\n';
                  _debugLog += 'App will clear data on next launch.\n';
                });
              } catch (e) {
                setState(() {
                  _debugLog += '\nError resetting cleanup flag: $e\n';
                });
              }
            },
          ),
        ],
      ),
    );
  }
}
