import 'package:flutter/material.dart';
import 'package:logbook_app_020/features/auth/login_controller.dart';
import 'package:logbook_app_020/features/logbook/log_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final LoginController _controller = LoginController();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  bool _obscurePassword = true;
  bool _isButtonDisabled = false;

  // Helper SnackBar
  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _handleLogin() {
    final user = _userController.text.trim();
    final pass = _passController.text.trim();

    if (user.isEmpty || pass.isEmpty) {
      _showSnack("Username dan Password tidak boleh kosong");
      return;
    }

    final currentUser = _controller.validateLogin(user, pass);

    if (currentUser != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LogView(currentUser: currentUser),
        ),
      );
    } else {
      if (_controller.shouldLock()) {
        _showSnack("Login gagal 3x. Tunggu 10 detik");
        setState(() => _isButtonDisabled = true);

        Future.delayed(const Duration(seconds: 10), () {
          if (!mounted) return;
          setState(() {
            _controller.failedAttempts = 0;
            _isButtonDisabled = false;
          });
        });
      } else {
        _showSnack("Username atau Password salah");
      }
    }
  }

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login Gatekeeper")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _userController,
              decoration: const InputDecoration(
                labelText: "Username",
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _passController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: "Password",
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _isButtonDisabled ? null : _handleLogin,
              child: const Text("Masuk"),
            ),
          ],
        ),
      ),
    );
  }
}