// lib/screens/reset_password_screen.dart
//
// Drop-in Flutter equivalent of ResetPasswordPage.jsx
// Usage: deep-link opens this screen with ?token=...&email=...
// In the app, launch it via Navigator after parsing the link.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'login_screen.dart'; // adjust import to your login screen path

// ── Palette (matches web + login screen exactly) ─────────────────────────────
class _C {
  static const navy        = Color(0xFF0B1F3A);
  static const purple      = Color(0xFF7C3AED);
  static const white       = Color(0xFFFFFFFF);
  static const gray50      = Color(0xFFF8F9FA);
  static const gray100     = Color(0xFFF1F3F5);
  static const gray200     = Color(0xFFE9ECEF);
  static const gray400     = Color(0xFFADB5BD);
  static const gray600     = Color(0xFF6C757D);
  static const gray800     = Color(0xFF343A40);
  static const red         = Color(0xFFDC3545);
  static const redBg       = Color(0xFFF8D7DA);
  static const redBorder   = Color(0xFFF5C6CB);
  static const redText     = Color(0xFF721C24);
  static const green       = Color(0xFF16A34A);
  static const greenBg     = Color(0xFFD1FAE5);
  static const greenBorder = Color(0xFF6EE7B7);
  static const amber       = Color(0xFFF59E0B);
  static const blue        = Color(0xFF2563EB);
}

// ── Screen ────────────────────────────────────────────────────────────────────
class ResetPasswordScreen extends StatefulWidget {
  /// Pass token + email parsed from the deep-link / email URL.
  final String token;
  final String email;

  const ResetPasswordScreen({
    super.key,
    required this.token,
    required this.email,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _pwCtrl  = TextEditingController();
  final _cfCtrl  = TextEditingController();

  bool   _showPw  = false;
  bool   _showCf  = false;
  bool   _loading = false;
  bool   _success = false;
  String _error   = '';

  // Derived
  bool get _invalid => widget.token.isEmpty || widget.email.isEmpty;

  // ── Password strength ──────────────────────────────────────────────────────
  int _strength(String pw) {
    if (pw.isEmpty) return 0;
    int s = 0;
    if (pw.length >= 8)                    s++;
    if (RegExp(r'[A-Z]').hasMatch(pw))     s++;
    if (RegExp(r'[0-9]').hasMatch(pw))     s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(pw)) s++;
    return s;
  }

  String _strengthLabel(int s) =>
      const ['', 'Weak', 'Fair', 'Good', 'Strong'][s.clamp(0, 4)];

  Color _strengthColor(int s) => const [
    _C.gray200, _C.red, _C.amber, _C.blue, _C.green,
  ][s.clamp(0, 4)];

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _handleSubmit() async {
    setState(() => _error = '');

    if (_pwCtrl.text.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    if (_pwCtrl.text != _cfCtrl.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/auth/reset-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'token':    widget.token,
              'email':    widget.email,
              'password': _pwCtrl.text,
            }),
          )
          .timeout(ApiConfig.timeout);

      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200) {
        setState(() => _success = true);
      } else {
        setState(() =>
          _error = data['message'] ?? 'Reset failed. Please request a new link.');
      }
    } catch (_) {
      setState(() =>
        _error = 'Unable to connect to server. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _pwCtrl.dispose();
    _cfCtrl.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final width    = MediaQuery.of(context).size.width;
    final isMobile = width < 700;

    return Scaffold(
      backgroundColor: _C.gray50,
      body: isMobile ? _mobileLayout() : _desktopLayout(),
    );
  }

  Widget _desktopLayout() => Row(
    children: [
      SizedBox(width: 380, child: _LeftPanel()),
      Expanded(child: _rightPanel()),
    ],
  );

  Widget _mobileLayout() => SingleChildScrollView(
    child: Column(
      children: [
        _LeftPanel(mobile: true),
        _rightPanel(mobile: true),
      ],
    ),
  );

  // ── Right panel ────────────────────────────────────────────────────────────
  Widget _rightPanel({bool mobile = false}) => Container(
    color: _C.gray50,
    child: Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: mobile ? 24 : 48,
          vertical:   mobile ? 32 : 48,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: _invalid
              ? _invalidState()
              : _success
                  ? _successState()
                  : _formState(),
        ),
      ),
    ),
  );

  // ── Invalid token state ────────────────────────────────────────────────────
  Widget _invalidState() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          color: _C.redBg,
          shape: BoxShape.circle,
          border: Border.all(color: _C.redBorder, width: 2)),
        child: const Icon(Icons.error_outline, color: _C.red, size: 28)),
      const SizedBox(height: 20),
      const Text('Invalid Reset Link',
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700,
          color: _C.navy)),
      const SizedBox(height: 12),
      const Text(
        'This password reset link is missing required information.\nPlease request a new one.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: _C.gray600, height: 1.7)),
      const SizedBox(height: 28),
      _PrimaryButton(
        label: 'Back to Login',
        icon:  Icons.arrow_back_rounded,
        onPressed: _goToLogin,
      ),
    ],
  );

  // ── Success state ─────────────────────────────────────────────────────────
  Widget _successState() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: _C.greenBg,
          shape: BoxShape.circle,
          border: Border.all(color: _C.greenBorder, width: 2)),
        child: const Icon(Icons.check_circle_outline,
          color: Color(0xFF065F46), size: 34)),
      const SizedBox(height: 24),
      const Text('Password Reset!',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700,
          color: _C.navy)),
      const SizedBox(height: 12),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'Your password has been successfully updated.\nYou can now sign in with your new password.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: _C.gray600, height: 1.75)),
      ),
      const SizedBox(height: 28),
      _PrimaryButton(
        label: 'Sign In Now',
        icon:  Icons.school_rounded,
        onPressed: _goToLogin,
      ),
    ],
  );

  // ── Reset form ────────────────────────────────────────────────────────────
  Widget _formState() {
    final pw       = _pwCtrl.text;
    final cf       = _cfCtrl.text;
    final s        = _strength(pw);
    final matchOk  = cf.isNotEmpty && pw == cf && cf.length >= 8;
    final mismatch = cf.isNotEmpty && pw != cf;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back link
        GestureDetector(
          onTap: _goToLogin,
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.arrow_back_rounded, size: 15, color: _C.gray600),
            SizedBox(width: 6),
            Text('Back to Sign In',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: _C.gray600)),
          ]),
        ),
        const SizedBox(height: 28),

        // Icon
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: _C.purple.withOpacity(.12),
            border: Border.all(color: _C.purple.withOpacity(.25)),
            borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.vpn_key_rounded, color: _C.purple, size: 24)),
        const SizedBox(height: 20),

        // Heading
        const Text('Set New Password',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700,
            color: _C.navy)),
        const SizedBox(height: 8),
        RichText(text: TextSpan(
          style: const TextStyle(fontSize: 14, color: _C.gray600, height: 1.7),
          children: [
            const TextSpan(text: 'Resetting password for '),
            TextSpan(text: widget.email,
              style: const TextStyle(
                color: _C.navy, fontWeight: FontWeight.w700)),
          ],
        )),
        const SizedBox(height: 24),

        // Error banner
        if (_error.isNotEmpty) ...[
          _ErrorBanner(message: _error),
          const SizedBox(height: 16),
        ],

        // New password
        _FieldLabel('New Password'),
        const SizedBox(height: 7),
        _InputField(
          controller: _pwCtrl,
          hint:       'Min. 8 characters',
          prefixIcon: Icons.lock_outline,
          obscure:    !_showPw,
          onChanged:  (_) => setState(() {}),
          suffixWidget: GestureDetector(
            onTap: () => setState(() => _showPw = !_showPw),
            child: Icon(
              _showPw
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
              size: 18, color: _C.gray400)),
        ),

        // Strength meter
        if (pw.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(children: List.generate(4, (i) => Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: i < s ? _strengthColor(s) : _C.gray200,
                borderRadius: BorderRadius.circular(2))),
          ))),
          const SizedBox(height: 5),
          Text(_strengthLabel(s),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: _strengthColor(s))),
        ],
        const SizedBox(height: 18),

        // Confirm password
        _FieldLabel('Confirm New Password'),
        const SizedBox(height: 7),
        _InputField(
          controller:  _cfCtrl,
          hint:        'Repeat your new password',
          prefixIcon:  Icons.lock_outline,
          obscure:     !_showCf,
          borderColor: mismatch ? _C.red : null,
          onChanged:   (_) => setState(() {}),
          suffixWidget: GestureDetector(
            onTap: () => setState(() => _showCf = !_showCf),
            child: Icon(
              _showCf
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
              size: 18, color: _C.gray400)),
        ),

        // Match feedback
        if (mismatch) ...[
          const SizedBox(height: 5),
          const Text('Passwords do not match',
            style: TextStyle(fontSize: 12, color: _C.red)),
        ] else if (matchOk) ...[
          const SizedBox(height: 5),
          const Row(children: [
            Icon(Icons.check_circle_outline, size: 12, color: _C.green),
            SizedBox(width: 4),
            Text('Passwords match',
              style: TextStyle(fontSize: 12, color: _C.green)),
          ]),
        ],

        const SizedBox(height: 28),

        // Submit
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _loading ? _C.gray400 : _C.purple,
              foregroundColor: _C.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
              elevation: 0,
              textStyle: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700),
            ),
            child: _loading
                ? const Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: _C.white)),
                    SizedBox(width: 8),
                    Text('Updating Password...'),
                  ])
                : const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.vpn_key_rounded, size: 16),
                    SizedBox(width: 8),
                    Text('Reset My Password'),
                  ]),
          ),
        ),
      ],
    );
  }

  void _goToLogin() => Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const StudentLoginPage()),
    (route) => false,
  );
}

// ── Left panel ────────────────────────────────────────────────────────────────
class _LeftPanel extends StatelessWidget {
  final bool mobile;
  const _LeftPanel({this.mobile = false});

  static const _tips = [
    'At least 8 characters long',
    'Mix of uppercase & lowercase',
    'Include numbers or symbols',
    'Don\'t reuse old passwords',
  ];

  @override
  Widget build(BuildContext context) => Stack(children: [
    Container(
      width: double.infinity,
      color: _C.navy,
      padding: EdgeInsets.symmetric(
        horizontal: 40, vertical: mobile ? 48 : 0),
      child: mobile ? _content() : Center(child: _content()),
    ),
    Positioned(top: 0, left: 0, right: 0,
      child: Container(height: 4, color: _C.purple)),
    Positioned(top: -80, right: -80,
      child: _Circle(300, const Color(0x127C3AED))),
    Positioned(bottom: -60, left: -60,
      child: _Circle(220, const Color(0x087C3AED))),
  ]);

  Widget _content() => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 300),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: _C.purple,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(
              color: _C.purple.withOpacity(.31),
              blurRadius: 32, offset: const Offset(0, 8))],
          ),
          child: const Icon(Icons.school, color: _C.white, size: 36)),
        const SizedBox(height: 28),
        const Text('California School\nof Trucking',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700,
            color: _C.white, height: 1.3)),
        const SizedBox(height: 6),
        Text('Student Portal',
          style: TextStyle(fontSize: 13,
            color: _C.white.withOpacity(.4))),
        const SizedBox(height: 36),

        // Password tips
        Align(
          alignment: Alignment.centerLeft,
          child: Text('PASSWORD TIPS',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: _C.white.withOpacity(.3), letterSpacing: 1.4))),
        const SizedBox(height: 12),
        ..._tips.map((tip) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Container(width: 6, height: 6,
              decoration: BoxDecoration(
                color: _C.purple.withOpacity(.7),
                shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(child: Text(tip,
              style: TextStyle(fontSize: 13,
                color: _C.white.withOpacity(.5)))),
          ]),
        )),
      ],
    ),
  );
}

class _Circle extends StatelessWidget {
  final double size; final Color color;
  const _Circle(this.size, this.color);
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

// ── Shared form widgets ───────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
      color: _C.navy, letterSpacing: .8));
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String    hint;
  final IconData  prefixIcon;
  final bool      obscure;
  final Widget?   suffixWidget;
  final Color?    borderColor;
  final void Function(String)? onChanged;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.obscure      = false,
    this.suffixWidget,
    this.borderColor,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller:  controller,
    obscureText: obscure,
    onChanged:   onChanged,
    style: const TextStyle(fontSize: 15, color: _C.gray800),
    decoration: InputDecoration(
      hintText:   hint,
      hintStyle:  const TextStyle(color: _C.gray400),
      prefixIcon: Icon(prefixIcon, size: 18, color: _C.gray400),
      suffixIcon: suffixWidget != null
          ? Padding(padding: const EdgeInsets.only(right: 12),
              child: suffixWidget)
          : null,
      suffixIconConstraints:
        const BoxConstraints(minWidth: 0, minHeight: 0),
      filled:     true,
      fillColor:  _C.white,
      contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: borderColor ?? _C.gray200, width: 1.5)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: borderColor ?? _C.purple, width: 1.5)),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: _C.redBg,
      border: Border.all(color: _C.redBorder),
      borderRadius: BorderRadius.circular(8)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.error_outline, size: 16, color: _C.red),
      const SizedBox(width: 10),
      Expanded(child: Text(message,
        style: const TextStyle(fontSize: 14, color: _C.redText))),
    ]),
  );
}

class _PrimaryButton extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final VoidCallback onPressed;
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    onPressed: onPressed,
    icon:  Icon(icon, size: 15),
    label: Text(label),
    style: ElevatedButton.styleFrom(
      backgroundColor: _C.purple,
      foregroundColor: _C.white,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 0,
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
  );
}