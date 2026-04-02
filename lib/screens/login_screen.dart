import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_services.dart';

final loginLoadingProvider = StateProvider.autoDispose<bool>((ref) => false);
final loginSignupProvider = StateProvider.autoDispose<bool>((ref) => false);
final loginRoleProvider = StateProvider.autoDispose<String>((ref) => 'community');

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  static const List<Map<String, String>> _roles = [
    {'value': 'community', 'label': 'Community / Volunteer'},
    {'value': 'ngo', 'label': 'NGO'},
    {'value': 'govt_authority', 'label': 'Govt authority'},
  ];

  Future<void> _submit() async {
    final isSignup = ref.read(loginSignupProvider);
    final selectedRole = ref.read(loginRoleProvider);

    if (_passwordController.text.length < 6) {
      _show('Password must be at least 6 characters');
      return;
    }
    if (isSignup && _nameController.text.trim().isEmpty) {
      _show('Please enter your name');
      return;
    }

    ref.read(loginLoadingProvider.notifier).state = true;
    try {
      if (isSignup) {
        final user = await _authService.signUp(_emailController.text.trim(), _passwordController.text.trim());
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'name': _nameController.text.trim(),
            'email': user.email,
            'role': selectedRole,
            'aadharSubmitted': false,
            'aadharStatus': 'not_submitted',
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          });
        }
      } else {
        await _authService.login(_emailController.text.trim(), _passwordController.text.trim());
      }
    } catch (e) {
      _show(e.toString());
    } finally {
      if (mounted) {
        ref.read(loginLoadingProvider.notifier).state = false;
      }
    }
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(loginLoadingProvider);
    final isSignup = ref.watch(loginSignupProvider);
    final selectedRole = ref.watch(loginRoleProvider);

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
                isSignup ? 'Create\nAccount' : 'Sign in',
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white),
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
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (isSignup) ...[
                      _field(controller: _nameController, label: 'Full Name', icon: Icons.person),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.badge_outlined),
                          labelText: 'Login type',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        items: _roles
                            .map((role) => DropdownMenuItem<String>(value: role['value'], child: Text(role['label']!)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            ref.read(loginRoleProvider.notifier).state = value;
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    _field(controller: _emailController, label: 'Email', icon: Icons.email),
                    const SizedBox(height: 16),
                    _field(controller: _passwordController, label: 'Password', icon: Icons.lock, obscure: true),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD3190D),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _submit,
                        child: Text(isSignup ? 'Create account' : 'Sign in'),
                      ),
                    ),
                    TextButton(
                      onPressed: () => ref.read(loginSignupProvider.notifier).state = !isSignup,
                      child: Text(
                        isSignup ? 'Already have an account? Sign in' : 'Don’t have an account? Create one',
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
}