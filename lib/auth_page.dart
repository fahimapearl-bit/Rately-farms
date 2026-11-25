import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'supabase_config.dart';
import 'app_colors.dart';
import 'auth_widgets.dart';
import 'password_strength.dart';
import 'reset_password_page.dart';

class AuthGate extends StatelessWidget {
  final Widget child;

  const AuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: SupabaseConfig.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = SupabaseConfig.client.auth.currentSession;
        return ValueListenableBuilder<bool>(
          valueListenable: passwordRecoveryActive,
          builder: (context, recovering, _) {
            if (recovering) return const ResetPasswordPage();
            if (session == null) return const AuthPage();
            return child;
          },
        );
      },
    );
  }
}

enum UserRole { owner, manager, worker }

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
  UserRole selectedRole = UserRole.owner;
  String? _error;

  // Location related
  double? _latitude;
  double? _longitude;
  bool _locationLoading = false;
  String? _locationStatus;

  SupabaseClient get client => SupabaseConfig.client;

  @override
  void initState() {
    super.initState();
    passwordController.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    passwordController.removeListener(_onPasswordChanged);
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    mobileController.dispose();
    farmController.dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    if (!mounted || isLogin) return;
    setState(() {});
  }

  /// Location permission চেক করে current position নেয়
  Future<bool> _getCurrentLocation() async {
    setState(() {
      _locationLoading = true;
      _locationStatus = 'Getting location...';
    });

    try {
      // 1. Location service চালু আছে কিনা চেক
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationStatus = 'Location services are disabled. Please turn on GPS.';
          _locationLoading = false;
        });
        return false;
      }

      // 2. Permission চেক
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationStatus = 'Location permission denied.';
            _locationLoading = false;
          });
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationStatus =
              'Location permission permanently denied. Please enable from settings.';
          _locationLoading = false;
        });
        return false;
      }

      // 3. Current position নেওয়া
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationStatus =
            'Location captured: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
        _locationLoading = false;
      });

      return true;
    } catch (e) {
      setState(() {
        _locationStatus = 'Failed to get location: $e';
        _locationLoading = false;
      });
      return false;
    }
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      _error = null;
    });

    try {
      if (isLogin) {
        await client.auth.signInWithPassword(
          email: emailController.text.trim(),
          password: passwordController.text,
        );
      } else {
        // ========== SIGN UP ==========
        // প্রথমে location নেওয়ার চেষ্টা
        final hasLocation = await _getCurrentLocation();

        // Location না পেলেও signup চালিয়ে যেতে পারবেন (optional করে রাখা হয়েছে)
        // যদি বাধ্যতামূলক করতে চান, তাহলে নিচের if ব্লক আনকমেন্ট করুন:
        /*
        if (!hasLocation) {
          _showError('Location is required for registration. Please enable GPS and try again.');
          setState(() => busy = false);
          return;
        }
        */

        final response = await client.auth.signUp(
          email: emailController.text.trim(),
          password: passwordController.text,
          data: {
            'full_name': nameController.text.trim(),
            'mobile_number': mobileController.text.trim(),
            'farm_name': farmController.text.trim(),
            'role': selectedRole.name,
            // Location data
            if (_latitude != null) 'latitude': _latitude,
            if (_longitude != null) 'longitude': _longitude,
          },
        );

        if (!mounted) return;
        final message = response.session == null
            ? 'Registration complete. Verify your email, then sign in.'
            : 'Registration successful.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
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
    final colors = context.colors;
    setState(() => _error = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: colors.error),
    );
  }

  String? requiredField(String? value, String label) {
    if (value == null || value.trim().isEmpty) return 'Enter $label';
    return null;
  }

  Future<void> _openForgotPassword() async {
    FocusScope.of(context).unfocus();
    await showDialog<void>(
      context: context,
      builder: (_) =>
          _ForgotPasswordDialog(initialEmail: emailController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.soft,
      body: AuthBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: AuthCardShell(
                  header: AuthHeader(
                    title: 'Rately Farms',
                    subtitle:
                        isLogin ? 'Welcome back' : 'Create a new account',
                  ),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _modeTabs(colors),
                        const SizedBox(height: 22),

                        // Role Selection (শুধু সাইন-আপের সময়)
                        if (!isLogin) ...[
                          Text(
                            'I am a:',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colors.muted),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: UserRole.values.map((role) {
                              bool isSelected = selectedRole == role;
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => selectedRole = role),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 95,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colors.brand.withOpacity(0.1)
                                        : colors.surfaceAlt,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? colors.brand
                                          : colors.line,
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        role == UserRole.owner
                                            ? Icons.account_balance
                                            : (role == UserRole.manager
                                                ? Icons.supervisor_account
                                                : Icons.groups),
                                        size: 24,
                                        color: isSelected
                                            ? colors.brand
                                            : colors.muted,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        role.name.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? colors.brand
                                              : colors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // সাইন-আপ ফিল্ডস
                        if (!isLogin) ...[
                          AuthField(
                            controller: nameController,
                            label: 'Full Name',
                            hint: 'e.g. John Doe',
                            icon: Icons.person_outline_rounded,
                            enabled: !busy,
                            keyboardType: TextInputType.name,
                            textInputAction: TextInputAction.next,
                            validator: (value) =>
                                requiredField(value, 'your full name'),
                          ),
                          const SizedBox(height: 12),
                          AuthField(
                            controller: mobileController,
                            label: 'Mobile Number',
                            hint: '+8801XXXXXXXXX',
                            icon: Icons.phone_outlined,
                            enabled: !busy,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            validator: (value) =>
                                requiredField(value, 'your mobile number'),
                          ),
                          const SizedBox(height: 12),
                          // শুধু Owner হলে Farm Name চাই
                          if (selectedRole == UserRole.owner) ...[
                            AuthField(
                              controller: farmController,
                              label: 'Farm Name',
                              hint: 'e.g. Green Valley Farm',
                              icon: Icons.home_work_outlined,
                              enabled: !busy,
                              textInputAction: TextInputAction.next,
                              validator: (value) =>
                                  requiredField(value, 'your farm name'),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // ========== Location Status UI ==========
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colors.surfaceAlt,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colors.line),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _latitude != null
                                      ? Icons.location_on
                                      : Icons.location_off,
                                  color: _latitude != null
                                      ? colors.brand
                                      : colors.muted,
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Farm Location',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: colors.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _locationLoading
                                            ? 'Getting location...'
                                            : (_locationStatus ??
                                                'Location will be captured on signup'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_locationLoading)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                else
                                  TextButton(
                                    onPressed: busy ? null : _getCurrentLocation,
                                    child: const Text('Get'),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Email & Password (উভয় মোডে)
                        AuthField(
                          controller: emailController,
                          label: 'Email',
                          hint: 'you@example.com',
                          icon: Icons.alternate_email_rounded,
                          enabled: !busy,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter your email';
                            }
                            if (!value.contains('@') || !value.contains('.')) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _passwordField(colors),
                        if (!isLogin)
                          PasswordStrengthMeter(value: passwordController.text),
                        if (isLogin)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: busy ? null : _openForgotPassword,
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                minimumSize: const Size(0, 40),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Forgot password?',
                                style: TextStyle(
                                    fontSize: 12.5, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        const SizedBox(height: 18),
                        AuthErrorBanner(message: _error),
                        AuthPrimaryButton(
                          label: isLogin ? 'Sign in' : 'Create account',
                          busy: busy,
                          busyLabel: 'Please wait…',
                          onPressed: submit,
                        ),
                        _switchLink(colors),
                        const SizedBox(height: 6),
                        Center(
                          child: Text(
                            'Rately Farms · Poultry farm management',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 0.1,
                                color: colors.hint),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeTabs(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        children: [
          _tab(colors, 'Sign in', isLogin, () {
            if (busy) return;
            setState(() {
              isLogin = true;
              _error = null;
            });
          }),
          _tab(colors, 'Register', !isLogin, () {
            if (busy) return;
            setState(() {
              isLogin = false;
              _error = null;
            });
          }),
        ],
      ),
    );
  }

  Widget _tab(
      AppColors colors, String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: selected ? colors.card : AppColors.transparent,
              borderRadius: BorderRadius.circular(11),
              boxShadow: selected
                  ? [
                      BoxShadow(
                          color: colors.shadow,
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ]
                  : null,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? colors.brand : colors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _passwordField(AppColors colors) {
    return AuthField(
      controller: passwordController,
      label: 'Password',
      hint: isLogin ? 'Your password' : 'At least 8 characters',
      icon: Icons.lock_outline_rounded,
      enabled: !busy,
      obscureText: obscurePassword,
      keyboardType: TextInputType.visiblePassword,
      autofillHints: [
        isLogin ? AutofillHints.password : AutofillHints.newPassword
      ],
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => busy ? null : submit(),
      suffixIcon: IconButton(
        tooltip: obscurePassword ? 'Show password' : 'Hide password',
        icon: Icon(
          obscurePassword
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          size: 20,
          color: colors.muted,
        ),
        onPressed: () => setState(() => obscurePassword = !obscurePassword),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Enter your password';
        if (!isLogin && value.length < 8) {
          return 'Password must be at least 8 characters';
        }
        return null;
      },
    );
  }

  Widget _switchLink(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            isLogin ? 'New to Rately Farms?' : 'Already have an account?',
            style: TextStyle(fontSize: 13, color: colors.muted),
          ),
          TextButton(
            onPressed: busy
                ? null
                : () => setState(() {
                      isLogin = !isLogin;
                      _error = null;
                    }),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              isLogin ? 'Create one' : 'Sign in',
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Forgot password dialog
class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({required this.initialEmail});
  final String initialEmail;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController emailController =
      TextEditingController(text: widget.initialEmail);
  bool busy = false;
  bool sent = false;
  String? error;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await SupabaseConfig.client.auth.resetPasswordForEmail(
        emailController.text.trim(),
        redirectTo: passwordRecoveryRedirectTo(),
      );
      if (!mounted) return;
      setState(() => sent = true);
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (e) {
      if (mounted) setState(() => error = 'Could not send reset email: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AlertDialog(
      backgroundColor: context.colors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
      contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 4),
      actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      title: Row(
        children: [
          Icon(sent ? Icons.mark_email_read_outlined : Icons.lock_reset_rounded,
              size: 22, color: colors.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              sent ? 'Check your inbox' : 'Reset your password',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: colors.ink),
            ),
          ),
        ],
      ),
      content: SizedBox(width: 340, child: sent ? _sentBody() : _formBody()),
      actions: [
        if (sent)
          FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'))
        else ...[
          TextButton(
              onPressed: busy ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: busy ? null : _send,
            child: busy
                ? SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: colors.onBrand))
                : const Text('Send link'),
          ),
        ],
      ],
    );
  }

  Widget _formBody() {
    final colors = context.colors;
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enter the email on your account and we will send you a link to set a new password.',
            style: TextStyle(fontSize: 12.5, height: 1.45, color: colors.muted),
          ),
          const SizedBox(height: 16),
          AuthField(
            controller: emailController,
            label: 'Email',
            hint: 'you@example.com',
            icon: Icons.alternate_email_rounded,
            enabled: !busy,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => busy ? null : _send(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Enter your email';
              }
              if (!value.contains('@') || !value.contains('.')) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            AuthErrorBanner(message: error),
          ],
        ],
      ),
    );
  }

  Widget _sentBody() {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('We sent a password reset link to',
            style:
                TextStyle(fontSize: 12.5, height: 1.45, color: colors.muted)),
        const SizedBox(height: 4),
        Text(emailController.text.trim(),
            style: TextStyle(
                fontSize: 13.5, fontWeight: FontWeight.w700, color: colors.ink)),
        const SizedBox(height: 12),
        Text(
          'Open the link on this device to set a new password. The link expires after a short time — check your spam folder if it does not arrive.',
          style: TextStyle(fontSize: 12.5, height: 1.45, color: colors.muted),
        ),
      ],
    );
  }
}
