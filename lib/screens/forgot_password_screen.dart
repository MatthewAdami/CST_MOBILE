// lib/screens/forgot_password_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

// ── Colour palette (mirrors login page) ─────────────────────────────────────
class _C {
  static const navy        = Color(0xFF0B1F3A);
  static const purple      = Color(0xFF7C3AED);
  static const purpleLight = Color(0xFF9F67FF);
  static const white       = Color(0xFFFFFFFF);
  static const gray50      = Color(0xFFF8F9FA);
  static const gray200     = Color(0xFFE9ECEF);
  static const gray400     = Color(0xFFADB5BD);
  static const gray600     = Color(0xFF6C757D);
  static const gray800     = Color(0xFF343A40);
  static const red         = Color(0xFFDC3545);
  static const redBg       = Color(0xFFF8D7DA);
  static const redBorder   = Color(0xFFF5C6CB);
  static const redText     = Color(0xFF721C24);
  static const green       = Color(0xFF198754);
  static const greenBg     = Color(0xFFD1E7DD);
  static const greenBorder = Color(0xFFBACFCA);
  static const greenText   = Color(0xFF0A3622);
}

// ── Screen states ────────────────────────────────────────────────────────────
enum _ForgotStep { enterEmail, emailSent }

// ── Main screen ──────────────────────────────────────────────────────────────
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();

  bool        _loading = false;
  String      _error   = '';
  _ForgotStep _step    = _ForgotStep.enterEmail;

  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // ── Step transition ───────────────────────────────────────────────────────
  void _goToStep(_ForgotStep step) {
    _animCtrl.reverse().then((_) {
      setState(() {
        _step  = step;
        _error = '';
      });
      _animCtrl.forward();
    });
  }

  // ── Send reset email ──────────────────────────────────────────────────────
  Future<void> _handleSendEmail() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email address.');
      return;
    }
    setState(() { _error = ''; _loading = true; });

    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(ApiConfig.timeout);

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        _goToStep(_ForgotStep.emailSent);
      } else {
        setState(() =>
          _error = data['message'] ?? 'Something went wrong. Please try again.');
      }
    } catch (e) {
      setState(() => _error = 'Network error. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
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
      SizedBox(width: 380, child: _LeftPanel(step: _step)),
      Expanded(child: _formPanel()),
    ],
  );

  Widget _mobileLayout() => SingleChildScrollView(
    child: Column(
      children: [
        _LeftPanel(step: _step, mobile: true),
        _formPanel(mobile: true),
      ],
    ),
  );

  Widget _formPanel({bool mobile = false}) => Container(
    color: _C.gray50,
    child: Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: mobile ? 24 : 48,
          vertical:   mobile ? 32 : 48,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Back button ──────────────────────────────────────────
                  GestureDetector(
                    onTap: () {
                      if (_step == _ForgotStep.enterEmail) {
                        Navigator.of(context).pop();
                      } else {
                        _goToStep(_ForgotStep.enterEmail);
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 13, color: _C.purple),
                        const SizedBox(width: 6),
                        Text(
                          _step == _ForgotStep.enterEmail
                            ? 'Back to Sign In'
                            : 'Back',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _C.purple),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Step label ───────────────────────────────────────────
                  Text(
                    _step == _ForgotStep.enterEmail
                      ? 'FORGOT PASSWORD'
                      : 'CHECK YOUR EMAIL',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _C.purple,
                      letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 6),

                  // ── Step title ───────────────────────────────────────────
                  Text(
                    _step == _ForgotStep.enterEmail
                      ? 'Reset Password'
                      : 'Email Sent!',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: _C.navy),
                  ),
                  const SizedBox(height: 8),

                  // ── Step subtitle ────────────────────────────────────────
                  Text(
                    _step == _ForgotStep.enterEmail
                      ? 'Enter your registered email and we\'ll send you a reset link.'
                      : 'We sent a reset link to ${_emailCtrl.text.trim()}. Click the link in the email to set your new password.',
                    style: const TextStyle(
                      fontSize: 14, color: _C.gray600, height: 1.5),
                  ),
                  const SizedBox(height: 28),

                  // ── Error banner ─────────────────────────────────────────
                  if (_error.isNotEmpty) ...[
                    _ErrorBanner(message: _error),
                    const SizedBox(height: 16),
                  ],

                  // ── Step content ─────────────────────────────────────────
                  _step == _ForgotStep.enterEmail
                    ? _buildEnterEmail()
                    : _buildEmailSent(),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  // ── Step 1: Enter email ───────────────────────────────────────────────────
  Widget _buildEnterEmail() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _FieldLabel('Email Address'),
      const SizedBox(height: 7),
      _InputField(
        controller:   _emailCtrl,
        hint:         'student@email.com',
        prefixIcon:   Icons.mail_outline,
        keyboardType: TextInputType.emailAddress,
        onSubmitted:  (_) => _handleSendEmail(),
      ),
      const SizedBox(height: 24),
      _PrimaryButton(
        label:     'Send Reset Link',
        icon:      Icons.send_outlined,
        loading:   _loading,
        onPressed: _loading ? null : _handleSendEmail,
      ),
    ],
  );

  // ── Step 2: Email sent ────────────────────────────────────────────────────
  Widget _buildEmailSent() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Confirmation box
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: _C.purple.withOpacity(0.06),
          border: Border.all(color: _C.purple.withOpacity(0.15)),
          borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: _C.purple.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.mark_email_read_outlined,
              size: 32, color: _C.purple)),
          const SizedBox(height: 14),
          const Text('Reset link sent!',
            style: TextStyle(fontSize: 15,
              fontWeight: FontWeight.w700, color: _C.navy)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Open the email and tap the link to\nreset your password.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13, color: _C.gray600, height: 1.6))),
        ]),
      ),
      const SizedBox(height: 16),

      // Tips box
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.gray50,
          border: Border.all(color: _C.gray200),
          borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Didn't receive it?",
              style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w700, color: _C.navy)),
            const SizedBox(height: 8),
            ...[
              'Check your spam or junk folder',
              'Make sure you entered the correct email',
              'The link expires after 1 hour',
            ].map((tip) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    width: 5, height: 5,
                    decoration: BoxDecoration(
                      color: _C.purple.withOpacity(0.5),
                      shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(tip,
                    style: const TextStyle(
                      fontSize: 13, color: _C.gray600))),
                ],
              ),
            )),
          ],
        ),
      ),
      const SizedBox(height: 24),

      // Back to sign in
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon:  const Icon(Icons.login_rounded, size: 16),
          label: const Text('Back to Sign In'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _C.navy,
            foregroundColor: _C.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
            elevation: 0,
            textStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      ),
      const SizedBox(height: 16),

      // Resend
      Center(
        child: GestureDetector(
          onTap: _loading ? null : () => _goToStep(_ForgotStep.enterEmail),
          child: Text(
            'Send to a different email',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _loading ? _C.gray400 : _C.purple),
          ),
        ),
      ),
    ],
  );
}

// ── Left panel ────────────────────────────────────────────────────────────────
class _LeftPanel extends StatelessWidget {
  final _ForgotStep step;
  final bool        mobile;
  const _LeftPanel({required this.step, this.mobile = false});

  @override
  Widget build(BuildContext context) => Stack(
    children: [
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
    ],
  );

  Widget _content() => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 300),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: _C.purple,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(
              color: _C.purple.withOpacity(.31),
              blurRadius: 32,
              offset: const Offset(0, 8))],
          ),
          child: const Icon(Icons.lock_reset_outlined,
            color: _C.white, size: 36)),
        const SizedBox(height: 28),
        const Text('Password Reset',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24,
            fontWeight: FontWeight.w700,
            color: _C.white, height: 1.3)),
        const SizedBox(height: 6),
        Text('Regain access to your account',
          style: TextStyle(fontSize: 13,
            color: _C.white.withOpacity(.4))),
        const SizedBox(height: 40),

        // Step indicators
        _StepRow(
          icon:     Icons.mail_outline,
          label:    'Enter your email address',
          number:   1,
          isActive: step == _ForgotStep.enterEmail,
          isDone:   step == _ForgotStep.emailSent,
        ),
        _StepRow(
          icon:     Icons.mark_email_read_outlined,
          label:    'Check your inbox for the link',
          number:   2,
          isActive: step == _ForgotStep.emailSent,
          isDone:   false,
        ),
        _StepRow(
          icon:     Icons.lock_reset_outlined,
          label:    'Set your new password',
          number:   3,
          isActive: false,
          isDone:   false,
        ),

        const SizedBox(height: 24),
        Text(
          'Having trouble? Contact admissions@cst.edu',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12,
            color: _C.white.withOpacity(.25), height: 1.6)),
      ],
    ),
  );
}

// ── Step row widget ───────────────────────────────────────────────────────────
class _StepRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final int      number;
  final bool     isActive;
  final bool     isDone;

  const _StepRow({
    required this.icon,
    required this.label,
    required this.number,
    required this.isActive,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = isDone
        ? _C.green.withOpacity(0.18)
        : isActive
            ? _C.purple.withOpacity(0.20)
            : _C.white.withOpacity(0.05);
    final Color border = isDone
        ? _C.green.withOpacity(0.35)
        : isActive
            ? _C.purple.withOpacity(0.40)
            : _C.white.withOpacity(0.08);
    final Color iconColor = isDone
        ? _C.green
        : isActive
            ? _C.purpleLight
            : _C.white.withOpacity(0.30);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8)),
          child: isDone
              ? const Icon(Icons.check_rounded, size: 16, color: _C.green)
              : Icon(icon, size: 16, color: iconColor)),
        const SizedBox(width: 12),
        Expanded(child: Text(label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive
                ? _C.white
                : isDone
                    ? _C.white.withOpacity(0.60)
                    : _C.white.withOpacity(0.30)))),
        if (isActive)
          Container(
            width: 6, height: 6,
            decoration: const BoxDecoration(
              color: _C.purpleLight, shape: BoxShape.circle)),
      ]),
    );
  }
}

class _Circle extends StatelessWidget {
  final double size; final Color color;
  const _Circle(this.size, this.color);
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

// ── Reusable widgets ──────────────────────────────────────────────────────────
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
  final String                hint;
  final IconData              prefixIcon;
  final bool                  obscure;
  final Widget?               suffixWidget;
  final TextInputType         keyboardType;
  final ValueChanged<String>? onSubmitted;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.obscure      = false,
    this.suffixWidget,
    this.keyboardType = TextInputType.text,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller:   controller,
    obscureText:  obscure,
    keyboardType: keyboardType,
    onSubmitted:  onSubmitted,
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
        borderSide: const BorderSide(color: _C.gray200, width: 1.5)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _C.purple, width: 1.5)),
    ),
  );
}

class _PrimaryButton extends StatelessWidget {
  final String        label;
  final IconData      icon;
  final bool          loading;
  final VoidCallback? onPressed;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: loading ? _C.gray400 : _C.purple,
        foregroundColor: _C.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8)),
        elevation: 0,
        textStyle: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w700)),
      child: loading
          ? const Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2, color: _C.white)),
              SizedBox(width: 8),
              Text('Sending...'),
            ])
          : Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16),
              const SizedBox(width: 8),
              Text(label),
            ]),
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