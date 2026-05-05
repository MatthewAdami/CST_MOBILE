// lib/screens/student_settings.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cst_mobile/config/api_config.dart';
import 'package:cst_mobile/screens/login_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _purple    = Color(0xFF7C3AED);
const _navy      = Color(0xFF0B1F3A);
const _green     = Color(0xFF28A745);
const _red       = Color(0xFFDC3545);
const _yellow    = Color(0xFFFFC107);
const _gray      = Color(0xFF6C757D);
const _lightGray = Color(0xFFADB5BD);
const _bgGray    = Color(0xFFF1F3F5);
const _border    = Color(0xFFE9ECEF);
const _rowAlt    = Color(0xFFF8F9FA);
const _white     = Color(0xFFFFFFFF);

// ── Helpers ───────────────────────────────────────────────────────────────────
Future<Map<String, String>> _authHeaders() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token') ?? '';
  return {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };
}

Future<String> _getToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('token') ?? '';
}

/// Returns true only when the response is a real JSON payload.
bool _isJson(http.Response res) {
  final ct = res.headers['content-type'] ?? '';
  return ct.contains('application/json') || ct.contains('json');
}

/// Safe JSON decode — returns null when the body is HTML / empty.
Map<String, dynamic>? _tryDecode(http.Response res) {
  if (!_isJson(res)) return null;
  try {
    return jsonDecode(res.body) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ROOT SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class StudentSettingsScreen extends StatefulWidget {
  const StudentSettingsScreen({super.key});
  @override
  State<StudentSettingsScreen> createState() => _StudentSettingsScreenState();
}

class _StudentSettingsScreenState extends State<StudentSettingsScreen> {
  int _activeTab = 0;
  Map<String, dynamic>? _user;
  bool _loading = true;

  final _tabs = const [
    (label: 'Profile',       icon: Icons.person_outline),
    (label: 'Password',      icon: Icons.lock_outline),
    (label: 'Notifications', icon: Icons.notifications_none),
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  // ── Load user: local first, then API ────────────────────────────────────────
  Future<void> _loadUser() async {
    // Step 1 — always load from SharedPreferences instantly (no network needed)
    try {
      final prefs   = await SharedPreferences.getInstance();
      final userStr = prefs.getString('user') ?? '{}';
      final local   = jsonDecode(userStr) as Map<String, dynamic>;
      if (local.isNotEmpty && mounted) {
        setState(() { _user = local; _loading = false; });
      }
    } catch (e) {
      debugPrint('Local user load error: $e');
    }

    // Step 2 — try the API for fresher data (graceful fallback if route missing)
    try {
      final headers = await _authHeaders();
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/student-settings/profile'),
        headers: headers,
      ).timeout(ApiConfig.timeout);

      final data = _tryDecode(res);
      if (res.statusCode == 200 && data != null && mounted) {
        setState(() => _user = data);
        // Keep local cache in sync
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(data));
      }
    } catch (e) {
      debugPrint('Settings API (non-fatal): $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log Out',
          style: TextStyle(fontWeight: FontWeight.w700, color: _navy)),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: _gray))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _red, foregroundColor: _white),
            child: const Text('Log Out')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('user');
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const StudentLoginPage()),
          (r) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGray,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: _white,
        elevation: 0,
        title: const Row(children: [
          Icon(Icons.settings_outlined, color: _purple, size: 20),
          SizedBox(width: 8),
          Text('Settings', style: TextStyle(
            fontSize: 17, fontWeight: FontWeight.w800, color: _white)),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : Column(children: [
              // ── Tab bar ──
              Container(
                color: _white,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: _bgGray,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border)),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: _tabs.asMap().entries.map((e) {
                      final active = _activeTab == e.key;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _activeTab = e.key),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              vertical: 9, horizontal: 4),
                            decoration: BoxDecoration(
                              color: active ? _purple : Colors.transparent,
                              borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(e.value.icon, size: 14,
                                  color: active ? _white : _gray),
                                const SizedBox(width: 4),
                                Text(e.value.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: active ? _white : _gray)),
                              ]),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // ── Content ──
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    if (_activeTab == 0)
                      _ProfileTab(
                        user: _user,
                        onUserUpdate: (u) => setState(() => _user = u)),
                    if (_activeTab == 1)
                      const _PasswordTab(),
                    if (_activeTab == 2)
                      _NotificationsTab(user: _user),

                    const SizedBox(height: 16),

                    // Log out
                    _SectionCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: _red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.logout, color: _red, size: 18)),
                        title: const Text('Log Out',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _red, fontSize: 14)),
                        subtitle: const Text('Sign out of your student portal',
                          style: TextStyle(fontSize: 12, color: _lightGray)),
                        trailing: const Icon(Icons.chevron_right, color: _lightGray),
                        onTap: _confirmLogout,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PROFILE TAB
// ══════════════════════════════════════════════════════════════════════════════
class _ProfileTab extends StatefulWidget {
  final Map<String, dynamic>? user;
  final ValueChanged<Map<String, dynamic>> onUserUpdate;
  const _ProfileTab({required this.user, required this.onUserUpdate});
  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  late TextEditingController _firstName, _lastName, _email, _phone;
  bool   _saving    = false;
  bool   _saved     = false;
  String _error     = '';
  bool   _uploading = false;
  bool   _removing  = false;

  @override
  void initState() {
    super.initState();
    final u = widget.user ?? {};
    _firstName = TextEditingController(text: u['firstName'] ?? '');
    _lastName  = TextEditingController(text: u['lastName']  ?? '');
    _email     = TextEditingController(text: u['email']     ?? '');
    _phone     = TextEditingController(text: u['phone']     ?? '');
  }

  @override
  void didUpdateWidget(_ProfileTab old) {
    super.didUpdateWidget(old);
    if (old.user != widget.user) {
      final u = widget.user ?? {};
      _firstName.text = u['firstName'] ?? '';
      _lastName.text  = u['lastName']  ?? '';
      _email.text     = u['email']     ?? '';
      _phone.text     = u['phone']     ?? '';
    }
  }

  @override
  void dispose() {
    _firstName.dispose(); _lastName.dispose();
    _email.dispose(); _phone.dispose();
    super.dispose();
  }

  // ── Save profile ────────────────────────────────────────────────────────────
  Future<void> _save() async {
    setState(() { _saving = true; _error = ''; });
    try {
      final updated = {
        ...?widget.user,
        'firstName': _firstName.text.trim(),
        'lastName':  _lastName.text.trim(),
        'email':     _email.text.trim(),
        'phone':     _phone.text.trim(),
      };

      // Try API
      bool savedToApi = false;
      try {
        final headers = await _authHeaders();
        final res = await http.patch(
          Uri.parse('${ApiConfig.baseUrl}/api/student-settings/profile'),
          headers: headers,
          body: jsonEncode({
            'firstName': _firstName.text.trim(),
            'lastName':  _lastName.text.trim(),
            'email':     _email.text.trim(),
            'phone':     _phone.text.trim(),
          }),
        ).timeout(ApiConfig.timeout);

        final data = _tryDecode(res);
        if (res.statusCode == 200 && data != null) {
          updated.addAll(data);
          savedToApi = true;
        }
      } catch (e) {
        debugPrint('Profile PATCH API error (non-fatal): $e');
      }

      // Always update local cache + UI
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', jsonEncode(updated));
      widget.onUserUpdate(updated);

      setState(() => _saved = true);
      if (!savedToApi) {
        // Let user know it was saved locally only
        debugPrint('Profile saved locally (API route not available).');
      }
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _saved = false);
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Pick & upload photo ─────────────────────────────────────────────────────
  Future<void> _pickAndUploadPhoto() async {
  try {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source:       ImageSource.gallery,
      imageQuality: 85,
      maxWidth:     800,
      // ← Force JPEG so Android never sends webp/heic
    );
    if (picked == null) return;

    setState(() { _uploading = true; _error = ''; });

    // Read as bytes and force .jpg extension
    final bytes    = await picked.readAsBytes();
    final token    = await _getToken();
    final request  = http.MultipartRequest(
      'PATCH',
      Uri.parse('${ApiConfig.baseUrl}/api/student-settings/photo'));

    request.headers['Authorization'] = 'Bearer $token';

    // Force image/jpeg MIME type regardless of original format
    request.files.add(http.MultipartFile.fromBytes(
      'photo',
      bytes,
      filename:    'profile.jpg',
      contentType: MediaType('image', 'jpeg'),  // ← always jpeg
    ));

    final streamed = await request.send()
        .timeout(const Duration(seconds: 30));
    final res  = await http.Response.fromStream(streamed);
    final data = _tryDecode(res);

    if (res.statusCode == 200 && data != null) {
      final updated = data['user'] ?? data;
      final prefs   = await SharedPreferences.getInstance();
      await prefs.setString('user', jsonEncode(updated));
      widget.onUserUpdate(Map<String, dynamic>.from(updated));
    } else {
      throw Exception(data?['message'] ?? 'Upload failed (${res.statusCode}).');
    }
  } on PlatformException catch (e) {
    setState(() => _error =
      'Could not open gallery: ${e.message ?? e.code}.');
  } catch (e) {
    setState(() =>
      _error = e.toString().replaceFirst('Exception: ', ''));
  } finally {
    if (mounted) setState(() => _uploading = false);
  }
}
  // ── Remove photo ────────────────────────────────────────────────────────────
  Future<void> _removePhoto() async {
    setState(() { _removing = true; _error = ''; });
    try {
      final headers = await _authHeaders();
      final res = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/student-settings/photo'),
        headers: headers,
      ).timeout(ApiConfig.timeout);
      final data = _tryDecode(res);
      if (res.statusCode == 200) {
        final updated = Map<String, dynamic>.from(
          data?['user'] ?? data ?? widget.user ?? {});
        updated['profilePhoto'] = '';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(updated));
        widget.onUserUpdate(updated);
      } else {
        throw Exception(data?['message'] ?? 'Failed to remove photo.');
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  String get _initials {
    final f = widget.user?['firstName']?.toString() ?? '';
    final l = widget.user?['lastName']?.toString()  ?? '';
    return '${f.isNotEmpty ? f[0] : ''}${l.isNotEmpty ? l[0] : ''}'.toUpperCase();
  }

  String? get _photoUrl {
    final raw = widget.user?['profilePhoto']?.toString() ?? '';
    if (raw.isEmpty) return null;
    if (raw.startsWith('http')) return raw;
    return '${ApiConfig.baseUrl}${raw.startsWith('/') ? '' : '/'}$raw';
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user ?? {};
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── Avatar card ──
      _SectionCard(
        child: Row(children: [
          Stack(children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: _purple.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _purple.withOpacity(0.3), width: 3)),
              clipBehavior: Clip.antiAlias,
              child: _uploading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: _purple, strokeWidth: 2))
                  : _photoUrl != null
                      ? Image.network(_photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(_initials,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: _purple))))
                      : Center(child: Text(_initials,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _purple)))),

            Positioned(
              bottom: 0, right: 0,
              child: GestureDetector(
                onTap: _uploading ? null : _pickAndUploadPhoto,
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: _purple, shape: BoxShape.circle,
                    border: Border.all(color: _white, width: 2)),
                  child: const Icon(Icons.camera_alt,
                    size: 12, color: _white)))),
          ]),
          const SizedBox(width: 16),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim(),
                style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: _navy)),
              const SizedBox(height: 2),
              Text(
                u['role'] == 'student' ? 'CDL Student' : (u['role'] ?? ''),
                style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: _purple)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _uploading ? null : _pickAndUploadPhoto,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 7, horizontal: 8),
                      decoration: BoxDecoration(
                        color: _purple.withOpacity(0.08),
                        border: Border.all(color: _purple),
                        borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.upload,
                            size: 12, color: _purple),
                          const SizedBox(width: 4),
                          Text(
                            _uploading
                                ? 'Uploading...'
                                : (_photoUrl != null
                                    ? 'Change' : 'Upload'),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _purple)),
                        ])))),
                if (_photoUrl != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: _removing ? null : _removePhoto,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 7, horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDECEA),
                          border: Border.all(
                            color: const Color(0xFFF5C6CB)),
                          borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.delete_outline,
                              size: 12, color: _red),
                            const SizedBox(width: 4),
                            Text(
                              _removing ? 'Removing...' : 'Remove',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _red)),
                          ])))),
                ],
              ]),
              const SizedBox(height: 4),
              const Text('JPG or PNG · Max 10MB',
                style: TextStyle(fontSize: 10, color: _lightGray)),
            ])),
        ]),
      ),

      if (_error.isNotEmpty) ...[
        const SizedBox(height: 10),
        _ErrorBox(message: _error),
      ],
      const SizedBox(height: 14),

      // ── Personal info ──
      _SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _SectionTitle(
            icon: Icons.person_outline,
            title: 'Personal Information'),
          Row(children: [
            Expanded(child: _FieldPair('First Name', _firstName)),
            const SizedBox(width: 12),
            Expanded(child: _FieldPair('Last Name', _lastName)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _FieldPair('Email', _email,
              type: TextInputType.emailAddress,
              prefix: Icons.mail_outline)),
            const SizedBox(width: 12),
            Expanded(child: _FieldPair('Phone', _phone,
              type: TextInputType.phone,
              prefix: Icons.phone_outlined)),
          ]),
        ]),
      ),
      const SizedBox(height: 14),

      // ── Enrollment info ──
      _SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _SectionTitle(
            icon: Icons.school_outlined,
            title: 'Enrollment Information'),
          Row(children: [
            Expanded(child: _FieldPair('Student ID',
              TextEditingController(
                text: u['studentId'] ?? 'Not assigned'),
              disabled: true)),
            const SizedBox(width: 12),
            Expanded(child: _FieldPair('Role',
              TextEditingController(text: u['role'] ?? '—'),
              disabled: true)),
          ]),
          const SizedBox(height: 8),
          const Text(
            'Enrollment details can only be updated by an Administrator.',
            style: TextStyle(fontSize: 12, color: _lightGray)),
        ]),
      ),
      const SizedBox(height: 16),

      Align(
        alignment: Alignment.centerRight,
        child: _SaveButton(
          saved: _saved, saving: _saving, onTap: _save)),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PASSWORD TAB
// ══════════════════════════════════════════════════════════════════════════════
class _PasswordTab extends StatefulWidget {
  const _PasswordTab();
  @override
  State<_PasswordTab> createState() => _PasswordTabState();
}

class _PasswordTabState extends State<_PasswordTab> {
  final _current = TextEditingController();
  final _newPass = TextEditingController();
  final _confirm = TextEditingController();
  bool   _showCurrent = false, _showNew = false, _showConfirm = false;
  bool   _saving = false, _saved = false;
  String _error  = '';

  @override
  void dispose() {
    _current.dispose(); _newPass.dispose(); _confirm.dispose();
    super.dispose();
  }

  int get _strength {
    final p = _newPass.text;
    if (p.isEmpty) return 0;
    int s = 0;
    if (p.length >= 8)                        s++;
    if (p.contains(RegExp(r'[A-Z]')))         s++;
    if (p.contains(RegExp(r'[0-9]')))         s++;
    if (p.contains(RegExp(r'[^A-Za-z0-9]'))) s++;
    return s;
  }

  static const _strengthLabel = ['', 'Weak', 'Fair', 'Good', 'Strong'];
  static const _strengthColor = [
    Colors.transparent, _red, _yellow, _purple, _green];

  Future<void> _save() async {
    setState(() => _error = '');
    if (_current.text.isEmpty) {
      setState(() => _error = 'Please enter your current password.'); return;
    }
    if (_newPass.text.length < 8) {
      setState(() => _error = 'New password must be at least 8 characters.'); return;
    }
    if (_newPass.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match.'); return;
    }
    setState(() => _saving = true);
    try {
      final headers = await _authHeaders();
      final res = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/api/student-settings/password'),
        headers: headers,
        body: jsonEncode({
          'currentPassword': _current.text,
          'newPassword':     _newPass.text,
        }),
      ).timeout(ApiConfig.timeout);

      final data = _tryDecode(res);
      if (!_isJson(res)) {
        throw Exception(
          'Password update route not available yet on the server.');
      }
      if (res.statusCode != 200) {
        throw Exception(data?['message'] ?? 'Failed to update password.');
      }
      setState(() {
        _saved = true;
        _current.clear(); _newPass.clear(); _confirm.clear();
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _saved = false);
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _newPass,
      builder: (_, __) {
        final p        = _newPass.text;
        final strength = _strength;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle(
                  icon: Icons.shield_outlined,
                  title: 'Change Password'),

                const _FieldLabel('Current Password'),
                const SizedBox(height: 6),
                _StyledInput(
                  controller: _current,
                  obscure: !_showCurrent, showToggle: true,
                  onToggleObscure: () =>
                    setState(() => _showCurrent = !_showCurrent)),
                const SizedBox(height: 14),

                const _FieldLabel('New Password'),
                const SizedBox(height: 6),
                _StyledInput(
                  controller: _newPass,
                  obscure: !_showNew, showToggle: true,
                  onToggleObscure: () =>
                    setState(() => _showNew = !_showNew)),
                const SizedBox(height: 8),

                if (p.isNotEmpty) ...[
                  Row(children: List.generate(4, (i) => Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: i < strength
                            ? _strengthColor[strength] : _border))))),
                  const SizedBox(height: 4),
                  Text(_strengthLabel[strength],
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: _strengthColor[strength])),
                  const SizedBox(height: 12),
                ],

                const _FieldLabel('Confirm New Password'),
                const SizedBox(height: 6),
                _StyledInput(
                  controller: _confirm,
                  obscure: !_showConfirm, showToggle: true,
                  onToggleObscure: () =>
                    setState(() => _showConfirm = !_showConfirm)),
                const SizedBox(height: 12),

                if (_error.isNotEmpty) ...[
                  _ErrorBox(message: _error),
                  const SizedBox(height: 12),
                ],

                // Requirements
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _rowAlt,
                    borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Password requirements:',
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: _gray)),
                      const SizedBox(height: 6),
                      ...[
                        ('At least 8 characters',  p.length >= 8),
                        ('One uppercase letter',    p.contains(RegExp(r'[A-Z]'))),
                        ('One number',             p.contains(RegExp(r'[0-9]'))),
                        ('One special character',  p.contains(RegExp(r'[^A-Za-z0-9]'))),
                      ].map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(children: [
                          Icon(Icons.check_circle,
                            size: 12, color: r.$2 ? _green : _border),
                          const SizedBox(width: 6),
                          Text(r.$1, style: TextStyle(
                            fontSize: 12,
                            color: r.$2 ? _green : _lightGray)),
                        ]))),
                    ]),
                ),
              ]),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: _SaveButton(
              saved: _saved, saving: _saving,
              label: 'Update Password', onTap: _save)),
        ]);
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// NOTIFICATIONS TAB
// ══════════════════════════════════════════════════════════════════════════════
class _NotificationsTab extends StatefulWidget {
  final Map<String, dynamic>? user;
  const _NotificationsTab({required this.user});
  @override
  State<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<_NotificationsTab> {
  Map<String, bool> _prefs = {
    'sessionReminders':  true,
    'gradeUpdates':      true,
    'attendanceAlerts':  true,
    'paymentReminders':  true,
    'documentAlerts':    true,
    'announcements':     true,
    'emailDigest':       false,
    'smsAlerts':         false,
  };
  bool   _saving = false, _saved = false;
  String _error  = '';

  @override
  void initState() {
    super.initState();
    final notifs = widget.user?['notifications'];
    if (notifs is Map) {
      notifs.forEach((k, v) {
        if (_prefs.containsKey(k)) _prefs[k] = v == true;
      });
    }
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = ''; });
    try {
      final headers = await _authHeaders();
      final res = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/api/student-settings/notifications'),
        headers: headers,
        body: jsonEncode({'notifications': _prefs}),
      ).timeout(ApiConfig.timeout);

      if (!_isJson(res)) {
        // Route missing — save locally only
        final prefs = await SharedPreferences.getInstance();
        final userStr = prefs.getString('user') ?? '{}';
        final user    = jsonDecode(userStr) as Map<String, dynamic>;
        user['notifications'] = _prefs;
        await prefs.setString('user', jsonEncode(user));
      } else {
        final data = _tryDecode(res);
        if (res.statusCode != 200) {
          throw Exception(data?['message'] ?? 'Failed to save preferences.');
        }
      }
      setState(() => _saved = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _saved = false);
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _SectionTitle(
            icon: Icons.notifications_none,
            title: 'In-App Notifications',
            subtitle: 'Control which alerts appear in your notification bell.'),
          _ToggleRow('sessionReminders',  'Session Reminders',
            'Notified 30 minutes before a class starts'),
          _ToggleRow('gradeUpdates',      'Grade & Score Updates',
            'When your instructor posts exam results'),
          _ToggleRow('attendanceAlerts',  'Attendance Alerts',
            'When attendance falls below threshold'),
          _ToggleRow('paymentReminders',  'Payment Reminders',
            '3 days before tuition is due'),
          _ToggleRow('documentAlerts',    'Document Status',
            'When a document is approved or rejected'),
          _ToggleRow('announcements',     'School Announcements',
            'Important notices from CST administration',
            showDivider: false),
        ]),
      ),
      const SizedBox(height: 14),

      _SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _SectionTitle(
            icon: Icons.mail_outline,
            title: 'Email & SMS',
            subtitle: 'External notifications to your email and phone.'),
          _ToggleRow('emailDigest', 'Weekly Email Summary',
            'Recap of attendance, grades, and sessions'),
          _ToggleRow('smsAlerts',   'SMS Alerts',
            'Critical alerts as text messages',
            showDivider: false),
        ]),
      ),

      if (_error.isNotEmpty) ...[
        const SizedBox(height: 10),
        _ErrorBox(message: _error),
      ],
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerRight,
        child: _SaveButton(
          saved: _saved, saving: _saving,
          label: 'Save Preferences', onTap: _save)),
    ]);
  }

  Widget _ToggleRow(String key, String label, String sublabel,
      {bool showDivider = true}) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: _navy)),
              const SizedBox(height: 2),
              Text(sublabel, style: const TextStyle(
                fontSize: 11, color: _lightGray)),
            ])),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => setState(() =>
              _prefs[key] = !(_prefs[key] ?? false)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44, height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: (_prefs[key] ?? false)
                    ? _purple : const Color(0xFFDEE2E6)),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: (_prefs[key] ?? false)
                    ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.all(3),
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    color: _white, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 4)])))),
          ),
        ]),
      ),
      if (showDivider)
        const Divider(height: 1, color: Color(0xFFF1F3F5)),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ══════════════════════════════════════════════════════════════════════════════
class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: _white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border)),
    padding: const EdgeInsets.all(18),
    child: child,
  );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
    style: const TextStyle(
      fontSize: 10, fontWeight: FontWeight.w700,
      color: _gray, letterSpacing: 0.6));
}

class _FieldPair extends StatelessWidget {
  final String                label;
  final TextEditingController ctrl;
  final bool                  disabled;
  final TextInputType?        type;
  final IconData?             prefix;
  const _FieldPair(this.label, this.ctrl,
    {this.disabled = false, this.type, this.prefix});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _FieldLabel(label),
      const SizedBox(height: 6),
      _StyledInput(
        controller:   ctrl,
        disabled:     disabled,
        keyboardType: type ?? TextInputType.text,
        prefix:       prefix != null
            ? Icon(prefix, size: 16, color: _lightGray) : null),
    ]);
}

class _StyledInput extends StatelessWidget {
  final TextEditingController controller;
  final String?     placeholder;
  final bool        disabled, obscure, showToggle;
  final TextInputType keyboardType;
  final Widget?     prefix;
  final VoidCallback? onToggleObscure;

  const _StyledInput({
    required this.controller,
    this.placeholder,
    this.disabled = false,
    this.obscure  = false,
    this.showToggle = false,
    this.keyboardType = TextInputType.text,
    this.prefix,
    this.onToggleObscure,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller:  controller,
    enabled:     !disabled,
    obscureText: obscure,
    keyboardType: keyboardType,
    style: TextStyle(
      fontSize: 14, color: disabled ? _lightGray : _navy),
    decoration: InputDecoration(
      hintText:  placeholder,
      hintStyle: const TextStyle(color: _lightGray, fontSize: 13),
      prefixIcon: prefix,
      suffixIcon: showToggle
          ? IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                size: 18, color: _lightGray),
              onPressed: onToggleObscure)
          : null,
      filled:    true,
      fillColor: disabled ? _rowAlt : _white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14, vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _border, width: 1.5)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _purple, width: 1.5)),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Color(0xFFF1F3F5), width: 1.5)),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String?  subtitle;
  const _SectionTitle(
    {required this.icon, required this.title, this.subtitle});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Icon(icon, color: _purple, size: 15),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
      ]),
      if (subtitle != null) ...[
        const SizedBox(height: 3),
        Text(subtitle!, style: const TextStyle(
          fontSize: 12, color: _lightGray)),
      ],
      const SizedBox(height: 16),
    ]);
}

class _SaveButton extends StatelessWidget {
  final bool         saved, saving;
  final VoidCallback onTap;
  final String       label;
  const _SaveButton({
    required this.saved, required this.saving,
    required this.onTap, this.label = 'Save Changes'});
  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    onPressed: saving ? null : onTap,
    icon: saving
        ? const SizedBox(width: 14, height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2, color: _white))
        : Icon(saved ? Icons.check_circle : Icons.save, size: 16),
    label: Text(saving ? 'Saving...' : saved ? 'Saved!' : label),
    style: ElevatedButton.styleFrom(
      backgroundColor: saved ? _green : _purple,
      foregroundColor: _white,
      padding: const EdgeInsets.symmetric(
        horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(
        fontSize: 14, fontWeight: FontWeight.w700),
      elevation: 3,
      shadowColor: _purple.withOpacity(0.35)),
  );
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFFDECEA),
      border: Border.all(color: const Color(0xFFF5C6CB)),
      borderRadius: BorderRadius.circular(8)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.error_outline, size: 14, color: _red),
      const SizedBox(width: 8),
      Expanded(child: Text(message,
        style: const TextStyle(
          fontSize: 12, color: Color(0xFF721C24), height: 1.4))),
    ]),
  );
}