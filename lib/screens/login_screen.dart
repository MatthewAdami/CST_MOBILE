// lib/screens/student_login_page.dart
//
// Mobile port of the React web login — CST gold/navy palette, Playfair-style
// heading, Source-Sans-like body, three-view flow: login → forgot → check-email.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'dashboard_screen.dart';

// ── Colour palette (mirrors React C object) ──────────────────────────────────
class _C {
  static const navy        = Color(0xFF1B2B4B);
  static const navyDark    = Color(0xFF101D33);
  static const gold        = Color(0xFFB8963E);
  static const goldLight   = Color(0xFFD4AE5A);
  static const goldPale    = Color(0xFFF5EDD8);
  static const white       = Color(0xFFFFFFFF);
  static const offWhite    = Color(0xFFF8F7F4);
  static const border      = Color(0x1F1B2B4B); // rgba(27,43,75,0.12)
  static const textMuted   = Color(0xFF6B6966);
  static const dark1       = Color(0xFF1A1A1A);
  static const dark2       = Color(0xFF262523);
  static const lightGray   = Color(0xFFEEECE8);
  static const darkGray    = Color(0xFF4A4844);
  static const red         = Color(0xFFDC3545);
  static const redBg       = Color(0xFFFEE2E2);
  static const redBorder   = Color(0xFFFECACA);
  static const redText     = Color(0xFF991B1B);
  static const greenBg     = Color(0xFFD1FAE5);
  static const greenBorder = Color(0xFF6EE7B7);
  static const greenText   = Color(0xFF065F46);
}

const _kToken         = 'token';
const _kUser          = 'user';
const _kRememberMe    = 'remember_me';
const _kSavedEmail    = 'saved_email';
const _kSavedPassword = 'saved_password';

// ── Entry point ───────────────────────────────────────────────────────────────
class StudentLoginPage extends StatefulWidget {
  const StudentLoginPage({super.key});
  @override
  State<StudentLoginPage> createState() => _StudentLoginPageState();
}

typedef _View = String;
const _vLogin      = 'login';
const _vForgot     = 'forgot';
const _vCheckEmail = 'check-email';

class _StudentLoginPageState extends State<StudentLoginPage> {
  _View  _view  = _vLogin;
  String _email = '';

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _C.offWhite,
    body: SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            _TopBanner(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: _Card(
                child: switch (_view) {
                  _vLogin => _LoginView(
                      onForgotPassword: () => setState(() => _view = _vForgot),
                    ),
                  _vForgot => _ForgotView(
                      onBack: () => setState(() => _view = _vLogin),
                      onEmailSent: (e) => setState(() {
                        _email = e;
                        _view  = _vCheckEmail;
                      }),
                    ),
                  _ => _CheckEmailView(
                      email: _email,
                      onBack: () => setState(() => _view = _vLogin),
                    ),
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Top banner (collapsed left-panel for mobile) ──────────────────────────────
class _TopBanner extends StatelessWidget {
  static const _items = [
    (Icons.trending_up,    'Track your training progress'),
    (Icons.calendar_today, 'View class schedules and updates'),
    (Icons.description,    'Access student records and documents'),
  ];

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: _C.dark1,
    padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
    child: Column(
      children: [
        // Gold accent bar at the very top
        Align(
          alignment: Alignment.topCenter,
          child: Container(
            height: 3,
            width: 64,
            decoration: BoxDecoration(
              color: _C.gold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Logo placeholder circle (replace with Image.asset if you have the PNG)
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: _C.gold.withOpacity(.15),
            shape: BoxShape.circle,
            border: Border.all(color: _C.gold.withOpacity(.35), width: 1.5),
          ),
          child: const Icon(Icons.school, color: _C.gold, size: 32),
        ),
        const SizedBox(height: 14),

        _SectionLabel('Student Portal', dark: true),
        const SizedBox(height: 6),

        Text(
          'California School\nof Trucking',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Georgia', // closest serif available; swap to Playfair Display if added
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _C.white,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Access your student portal to manage your\ntraining journey and stay updated.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: _C.white.withOpacity(.6),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 20),

        // Feature rows
        ..._items.map((f) => _FeatureRow(icon: f.$1, label: f.$2)),

        const SizedBox(height: 12),
        Text(
          'Student access is available after enrollment confirmation.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: _C.white.withOpacity(.3), height: 1.5),
        ),
      ],
    ),
  );
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _FeatureRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color:  _C.gold.withOpacity(.10),
      border: Border.all(color: _C.gold.withOpacity(.20)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: _C.gold.withOpacity(.18),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: _C.gold),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(label,
          style: TextStyle(fontSize: 13, color: _C.white.withOpacity(.74))),
      ),
    ]),
  );
}

// ── Card wrapper ──────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: _C.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _C.border, width: 1),
      boxShadow: [
        BoxShadow(
          color: _C.navy.withOpacity(.07),
          blurRadius: 32,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gold top accent bar
          Container(height: 4, color: _C.gold),
          Padding(
            padding: const EdgeInsets.all(24),
            child: child,
          ),
        ],
      ),
    ),
  );
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  final bool   dark;
  const _SectionLabel(this.text, {this.dark = false});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 28, height: 2, color: _C.gold),
      const SizedBox(width: 8),
      Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: _C.gold,
        ),
      ),
    ],
  );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: _C.navy,
      letterSpacing: .6,
    ),
  );
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String         hint;
  final IconData       prefixIcon;
  final bool           obscure;
  final Widget?        suffix;
  final TextInputType  keyboardType;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.obscure      = false,
    this.suffix,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller:   controller,
    obscureText:  obscure,
    keyboardType: keyboardType,
    style: const TextStyle(fontSize: 15, color: _C.darkGray),
    decoration: InputDecoration(
      hintText:        hint,
      hintStyle:       const TextStyle(color: Color(0xFF9CA3AF)),
      prefixIcon:      Icon(prefixIcon, size: 16, color: const Color(0xFF9CA3AF)),
      suffixIcon:      suffix != null
          ? Padding(padding: const EdgeInsets.only(right: 10), child: suffix)
          : null,
      suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      filled:          true,
      fillColor:       _C.white,
      contentPadding:  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:   const BorderSide(color: _C.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:   const BorderSide(color: _C.gold, width: 1.5),
      ),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color:  _C.redBg,
      border: Border.all(color: _C.redBorder),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, size: 16, color: _C.red),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
            style: const TextStyle(fontSize: 13, color: _C.redText, height: 1.5)),
        ),
      ],
    ),
  );
}

class _SubmitButton extends StatelessWidget {
  final bool          loading;
  final String        label;
  final IconData      icon;
  final VoidCallback? onPressed;
  const _SubmitButton({
    required this.loading,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: loading ? const Color(0xFF9CA3AF) : _C.dark1,
        foregroundColor: _C.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      child: loading
          ? const Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: _C.white)),
              SizedBox(width: 8),
              Text('Processing...'),
            ])
          : Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16),
              const SizedBox(width: 8),
              Text(label),
            ]),
    ),
  );
}

// ── LOGIN VIEW ────────────────────────────────────────────────────────────────
class _LoginView extends StatefulWidget {
  final VoidCallback onForgotPassword;
  const _LoginView({required this.onForgotPassword});
  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool   _showPw     = false;
  bool   _loading    = false;
  bool   _rememberMe = false;
  String _error      = '';

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kRememberMe) ?? false) {
      final savedEmail = prefs.getString(_kSavedEmail) ?? '';
      final savedPw    = prefs.getString(_kSavedPassword) ?? '';
      setState(() {
        _rememberMe = true;
        _emailCtrl.text    = savedEmail;
        _passwordCtrl.text = savedPw;
      });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailCtrl.text.trim();
    final pw    = _passwordCtrl.text;

    if (email.isEmpty || pw.isEmpty) {
      setState(() => _error = 'Please enter your email and password.');
      return;
    }

    setState(() { _error = ''; _loading = true; });

    try {
      final res = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': pw}),
          )
          .timeout(ApiConfig.timeout);

      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode != 200) {
        setState(() => _error = data['message'] ?? 'Login failed. Please try again.');
        return;
      }

      final user = data['user'] as Map<String, dynamic>;
      if (user['role'] != 'student') {
        setState(() => _error =
          'You do not have student access. Please use the correct login portal.');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kToken, data['token'] as String);
      await prefs.setString(_kUser,  jsonEncode(user));

      await prefs.setBool(_kRememberMe, _rememberMe);
      if (_rememberMe) {
        await prefs.setString(_kSavedEmail,    _emailCtrl.text.trim());
        await prefs.setString(_kSavedPassword, _passwordCtrl.text);
      } else {
        await prefs.remove(_kSavedEmail);
        await prefs.remove(_kSavedPassword);
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const StudentDashboard(forceOnboarding: true),
          ),
        );
      }
    } on Exception catch (e) {
      setState(() => _error = 'Unable to connect to the server. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionLabel('Student Login'),
      const SizedBox(height: 8),
      const Text('Sign In',
        style: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: _C.navy,
        )),
      const SizedBox(height: 6),
      Text('Enter your student credentials to access your portal.',
        style: TextStyle(fontSize: 14, color: _C.textMuted, height: 1.7)),
      const SizedBox(height: 20),

      if (_error.isNotEmpty) ...[
        _ErrorBanner(_error),
        const SizedBox(height: 16),
      ],

      _FieldLabel('Email Address'),
      const SizedBox(height: 7),
      _InputField(
        controller:   _emailCtrl,
        hint:         'student@email.com',
        prefixIcon:   Icons.mail_outline,
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 16),

      _FieldLabel('Password'),
      const SizedBox(height: 7),
      _InputField(
        controller:  _passwordCtrl,
        hint:        '••••••••',
        prefixIcon:  Icons.lock_outline,
        obscure:     !_showPw,
        suffix: GestureDetector(
          onTap: () => setState(() => _showPw = !_showPw),
          child: Icon(
            _showPw ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 16, color: const Color(0xFF9CA3AF),
          ),
        ),
      ),

      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: widget.onForgotPassword,
          child: const Text(
            'Forgot your password?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _C.gold,
            ),
          ),
        ),
      ),

      const SizedBox(height: 16),
      GestureDetector(
        onTap: () => setState(() => _rememberMe = !_rememberMe),
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20, height: 20,
              decoration: BoxDecoration(
                color:        _rememberMe ? _C.gold : _C.white,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: _rememberMe ? _C.gold : const Color(0xFF9CA3AF),
                  width: 1.5,
                ),
              ),
              child: _rememberMe
                  ? const Icon(Icons.check_rounded, size: 13, color: _C.white)
                  : null,
            ),
            const SizedBox(width: 10),
            const Text(
              'Remember me',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _C.dark1,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      _SubmitButton(
        loading:   _loading,
        label:     'Sign In to Student Portal',
        icon:      Icons.school,
        onPressed: _loading ? null : _handleLogin,
      ),
      const SizedBox(height: 22),
      _InfoNote(),
    ],
  );
}

class _InfoNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color:  _C.goldPale,
      border: Border.all(color: _C.gold.withOpacity(.25)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: RichText(
      text: const TextSpan(
        style: TextStyle(fontSize: 12, color: _C.textMuted, height: 1.6),
        children: [
          TextSpan(
            text: 'Your login credentials are provided after your enrollment is confirmed. '
                  'Questions? Contact '),
          TextSpan(
            text: 'admissions@caschooloftrucking.com',
            style: TextStyle(color: _C.navy, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

// ── FORGOT PASSWORD VIEW ──────────────────────────────────────────────────────
class _ForgotView extends StatefulWidget {
  final VoidCallback          onBack;
  final void Function(String) onEmailSent;
  const _ForgotView({required this.onBack, required this.onEmailSent});
  @override
  State<_ForgotView> createState() => _ForgotViewState();
}

class _ForgotViewState extends State<_ForgotView> {
  final _emailCtrl = TextEditingController();
  bool   _loading  = false;
  String _error    = '';

  @override
  void dispose() { _emailCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final re    = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (email.isEmpty || !re.hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    setState(() { _error = ''; _loading = true; });
    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(ApiConfig.timeout);
      widget.onEmailSent(email);
    } on Exception {
      setState(() => _error = 'Unable to connect to the server. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Back button
      GestureDetector(
        onTap: widget.onBack,
        child: Row(mainAxisSize: MainAxisSize.min, children: const [
          Icon(Icons.arrow_back, size: 16, color: _C.textMuted),
          SizedBox(width: 6),
          Text('Back to Sign In',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _C.textMuted,
            )),
        ]),
      ),
      const SizedBox(height: 20),

      // Key icon
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color:  _C.goldPale,
          border: Border.all(color: _C.gold.withOpacity(.25)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.vpn_key_outlined, color: _C.gold, size: 24),
      ),
      const SizedBox(height: 16),

      _SectionLabel('Student Password Reset'),
      const SizedBox(height: 8),
      const Text('Forgot Password?',
        style: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: _C.navy,
        )),
      const SizedBox(height: 8),
      Text(
        "Enter the email address linked to your student account and we'll send you a password reset link.",
        style: TextStyle(fontSize: 14, color: _C.textMuted, height: 1.7),
      ),
      const SizedBox(height: 20),

      if (_error.isNotEmpty) ...[
        _ErrorBanner(_error),
        const SizedBox(height: 14),
      ],

      _FieldLabel('Email Address'),
      const SizedBox(height: 7),
      _InputField(
        controller:   _emailCtrl,
        hint:         'student@email.com',
        prefixIcon:   Icons.mail_outline,
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 22),

      _SubmitButton(
        loading:   _loading,
        label:     'Send Reset Link',
        icon:      Icons.send_outlined,
        onPressed: _loading ? null : _submit,
      ),
    ],
  );
}

// ── CHECK EMAIL VIEW ──────────────────────────────────────────────────────────
class _CheckEmailView extends StatelessWidget {
  final String         email;
  final VoidCallback   onBack;
  const _CheckEmailView({required this.email, required this.onBack});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Green circle check
      Container(
        width: 58, height: 58,
        decoration: BoxDecoration(
          color:  _C.greenBg,
          shape:  BoxShape.circle,
          border: Border.all(color: _C.greenBorder, width: 1.5),
        ),
        child: const Icon(Icons.check_circle_outline_rounded,
          color: _C.greenText, size: 28),
      ),
      const SizedBox(height: 16),

      _SectionLabel('Student Password Reset'),
      const SizedBox(height: 8),
      const Text('Check Your Email',
        style: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: _C.navy,
        )),
      const SizedBox(height: 8),
      Text('We sent a password reset link to:',
        style: TextStyle(fontSize: 14, color: _C.textMuted, height: 1.7)),
      const SizedBox(height: 10),

      // Email chip
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color:  _C.goldPale,
          border: Border.all(color: _C.gold.withOpacity(.25)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          const Icon(Icons.mail_outline, size: 15, color: _C.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(email,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _C.navy,
              )),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 13, color: _C.textMuted, height: 1.7),
          children: const [
            TextSpan(text: 'Click the link in the email to reset your password. The link expires in '),
            TextSpan(text: '1 hour', style: TextStyle(fontWeight: FontWeight.bold, color: _C.navy)),
            TextSpan(text: '.'),
          ],
        ),
      ),
      const SizedBox(height: 18),

      // Didn't receive box
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:  _C.offWhite,
          border: Border.all(color: _C.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("DIDN'T RECEIVE IT?",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _C.navy,
                letterSpacing: .6,
              )),
            const SizedBox(height: 6),
            RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 13, color: _C.textMuted, height: 1.6),
                children: const [
                  TextSpan(text: 'Check your spam folder. If you still don\'t see it, contact '),
                  TextSpan(
                    text: 'admissions@caschooloftrucking.com',
                    style: TextStyle(
                      color: _C.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),

      // Back button
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, size: 15),
          label: const Text('Back to Sign In'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _C.navy,
            side: const BorderSide(color: _C.border, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ],
  );
}