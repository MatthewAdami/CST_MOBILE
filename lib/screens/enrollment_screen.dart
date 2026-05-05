// lib/screens/enrollment_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

// ── Colour palette ────────────────────────────────────────────────────────────
class _C {
  static const navy      = Color(0xFF0B1F3A);
  static const navyMid   = Color(0xFF162D50);
  static const gold      = Color(0xFFC9A84C);
  static const goldLight = Color(0xFFE2C07A);
  static const goldPale  = Color(0xFFFFFBF0);
  static const white     = Color(0xFFFFFFFF);
  static const gray50    = Color(0xFFF8F9FA);
  static const gray100   = Color(0xFFF1F3F5);
  static const gray200   = Color(0xFFE9ECEF);
  static const gray400   = Color(0xFFADB5BD);
  static const gray600   = Color(0xFF6C757D);
  static const gray800   = Color(0xFF343A40);
  static const red       = Color(0xFFDC3545);
  static const redBg     = Color(0xFFF8D7DA);
  static const green     = Color(0xFF198754);
  static const greenBg   = Color(0xFFD1E7DD);
  static const border    = Color(0xFFE9ECEF);
}

// ── Data ──────────────────────────────────────────────────────────────────────
const _programs = [
  ('class-a', 'Class A CDL',            '4 Weeks', '\$5,500', 'Full tractor-trailer license. Covers combination vehicles over 26,001 lbs.'),
  ('class-b', 'Class B CDL',            '3 Weeks', '\$3,800', 'Straight truck license. Covers single vehicles over 26,001 lbs.'),
  ('hazmat',  'Hazmat Endorsement',     '1 Week',  '\$1,200', 'Add-on endorsement for hazardous materials. Requires existing CDL.'),
  ('combo',   'Class A + Hazmat Combo', '5 Weeks', '\$6,200', 'Best value — full Class A CDL plus Hazmat endorsement in one program.'),
];

const _startDates = [
  'May 5, 2025', 'May 19, 2025', 'June 2, 2025',
  'June 16, 2025', 'July 7, 2025', 'July 21, 2025',
];

const _kFinancingOptions = [
  ('self',      'Self-Pay / Out of Pocket'),
  ('va',        'VA / Veterans Benefits'),
  ('loan',      'Third-Party Student Loan'),
  ('workforce', 'Workforce Development Grant'),
  ('employer',  'Employer Sponsorship'),
];

const _states = ['CA','NV','AZ','OR','WA','TX','FL','NY'];

const _referrals = [
  'Internet Search', 'Social Media', 'Friend / Family Referral',
  'Employer', 'Veterans Organization', 'Radio / TV', 'Other',
];

const _stepLabels = ['Personal', 'Contact', 'Program', 'Review'];

// ── Main Screen ───────────────────────────────────────────────────────────────
class EnrollmentScreen extends StatefulWidget {
  const EnrollmentScreen({super.key});

  @override
  State<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends State<EnrollmentScreen>
    with SingleTickerProviderStateMixin {
  int  _step      = 0; // 0-3
  bool _submitted = false;
  bool _loading   = false;

  // ── Form data ──────────────────────────────────────────────────────────────
  // Step 1 — Personal
  final _firstCtrl    = TextEditingController();
  final _lastCtrl     = TextEditingController();
  final _dobCtrl      = TextEditingController();
  final _ssnCtrl      = TextEditingController();
  String? _gender;
  String? _veteran;
  String? _hasCdl;

  // Step 2 — Contact
  final _emailCtrl    = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _altPhoneCtrl = TextEditingController();
  final _addressCtrl  = TextEditingController();
  final _cityCtrl     = TextEditingController();
  String? _state;
  final _zipCtrl      = TextEditingController();
  final _emNameCtrl   = TextEditingController();
  final _emPhoneCtrl  = TextEditingController();

  // Step 3 — Program
  String? _program;
  String? _startDate;
  String? _financing;
  String? _referral;
  final _notesCtrl    = TextEditingController();

  // ── Errors ────────────────────────────────────────────────────────────────
  Map<String, String> _errors = {};

  late final AnimationController _slideCtrl;
  late final Animation<Offset>   _slideAnim;
  int _slideDir = 1; // 1 = forward, -1 = back

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.08, 0),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    for (final c in [
      _firstCtrl, _lastCtrl, _dobCtrl, _ssnCtrl,
      _emailCtrl, _phoneCtrl, _altPhoneCtrl, _addressCtrl,
      _cityCtrl, _zipCtrl, _emNameCtrl, _emPhoneCtrl, _notesCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  // ── Validation ─────────────────────────────────────────────────────────────
  bool _validate() {
    final e = <String, String>{};

    if (_step == 0) {
      if (_firstCtrl.text.trim().isEmpty) e['firstName'] = 'First name is required';
      if (_lastCtrl.text.trim().isEmpty)  e['lastName']  = 'Last name is required';
      if (_dobCtrl.text.trim().isEmpty)   e['dob']       = 'Date of birth is required';
    }

    if (_step == 1) {
      if (_emailCtrl.text.trim().isEmpty ||
          !RegExp(r'\S+@\S+\.\S+').hasMatch(_emailCtrl.text)) {
        e['email'] = 'Valid email is required';
      }
      if (_phoneCtrl.text.trim().isEmpty)   e['phone']   = 'Phone number is required';
      if (_addressCtrl.text.trim().isEmpty) e['address'] = 'Address is required';
      if (_cityCtrl.text.trim().isEmpty)    e['city']    = 'City is required';
      if (_state == null)                   e['state']   = 'State is required';
      if (_zipCtrl.text.trim().length < 5)  e['zip']     = 'Valid ZIP is required';
    }

    if (_step == 2) {
      if (_program == null)   e['program']   = 'Please select a program';
      if (_startDate == null) e['startDate'] = 'Please select a start date';
      if (_financing == null) e['financing'] = 'Please select a financing option';
    }

    setState(() => _errors = e);
    return e.isEmpty;
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  void _next() {
    if (!_validate()) return;
    _animateTo(_step + 1, 1);
  }

  void _back() {
    setState(() => _errors = {});
    _animateTo(_step - 1, -1);
  }

  void _animateTo(int target, int dir) async {
    _slideDir = dir;
    await _slideCtrl.reverse();
    setState(() => _step = target);
    _slideCtrl.forward();
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/apply'),
        headers: ApiConfig.headers,
        body: jsonEncode({
          // Personal
          'firstName':      _firstCtrl.text.trim(),
          'lastName':       _lastCtrl.text.trim(),
          'dob':            _dobCtrl.text.trim(),
          'ssn':            _ssnCtrl.text.trim(),
          'gender':         _gender,
          'veteran':        _veteran,
          'hasCdl':         _hasCdl,
          // Contact
          'email':          _emailCtrl.text.trim(),
          'phone':          _phoneCtrl.text.trim(),
          'altPhone':       _altPhoneCtrl.text.trim(),
          'address':        _addressCtrl.text.trim(),
          'city':           _cityCtrl.text.trim(),
          'state':          _state,
          'zip':            _zipCtrl.text.trim(),
          'emergencyName':  _emNameCtrl.text.trim(),
          'emergencyPhone': _emPhoneCtrl.text.trim(),
          // Program
          'program':        _program,
          'startDate':      _startDate,
          'financing':      _financing,
          'referral':       _referral,
          'notes':          _notesCtrl.text.trim(),
        }),
      ).timeout(ApiConfig.timeout);

      if (res.statusCode == 200 || res.statusCode == 201) {
        setState(() => _submitted = true);
      } else {
        String msg = 'Submission failed (${res.statusCode}). Please try again.';
        try {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          if (body['message'] != null) msg = body['message'] as String;
        } catch (_) {}
        _showError(msg);
      }
    } on TimeoutException {
      _showError('Request timed out. Please check your connection.');
    } catch (e) {
      _showError('Network error. Please check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _C.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.gray50,
      body: Column(
        children: [
          _buildHeader(),
          if (!_submitted) _buildStepper(),
          Expanded(
            child: _submitted
                ? _buildSuccess()
                : SlideTransition(
                    position: _slideAnim,
                    child: FadeTransition(
                      opacity: _slideCtrl,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                        child: _buildStep(),
                      ),
                    ),
                  ),
          ),
          if (!_submitted) _buildNavBar(),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF071018), _C.navy],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
        border: Border(bottom: BorderSide(color: _C.gold, width: 3)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color:        Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.15)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 14, color: _C.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CALIFORNIA SCHOOL OF TRUCKING',
                      style: TextStyle(
                        fontSize:   9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: _C.gold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Enrollment Application',
                      style: TextStyle(
                        fontSize:   18,
                        fontWeight: FontWeight.w700,
                        color: _C.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Stepper ────────────────────────────────────────────────────────────────
  Widget _buildStepper() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: _C.white,
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: Row(
        children: List.generate(_stepLabels.length, (i) {
          final active = i == _step;
          final done   = i < _step;
          final isLast = i == _stepLabels.length - 1;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: done
                              ? _C.gold
                              : active
                                  ? _C.navy
                                  : _C.white,
                          border: Border.all(
                            color: done || active ? Colors.transparent : _C.gray200,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: done
                              ? const Icon(Icons.check_rounded,
                                  size: 16, color: _C.white)
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize:   13,
                                    fontWeight: FontWeight.w700,
                                    color: active ? _C.white : _C.gray400,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _stepLabels[i],
                        style: TextStyle(
                          fontSize:   9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: active
                              ? _C.navy
                              : done
                                  ? _C.gold
                                  : _C.gray400,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 18),
                      color: done ? _C.gold : _C.gray200,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── Step router ────────────────────────────────────────────────────────────
  Widget _buildStep() {
    switch (_step) {
      case 0: return _buildPersonalStep();
      case 1: return _buildContactStep();
      case 2: return _buildProgramStep();
      case 3: return _buildReviewStep();
      default: return const SizedBox();
    }
  }

  // ── Step 1: Personal ───────────────────────────────────────────────────────
  Widget _buildPersonalStep() => _StepCard(
    title:    'Personal Information',
    subtitle: 'Enter your legal name as it appears on your government-issued ID.',
    child: Column(
      children: [
        Row(children: [
          Expanded(child: _Field(
            label: 'First Name *',
            error: _errors['firstName'],
            child: _Input(controller: _firstCtrl, hint: 'John'),
          )),
          const SizedBox(width: 12),
          Expanded(child: _Field(
            label: 'Last Name *',
            error: _errors['lastName'],
            child: _Input(controller: _lastCtrl, hint: 'Smith'),
          )),
        ]),
        _Field(
          label: 'Date of Birth *',
          error: _errors['dob'],
          child: _Input(
            controller: _dobCtrl,
            hint:       'MM/DD/YYYY',
            keyboard:   TextInputType.datetime,
          ),
        ),
        _Field(
          label: 'SSN (last 4 digits)',
          child: _Input(
            controller:  _ssnCtrl,
            hint:        'XXXX',
            keyboard:    TextInputType.number,
            maxLength:   4,
          ),
        ),
        _Field(
          label: 'Gender',
          child: _Dropdown(
            value:   _gender,
            hint:    '— Select —',
            items:   const ['Male', 'Female', 'Non-binary', 'Prefer not to say'],
            onChanged: (v) => setState(() => _gender = v),
          ),
        ),
        _Field(
          label: 'Are you a U.S. Military Veteran?',
          child: _Dropdown(
            value:   _veteran,
            hint:    '— Select —',
            items:   const ['Yes', 'No', 'Currently Active Duty'],
            onChanged: (v) => setState(() => _veteran = v),
          ),
        ),
        _Field(
          label: 'Do you currently hold a CDL?',
          child: _Dropdown(
            value:   _hasCdl,
            hint:    '— Select —',
            items:   const ['No CDL', 'Class B CDL', 'Class A CDL'],
            onChanged: (v) => setState(() => _hasCdl = v),
          ),
        ),
      ],
    ),
  );

  // ── Step 2: Contact ────────────────────────────────────────────────────────
  Widget _buildContactStep() => _StepCard(
    title:    'Contact Information',
    subtitle: 'We will use this to send your enrollment confirmation and updates.',
    child: Column(
      children: [
        _Field(
          label: 'Email Address *',
          error: _errors['email'],
          child: _Input(
            controller: _emailCtrl,
            hint:       'john.smith@email.com',
            keyboard:   TextInputType.emailAddress,
          ),
        ),
        Row(children: [
          Expanded(child: _Field(
            label: 'Primary Phone *',
            error: _errors['phone'],
            child: _Input(
              controller: _phoneCtrl,
              hint:       '(555) 000-0000',
              keyboard:   TextInputType.phone,
            ),
          )),
          const SizedBox(width: 12),
          Expanded(child: _Field(
            label: 'Alternate Phone',
            child: _Input(
              controller: _altPhoneCtrl,
              hint:       '(555) 000-0000',
              keyboard:   TextInputType.phone,
            ),
          )),
        ]),
        _Field(
          label: 'Street Address *',
          error: _errors['address'],
          child: _Input(controller: _addressCtrl, hint: '123 Main Street'),
        ),
        _Field(
          label: 'City *',
          error: _errors['city'],
          child: _Input(controller: _cityCtrl, hint: 'Los Angeles'),
        ),
        Row(children: [
          Expanded(
            flex: 2,
            child: _Field(
              label: 'State *',
              error: _errors['state'],
              child: _Dropdown(
                value:   _state,
                hint:    '—',
                items:   _states,
                onChanged: (v) => setState(() => _state = v),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _Field(
              label: 'ZIP *',
              error: _errors['zip'],
              child: _Input(
                controller: _zipCtrl,
                hint:       '90001',
                keyboard:   TextInputType.number,
                maxLength:  5,
              ),
            ),
          ),
        ]),
        _Field(
          label: 'Emergency Contact Name',
          child: _Input(controller: _emNameCtrl, hint: 'Jane Smith'),
        ),
        _Field(
          label: 'Emergency Contact Phone',
          child: _Input(
            controller: _emPhoneCtrl,
            hint:       '(555) 000-0000',
            keyboard:   TextInputType.phone,
          ),
        ),
      ],
    ),
  );

  // ── Step 3: Program ────────────────────────────────────────────────────────
  Widget _buildProgramStep() {
    // Build program cards list explicitly to avoid spread + map nullability issues
    final programCards = _programs.map<Widget>((p) {
      final selected = _program == p.$1;
      return GestureDetector(
        onTap: () => setState(() => _program = p.$1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:        selected ? _C.goldPale : _C.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? _C.gold : _C.border,
              width: selected ? 2 : 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.$2,
                      style: const TextStyle(
                        fontSize:   15,
                        fontWeight: FontWeight.w700,
                        color: _C.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${p.$3} · ${p.$5}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _C.gray600,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    p.$4,
                    style: const TextStyle(
                      fontSize:   18,
                      fontWeight: FontWeight.w700,
                      color: _C.gold,
                    ),
                  ),
                  if (selected)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(Icons.check_circle_rounded,
                          size: 18, color: _C.gold),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }).toList();

    // Build financing options list explicitly
    final financingOptions = _kFinancingOptions.map<Widget>((f) {
      final isSelected = _financing == f.$1;
      return GestureDetector(
        onTap: () => setState(() => _financing = f.$1),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color:        isSelected ? _C.navy.withOpacity(0.04) : _C.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? _C.navy : _C.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20, height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? _C.gold : _C.white,
                border: Border.all(
                  color: isSelected ? _C.gold : _C.gray400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.circle, size: 8, color: _C.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              f.$2,
              style: TextStyle(
                fontSize:   14,
                color: isSelected ? _C.navy : _C.gray800,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ]),
        ),
      );
    }).toList();

    return _StepCard(
      title:    'Program Selection',
      subtitle: 'Select the program and preferred start date for your enrollment.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Program error
          if (_errors['program'] != null)
            _ErrorText(_errors['program']!),

          // Program cards
          const _FieldLabel('Select a Program *'),
          const SizedBox(height: 8),
          ...programCards,

          const SizedBox(height: 8),
          _Field(
            label: 'Preferred Start Date *',
            error: _errors['startDate'],
            child: _Dropdown(
              value:   _startDate,
              hint:    '— Select a start date —',
              items:   _startDates,
              onChanged: (v) => setState(() => _startDate = v),
            ),
          ),

          // Financing
          const SizedBox(height: 4),
          const _FieldLabel('Financing Option *'),
          if (_errors['financing'] != null) _ErrorText(_errors['financing']!),
          const SizedBox(height: 8),
          ...financingOptions,

          const SizedBox(height: 8),
          _Field(
            label: 'How did you hear about us?',
            child: _Dropdown(
              value:   _referral,
              hint:    '— Select —',
              items:   _referrals,
              onChanged: (v) => setState(() => _referral = v),
            ),
          ),
          _Field(
            label: 'Additional Notes or Questions',
            child: TextField(
              controller: _notesCtrl,
              maxLines:   4,
              style: const TextStyle(fontSize: 15, color: _C.gray800),
              decoration: InputDecoration(
                hintText: 'Any questions or special accommodations...',
                hintStyle: const TextStyle(color: _C.gray400, fontSize: 14),
                filled:    true,
                fillColor: _C.white,
                contentPadding: const EdgeInsets.all(14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:   const BorderSide(color: _C.border, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:   const BorderSide(color: _C.gold, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 4: Review ─────────────────────────────────────────────────────────
  Widget _buildReviewStep() {
    final prog = _programs.firstWhere(
        (p) => p.$1 == _program,
        orElse: () => ('', '—', '—', '—', '—'));

    String finLabel = '—';
    if (_financing != null) {
      const finMap = {
        'self':      'Self-Pay / Out of Pocket',
        'va':        'VA / Veterans Benefits',
        'loan':      'Third-Party Student Loan',
        'workforce': 'Workforce Development Grant',
        'employer':  'Employer Sponsorship',
      };
      finLabel = finMap[_financing] ?? _financing!;
    }

    return _StepCard(
      title:    'Review Your Application',
      subtitle: 'Please review all information before submitting.',
      child: Column(
        children: [
          _ReviewSection(title: 'Personal Information', rows: [
            ('Full Name',     '${_firstCtrl.text} ${_lastCtrl.text}'),
            ('Date of Birth', _dobCtrl.text),
            ('Veteran',       _veteran ?? '—'),
            ('Current CDL',   _hasCdl   ?? 'None'),
          ]),
          _ReviewSection(title: 'Contact Information', rows: [
            ('Email',   _emailCtrl.text),
            ('Phone',   _phoneCtrl.text),
            ('Address', '${_addressCtrl.text}, ${_cityCtrl.text}, ${_state ?? ''} ${_zipCtrl.text}'),
          ]),
          _ReviewSection(title: 'Program Details', rows: [
            ('Program',    prog.$2),
            ('Duration',   prog.$3),
            ('Tuition',    prog.$4),
            ('Start Date', _startDate ?? '—'),
            ('Financing',  finLabel),
          ]),
          // Disclaimer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:        _C.goldPale,
              borderRadius: BorderRadius.circular(8),
              border:       Border.all(color: _C.goldLight),
            ),
            child: const Text(
              'By submitting this application, I certify that all information provided is accurate and complete. I understand this is an enrollment inquiry and not a binding contract. An admissions advisor will contact me within 1–2 business days.',
              style: TextStyle(
                fontSize: 12,
                color: _C.gray600,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Success ────────────────────────────────────────────────────────────────
  Widget _buildSuccess() {
    const nextSteps = [
      'Check your email for a confirmation',
      'Gather your ID and driving record',
      'Prepare for a call from admissions',
      'Review financing options if applicable',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Container(
            width: 80, height: 80,
            decoration: const BoxDecoration(
              color: _C.greenBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                size: 44, color: _C.green),
          ),
          const SizedBox(height: 24),
          const Text(
            'Application Submitted!',
            style: TextStyle(
              fontSize:   26,
              fontWeight: FontWeight.w700,
              color: _C.navy,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Thank you, ${_firstCtrl.text}. Your enrollment application has been received.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: _C.gray600,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'An admissions advisor will contact you within 1–2 business days.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: _C.gray600,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),

          // What's next
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color:        _C.gray50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "WHAT'S NEXT",
                  style: TextStyle(
                    fontSize:   11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: _C.navy,
                  ),
                ),
                const SizedBox(height: 14),
                // FIX: materialize to List<Widget> before spreading
                ...List<Widget>.generate(nextSteps.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24, height: 24,
                          decoration: const BoxDecoration(
                            color: _C.navy,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontSize:   11,
                                fontWeight: FontWeight.w700,
                                color: _C.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              nextSteps[index],
                              style: const TextStyle(
                                fontSize: 14,
                                color: _C.gray600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.navy,
                foregroundColor: _C.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text(
                'Return to Homepage',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom nav bar ─────────────────────────────────────────────────────────
  Widget _buildNavBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: _C.white,
        border: Border(top: BorderSide(color: _C.border)),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset:     const Offset(0, -4),
          )
        ],
      ),
      child: Row(
        children: [
          // Back
          GestureDetector(
            onTap: _step == 0 ? null : _back,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 13),
              decoration: BoxDecoration(
                color: _step == 0 ? _C.gray100 : _C.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _step == 0 ? _C.gray200 : _C.border,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.chevron_left_rounded,
                    size: 18,
                    color: _step == 0 ? _C.gray400 : _C.gray800),
                Text(
                  'Back',
                  style: TextStyle(
                    fontSize:   14,
                    fontWeight: FontWeight.w600,
                    color: _step == 0 ? _C.gray400 : _C.gray800,
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 12),

          // Next / Submit
          Expanded(
            child: GestureDetector(
              onTap: _loading
                  ? null
                  : _step < 3
                      ? _next
                      : _submit,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: _step == 3 ? _C.gold : _C.navy,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: _loading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _C.white,
                          ))
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _step < 3 ? 'Continue' : 'Submit Application',
                              style: TextStyle(
                                fontSize:   15,
                                fontWeight: FontWeight.w700,
                                color: _step == 3 ? _C.navy : _C.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              _step < 3
                                  ? Icons.chevron_right_rounded
                                  : Icons.check_circle_outline_rounded,
                              size: 18,
                              color: _step == 3 ? _C.navy : _C.white,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable Step Card ────────────────────────────────────────────────────────
class _StepCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _StepCard({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize:   22,
          fontWeight: FontWeight.w700,
          color: _C.navy,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        subtitle,
        style: const TextStyle(
          fontSize: 14,
          color: _C.gray600,
          height: 1.55,
        ),
      ),
      const SizedBox(height: 24),
      child,
    ],
  );
}

// ── Field wrapper ─────────────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final String  label;
  final String? error;
  final Widget  child;
  const _Field({required this.label, required this.child, this.error});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 6),
        child,
        if (error != null) _ErrorText(error!),
      ],
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize:   11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
      color: _C.navy,
    ),
  );
}

class _ErrorText extends StatelessWidget {
  final String text;
  const _ErrorText(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(children: [
      const Icon(Icons.error_outline, size: 12, color: _C.red),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontSize: 12, color: _C.red)),
    ]),
  );
}

// ── Text input ────────────────────────────────────────────────────────────────
class _Input extends StatefulWidget {
  final TextEditingController controller;
  final String               hint;
  final TextInputType        keyboard;
  final int?                 maxLength;

  const _Input({
    required this.controller,
    required this.hint,
    this.keyboard  = TextInputType.text,
    this.maxLength,
  });

  @override
  State<_Input> createState() => _InputState();
}

class _InputState extends State<_Input> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => Focus(
    onFocusChange: (v) => setState(() => _focused = v),
    child: TextField(
      controller:   widget.controller,
      keyboardType: widget.keyboard,
      maxLength:    widget.maxLength,
      style: const TextStyle(fontSize: 15, color: _C.gray800),
      decoration: InputDecoration(
        counterText: '',
        hintText:    widget.hint,
        hintStyle:   const TextStyle(color: _C.gray400),
        filled:      true,
        fillColor:   _C.white,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   const BorderSide(color: _C.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   const BorderSide(color: _C.gold, width: 1.5),
        ),
      ),
    ),
  );
}

// ── Dropdown ──────────────────────────────────────────────────────────────────
class _Dropdown extends StatelessWidget {
  final String?               value;
  final String                hint;
  final List<String>          items;
  final ValueChanged<String?> onChanged;
  const _Dropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    value:       value,
    hint:        Text(hint,
        style: const TextStyle(color: _C.gray400, fontSize: 15)),
    icon:        const Icon(Icons.keyboard_arrow_down_rounded,
        color: _C.gray400),
    style:       const TextStyle(fontSize: 15, color: _C.gray800),
    dropdownColor: _C.white,
    decoration: const InputDecoration(
      filled:    true,
      fillColor: _C.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide:   BorderSide(color: _C.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide:   BorderSide(color: _C.gold, width: 1.5),
      ),
    ),
    items: items.map((s) => DropdownMenuItem(
      value: s,
      child: Text(s),
    )).toList(),
    onChanged: onChanged,
  );
}

// ── Review Section ────────────────────────────────────────────────────────────
class _ReviewSection extends StatelessWidget {
  final String                 title;
  final List<(String, String)> rows;
  const _ReviewSection({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _C.gold, width: 2)),
          ),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize:   12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: _C.navy,
            ),
          ),
        ),
        // FIX: explicit List<Widget> to avoid spread nullability error
        ...rows.map<Widget>((r) => Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _C.gray100)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  r.$1,
                  style: const TextStyle(
                    fontSize:   12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: _C.gray600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  r.$2,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _C.gray800,
                  ),
                ),
              ),
            ],
          ),
        )).toList(),
      ],
    ),
  );
}