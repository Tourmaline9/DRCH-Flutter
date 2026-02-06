import 'package:flutter/material.dart';
import '../services/auth_services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _authService = AuthService();

  bool _loading = false;
  bool _isSignup = false; // 🔥 toggle mode

  Future<void> _submit() async {
    if (_passwordController.text.length < 6) {
      _showError("Password must be at least 6 characters");
      return;
    }

    setState(() => _loading = true);

    try {
      if (_isSignup) {
        await _authService.signUp(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        await _authService.login(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      }
    } catch (e) {
      _showError(e.toString());
    }

    setState(() => _loading = false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSignup ? "Create Account" : "Login"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            Text(
              _isSignup
                  ? "Create a new account"
                  : "Login to continue",
              style: Theme.of(context).textTheme.titleLarge,
            ),

            const SizedBox(height: 24),

            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Email",
                prefixIcon: Icon(Icons.email),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password (min 6 chars)",
                prefixIcon: Icon(Icons.lock),
              ),
            ),

            const SizedBox(height: 24),

            if (_loading)
              const CircularProgressIndicator()
            else
              Column(
                children: [

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submit,
                      child: Text(
                        _isSignup ? "Create Account" : "Login",
                      ),
                    ),
                  ),

                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignup = !_isSignup;
                      });
                    },
                    child: Text(
                      _isSignup
                          ? "Already have an account? Login"
                          : "Don't have an account? Create one",
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
