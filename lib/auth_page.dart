import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

import 'app_colors.dart';

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

  /// Inline error text shown inside the card (the snackbar is still fired,
  /// this is the calmer, non-transient alternative).
  String? _error;

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
    final colors = context.colors;
    setState(() => _error = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: colors.error),
    );
  }

  String? requiredField(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label দিন';
    return null;
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.soft,
      body: Stack(
        children: [
          Positioned(top: -130, right: -90, child: _blob(colors.brand.withAlpha(20), 300)),
          Positioned(bottom: -150, left: -110, child: _blob(colors.accent.withAlpha(18), 340)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: _buildCard(colors),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }

  Widget _buildCard(AppColors colors) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.line),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(colors),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _modeTabs(colors),
                  const SizedBox(height: 22),
                  if (!isLogin) ...[
                    _field(
                      colors: colors,
                      controller: nameController,
                      label: 'Full name',
                      hint: 'যেমন: আব্দুর রহিম',
                      icon: Icons.person_outline_rounded,
                      keyboardType: TextInputType.name,
                      autofillHints: const [AutofillHints.name],
                      textInputAction: TextInputAction.next,
                      validator: (value) => requiredField(value, 'Full name'),
                    ),
                    const SizedBox(height: 12),
                    _field(
                      colors: colors,
                      controller: mobileController,
                      label: 'Mobile number',
                      hint: '01XXXXXXXXX',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      textInputAction: TextInputAction.next,
                      validator: (value) => requiredField(value, 'Mobile number'),
                    ),
                    const SizedBox(height: 12),
                    _field(
                      colors: colors,
                      controller: farmController,
                      label: 'Farm name',
                      hint: 'যেমন: রহিম পোল্ট্রি ফার্ম',
                      icon: Icons.home_work_outlined,
                      textInputAction: TextInputAction.next,
                      validator: (value) => requiredField(value, 'Farm name'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _field(
                    colors: colors,
                    controller: emailController,
                    label: 'Email',
                    hint: 'you@example.com',
                    icon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Email দিন';
                      if (!value.contains('@')) return 'সঠিক email দিন';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _passwordField(colors),
                  if (!isLogin) _strengthMeter(colors),
                  const SizedBox(height: 18),
                  _errorBanner(colors),
                  _submitButton(colors),
                  _switchLink(colors),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Rately Farms · পোল্ট্রি ফার্ম ম্যানেজমেন্ট',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.1,
                        color: colors.hint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(AppColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.brand, colors.accent],
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: colors.onBrand.withAlpha(36),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.onBrand.withAlpha(64)),
            ),
            child: Icon(Icons.agriculture_rounded, color: colors.onBrand, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Rately Farms',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: colors.onBrand,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isLogin
                      ? 'আপনার farm-এ ফিরে আসুন'
                      : 'নতুন farm account তৈরি করুন',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                    color: colors.onBrand.withAlpha(215),
                  ),
                ),
              ],
            ),
          ),
        ],
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
          _tab(colors, 'লগইন', isLogin, () {
            if (busy) return;
            setState(() {
              isLogin = true;
              _error = null;
            });
          }),
          _tab(colors, 'রেজিস্টার', !isLogin, () {
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

  Widget _tab(AppColors colors, String label, bool selected, VoidCallback onTap) {
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
                        offset: const Offset(0, 2),
                      ),
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

  Widget _field({
    required AppColors colors,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    Iterable<String>? autofillHints,
    TextInputAction? textInputAction,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    void Function(String)? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !busy,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      style: TextStyle(fontSize: 15, color: colors.ink),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: colors.surfaceAlt,
        prefixIcon: Icon(icon, size: 20, color: colors.muted),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _passwordField(AppColors colors) {
    return _field(
      colors: colors,
      controller: passwordController,
      label: 'Password',
      hint: 'কমপক্ষে ৬ অক্ষর',
      icon: Icons.lock_outline_rounded,
      keyboardType: TextInputType.visiblePassword,
      autofillHints: [
        isLogin ? AutofillHints.password : AutofillHints.newPassword,
      ],
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => busy ? null : submit(),
      suffixIcon: IconButton(
        tooltip: obscurePassword ? 'Password দেখুন' : 'Password লুকান',
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
        if (value == null || value.length < 6) {
          return 'কমপক্ষে ৬ অক্ষরের password দিন';
        }
        return null;
      },
    );
  }

  Widget _strengthMeter(AppColors colors) {
    final value = passwordController.text;
    final checks = <bool>[
      value.length >= 8,
      RegExp(r'[A-Z]').hasMatch(value),
      RegExp(r'[0-9]').hasMatch(value),
      RegExp(r'[^A-Za-z0-9]').hasMatch(value),
    ];
    final score = value.isEmpty ? 0 : checks.where((e) => e).length;
    final Color color = score <= 1
        ? colors.error
        : score == 2
            ? colors.warning
            : score == 3
                ? colors.info
                : colors.brand;

    const labels = <String>['খুব দুর্বল', 'দুর্বল', 'মাঝারি', 'ভালো', 'শক্তিশালী'];
    final label = value.isEmpty ? 'শক্তি' : labels[score];

    return Padding(
      padding: const EdgeInsets.only(top: 9, left: 2, right: 2),
      child: Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 5,
                decoration: BoxDecoration(
                  color: i < score ? color : colors.line,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            if (i != 3) const SizedBox(width: 6),
          ],
          const SizedBox(width: 10),
          SizedBox(
            width: 62,
            child: Text(
              label,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: value.isEmpty ? colors.muted : color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBanner(AppColors colors) {
    final message = _error;
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: colors.errorSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.errorBorder.withAlpha(110)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, size: 18, color: colors.errorText),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: colors.errorText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _submitButton(AppColors colors) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: busy ? null : submit,
        child: busy
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.onBrand,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'অপেক্ষা করুন…',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLogin ? 'লগইন করুন' : 'রেজিস্টার করুন',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
      ),
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
            isLogin ? 'নতুন ব্যবহারকারী?' : 'আগেই account আছে?',
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
              isLogin ? 'রেজিস্টার করুন' : 'লগইন করুন',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
