import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_provider.dart';
import 'providers/app_lock_provider.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/register_screen.dart';
import 'presentation/screens/auth/lock_screen.dart';
import 'presentation/screens/main_screen.dart';
import 'presentation/screens/debts/debt_list_screen.dart';
import 'presentation/screens/debts/debt_form_screen.dart';

/// Root application widget with app lock lifecycle management
class ThuChiApp extends ConsumerStatefulWidget {
  const ThuChiApp({super.key});

  @override
  ConsumerState<ThuChiApp> createState() => _ThuChiAppState();
}

class _ThuChiAppState extends ConsumerState<ThuChiApp>
    with WidgetsBindingObserver {
  DateTime? _pausedAt;
  static const _lockTimeoutSeconds = 30;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Check if app should show lock screen on startup
  Future<void> _checkInitialLock() async {
    final lockService = ref.read(appLockServiceProvider);
    final isEnabled = await lockService.isLockEnabled();
    if (isEnabled) {
      ref.read(appLockedProvider.notifier).state = true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _handleResume();
    }
  }

  Future<void> _handleResume() async {
    if (_pausedAt == null) return;
    final elapsed = DateTime.now().difference(_pausedAt!).inSeconds;
    if (elapsed >= _lockTimeoutSeconds) {
      final lockService = ref.read(appLockServiceProvider);
      final isEnabled = await lockService.isLockEnabled();
      if (isEnabled) {
        ref.read(appLockedProvider.notifier).state = true;
      }
    }
    _pausedAt = null;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLocked = ref.watch(appLockedProvider);

    return MaterialApp(
      title: 'Quản lý thu chi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('vi', 'VN'),
        Locale('en', 'US'),
      ],
      home: _buildHome(authState, isLocked),
      routes: {
        '/debts': (context) => const DebtListScreen(),
        '/debts/add': (context) => const DebtFormScreen(),
        '/register': (context) => const RegisterScreen(),
      },
    );
  }

  Widget _buildHome(AuthState authState, bool isLocked) {
    // Not logged in → show login
    if (authState.user == null) return const LoginScreen();

    // Locked → show lock screen
    if (isLocked) {
      return LockScreen(
        onUnlocked: () {
          ref.read(appLockedProvider.notifier).state = false;
        },
      );
    }

    // Normal → main screen
    return const MainScreen();
  }
}
