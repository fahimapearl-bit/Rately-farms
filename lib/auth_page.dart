import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

class AuthGate extends StatelessWidget {
  final Widget child;

  const AuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: SupabaseConfig.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = SupabaseConfig.client.auth.currentSession;
        if (session == null) return const AuthPage();
        return child;
      },
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final mobileController = TextEditingController();
  final farmController = TextEditingController();
  bool isLogin = true;
  bool busy = false;
  bool obscurePassword = true;

  SupabaseClient get client => SupabaseConfig.client;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    mobileController.dispose();
    farmController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      if (isLogin) {
        await client.auth.signInWithPassword(
          email: emailController.text.trim(),
          password: passwordController.text,
        );
      } else {
        final response = await client.auth.signUp(
          email: emailController.text.trim(),
          password: passwordController.text,
          data: {
            'full_name': nameController.text.trim(),
            'mobile_number': mobileController.text.trim(),
            'farm_name': farmController.text.trim(),
          },
        );
        if (!mounted) return;
        final message = response.session == null
            ? 'Registration হয়েছে। Email verify করে Login করুন।'
            : 'Registration সফল হয়েছে।';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        if (response.session == null) setState(() => isLogin = true);
      }
    } on AuthException catch (error) {
      if (mounted) _showError(error.message);
    } catch (error) {
      if (mounted) _showError('Unexpected error: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String? requiredField(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label দিন';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.agriculture, size: 64, color: Colors.green),
                  const SizedBox(height: 12),
                  Text(
                    'Rately Farms',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isLogin ? 'আপনার account-এ Login করুন' : 'নতুন account তৈরি করুন',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (!isLogin) ...[
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder()),
                      validator: (value) => requiredField(value, 'Full name'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: mobileController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Mobile number', border: OutlineInputBorder()),
                      validator: (value) => requiredField(value, 'Mobile number'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: farmController,
                      decoration: const InputDecoration(labelText: 'Farm name', border: OutlineInputBorder()),
                      validator: (value) => requiredField(value, 'Farm name'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Email দিন';
                      if (!value.contains('@')) return 'সঠিক email দিন';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => obscurePassword = !obscurePassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.length < 6) return 'কমপক্ষে ৬ অক্ষরের password দিন';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: busy
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(isLogin ? 'Login' : 'Register'),
                  ),
                  TextButton(
                    onPressed: busy ? null : () => setState(() => isLogin = !isLogin),
                    child: Text(isLogin ? 'নতুন account তৈরি করুন' : 'আগের account দিয়ে Login করুন'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
