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

  static const _ink = Color(0xFF102A1F);
  static const _muted = Color(0xFF6B7280);
  static const _line = Color(0xFFE5E9E6);
  static const _soft = Color(0xFFF4F7F5);
  static const _brand = Color(0xFF1B5E20);
  static const _brandSoft = Color(0xFFE8F2E9);

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

  String _mapAuthError(AuthException error) {
    final raw = '${error.message} ${error.code ?? ''}'.toLowerCase();

    if (raw.contains('invalid login credentials') ||
        raw.contains('invalid_credentials')) {
      return 'Incorrect email or password.';
    }
    if (raw.contains('email not confirmed') ||
        raw.contains('email_not_confirmed')) {
      return 'Please verify your email before logging in.';
    }
    if (raw.contains('user already registered') ||
        raw.contains('already registered') ||
        raw.contains('user_already_exists')) {
      return 'An account with this email already exists. Please log in.';
    }
    if (raw.contains('password') &&
        (raw.contains('least') || raw.contains('weak') || raw.contains('short'))) {
      return 'Password is too weak. Use at least 6 characters.';
    }
    if (raw.contains('rate limit') || raw.contains('too many')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (raw.contains('network') || raw.contains('socket')) {
      return 'Network error. Check your internet connection.';
    }
    if (raw.contains('user not found')) {
      return 'No account found with this email.';
    }
    if (error.message.trim().isNotEmpty) {
      return error.message.trim();
    }
    return 'Something went wrong. Please try again.';
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : _brand,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
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
        if (response.session == null) {
          _showMessage(
            'Registration successful. Please verify your email, then log in.',
          );
          setState(() => isLogin = true);
        } else {
          _showMessage('Registration successful.');
        }
      }
    } on AuthException catch (error) {
      if (mounted) _showMessage(_mapAuthError(error), error: true);
    } catch (_) {
      if (mounted) {
        _showMessage('Something went wrong. Please try again.', error: true);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> forgotPassword() async {
    final email = emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showMessage('Enter a valid email above, then tap Forgot password.', error: true);
      return;
    }

    setState(() => busy = true);
    try {
      await client.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      _showMessage(
        'Password reset email sent. Check your inbox and spam folder.',
      );
    } on AuthException catch (error) {
      if (mounted) _showMessage(_mapAuthError(error), error: true);
    } catch (_) {
      if (mounted) {
        _showMessage('Could not send reset email. Please try again.', error: true);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  InputDecoration _field(
    String label, {
    String? hint,
    IconData? icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null
          ? null
          : Icon(icon, size: 20, color: _brand.withOpacity(0.85)),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      labelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: _muted,
      ),
      floatingLabelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: _brand,
      ),
      hintStyle: TextStyle(
        fontSize: 14,
        color: Colors.grey.shade400,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _brand, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _soft,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Brand header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _line),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: _brandSoft,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.agriculture_outlined,
                            color: _brand,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Rately Farms',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isLogin
                              ? 'Sign in to manage your farm'
                              : 'Create your farm account',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.35,
                            color: _muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Form card
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _line),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Segmented Login / Register
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _soft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _modeChip(
                                    label: 'Log in',
                                    selected: isLogin,
                                    onTap: () => setState(() => isLogin = true),
                                  ),
                                ),
                                Expanded(
                                  child: _modeChip(
                                    label: 'Register',
                                    selected: !isLogin,
                                    onTap: () => setState(() => isLogin = false),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          if (!isLogin) ...[
                            TextFormField(
                              controller: nameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: _field(
                                'Full name',
                                hint: 'Your name',
                                icon: Icons.person_outline,
                              ),
                              validator: (v) =>
                                  isLogin ? null : _required(v, 'Full name'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: mobileController,
                              keyboardType: TextInputType.phone,
                              decoration: _field(
                                'Mobile number',
                                hint: '01XXXXXXXXX',
                                icon: Icons.phone_outlined,
                              ),
                              validator: (v) =>
                                  isLogin ? null : _required(v, 'Mobile number'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: farmController,
                              textCapitalization: TextCapitalization.words,
                              decoration: _field(
                                'Farm name',
                                hint: 'Your farm name',
                                icon: Icons.home_work_outlined,
                              ),
                              validator: (v) =>
                                  isLogin ? null : _required(v, 'Farm name'),
                            ),
                            const SizedBox(height: 12),
                          ],

                          TextFormField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: _field(
                              'Email',
                              hint: 'you@example.com',
                              icon: Icons.mail_outline,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email is required';
                              }
                              if (!value.contains('@') || !value.contains('.')) {
                                return 'Enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: passwordController,
                            obscureText: obscurePassword,
                            autofillHints: const [AutofillHints.password],
                            decoration: _field(
                              'Password',
                              hint: 'At least 6 characters',
                              icon: Icons.lock_outline,
                              suffix: IconButton(
                                onPressed: () => setState(
                                  () => obscurePassword = !obscurePassword,
                                ),
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                  color: _muted,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password is required';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),

                          if (isLogin) ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: busy ? null : forgotPassword,
                                style: TextButton.styleFrom(
                                  foregroundColor: _brand,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 8,
                                  ),
                                ),
                                child: const Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ] else
                            const SizedBox(height: 16),

                          const SizedBox(height: 4),
                          SizedBox(
                            height: 50,
                            child: FilledButton(
                              onPressed: busy ? null : submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: _brand,
                                disabledBackgroundColor: _brand.withOpacity(0.55),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: busy
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      isLogin ? 'Log in' : 'Create account',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),
                  Text(
                    isLogin
                        ? 'New here? Switch to Register above.'
                        : 'Already registered? Switch to Log in above.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: _muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _brand : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : _ink,
          ),
        ),
      ),
    );
  }
}
