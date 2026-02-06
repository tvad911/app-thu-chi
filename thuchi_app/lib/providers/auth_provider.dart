
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database/app_database.dart';
import 'app_providers.dart';

// State to hold current user
class AuthState {
  final User? user;
  final bool isLoading;

  AuthState({this.user, this.isLoading = false});
}

class AuthController extends StateNotifier<AuthState> {
  final Ref ref;

  AuthController(this.ref) : super(AuthState(isLoading: true)) {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('auth_user_id');
    
    if (userId != null) {
      final userRepo = ref.read(userRepositoryProvider);
      final user = await userRepo.getUserById(userId);
      if (user != null) {
        state = AuthState(user: user);
        return;
      }
    }
    state = AuthState(user: null);
  }

  Future<bool> login(String username, String password) async {
    state = AuthState(isLoading: true);
    final userRepo = ref.read(userRepositoryProvider);
    final user = await userRepo.login(username, password);

    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('auth_user_id', user.id);
      state = AuthState(user: user);
      return true;
    } else {
      state = AuthState(user: null);
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_user_id');
    state = AuthState(user: null);
  }
  
  Future<bool> register(String username, String password, String name) async {
      state = AuthState(isLoading: true);
      try {
          final userRepo = ref.read(userRepositoryProvider);
          final id = await userRepo.register(username, password, name);
          // Seed defaults
          final catRepo = ref.read(categoryRepositoryProvider);
          await catRepo.seedDefaultCategories(id);
          
          // Auto login after register
          return await login(username, password);
      } catch (e) {
          state = AuthState(user: null);
          return false;
      }
  }
}

final authProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref);
});

// Provide current user id easier
final currentUserProvider = Provider<User?>((ref) => ref.watch(authProvider).user);
