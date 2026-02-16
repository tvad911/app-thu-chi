import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/app_lock_service.dart';

/// Lock screen with PIN entry and optional biometric auth
class LockScreen extends ConsumerStatefulWidget {
  /// If true, user is setting a new PIN (not unlocking)
  final bool isSettingPin;

  /// Callback after successful unlock/PIN set
  final VoidCallback? onUnlocked;

  const LockScreen({super.key, this.isSettingPin = false, this.onUnlocked});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _appLockService = AppLockService();
  String _enteredPin = '';
  String? _firstPin; // For confirm flow when setting
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isSettingPin) {
      _tryBiometric();
    }
  }

  Future<void> _tryBiometric() async {
    // Biometric not supported on Linux desktop
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) return;

    final bioEnabled = await _appLockService.isBiometricEnabled();
    if (!bioEnabled) return;

    final bioAvailable = await _appLockService.isBiometricAvailable();
    if (!bioAvailable) return;

    final success = await _appLockService.authenticateWithBiometrics();
    if (success && mounted) {
      _onSuccess();
    }
  }

  void _onDigitPressed(String digit) {
    if (_enteredPin.length >= 6) return;
    setState(() {
      _enteredPin += digit;
      _errorMessage = null;
    });

    if (_enteredPin.length >= 4) {
      // Allow 4–6 digits. Auto-submit at 6 or user can press confirm at 4+
    }
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _errorMessage = null;
    });
  }

  Future<void> _onConfirm() async {
    if (_enteredPin.length < 4) {
      setState(() => _errorMessage = 'PIN phải có ít nhất 4 số');
      return;
    }

    setState(() => _isLoading = true);

    if (widget.isSettingPin) {
      await _handleSetPin();
    } else {
      await _handleVerifyPin();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _handleSetPin() async {
    if (_firstPin == null) {
      // First entry
      setState(() {
        _firstPin = _enteredPin;
        _enteredPin = '';
        _errorMessage = null;
      });
    } else {
      // Confirm entry
      if (_enteredPin == _firstPin) {
        await _appLockService.setPin(_enteredPin);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã đặt mã PIN thành công!')),
          );
          _onSuccess();
        }
      } else {
        setState(() {
          _errorMessage = 'Mã PIN không khớp. Vui lòng thử lại.';
          _enteredPin = '';
          _firstPin = null;
        });
      }
    }
  }

  Future<void> _handleVerifyPin() async {
    final isValid = await _appLockService.verifyPin(_enteredPin);
    if (isValid) {
      _onSuccess();
    } else {
      setState(() {
        _errorMessage = 'Mã PIN không đúng';
        _enteredPin = '';
      });
      HapticFeedback.heavyImpact();
    }
  }

  void _onSuccess() {
    if (widget.onUnlocked != null) {
      widget.onUnlocked!();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String title;
    String subtitle;
    if (widget.isSettingPin) {
      if (_firstPin == null) {
        title = 'Đặt mã PIN';
        subtitle = 'Nhập mã PIN mới (4–6 số)';
      } else {
        title = 'Xác nhận mã PIN';
        subtitle = 'Nhập lại mã PIN để xác nhận';
      }
    } else {
      title = 'Mở khóa';
      subtitle = 'Nhập mã PIN để tiếp tục';
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // Lock icon
            Icon(
              widget.isSettingPin ? Icons.lock_outline : Icons.lock,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),

            // Title
            Text(title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),

            const SizedBox(height: 32),

            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (i) {
                final isFilled = i < _enteredPin.length;
                final isActive = i < 6; // show 6 slots
                return Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled ? theme.colorScheme.primary : Colors.transparent,
                    border: Border.all(
                      color: isActive ? theme.colorScheme.primary : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 16),

            // Error message
            SizedBox(
              height: 24,
              child: _errorMessage != null
                  ? Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 14))
                  : null,
            ),

            const Spacer(),

            // Number pad
            _buildNumberPad(theme),

            const SizedBox(height: 16),

            // Confirm button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_enteredPin.length >= 4 && !_isLoading) ? _onConfirm : null,
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Xác nhận'),
                ),
              ),
            ),

            if (widget.isSettingPin) ...[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Hủy'),
              ),
            ],

            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberPad(ThemeData theme) {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'backspace'],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          for (var i = 0; i < keys.length; i++) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: keys[i].map((key) {
                if (key.isEmpty) return const SizedBox(width: 72, height: 72);

                if (key == 'backspace') {
                  return SizedBox(
                    width: 72,
                    height: 72,
                    child: IconButton(
                      icon: const Icon(Icons.backspace_outlined),
                      onPressed: _onBackspace,
                    ),
                  );
                }

                if (key == '0') {
                    // special handling if needed, otherwise same as numbers
                }

                return SizedBox(
                  width: 72,
                  height: 72,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      shape: const CircleBorder(),
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                    onPressed: () => _onDigitPressed(key),
                    child: Text(key, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                );
              }).toList(),
            ),
            if (i < keys.length - 1) const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}
