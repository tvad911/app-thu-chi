import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/app_lock_service.dart';

/// Provider for AppLockService singleton
final appLockServiceProvider = Provider<AppLockService>((ref) {
  return AppLockService();
});

/// Whether app lock is currently active (app should show lock screen)
final appLockedProvider = StateProvider<bool>((ref) => false);
