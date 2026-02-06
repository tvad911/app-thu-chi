import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_provider.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/register_screen.dart';
import 'presentation/screens/main_screen.dart';
import 'presentation/screens/debts/debt_list_screen.dart';
import 'presentation/screens/debts/debt_form_screen.dart';

/// Root application widget
class ThuChiApp extends ConsumerWidget {
  const ThuChiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    
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
      home: authState.user != null ? const MainScreen() : const LoginScreen(),
      routes: {
        '/debts': (context) => const DebtListScreen(),
        '/debts/add': (context) => const DebtFormScreen(),
        '/register': (context) => const RegisterScreen(),
      },
    );
  }
}
