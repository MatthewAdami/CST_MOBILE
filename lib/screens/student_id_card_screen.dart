import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:cst_mobile/config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const kNavy   = Color(0xFF0B1F3A);
const kNavy2  = Color(0xFF1A3A6E);
const kGold   = Color(0xFFC9A84C);
const kPurple = Color(0xFF7C3AED);
const kGray   = Color(0xFF6C757D);

// ── Model ─────────────────────────────────────────────────────────────────────
class StudentIdData {
  final String studentId;
  final String firstName;
  final String lastName;
  final String program;
  final String email;
  final String status;
  final String? profilePhoto;
  final String? qrCode;
  final DateTime? enrolledAt;
  final DateTime? expiryDate;
  final DateTime? issuedDate;

  StudentIdData({
    required this.studentId,
    required this.firstName,
    required this.lastName,
    required this.program,
    required this.email,
    required this.status,
    this.profilePhoto,
    this.qrCode,
    this.enrolledAt,
    this.expiryDate,
    this.issuedDate,
  });

  factory StudentIdData.fromJson(Map<String, dynamic> j) => StudentIdData(
    studentId:    j['studentId']    ?? '',
    firstName:    j['firstName']    ?? '',
    lastName:     j['lastName']     ?? '',
    program:      j['program']      ?? 'CDL Class A',
    email:        j['email']        ?? '',
    status:       j['status']       ?? 'active',
    profilePhoto: j['profilePhoto'],
    qrCode:       j['qrCode'],
    enrolledAt:   j['enrolledAt'] != null ? DateTime.tryParse(j['enrolledAt']) : null,
    expiryDate:   j['expiryDate'] != null ? DateTime.tryParse(j['expiryDate']) : null,
    issuedDate:   j['issuedDate'] != null ? DateTime.tryParse(j['issuedDate']) : null,
  );

  String get fullName => '$firstName $lastName';
}

// ── Helpers ───────────────────────────────────────────────────────────────────
String fmtDate(DateTime? dt) {
  if (dt == null) return '—';
  return DateFormat('MMM d, yyyy').format(dt);
}

Color statusColor(String status) {
  switch (status) {
    case 'active':  return const Color(0xFF16A34A);
    case 'pending': return const Color(0xFFD97706);
    default:        return const Color(0xFF6B7280);
  }
}

// ── API ───────────────────────────────────────────────────────────────────────
class StudentIdService {
  final String token;
  StudentIdService(this.token);

  Future<StudentIdData> fetchId() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/student-id/my'),
      headers: ApiConfig.authHeaders(token),
    ).timeout(ApiConfig.timeout);

    if (res.statusCode == 200) {
      return StudentIdData.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to load ID card (${res.statusCode})');
  }
}

// ── Main Screen ───────────────────────────────────────────────────────────────
class StudentIdCardScreen extends StatefulWidget {
  final String authToken;
  const StudentIdCardScreen({ super.key, required this.authToken });

  @override
  State<StudentIdCardScreen> createState() => _StudentIdCardScreenState();
}

class _StudentIdCardScreenState extends State<StudentIdCardScreen>
    with SingleTickerProviderStateMixin {
  StudentIdData? _data;
  bool  _loading = true;
  String? _error;
  bool  _showBack = false;
  bool  _hideId   = true;
  late final AnimationController _flipCtrl;
  late final Animation<double>   _flipAnim;

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 550));
    _flipAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOut));
    _load();
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await StudentIdService(widget.authToken).fetchId();
      setState(() => _data = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _flip(bool toBack) {
    setState(() => _showBack = toBack);
    if (toBack) {
      _flipCtrl.forward();
    } else {
      _flipCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: kPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kPurple.withOpacity(0.25)),
              ),
              child: const Icon(Icons.badge_outlined, color: kPurple, size: 18),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Student ID Card', style: TextStyle(
                  fontFamily: 'Georgia', fontSize: 17,
                  fontWeight: FontWeight.w800, color: kNavy,
                )),
                Text('Official CST identification', style: TextStyle(
                  fontSize: 11, color: kGray, fontWeight: FontWeight.w500,
                )),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: kNavy),
            onPressed: _load,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE9ECEF)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPurple))
          : _error != null
              ? _ErrorState(error: _error!, onRetry: _load)
              : _data == null
                  ? const SizedBox()
                  : RefreshIndicator(
                      color: kPurple,
                      onRefresh: _load,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Flip tabs ──────────────────────────────────
                            Row(
                              children: [
                                _FlipTab(label: '🪪  Front', active: !_showBack,
                                    onTap: () => _flip(false)),
                                const SizedBox(width: 8),
                                _FlipTab(label: '🔄  Back', active: _showBack,
                                    onTap: () => _flip(true)),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // ── Card with flip ─────────────────────────────
                            Center(
                              child: AnimatedBuilder(
                                animation: _flipAnim,
                                builder: (_, __) {
                                  final angle = _flipAnim.value * 3.14159;
                                  final isFront = angle <= 1.5708;
                                  return Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()
                                      ..setEntry(3, 2, 0.001)
                                      ..rotateY(angle),
                                    child: isFront
                                        ? _CardFront(data: _data!, hideId: _hideId)
                                        : Transform(
                                            alignment: Alignment.center,
                                            transform: Matrix4.identity()..rotateY(3.14159),
                                            child: _CardBack(data: _data!),
                                          ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ── Action buttons ─────────────────────────────
                            Row(
                              children: [
                                Expanded(
                                  child: _ActionBtn(
                                    label: _hideId ? 'Show ID' : 'Hide ID',
                                    icon: _hideId ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    onTap: () => setState(() => _hideId = !_hideId),
                                    color: kNavy,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _ActionBtn(
                                  label: 'Copy ID',
                                  icon: Icons.copy_rounded,
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: _data!.studentId));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Student ID copied!'),
                                          duration: Duration(seconds: 2)),
                                    );
                                  },
                                  color: kPurple,
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // ── ID Details ─────────────────────────────────
                            _InfoCard(data: _data!, hideId: _hideId),
                            const SizedBox(height: 16),

                            // ── QR Code ────────────────────────────────────
                            if (_data!.qrCode != null) ...[
                              _QrCard(data: _data!),
                              const SizedBox(height: 16),
                            ],

                            // ── Tips ───────────────────────────────────────
                            _TipsCard(),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
    );
  }
}

// ── Flip Tab ──────────────────────────────────────────────────────────────────
class _FlipTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FlipTab({ required this.label, required this.active, required this.onTap });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: active ? kPurple : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? kPurple : const Color(0xFFDEE2E6)),
      ),
      child: Text(label, style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w700,
        color: active ? Colors.white : kGray,
      )),
    ),
  );
}

// ── Card Front ────────────────────────────────────────────────────────────────
class _CardFront extends StatelessWidget {
  final StudentIdData data;
  final bool hideId;
  const _CardFront({ required this.data, required this.hideId });

  @override
  Widget build(BuildContext context) {
    final sc = statusColor(data.status);
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 380),
      height: 220,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kNavy, Color(0xFF1A3A6E), Color(0xFF0D2D5E)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: kNavy.withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 12)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(top: -40, right: -40,
              child: Container(width: 160, height: 160,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: kGold.withOpacity(0.1),
                  border: Border.all(color: kGold.withOpacity(0.2), width: 2)))),
            Positioned(bottom: -50, left: -20,
              child: Container(width: 140, height: 140,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: kPurple.withOpacity(0.1),
                  border: Border.all(color: kPurple.withOpacity(0.15))))),

            // Gold top stripe
            Positioned(top: 0, left: 0, right: 0,
              child: Container(height: 4,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [kGold, kPurple, kGold])))),

            Column(
              children: [
                const SizedBox(height: 4),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: kGold, borderRadius: BorderRadius.circular(7)),
                        child: const Icon(Icons.local_shipping, color: kNavy, size: 14),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('California School of Trucking',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                                color: kGold, letterSpacing: 0.8)),
                            Text('caschooloftrucking.com',
                              style: TextStyle(fontSize: 7,
                                color: Colors.white.withOpacity(0.4))),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: sc.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: sc.withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 5, height: 5,
                              decoration: BoxDecoration(color: sc, shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Text(data.status.toUpperCase(),
                              style: TextStyle(fontSize: 7, fontWeight: FontWeight.w800,
                                color: sc, letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: kGold.withOpacity(0.2)),

                // Body
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Row(
                      children: [
                        // Photo
                        Container(
                          width: 66, height: 76,
                          decoration: BoxDecoration(
                            color: kNavy.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: kGold.withOpacity(0.5), width: 2),
                          ),
                          child: data.profilePhoto != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(7),
                                  child: Image.network(data.profilePhoto!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const _NoPhoto()))
                              : const _NoPhoto(),
                        ),
                        const SizedBox(width: 12),

                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(data.fullName,
                                style: const TextStyle(fontSize: 16,
                                  fontWeight: FontWeight.w800, color: Colors.white,
                                  fontFamily: 'Georgia', height: 1.2),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(data.program,
                                style: const TextStyle(fontSize: 9,
                                  color: kGold, fontWeight: FontWeight.w600),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 8),
                              _CardDetail(
                                icon: Icons.tag,
                                label: 'ID',
                                value: hideId ? '••••••••••' : data.studentId,
                                mono: true,
                              ),
                              const SizedBox(height: 3),
                              _CardDetail(
                                icon: Icons.calendar_today_outlined,
                                label: 'Enrolled',
                                value: fmtDate(data.enrolledAt),
                              ),
                              const SizedBox(height: 3),
                              _CardDetail(
                                icon: Icons.event_outlined,
                                label: 'Expires',
                                value: fmtDate(data.expiryDate),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // QR placeholder
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 58, height: 58,
                              decoration: BoxDecoration(
                                color: data.qrCode != null
                                    ? Colors.white : Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: kGold.withOpacity(0.5), width: 2),
                              ),
                              child: data.qrCode != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(data.qrCode!, fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.qr_code_2, color: kNavy, size: 36)))
                                  : Icon(Icons.qr_code_2,
                                      color: Colors.white.withOpacity(0.2), size: 28),
                            ),
                            const SizedBox(height: 4),
                            Text('Scan to\nVerify',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 7,
                                color: Colors.white.withOpacity(0.3), height: 1.2)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Footer
                Container(
                  height: 22,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [kGold.withOpacity(0.25), kPurple.withOpacity(0.25),
                               kGold.withOpacity(0.25)]),
                    border: Border(top: BorderSide(color: kGold.withOpacity(0.25))),
                  ),
                  child: Center(
                    child: Text('Student Identification Card · Not Transferable',
                      style: TextStyle(fontSize: 7, letterSpacing: 1.2,
                        color: Colors.white.withOpacity(0.35),
                        fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoPhoto extends StatelessWidget {
  const _NoPhoto();
  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.person_outline, color: kGold.withOpacity(0.5), size: 26),
      const SizedBox(height: 2),
      Text('No Photo', style: TextStyle(fontSize: 7,
        color: Colors.white.withOpacity(0.3))),
    ],
  );
}

class _CardDetail extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool mono;
  const _CardDetail({ required this.icon, required this.label,
    required this.value, this.mono = false });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 8, color: kGold.withOpacity(0.6)),
      const SizedBox(width: 4),
      Text('$label: ', style: TextStyle(fontSize: 8,
        color: Colors.white.withOpacity(0.45))),
      Expanded(child: Text(value,
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700,
          color: Colors.white.withOpacity(0.85),
          fontFamily: mono ? 'monospace' : null),
        maxLines: 1, overflow: TextOverflow.ellipsis)),
    ],
  );
}

// ── Card Back ─────────────────────────────────────────────────────────────────
class _CardBack extends StatelessWidget {
  final StudentIdData data;
  const _CardBack({ required this.data });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    constraints: const BoxConstraints(maxWidth: 380),
    height: 220,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF1A1A2E), Color(0xFF16213E), kNavy],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: kNavy.withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 12)),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          // Top stripe
          Positioned(top: 0, left: 0, right: 0,
            child: Container(height: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [kPurple, kGold, kPurple])))),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              // Magnetic strip
              Container(
                margin: const EdgeInsets.only(top: 14),
                height: 34,
                color: Colors.black.withOpacity(0.55),
              ),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('If Found, Please Return To:',
                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700,
                                color: kGold, letterSpacing: 0.6)),
                            const SizedBox(height: 5),
                            const Text('California School of Trucking',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                                color: Colors.white)),
                            const SizedBox(height: 2),
                            Text('info@caschooloftrucking.com · (888) 880-0847',
                              style: TextStyle(fontSize: 8,
                                color: Colors.white.withOpacity(0.45))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This card is property of California School of Trucking. '
                        'Misuse may result in disciplinary action. '
                        'Valid only with photo ID. Non-transferable.',
                        style: TextStyle(fontSize: 7.5, height: 1.5,
                          color: Colors.white.withOpacity(0.3)),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ISSUED', style: TextStyle(fontSize: 7,
                                color: Colors.white.withOpacity(0.3), letterSpacing: 0.6)),
                              Text(fmtDate(data.issuedDate),
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.6))),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('VALID THROUGH', style: TextStyle(fontSize: 7,
                                color: Colors.white.withOpacity(0.3), letterSpacing: 0.6)),
                              Text(fmtDate(data.expiryDate),
                                style: const TextStyle(fontSize: 9,
                                  fontWeight: FontWeight.w700, color: kGold)),
                            ],
                          ),
                          Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(
                              color: kGold.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: kGold.withOpacity(0.35)),
                            ),
                            child: const Icon(Icons.shield_outlined, color: kGold, size: 15),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // Footer
              Container(
                height: 20,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kPurple.withOpacity(0.2), kGold.withOpacity(0.2),
                             kPurple.withOpacity(0.2)]),
                  border: Border(top: BorderSide(color: kGold.withOpacity(0.15))),
                ),
                child: Center(
                  child: Text('caschooloftrucking.com',
                    style: TextStyle(fontSize: 7, letterSpacing: 1.0,
                      color: Colors.white.withOpacity(0.3))),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

// ── Action Button ─────────────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  const _ActionBtn({ required this.label, required this.icon,
    required this.onTap, required this.color });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: color.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(fontSize: 13,
            fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    ),
  );
}

// ── Info Card ─────────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final StudentIdData data;
  final bool hideId;
  const _InfoCard({ required this.data, required this.hideId });

  @override
  Widget build(BuildContext context) {
    final rows = [
      (label: 'Student ID',  value: hideId ? '••••••••••' : data.studentId, mono: true),
      (label: 'Full Name',   value: data.fullName, mono: false),
      (label: 'Program',     value: data.program, mono: false),
      (label: 'Email',       value: data.email, mono: false),
      (label: 'Enrolled',    value: fmtDate(data.enrolledAt), mono: false),
      (label: 'Expires',     value: fmtDate(data.expiryDate), mono: false),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9ECEF)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('ID Details', style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800,
                  color: kNavy, fontFamily: 'Georgia')),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor(data.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor(data.status).withOpacity(0.3)),
                  ),
                  child: Text(data.status.toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                      color: statusColor(data.status))),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F3F5)),
          ...rows.map((row) => _InfoRow(
            label: row.label, value: row.value, mono: row.mono)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final bool mono;
  const _InfoRow({ required this.label, required this.value, this.mono = false });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFF1F3F5)))),
    child: Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 13,
          color: kGray, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
          color: const Color(0xFF343A40),
          fontFamily: mono ? 'monospace' : null),
          textAlign: TextAlign.right),
      ],
    ),
  );
}

// ── QR Card ───────────────────────────────────────────────────────────────────
class _QrCard extends StatelessWidget {
  final StudentIdData data;
  const _QrCard({ required this.data });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE9ECEF)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
    ),
    child: Column(
      children: [
        const Text('Verification QR Code', style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w800,
          color: kNavy, fontFamily: 'Georgia')),
        const SizedBox(height: 14),
        Container(
          width: 120, height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kPurple.withOpacity(0.3), width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(data.qrCode!, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                const Icon(Icons.qr_code_2, color: kNavy, size: 60)),
          ),
        ),
        const SizedBox(height: 10),
        const Text('Scan to verify enrollment status.\nValid for the current academic period.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: kGray, height: 1.5)),
      ],
    ),
  );
}

// ── Tips Card ─────────────────────────────────────────────────────────────────
class _TipsCard extends StatelessWidget {
  const _TipsCard();

  static const tips = [
    'Copy your Student ID using the button above',
    'Present at all campus locations for access',
    'QR code can be scanned by instructors to verify',
    'Keep your ID handy for DMV test appointments',
  ];

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: kPurple.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: kPurple.withOpacity(0.18)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.shield_outlined, color: kPurple, size: 15),
          const SizedBox(width: 8),
          const Text('Usage Tips', style: TextStyle(fontSize: 13,
            fontWeight: FontWeight.w700, color: kPurple)),
        ]),
        const SizedBox(height: 10),
        ...tips.map((tip) => Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle_outline, color: kPurple, size: 13),
              const SizedBox(width: 8),
              Expanded(child: Text(tip, style: const TextStyle(
                fontSize: 12, color: Color(0xFF495057), height: 1.4))),
            ],
          ),
        )),
      ],
    ),
  );
}

// ── Error State ───────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({ required this.error, required this.onRetry });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC3545), size: 48),
          const SizedBox(height: 12),
          Text(error, textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFDC3545), fontSize: 14)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPurple, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    ),
  );
}