import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Service for app lock (PIN + biometrics)
class AppLockService {
  static const _pinKey = 'app_lock_pin_hash';
  static const _lockEnabledKey = 'app_lock_enabled';
  static const _biometricEnabledKey = 'biometric_enabled';

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  AppLockService({
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuth,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _localAuth = localAuth ?? LocalAuthentication();

  /// Encode PIN for storage (flutter_secure_storage encrypts at rest)
  String _encodePin(String pin) {
    return base64Encode(utf8.encode(pin));
  }

  /// Check if app lock is enabled
  Future<bool> isLockEnabled() async {
    final value = await _storage.read(key: _lockEnabledKey);
    return value == 'true';
  }

  /// Check if a PIN has been set
  Future<bool> hasPinSet() async {
    final hash = await _storage.read(key: _pinKey);
    return hash != null && hash.isNotEmpty;
  }

  /// Set a new PIN
  Future<void> setPin(String pin) async {
    final hash = _encodePin(pin);
    await _storage.write(key: _pinKey, value: hash);
    await _storage.write(key: _lockEnabledKey, value: 'true');
  }

  /// Verify PIN
  Future<bool> verifyPin(String pin) async {
    final storedHash = await _storage.read(key: _pinKey);
    if (storedHash == null) return false;
    return _encodePin(pin) == storedHash;
  }

  /// Remove PIN and disable lock
  Future<void> removePin() async {
    await _storage.delete(key: _pinKey);
    await _storage.write(key: _lockEnabledKey, value: 'false');
    await _storage.write(key: _biometricEnabledKey, value: 'false');
  }

  /// Check if device supports biometrics
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (e) {
      if (kDebugMode) print('Biometric check failed: $e');
      return false;
    }
  }

  /// Get/set biometric preference
  Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: _biometricEnabledKey);
    return value == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
  }

  /// Authenticate with biometrics
  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Xác thực để mở khóa ứng dụng',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      if (kDebugMode) print('Biometric auth failed: $e');
      return false;
    }
  }
}
