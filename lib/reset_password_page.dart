import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_colors.dart';
import 'auth_widgets.dart';
import 'supabase_config.dart';

/// Set to `true` while the user is inside a PASSWORD_RECOVERY session.
///
/// [AuthGate] watches this notifier and shows [ResetPasswordPage] until the
/// user finishes setting a new password (or cancels).
final ValueNotifier<bool> passwordRecoveryActive = ValueNotifier<bool>(false);

/// Deep-link / redirect URL passed to Supabase `resetPasswordForEmail`.
///
/// Must match what you configure in the Supabase dashboard
/// (Authentication → URL Configuration → Redirect URLs) and in your
/// Android/iOS deep-link setup. Example scheme used in comments:
/// `ratelyfarms://reset-password`.
String passwordRecoveryRedirectTo() => 'ratelyfarms://reset-password';

/// Call this once from [main] (or early app bootstrap) so a recovery deep link
/// flips [passwordRecoveryActive] and routes the user to this page.
void listenForPasswordRecovery() {
  SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
    final event = data.event;
    if (event == AuthChangeEvent.passwordRecovery) {
      passwordRecoveryActive.value = true;
    }
  });
}

/// Full-screen form shown while the user is recovering their password.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final formKey = GlobalKey<FormState>();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  bool busy = false;
  bool obscurePassword = true;
  bool obscureConfirm = true;
  String? error;
  bool done = false;

  @override
  void dispose() {
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(password: passwordController.text),
      );
      if (!mounted) return;
      setState(() => done = true);
      // Leave recovery mode so AuthGate can show the normal app.
      passwordRecoveryActive.value = false;
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => error = 'Could not update password: $e');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _cancel() {
    passwordRecoveryActive.value = false;
    // Optional: sign out the temporary recovery session.
    SupabaseConfig.client.auth.signOut();
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
                  header: const AuthHeader(
                    title: 'Rately Farms',
                    subtitle: 'Set a new password',
                  ),
                  child: done ? _doneBody(colors) : _formBody(colors),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formBody(AppColors colors) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choose a strong password for your farm account. '
            'You will use this the next time you sign in.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: colors.muted,
            ),
          ),
          const SizedBox(height: 20),
          AuthField(
            controller: passwordController,
            label: 'New password',
            hint: 'At least 8 characters',
            icon: Icons.lock_outline_rounded,
            enabled: !busy,
            obscureText: obscurePassword,
            keyboardType: TextInputType.visiblePassword,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.next,
            suffixIcon: IconButton(
              tooltip: obscurePassword ? 'Show password' : 'Hide password',
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: colors.muted,
              ),
              onPressed: () =>
                  setState(() => obscurePassword = !obscurePassword),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Enter a new password';
              }
              if (value.length < 8) {
                return 'Password must be at least 8 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          AuthField(
            controller: confirmController,
            label: 'Confirm password',
            hint: 'Re-enter new password',
            icon: Icons.lock_outline_rounded,
            enabled: !busy,
            obscureText: obscureConfirm,
            keyboardType: TextInputType.visiblePassword,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => busy ? null : _submit(),
            suffixIcon: IconButton(
              tooltip: obscureConfirm ? 'Show password' : 'Hide password',
              icon: Icon(
                obscureConfirm
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: colors.muted,
              ),
              onPressed: () =>
                  setState(() => obscureConfirm = !obscureConfirm),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Confirm your password';
              }
              if (value != passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
          AuthErrorBanner(message: error),
          AuthPrimaryButton(
            label: 'Update password',
            busy: busy,
            busyLabel: 'Updating…',
            onPressed: _submit,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: busy ? null : _cancel,
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _doneBody(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          size: 48,
          color: colors.brand,
        ),
        const SizedBox(height: 14),
        Text(
          'Password updated',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: colors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'You can continue using the app with your new password.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: colors.muted,
          ),
        ),
        const SizedBox(height: 22),
        AuthPrimaryButton(
          label: 'Continue',
          onPressed: () {
            passwordRecoveryActive.value = false;
          },
        ),
      ],
    );
  }
}
