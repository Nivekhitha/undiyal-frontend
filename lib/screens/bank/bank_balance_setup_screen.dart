import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../services/bank_call_rate_limiter.dart';
import '../../services/balance_sms_parser.dart';

class BankBalanceSetupScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback? onSkip;

  const BankBalanceSetupScreen({
    super.key,
    required this.onComplete,
    this.onSkip,
  });

  @override
  State<BankBalanceSetupScreen> createState() => _BankBalanceSetupScreenState();
}

class _BankBalanceSetupScreenState extends State<BankBalanceSetupScreen> {
  int? _selectedBankIndex;
  Map<String, int> _remainingCalls = {};
  bool _isWaitingForBalance = false;
  StreamSubscription<Map<String, dynamic>>? _balanceSubscription;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _loadRemainingCalls();
  }

  @override
  void dispose() {
    _balanceSubscription?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRemainingCalls() async {
    final calls = <String, int>{};
    for (final bank in banks) {
      final remaining = await BankCallRateLimiter.getRemainingCalls(bank['code']!);
      calls[bank['code']!] = remaining;
    }
    if (mounted) {
      setState(() {
        _remainingCalls = calls;
      });
    }
  }

  final List<Map<String, String>> banks = const [
    {
      'name': 'SBI (State Bank of India)',
      'number': '09223866666',
      'code': 'SBI',
      'icon': '🏦',
    },
    {
      'name': 'Bank of Baroda',
      'number': '8468001111',
      'code': 'BOB',
      'icon': '🏛️',
    },
    {
      'name': 'IOB (Indian Overseas Bank)',
      'number': '9210622122',
      'code': 'IOB',
      'icon': '🏛️',
    },
    {
      'name': 'CUB (City Union Bank)',
      'number': '9278177444',
      'code': 'CUB',
      'icon': '🏛️',
    },
    {
      'name': 'HDFC Bank',
      'number': '18002703333',
      'code': 'HDFC',
      'icon': '🏛️',
    },
    {
      'name': 'Axis Bank',
      'number': '18004195959',
      'code': 'AXIS',
      'icon': '🏛️',
    },
  ];

  Future<void> _launchDialer(String number) async {
    final Uri telUri = Uri(scheme: 'tel', path: number);
    try {
      final launched = await launchUrl(
        telUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        await Clipboard.setData(ClipboardData(text: number));
        if (mounted) {
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Dialer Not Available'),
              content: Text('Number $number copied to clipboard. Please dial manually.'),
              actions: [
                CupertinoDialogAction(
                  child: const Text('OK'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: number));
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Could not open dialer. Number $number copied to clipboard.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _onCheckBalancePressed() async {
    if (_selectedBankIndex != null) {
      final bank = banks[_selectedBankIndex!];
      final bankCode = bank['code']!;
      
      // Check rate limit
      final canCall = await BankCallRateLimiter.canMakeCall(bankCode);
      if (!canCall) {
        final timeUntilReset = BankCallRateLimiter.getTimeUntilReset();
        final hours = timeUntilReset.inHours;
        final minutes = timeUntilReset.inMinutes % 60;
        
        if (mounted) {
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Daily Limit Reached'),
              content: Text(
                'You have reached the maximum of ${BankCallRateLimiter.maxCallsPerDay} missed calls per day for ${bank['name']}.\n\n'
                'Please try again in ${hours}h ${minutes}m.',
              ),
              actions: [
                CupertinoDialogAction(
                  child: const Text('OK'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        }
        return;
      }
      
      // Record the call
      await BankCallRateLimiter.recordCall(bankCode);
      
      // Update remaining calls
      await _loadRemainingCalls();
      
      // Launch dialer
      await _launchDialer(bank['number']!);
      
      // Start listening for balance SMS
      _startWaitingForBalance(bankCode, bank['name']!);
    }
  }

  void _startWaitingForBalance(String bankCode, String bankName) {
    // Cancel any previous listener
    _balanceSubscription?.cancel();
    _timeoutTimer?.cancel();

    setState(() {
      _isWaitingForBalance = true;
    });

    // Subscribe to balance updates from the notification listener
    _balanceSubscription = BalanceSmsParser.onBalanceUpdate.listen((data) {
      // Balance received!
      _balanceSubscription?.cancel();
      _timeoutTimer?.cancel();
      
      if (mounted) {
        setState(() {
          _isWaitingForBalance = false;
        });

        final balance = data['balance'] as double;
        final detectedBank = data['bank'] as String? ?? bankCode;
        final fullBankName = BalanceSmsParser.getBankFullName(detectedBank);

        _showBalanceResultDialog(
          bankName: fullBankName,
          balance: balance,
        );
      }
    });

    // Timeout after 5 minutes
    _timeoutTimer = Timer(const Duration(minutes: 5), () {
      _balanceSubscription?.cancel();
      if (mounted) {
        setState(() {
          _isWaitingForBalance = false;
        });
        _showTimeoutDialog(bankName);
      }
    });
  }

  void _showBalanceResultDialog({required String bankName, required double balance}) {
    final formattedBalance = '₹${balance.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    )}';

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.checkmark_circle_fill,
              color: CupertinoColors.activeGreen,
              size: 22,
            ),
            const SizedBox(width: 8),
            const Flexible(child: Text('Balance Received')),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              Text(
                bankName,
                style: const TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                formattedBalance,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.activeGreen,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your balance has been saved and will be displayed on the home screen.',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
              widget.onComplete();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showTimeoutDialog(String bankName) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('No Response Yet'),
        content: Text(
          'We haven\'t received a balance SMS from $bankName yet. '
          'This can take 1-2 minutes. You can:\n\n'
          '• Wait and try again\n'
          '• Continue and check later from the home screen',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context);
              // Retry - listen again
              _startWaitingForBalance(
                banks[_selectedBankIndex!]['code']!,
                bankName,
              );
            },
            child: const Text('Wait & Retry'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
              widget.onComplete();
            },
            child: const Text('Continue Anyway'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    'Set Up Bank Balance',
                    style: AppTextStyles.h1,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select your bank to check your balance via missed call',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.info_circle,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'How it works',
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '1. Select your bank from the list\n'
                          '2. Tap "Check Balance" to open dialer\n'
                          '3. Make a missed call to the number\n'
                          '4. Receive SMS and app auto-updates your balance',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Select Your Bank',
                    style: AppTextStyles.h3,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: banks.length,
                      itemBuilder: (context, index) {
                        final bank = banks[index];
                        final isSelected = _selectedBankIndex == index;
                        final remainingCalls = _remainingCalls[bank['code']] ?? BankCallRateLimiter.maxCallsPerDay;
                        final isLimited = remainingCalls <= 0;
                        
                        return GestureDetector(
                          onTap: isLimited ? null : () {
                            setState(() {
                              _selectedBankIndex = index;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withOpacity(0.15)
                                  : isLimited 
                                      ? AppColors.cardBackground.withOpacity(0.5)
                                      : AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : isLimited ? AppColors.textSecondary.withOpacity(0.3) : AppColors.border,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary.withOpacity(0.2)
                                        : isLimited
                                            ? AppColors.textSecondary.withOpacity(0.1)
                                            : AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      bank['icon']!,
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        bank['name']!,
                                        style: AppTextStyles.body.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: isLimited 
                                              ? AppColors.textSecondary 
                                              : isSelected
                                                  ? AppColors.primary
                                                  : AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Dial: ${bank['number']}',
                                        style: AppTextStyles.caption.copyWith(
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                      if (isLimited)
                                        Text(
                                          'Daily limit reached',
                                          style: AppTextStyles.caption.copyWith(
                                            color: CupertinoColors.destructiveRed,
                                            fontSize: 12,
                                          ),
                                        )
                                      else if (remainingCalls < BankCallRateLimiter.maxCallsPerDay)
                                        Text(
                                          '$remainingCalls calls remaining today',
                                          style: AppTextStyles.caption.copyWith(
                                            color: remainingCalls == 1 
                                                ? CupertinoColors.activeOrange 
                                                : AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    CupertinoIcons.checkmark_circle_fill,
                                    color: AppColors.primary,
                                    size: 24,
                                  )
                                else if (isLimited)
                                  Icon(
                                    CupertinoIcons.lock_fill,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  )
                                else
                                  const Icon(
                                    CupertinoIcons.circle,
                                    color: AppColors.border,
                                    size: 24,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      onPressed: (_selectedBankIndex != null && !_isWaitingForBalance) ? _onCheckBalancePressed : null,
                      child: const Text('Check Balance'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Show "Set up later" only during onboarding (when onSkip is provided)
                  if (widget.onSkip != null)
                    Center(
                      child: CupertinoButton(
                        onPressed: _isWaitingForBalance ? null : widget.onSkip,
                        child: Text(
                          'Set up later',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      _selectedBankIndex != null
                          ? 'Tap "Check Balance" to open dialer'
                          : 'Select a bank to continue',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Loading overlay while waiting for balance SMS
          if (_isWaitingForBalance)
            _buildWaitingOverlay(),
        ],
      ),
    );
  }

  Widget _buildWaitingOverlay() {
    return Container(
      color: CupertinoColors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CupertinoActivityIndicator(radius: 20),
              const SizedBox(height: 24),
              Text(
                'Waiting for Balance SMS',
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Make the missed call and hang up.\nYour bank will send an SMS with your balance shortly.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  _balanceSubscription?.cancel();
                  _timeoutTimer?.cancel();
                  setState(() {
                    _isWaitingForBalance = false;
                  });
                },
                child: Text(
                  'Cancel',
                  style: AppTextStyles.body.copyWith(
                    color: CupertinoColors.destructiveRed,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
