import 'dart:async';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:shared_preferences/shared_preferences.dart';

/// Service to handle biometric authentication
class BiometricService {
  static final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if device supports biometric authentication
  static Future<bool> isDeviceSupported() async {
    try {
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  /// Check if biometrics are enrolled on the device
  static Future<bool> areBiometricsEnrolled() async {
    try {
      final List<BiometricType> availableBiometrics = await _localAuth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get available biometric types
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Authenticate using biometrics
  static Future<Map<String, dynamic>> authenticate() async {
    try {
      final bool isDeviceSupported = await BiometricService.isDeviceSupported();
      if (!isDeviceSupported) {
        return {
          'success': false,
          'message': 'Biometric authentication is not supported on this device.',
        };
      }

      final bool areEnrolled = await BiometricService.areBiometricsEnrolled();
      if (!areEnrolled) {
        return {
          'success': false,
          'message': 'No biometrics are enrolled on this device. Please set up biometric authentication in your device settings.',
        };
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access Undiyal',
        options: const AuthenticationOptions(
          biometricOnly: true,
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );

      if (didAuthenticate) {
        // Record successful authentication
        await _recordAuthAttempt(true);
        return {
          'success': true,
          'message': 'Authentication successful',
        };
      } else {
        return {
          'success': false,
          'message': 'Authentication failed or was cancelled.',
        };
      }
    } on PlatformException catch (e) {
      String message;
      switch (e.code) {
        case auth_error.notAvailable:
          message = 'Biometric authentication is not available.';
          break;
        case auth_error.notEnrolled:
          message = 'No biometrics are enrolled on this device.';
          break;
        case auth_error.passcodeNotSet:
          message = 'Passcode is not set on the device.';
          break;
        case auth_error.lockedOut:
          message = 'Too many failed attempts. Biometric authentication is temporarily locked.';
          break;
        case auth_error.permanentlyLockedOut:
          message = 'Biometric authentication is permanently locked due to too many failed attempts.';
          break;
        default:
          message = 'Authentication error: ${e.message}';
      }
      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Authentication failed: $e',
      };
    }
  }

  /// Check if biometric lock is enabled in app settings
  static Future<bool> isBiometricLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometric_enabled') ?? false;
  }

  /// Enable/disable biometric lock
  static Future<void> setBiometricLock(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', enabled);
  }

  /// Record authentication attempt for tracking
  static Future<void> _recordAuthAttempt(bool success) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt('last_auth_attempt', now);
    await prefs.setBool('last_auth_success', success);
  }

  /// Get last authentication timestamp
  static Future<DateTime?> getLastAuthTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt('last_auth_attempt');
    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  }

  /// Check if authentication is required (based on time elapsed)
  static Future<bool> isAuthRequired() async {
    final isEnabled = await isBiometricLockEnabled();
    if (!isEnabled) return false;

    final lastAuthTime = await getLastAuthTime();
    if (lastAuthTime == null) return true;

    // Require re-auth after 5 minutes of inactivity
    final now = DateTime.now();
    final difference = now.difference(lastAuthTime);
    return difference.inMinutes >= 5;
  }

  /// Get human-readable biometric type name
  static String getBiometricTypeName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'Face ID';
      case BiometricType.fingerprint:
        return 'Fingerprint';
      case BiometricType.iris:
        return 'Iris';
      case BiometricType.strong:
        return 'Strong Biometric';
      case BiometricType.weak:
        return 'Weak Biometric';
      default:
        return 'Biometric';
    }
  }

  /// Get the primary available biometric name
  static Future<String> getPrimaryBiometricName() async {
    final types = await getAvailableBiometrics();
    if (types.isEmpty) return 'Biometric';
    
    // Prefer face over fingerprint
    if (types.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (types.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    }
    return getBiometricTypeName(types.first);
  }
}

// PlatformException stub for non-mobile platforms
class PlatformException implements Exception {
  final String code;
  final String? message;
  final dynamic details;

  PlatformException({
    required this.code,
    this.message,
    this.details,
  });

  @override
  String toString() => 'PlatformException($code, $message, $details)';
}
