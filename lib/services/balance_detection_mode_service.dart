import 'package:shared_preferences/shared_preferences.dart';

class BalanceDetectionSession {
  final String bankCode;
  final int startedAtMs;
  final int expiresAtMs;

  const BalanceDetectionSession({
    required this.bankCode,
    required this.startedAtMs,
    required this.expiresAtMs,
  });

  Duration get remaining {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diffMs = expiresAtMs - now;
    return diffMs > 0 ? Duration(milliseconds: diffMs) : Duration.zero;
  }
}

class BalanceDetectionModeService {
  static const String _isWaitingKey = 'balance_mode_is_waiting';
  static const String _waitingBankKey = 'balance_mode_waiting_bank';
  static const String _startedAtKey = 'balance_mode_started_at_ms';
  static const String _expiresAtKey = 'balance_mode_expires_at_ms';
  static const String _lastProcessedFingerprintKey =
      'balance_mode_last_processed_fingerprint';
  static const String _lastProcessedAtKey = 'balance_mode_last_processed_at_ms';

  static const Duration defaultTimeout = Duration(minutes: 5);

  static Future<void> startWaitingForBalance({
    required String bankCode,
    Duration timeout = defaultTimeout,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;

    await prefs.setBool(_isWaitingKey, true);
    await prefs.setString(_waitingBankKey, bankCode);
    await prefs.setInt(_startedAtKey, now);
    await prefs.setInt(_expiresAtKey, now + timeout.inMilliseconds);
  }

  static Future<void> stopWaitingForBalance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isWaitingKey, false);
    await prefs.remove(_waitingBankKey);
    await prefs.remove(_startedAtKey);
    await prefs.remove(_expiresAtKey);
  }

  static Future<BalanceDetectionSession?> getActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final isWaiting = prefs.getBool(_isWaitingKey) ?? false;
    if (!isWaiting) return null;

    final bankCode = prefs.getString(_waitingBankKey);
    final startedAt = prefs.getInt(_startedAtKey);
    final expiresAt = prefs.getInt(_expiresAtKey);

    if (bankCode == null || startedAt == null || expiresAt == null) {
      await stopWaitingForBalance();
      return null;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now >= expiresAt) {
      await stopWaitingForBalance();
      return null;
    }

    return BalanceDetectionSession(
      bankCode: bankCode,
      startedAtMs: startedAt,
      expiresAtMs: expiresAt,
    );
  }

  static Future<bool> isWaitingForBalance() async {
    return (await getActiveSession()) != null;
  }

  static Future<bool> tryMarkProcessedFingerprint(String fingerprint) async {
    final prefs = await SharedPreferences.getInstance();
    final lastFingerprint = prefs.getString(_lastProcessedFingerprintKey);
    final lastProcessedAt = prefs.getInt(_lastProcessedAtKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    final isSameFingerprint = lastFingerprint == fingerprint;
    final withinDedupeWindow = (now - lastProcessedAt) < 15000;

    if (isSameFingerprint && withinDedupeWindow) {
      return false;
    }

    await prefs.setString(_lastProcessedFingerprintKey, fingerprint);
    await prefs.setInt(_lastProcessedAtKey, now);
    return true;
  }
}
