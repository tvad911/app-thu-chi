
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
             TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Tên hiển thị'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Tên đăng nhập'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Mật khẩu'),
              obscureText: true,
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ),
             const SizedBox(height: 24),
            authState.isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _register,
                      child: const Text('Đăng ký'),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  void _register() async {
      final username = _usernameController.text;
      final password = _passwordController.text;
      final name = _nameController.text;

      if (username.isEmpty || password.isEmpty || name.isEmpty) return;

      final success = await ref.read(authProvider.notifier).register(username, password, name);
      if (success) {
          // Pop register screen if successful login happens or allow auth state stream to handle
          Navigator.pop(context); 
      } else {
           setState(() {
            _errorMessage = 'Đăng ký thất bại. Tên đăng nhập có thể đã tồn tại.';
          });
      }
  }
}
