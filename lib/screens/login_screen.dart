import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _authService = AuthService();

  bool _loading = false;
  bool _isSignup = false;
  String _selectedRole = "community";

  static const List<Map<String, String>> _roles = [
    {"value": "community", "label": "Community / Volunteer"},
    {"value": "ngo", "label": "NGO"},
    {"value": "govt_authority", "label": "Govt authority"},
  ];

  Future<void> _submit() async {
    if (_passwordController.text.length < 6) {
      _show("Password must be at least 6 characters");
      return;
    }

    if (_isSignup && _nameController.text.trim().isEmpty) {
      _show("Please enter your name");
      return;
    }

    setState(() => _loading = true);

    try {
      if (_isSignup) {
        final user = await _authService.signUp(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );

        if (user != null) {
          await FirebaseFirestore.instance
              .collection("users")
              .doc(user.uid)
              .set({
            "name": _nameController.text.trim(),
            "email": user.email,
            "role": _selectedRole,
            "aadharSubmitted": false,
            "aadharStatus": "not_submitted",
            "createdAt": DateTime.now().millisecondsSinceEpoch,
          });
        }
      } else {
        await _authService.login(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      }

      // AuthGate at app root listens to authStateChanges and
      // automatically routes authenticated users into MainScaffold.

    } catch (e) {
      _show(e.toString());
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD3190D),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              alignment: Alignment.bottomLeft,
              child: Text(
                _isSignup ? "Create\nAccount" : "Sign in",
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (_isSignup) ...[
                      _field(
                        controller: _nameController,
                        label: "Full Name",
                        icon: Icons.person,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.badge_outlined),
                          labelText: "Login type",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        items: _roles
                            .map(
                              (role) => DropdownMenuItem<String>(
                                value: role["value"],
                                child: Text(role["label"]!),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedRole = value);
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    _field(
                      controller: _emailController,
                      label: "Email",
                      icon: Icons.email,
                    ),
                    const SizedBox(height: 16),
                    _field(
                      controller: _passwordController,
                      label: "Password",
                      icon: Icons.lock,
                      obscure: true,
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: _loading
                          ? const Center(
                        child: CircularProgressIndicator(),
                      )
                          : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          const Color(0xFFD3190D),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _submit,
                        child: Text(
                          _isSignup
                              ? "Create Account"
                              : "Login",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextButton(
                      onPressed: () {
                        setState(
                                () => _isSignup = !_isSignup);
                      },
                      child: Text(
                        _isSignup
                            ? "Already have an account? Login"
                            : "Don’t have an account? Sign up",
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
