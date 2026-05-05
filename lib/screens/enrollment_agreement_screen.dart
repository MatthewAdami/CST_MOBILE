import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:cst_mobile/config/api_config.dart';
import 'package:cst_mobile/screens/signature_pad.dart';

// ── Colours ────────────────────────────────────────────────────────────────
const _navy    = Color(0xFF0B1F3A);
const _purple  = Color(0xFF7C3AED);
const _gold    = Color(0xFFB8963E);
const _success = Color(0xFF2D8A4E);
const _danger  = Color(0xFFC0392B);
const _border  = Color(0xFFE9ECEF);
const _muted   = Color(0xFF6C757D);
const _white   = Color(0xFFFFFFFF);
const _light   = Color(0xFFF8F9FA);

// ── API helpers ─────────────────────────────────────────────────────────────
Future<String> _getToken() async {
  final p = await SharedPreferences.getInstance();
  return p.getString('token') ?? '';
}

Map<String, String> _authHeaders(String token) => ApiConfig.authHeaders(token);

String get _enrollmentBase => '${ApiConfig.baseUrl}/api/enrollment-agreement/my';

// ── Step definitions ────────────────────────────────────────────────────────
const _steps = [
  'Course Selection', 'Student Info', 'Enrollment Info',
  'Qualifications', 'History & Record', 'Tuition & Fees',
  'Policies', 'DMV & Waiver', 'E-Signature',
];

// ══════════════════════════════════════════════════════════════════════════════
// FORM DATA MODEL
// ══════════════════════════════════════════════════════════════════════════════
class EnrollmentFormData {
  // Step 1
  String cdlClass = '', programType = '', transmission = '';
  Map<String, bool> endorsements = {
    'tankers': false, 'hazmat': false, 'doubles': false, 'airBrakes': false,
    'trailerCoupling': false, 'electronicLog': false, 'bitInspection': false,
    'cargoSecuring': false, 'drugsAlcohol': false, 'fatigueWellness': false,
  };

  // Step 2
  String firstName = '', middleName = '', lastName = '', address = '',
      city = '', state = '', zip = '', ssn = '', dob = '',
      cdlIdNo = '', email = '', phone = '', cell = '';

  // Step 3
  String currentlyEmployed = '', lastEmploymentDate = '', sponsoredByAgency = '',
      agencyName = '', agencyPosition = '', govtSponsored = '', govtAgencyName = '',
      govtContactPerson = '', govtContactPhone = '', hearAboutUs = '';

  // Step 4
  Map<String, String> qualifications = {
    'licenseExpired': '', 'ssnInvalid': '', 'trafficViolations': '',
    'licenseSuspended': '', 'outstandingFines': '', 'readingDifficulty': '',
    'visionProblems': '', 'epilepsyHistory': '', 'medications': '',
    'mentalHealthHistory': '', 'jobPlacementNeeded': '', 'eligibleOutOfState': '',
    'priorConvictions': '',
  };
  String suspensionDates = '', convictionDetails = '';

  // Step 5
  List<Map<String, String>> employmentHistory = [
    {'employer': '', 'position': '', 'jobDuties': '', 'startDate': '', 'endDate': ''}
  ];
  String statesHeld = '';
  List<Map<String, String>> violations = [
    {'violation': '', 'date': '', 'state': ''}
  ];
  String everServed = '', activeDuty = '', expectedDischarge = '', honorableDischarge = '';

  // Step 6
  String tuitionAmount = '', registrationFee = '', programMaterials = '', strf = '',
      downPayment = '', unpaidBalance = '', totalCharges = '', fundingSource = '', tuitionNotes = '';
  List<Map<String, String>> paymentSchedule = [
    {'amount': '', 'dueDate': ''}, {'amount': '', 'dueDate': ''}, {'amount': '', 'dueDate': ''},
  ];

  // Step 7
  Map<String, bool> policies = {
    'refundPolicyRead': false, 'drugFreePolicyRead': false,
    'codeOfConductRead': false, 'complaintPolicyRead': false,
    'transferabilityRead': false, 'financialAssistRead': false,
    'studentLoanRead': false, 'strfRead': false,
  };

  // Step 8
  Map<String, bool> dmvAndWaiver = {
    'dmvFeesAcknowledged': false, 'retestFeeAcknowledged': false,
    'waiverRead': false, 'physicallyFit': false,
    'photoVideoConsent': false, 'studentAcknowledgement': false,
  };

  // Step 9
  String printedName = '';
  bool agreed = false;

  Map<String, dynamic> toJson() => {
    'courseSelection': {
      'cdlClass': cdlClass, 'programType': programType, 'transmission': transmission,
      'endorsements': endorsements,
    },
    'studentInfo': {
      'firstName': firstName, 'middleName': middleName, 'lastName': lastName,
      'address': address, 'city': city, 'state': state, 'zip': zip,
      'ssn': ssn, 'dob': dob, 'cdlIdNo': cdlIdNo, 'email': email,
      'phone': phone, 'cell': cell,
    },
    'enrollmentInfo': {
      'currentlyEmployed': currentlyEmployed, 'lastEmploymentDate': lastEmploymentDate,
      'sponsoredByAgency': sponsoredByAgency, 'agencyName': agencyName,
      'agencyPosition': agencyPosition, 'govtSponsored': govtSponsored,
      'govtAgencyName': govtAgencyName, 'govtContactPerson': govtContactPerson,
      'govtContactPhone': govtContactPhone, 'hearAboutUs': hearAboutUs,
    },
    'qualifications': {...qualifications, 'suspensionDates': suspensionDates, 'convictionDetails': convictionDetails},
    'employmentHistory': employmentHistory,
    'drivingRecord': {'statesHeld': statesHeld, 'violations': violations},
    'militaryService': {
      'everServed': everServed, 'activeDuty': activeDuty,
      'expectedDischarge': expectedDischarge, 'honorableDischarge': honorableDischarge,
    },
    'tuition': {
      'tuitionAmount': tuitionAmount, 'registrationFee': registrationFee,
      'programMaterials': programMaterials, 'strf': strf,
      'downPayment': downPayment, 'unpaidBalance': unpaidBalance,
      'totalCharges': totalCharges, 'fundingSource': fundingSource,
      'paymentSchedule': paymentSchedule, 'notes': tuitionNotes,
    },
    'policies': policies,
    'dmvAndWaiver': dmvAndWaiver,
    'signature': {'printedName': printedName, 'agreed': agreed},
  };

  void mergeFromJson(Map<String, dynamic> d) {
    final cs = d['courseSelection'] as Map? ?? {};
    cdlClass = cs['cdlClass'] ?? '';
    programType = cs['programType'] ?? '';
    transmission = cs['transmission'] ?? '';
    if (cs['endorsements'] is Map) {
      cs['endorsements'].forEach((k, v) { if (endorsements.containsKey(k)) endorsements[k] = v == true; });
    }

    final si = d['studentInfo'] as Map? ?? {};
    firstName = si['firstName'] ?? ''; middleName = si['middleName'] ?? '';
    lastName  = si['lastName']  ?? ''; address    = si['address']    ?? '';
    city      = si['city']      ?? ''; state      = si['state']      ?? '';
    zip       = si['zip']       ?? ''; ssn        = si['ssn']        ?? '';
    dob       = si['dob']       ?? ''; cdlIdNo    = si['cdlIdNo']    ?? '';
    email     = si['email']     ?? ''; phone      = si['phone']      ?? '';
    cell      = si['cell']      ?? '';

    final ei = d['enrollmentInfo'] as Map? ?? {};
    currentlyEmployed   = ei['currentlyEmployed']   ?? '';
    lastEmploymentDate  = ei['lastEmploymentDate']  ?? '';
    sponsoredByAgency   = ei['sponsoredByAgency']   ?? '';
    agencyName          = ei['agencyName']          ?? '';
    agencyPosition      = ei['agencyPosition']      ?? '';
    govtSponsored       = ei['govtSponsored']       ?? '';
    govtAgencyName      = ei['govtAgencyName']      ?? '';
    govtContactPerson   = ei['govtContactPerson']   ?? '';
    govtContactPhone    = ei['govtContactPhone']    ?? '';
    hearAboutUs         = ei['hearAboutUs']         ?? '';

    final q = d['qualifications'] as Map? ?? {};
    qualifications.forEach((k, _) { qualifications[k] = q[k]?.toString() ?? ''; });
    suspensionDates  = q['suspensionDates']  ?? '';
    convictionDetails = q['convictionDetails'] ?? '';

    if (d['employmentHistory'] is List && (d['employmentHistory'] as List).isNotEmpty) {
      employmentHistory = (d['employmentHistory'] as List)
          .map((e) => Map<String, String>.from((e as Map).map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))))
          .toList();
    }

    final dr = d['drivingRecord'] as Map? ?? {};
    statesHeld = dr['statesHeld'] ?? '';
    if (dr['violations'] is List && (dr['violations'] as List).isNotEmpty) {
      violations = (dr['violations'] as List)
          .map((e) => Map<String, String>.from((e as Map).map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))))
          .toList();
    }

    final ms = d['militaryService'] as Map? ?? {};
    everServed         = ms['everServed']         ?? '';
    activeDuty         = ms['activeDuty']         ?? '';
    expectedDischarge  = ms['expectedDischarge']  ?? '';
    honorableDischarge = ms['honorableDischarge'] ?? '';

    final t = d['tuition'] as Map? ?? {};
    tuitionAmount   = t['tuitionAmount']   ?? '';
    registrationFee = t['registrationFee'] ?? '';
    programMaterials = t['programMaterials'] ?? '';
    strf            = t['strf']            ?? '';
    downPayment     = t['downPayment']     ?? '';
    unpaidBalance   = t['unpaidBalance']   ?? '';
    totalCharges    = t['totalCharges']    ?? '';
    fundingSource   = t['fundingSource']   ?? '';
    tuitionNotes    = t['notes']           ?? '';
    if (t['paymentSchedule'] is List && (t['paymentSchedule'] as List).isNotEmpty) {
      paymentSchedule = (t['paymentSchedule'] as List)
          .map((e) => Map<String, String>.from((e as Map).map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))))
          .toList();
    }

    final pol = d['policies'] as Map? ?? {};
    policies.forEach((k, _) { policies[k] = pol[k] == true; });

    final dmv = d['dmvAndWaiver'] as Map? ?? {};
    dmvAndWaiver.forEach((k, _) { dmvAndWaiver[k] = dmv[k] == true; });

    final sig = d['signature'] as Map? ?? {};
    printedName = sig['printedName'] ?? '';
    agreed      = sig['agreed'] == true;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(children: [
      Container(width: 4, height: 18, decoration: BoxDecoration(color: _purple, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      Expanded(child: Text(text.toUpperCase(),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _navy, letterSpacing: 0.8))),
    ]),
  );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel(this.text, {this.required = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: RichText(text: TextSpan(
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _muted, letterSpacing: 0.7),
      children: [
        TextSpan(text: text.toUpperCase()),
        if (required) const TextSpan(text: ' *', style: TextStyle(color: _danger)),
      ],
    )),
  );
}

class _AppInput extends StatelessWidget {
  final String? label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool required;
  final String? hint;
  final TextInputType keyboardType;
  final bool obscure;

  const _AppInput({
    this.label, required this.value, required this.onChanged,
    this.required = false, this.hint, this.keyboardType = TextInputType.text,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (label != null) _FieldLabel(label!, required: required),
      TextFormField(
        initialValue: value,
        onChanged: onChanged,
        keyboardType: keyboardType,
        obscureText: obscure,
        style: const TextStyle(fontSize: 13, color: _navy),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 13, color: _muted),
          contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _purple)),
          filled: true, fillColor: _white,
        ),
      ),
      if (hint != null) Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(hint!, style: const TextStyle(fontSize: 10, color: _muted)),
      ),
    ],
  );
}

class _AppSelect extends StatelessWidget {
  final String? label;
  final String value;
  final ValueChanged<String> onChanged;
  final List<Map<String, String>> options;
  final bool required;

  const _AppSelect({this.label, required this.value, required this.onChanged, required this.options, this.required = false});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (label != null) _FieldLabel(label!, required: required),
      DropdownButtonFormField<String>(
        value: value.isEmpty ? null : value,
        hint: const Text('— Select —', style: TextStyle(fontSize: 13, color: _muted)),
        style: const TextStyle(fontSize: 13, color: _navy),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _purple)),
          filled: true, fillColor: _white,
        ),
        onChanged: (v) { if (v != null) onChanged(v); },
        items: options.map((o) => DropdownMenuItem(value: o['value'], child: Text(o['label']!))).toList(),
      ),
    ],
  );
}

class _YesNo extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  const _YesNo({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: _light, borderRadius: BorderRadius.circular(8), border: Border.all(color: _border)),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: _navy, height: 1.4))),
      const SizedBox(width: 12),
      Row(children: ['yes', 'no'].map((v) => Padding(
        padding: const EdgeInsets.only(left: 6),
        child: GestureDetector(
          onTap: () => onChanged(v),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: value == v ? (v == 'yes' ? _success : _danger) : _white,
              border: Border.all(color: value == v ? Colors.transparent : _border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(v.toUpperCase(), style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5,
              color: value == v ? _white : _muted,
            )),
          ),
        ),
      )).toList()),
    ]),
  );
}

class _AppCheckbox extends StatelessWidget {
  final String label;
  final bool checked;
  final ValueChanged<bool> onChanged;
  final String? description;

  const _AppCheckbox({required this.label, required this.checked, required this.onChanged, this.description});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => onChanged(!checked),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: checked ? const Color(0xFFF0FDF4) : _light,
        border: Border.all(color: checked ? const Color(0xFF86EFAC) : _border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 20, height: 20, margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: checked ? _success : _white,
            border: Border.all(color: checked ? _success : _border, width: 2),
            borderRadius: BorderRadius.circular(5),
          ),
          child: checked ? const Icon(Icons.check, size: 13, color: _white) : null,
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _navy)),
          if (description != null) ...[
            const SizedBox(height: 3),
            Text(description!, style: const TextStyle(fontSize: 12, color: _muted, height: 1.5)),
          ],
        ])),
      ]),
    ),
  );
}

class _InfoBanner extends StatelessWidget {
  final String text;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;

  const _InfoBanner(this.text, {
    this.bgColor = const Color(0xFFFFF9EC),
    this.borderColor = const Color(0xFFFDE68A),
    this.textColor = const Color(0xFF92400E),
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: bgColor, border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text, style: TextStyle(fontSize: 12, color: textColor, height: 1.5)),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// STEP 1 — Course Selection
// ══════════════════════════════════════════════════════════════════════════════
class _Step1 extends StatelessWidget {
  final EnrollmentFormData data;
  final VoidCallback onChanged;
  const _Step1({required this.data, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const _SectionTitle('Please select the course or courses you will be enrolling for'),
    _AppSelect(
      label: 'CDL Class', value: data.cdlClass, required: true,
      onChanged: (v) { data.cdlClass = v; onChanged(); },
      options: [{'value': 'Class A', 'label': 'CDL Class A'}, {'value': 'Class B', 'label': 'CDL Class B'}],
    ),
    const SizedBox(height: 12),
    _AppSelect(
      label: 'Program Type', value: data.programType, required: true,
      onChanged: (v) { data.programType = v; onChanged(); },
      options: [
        {'value': 'Road Skills', 'label': 'Road Skills Program'},
        {'value': 'Standard', 'label': 'Standard Program'},
        {'value': 'Advance', 'label': 'Advance Program'},
        {'value': 'Refresher', 'label': 'Refresher Course'},
      ],
    ),
    const SizedBox(height: 12),
    _AppSelect(
      label: 'Transmission', value: data.transmission,
      onChanged: (v) { data.transmission = v; onChanged(); },
      options: [
        {'value': 'Automatic', 'label': 'Automatic Transmission'},
        {'value': 'Manual', 'label': 'Manual Transmission'},
        {'value': 'Both', 'label': 'Both'},
      ],
    ),
    const SizedBox(height: 20),
    const _FieldLabel('Add-on Endorsements (select all that apply)'),
    const SizedBox(height: 8),
    ...[
      ['tankers', 'Tankers'], ['hazmat', 'HazMat'], ['doubles', 'Doubles'],
      ['airBrakes', 'Air Brakes'], ['trailerCoupling', 'Trailer Coupling'],
      ['electronicLog', 'Electronic Log'], ['bitInspection', 'BIT Inspection'],
      ['cargoSecuring', 'Cargo Securing'], ['drugsAlcohol', 'Drugs/Alcohol'],
      ['fatigueWellness', 'Fatigue/Wellness'],
    ].map((e) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _AppCheckbox(
        label: e[1],
        checked: data.endorsements[e[0]] ?? false,
        onChanged: (v) { data.endorsements[e[0]] = v; onChanged(); },
      ),
    )),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════════
// STEP 2 — Student Info
// ══════════════════════════════════════════════════════════════════════════════
class _Step2 extends StatelessWidget {
  final EnrollmentFormData data;
  final VoidCallback onChanged;
  const _Step2({required this.data, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const _SectionTitle('Student Information — Please Print Clearly'),
    _AppInput(label: 'First Name', value: data.firstName, required: true, onChanged: (v) { data.firstName = v; onChanged(); }),
    const SizedBox(height: 12),
    _AppInput(label: 'Middle Name', value: data.middleName, onChanged: (v) { data.middleName = v; onChanged(); }),
    const SizedBox(height: 12),
    _AppInput(label: 'Last Name', value: data.lastName, required: true, onChanged: (v) { data.lastName = v; onChanged(); }),
    const SizedBox(height: 12),
    _AppInput(label: 'Street Address', value: data.address, required: true, onChanged: (v) { data.address = v; onChanged(); }),
    const SizedBox(height: 12),
    _AppInput(label: 'City', value: data.city, required: true, onChanged: (v) { data.city = v; onChanged(); }),
    const SizedBox(height: 12),
    Row(children: [
      Expanded(child: _AppInput(label: 'State', value: data.state, required: true, onChanged: (v) { data.state = v; onChanged(); })),
      const SizedBox(width: 12),
      Expanded(child: _AppInput(label: 'Zip Code', value: data.zip, required: true, keyboardType: TextInputType.number, onChanged: (v) { data.zip = v; onChanged(); })),
    ]),
    const SizedBox(height: 12),
    _AppInput(label: 'Social Security (xxx-xx-xxxx)', value: data.ssn, required: true,
      hint: 'Stored securely and encrypted', keyboardType: TextInputType.number, obscure: true,
      onChanged: (v) { data.ssn = v; onChanged(); }),
    const SizedBox(height: 12),
    _AppInput(label: 'Date of Birth (YYYY-MM-DD)', value: data.dob, required: true,
      keyboardType: TextInputType.datetime, onChanged: (v) { data.dob = v; onChanged(); }),
    const SizedBox(height: 12),
    _AppInput(label: 'CDL/ID No.', value: data.cdlIdNo, onChanged: (v) { data.cdlIdNo = v; onChanged(); }),
    const SizedBox(height: 12),
    _AppInput(label: 'Email', value: data.email, required: true, keyboardType: TextInputType.emailAddress, onChanged: (v) { data.email = v; onChanged(); }),
    const SizedBox(height: 12),
    Row(children: [
      Expanded(child: _AppInput(label: 'Telephone', value: data.phone, required: true, keyboardType: TextInputType.phone, onChanged: (v) { data.phone = v; onChanged(); })),
      const SizedBox(width: 12),
      Expanded(child: _AppInput(label: 'Cell', value: data.cell, keyboardType: TextInputType.phone, onChanged: (v) { data.cell = v; onChanged(); })),
    ]),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════════
// STEP 3 — Enrollment Info
// ══════════════════════════════════════════════════════════════════════════════
class _Step3 extends StatelessWidget {
  final EnrollmentFormData data;
  final VoidCallback onChanged;
  const _Step3({required this.data, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const _SectionTitle('Enrollment Information'),
    _YesNo(label: 'Are you currently employed?', value: data.currentlyEmployed, onChanged: (v) { data.currentlyEmployed = v; onChanged(); }),
    if (data.currentlyEmployed == 'no') ...[
      const SizedBox(height: 10),
      _AppInput(label: 'If NO, last date of employment (YYYY-MM-DD)', value: data.lastEmploymentDate, keyboardType: TextInputType.datetime, onChanged: (v) { data.lastEmploymentDate = v; onChanged(); }),
    ],
    const SizedBox(height: 10),
    _YesNo(label: 'Are you sponsored by an agency?', value: data.sponsoredByAgency, onChanged: (v) { data.sponsoredByAgency = v; onChanged(); }),
    if (data.sponsoredByAgency == 'yes') ...[
      const SizedBox(height: 10),
      _AppInput(label: 'Agency Name', value: data.agencyName, onChanged: (v) { data.agencyName = v; onChanged(); }),
      const SizedBox(height: 10),
      _AppInput(label: 'Your Position at Agency', value: data.agencyPosition, onChanged: (v) { data.agencyPosition = v; onChanged(); }),
    ],
    const SizedBox(height: 10),
    _YesNo(label: 'Are you sponsored by a city, state, or local government office?', value: data.govtSponsored, onChanged: (v) { data.govtSponsored = v; onChanged(); }),
    if (data.govtSponsored == 'yes') ...[
      const SizedBox(height: 10),
      _AppInput(label: 'Agency Name', value: data.govtAgencyName, onChanged: (v) { data.govtAgencyName = v; onChanged(); }),
      const SizedBox(height: 10),
      _AppInput(label: 'Contact Person', value: data.govtContactPerson, onChanged: (v) { data.govtContactPerson = v; onChanged(); }),
      const SizedBox(height: 10),
      _AppInput(label: 'Phone Number', value: data.govtContactPhone, keyboardType: TextInputType.phone, onChanged: (v) { data.govtContactPhone = v; onChanged(); }),
    ],
    const SizedBox(height: 16),
    const _FieldLabel('How did you hear about us?'),
    const SizedBox(height: 8),
    ...['Print Ad', 'Social Media', 'Website', 'Search Engine', 'Agency Referral', 'Personal Referral'].map((opt) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _AppCheckbox(
        label: opt,
        checked: data.hearAboutUs == opt,
        onChanged: (_) { data.hearAboutUs = opt; onChanged(); },
      ),
    )),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════════
// STEP 4 — Qualifications
// ══════════════════════════════════════════════════════════════════════════════
class _Step4 extends StatelessWidget {
  final EnrollmentFormData data;
  final VoidCallback onChanged;
  const _Step4({required this.data, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final questions = [
      ['licenseExpired', "Is your driver's license currently expired, suspended, or invalid?"],
      ['ssnInvalid', 'Is your social security card invalid?'],
      ['trafficViolations', 'Have you been convicted of more than 3 moving traffic violations in the last 3 years?'],
      ['licenseSuspended', "Has your driver's license ever been suspended or revoked?"],
      ['outstandingFines', 'Do you have any outstanding or unpaid traffic fines or citations in any state?'],
      ['readingDifficulty', 'Do you have serious difficulty reading or writing in English language?'],
      ['visionProblems', 'Do you have vision problems, worse than 20/40 in either eye, that would be deemed uncorrectable?'],
      ['epilepsyHistory', 'Do you have any personal history of epilepsy, diabetes, fainting or dizzy spells?'],
      ['medications', 'Are you currently taking medications?'],
      ['mentalHealthHistory', 'Do you have any history of behavioral health, psychiatric or mental illness?'],
      ['jobPlacementNeeded', 'Will you need Job Placement Assistance?'],
      ['eligibleOutOfState', 'Are you eligible to work out of state?'],
      ['priorConvictions', 'Have you ever been convicted of any offenses in ANY court jurisdiction?'],
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionTitle('Enrollment Qualifications'),
      const _InfoBanner('Please answer all questions honestly. This information is used for program eligibility and safety purposes.'),
      const SizedBox(height: 12),
      ...questions.map((q) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _YesNo(
            label: q[1],
            value: data.qualifications[q[0]] ?? '',
            onChanged: (v) { data.qualifications[q[0]] = v; onChanged(); },
          ),
          if (q[0] == 'licenseSuspended' && data.qualifications['licenseSuspended'] == 'yes') ...[
            const SizedBox(height: 8),
            _AppInput(
              label: 'Provide accurate dates and length of suspension',
              value: data.suspensionDates,
              onChanged: (v) { data.suspensionDates = v; onChanged(); },
            ),
          ],
          if (q[0] == 'priorConvictions' && data.qualifications['priorConvictions'] == 'yes') ...[
            const SizedBox(height: 8),
            _AppInput(
              label: 'Please provide dates and explanation',
              value: data.convictionDetails,
              hint: 'Provide details...',
              onChanged: (v) { data.convictionDetails = v; onChanged(); },
            ),
          ],
        ]),
      )),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STEP 5 — History & Record
// ══════════════════════════════════════════════════════════════════════════════
class _Step5 extends StatefulWidget {
  final EnrollmentFormData data;
  final VoidCallback onChanged;
  const _Step5({required this.data, required this.onChanged});
  @override
  State<_Step5> createState() => _Step5State();
}

class _Step5State extends State<_Step5> {
  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Employment
      const _SectionTitle('Employment History'),
      ...data.employmentHistory.asMap().entries.map((entry) {
        final idx = entry.key;
        final emp = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _light, border: Border.all(color: _border), borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(
                idx == 0 ? 'Most Recent Employer' : idx == 1 ? 'Previous Employer' : 'Employer ${idx + 1}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _muted, letterSpacing: 0.5),
              )),
              if (idx > 0) GestureDetector(
                onTap: () { data.employmentHistory.removeAt(idx); widget.onChanged(); setState(() {}); },
                child: const Icon(Icons.delete_outline, size: 18, color: _danger),
              ),
            ]),
            const SizedBox(height: 12),
            _AppInput(label: 'Employer', value: emp['employer'] ?? '', onChanged: (v) { data.employmentHistory[idx]['employer'] = v; widget.onChanged(); }),
            const SizedBox(height: 10),
            _AppInput(label: 'Position Held', value: emp['position'] ?? '', onChanged: (v) { data.employmentHistory[idx]['position'] = v; widget.onChanged(); }),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _AppInput(label: 'Start Date', value: emp['startDate'] ?? '', keyboardType: TextInputType.datetime, onChanged: (v) { data.employmentHistory[idx]['startDate'] = v; widget.onChanged(); })),
              const SizedBox(width: 10),
              Expanded(child: _AppInput(label: 'End Date', value: emp['endDate'] ?? '', keyboardType: TextInputType.datetime, onChanged: (v) { data.employmentHistory[idx]['endDate'] = v; widget.onChanged(); })),
            ]),
            const SizedBox(height: 10),
            _AppInput(label: 'Job Duties', value: emp['jobDuties'] ?? '', onChanged: (v) { data.employmentHistory[idx]['jobDuties'] = v; widget.onChanged(); }),
          ]),
        );
      }),
      TextButton.icon(
        onPressed: () { data.employmentHistory.add({'employer': '', 'position': '', 'jobDuties': '', 'startDate': '', 'endDate': ''}); widget.onChanged(); setState(() {}); },
        icon: const Icon(Icons.add, size: 16, color: _purple),
        label: const Text('Add Another Employer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _purple)),
        style: TextButton.styleFrom(side: const BorderSide(color: _purple, style: BorderStyle.solid), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      ),
      const SizedBox(height: 24),

      // Driving Record
      const _SectionTitle('Driving Record — List all states where you held a license (last 5 years)'),
      _AppInput(label: 'States', value: data.statesHeld, hint: 'e.g. CA, TX, AZ', onChanged: (v) { data.statesHeld = v; widget.onChanged(); }),
      const SizedBox(height: 16),
      const _FieldLabel('Motor Vehicle / Traffic Violations (last 5 years)'),
      const SizedBox(height: 8),
      ...data.violations.asMap().entries.map((entry) {
        final idx = entry.key;
        final vio = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(flex: 3, child: _AppInput(label: idx == 0 ? 'Violation' : null, value: vio['violation'] ?? '', hint: 'Description', onChanged: (v) { data.violations[idx]['violation'] = v; widget.onChanged(); })),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: _AppInput(label: idx == 0 ? 'Date' : null, value: vio['date'] ?? '', keyboardType: TextInputType.datetime, onChanged: (v) { data.violations[idx]['date'] = v; widget.onChanged(); })),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: _AppInput(label: idx == 0 ? 'State' : null, value: vio['state'] ?? '', onChanged: (v) { data.violations[idx]['state'] = v; widget.onChanged(); })),
            if (idx > 0) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () { data.violations.removeAt(idx); widget.onChanged(); setState(() {}); },
                child: const Padding(padding: EdgeInsets.only(bottom: 10), child: Icon(Icons.delete_outline, size: 18, color: _danger)),
              ),
            ],
          ]),
        );
      }),
      TextButton.icon(
        onPressed: () { data.violations.add({'violation': '', 'date': '', 'state': ''}); widget.onChanged(); setState(() {}); },
        icon: const Icon(Icons.add, size: 16, color: _purple),
        label: const Text('Add Violation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _purple)),
        style: TextButton.styleFrom(side: const BorderSide(color: _purple, style: BorderStyle.solid), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      ),
      const SizedBox(height: 24),

      // Military
      const _SectionTitle('Military Scholarship Eligibility'),
      _YesNo(label: 'Have you ever served in the armed forces?', value: data.everServed, onChanged: (v) { data.everServed = v; widget.onChanged(); }),
      const SizedBox(height: 10),
      _YesNo(label: 'Are you currently ACTIVE DUTY or RESERVE?', value: data.activeDuty, onChanged: (v) { data.activeDuty = v; widget.onChanged(); }),
      if (data.activeDuty == 'yes') ...[
        const SizedBox(height: 10),
        _AppInput(label: 'Expected date of discharge', value: data.expectedDischarge, keyboardType: TextInputType.datetime, onChanged: (v) { data.expectedDischarge = v; widget.onChanged(); }),
      ],
      const SizedBox(height: 10),
      _YesNo(label: 'Have you obtained an honorable discharge? (Must provide DD214)', value: data.honorableDischarge, onChanged: (v) { data.honorableDischarge = v; widget.onChanged(); }),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STEP 6 — Tuition & Fees
// ══════════════════════════════════════════════════════════════════════════════
class _Step6 extends StatelessWidget {
  final EnrollmentFormData data;
  final VoidCallback onChanged;
  const _Step6({required this.data, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const _SectionTitle('Tuition Outline of Fees'),
    const _InfoBanner(
      'These amounts will be confirmed by your admissions advisor.',
      bgColor: Color(0xFFEFF6FF),
      borderColor: Color(0xFFBFDBFE),
      textColor: Color(0xFF1E40AF),
    ),
    const SizedBox(height: 16),
    Row(children: [
      Expanded(child: _AppInput(label: 'Tuition (\$)', value: data.tuitionAmount, keyboardType: TextInputType.number, onChanged: (v) { data.tuitionAmount = v; onChanged(); })),
      const SizedBox(width: 12),
      Expanded(child: _AppInput(label: 'Registration Fee (\$)', value: data.registrationFee, keyboardType: TextInputType.number, onChanged: (v) { data.registrationFee = v; onChanged(); })),
    ]),
    const SizedBox(height: 12),
    Row(children: [
      Expanded(child: _AppInput(label: 'Program Materials (\$)', value: data.programMaterials, keyboardType: TextInputType.number, onChanged: (v) { data.programMaterials = v; onChanged(); })),
      const SizedBox(width: 12),
      Expanded(child: _AppInput(label: 'STRF (\$)', value: data.strf, keyboardType: TextInputType.number, hint: '\$0.00 per \$1,000', onChanged: (v) { data.strf = v; onChanged(); })),
    ]),
    const SizedBox(height: 12),
    Row(children: [
      Expanded(child: _AppInput(label: 'Down Payment (\$)', value: data.downPayment, keyboardType: TextInputType.number, onChanged: (v) { data.downPayment = v; onChanged(); })),
      const SizedBox(width: 12),
      Expanded(child: _AppInput(label: 'Unpaid Balance (\$)', value: data.unpaidBalance, keyboardType: TextInputType.number, onChanged: (v) { data.unpaidBalance = v; onChanged(); })),
    ]),
    const SizedBox(height: 12),
    _AppInput(label: 'Total Charges (\$)', value: data.totalCharges, keyboardType: TextInputType.number, onChanged: (v) { data.totalCharges = v; onChanged(); }),
    const SizedBox(height: 20),
    const _FieldLabel('Funding Source'),
    const SizedBox(height: 8),
    ...['Help', 'WIOA', 'Voucher', 'Cash', 'Credit', 'Other'].map((src) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _AppCheckbox(label: src, checked: data.fundingSource == src, onChanged: (_) { data.fundingSource = src; onChanged(); }),
    )),
    const SizedBox(height: 20),
    const _FieldLabel('Payment Schedule'),
    const SizedBox(height: 8),
    ...data.paymentSchedule.asMap().entries.map((entry) {
      final idx = entry.key;
      final suffix = idx == 0 ? 'st' : idx == 1 ? 'nd' : 'rd';
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _light, border: Border.all(color: _border), borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${idx + 1}$suffix Payment', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _muted, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _AppInput(label: 'Amount (\$)', value: entry.value['amount'] ?? '', keyboardType: TextInputType.number, onChanged: (v) { data.paymentSchedule[idx]['amount'] = v; onChanged(); })),
            const SizedBox(width: 12),
            Expanded(child: _AppInput(label: 'Due Date', value: entry.value['dueDate'] ?? '', keyboardType: TextInputType.datetime, onChanged: (v) { data.paymentSchedule[idx]['dueDate'] = v; onChanged(); })),
          ]),
        ]),
      );
    }),
    const SizedBox(height: 12),
    _AppInput(label: 'Notes', value: data.tuitionNotes, hint: 'Additional payment notes...', onChanged: (v) { data.tuitionNotes = v; onChanged(); }),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════════
// STEP 7 — Policies
// ══════════════════════════════════════════════════════════════════════════════
class _Step7 extends StatelessWidget {
  final EnrollmentFormData data;
  final VoidCallback onChanged;
  const _Step7({required this.data, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final policies = [
      ['refundPolicyRead', 'Refund, Cancellation & Withdrawal Policy', 'I have read and understand the refund policy. I understand I may cancel within 7 days of enrollment for a full refund less \$500 processing fee.'],
      ['transferabilityRead', 'Transferability of Credits', 'I understand that credits earned at CST may not transfer to other institutions.'],
      ['financialAssistRead', 'Financial Assistance Policy', 'I understand that CST does not offer financial aid and I am responsible for all program fees.'],
      ['studentLoanRead', 'Student Loan Policy', 'I understand my obligations regarding any federal or state loans and the consequences of default.'],
      ['strfRead', 'Student Tuition Recovery Fund (STRF)', 'I have read and understand the STRF policy and my eligibility requirements as a California resident.'],
      ['drugFreePolicyRead', 'Drug-Free Instructional Workplace Policy', 'I agree to comply with the Drug-Free Instructional Workplace Policy.'],
      ['codeOfConductRead', 'Student Rules, Regulations & Code of Conduct', 'I have read, understood, and agreed to comply with all rules and regulations. Violations may lead to dismissal.'],
      ['complaintPolicyRead', 'Student Complaint Policy', 'I have read and agree to comply with the Student Complaint Policy.'],
    ];

    final allChecked = data.policies.values.every((v) => v);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionTitle('Policies & Acknowledgments'),
      const _InfoBanner('You must read and acknowledge all policies before proceeding. Click each item to confirm you have read and understood it.'),
      const SizedBox(height: 12),
      ...policies.map((p) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _AppCheckbox(
          label: p[1], description: p[2],
          checked: data.policies[p[0]] ?? false,
          onChanged: (v) { data.policies[p[0]] = v; onChanged(); },
        ),
      )),
      if (allChecked) Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF0FDF4), border: Border.all(color: const Color(0xFF86EFAC)), borderRadius: BorderRadius.circular(8)),
        child: const Row(children: [
          Icon(Icons.check_circle, size: 16, color: _success),
          SizedBox(width: 8),
          Text('All policies acknowledged', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _success)),
        ]),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STEP 8 — DMV & Waiver
// ══════════════════════════════════════════════════════════════════════════════
class _Step8 extends StatelessWidget {
  final EnrollmentFormData data;
  final VoidCallback onChanged;
  const _Step8({required this.data, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = [
      ['dmvFeesAcknowledged', 'DMV Testing Fees Acknowledged', 'I understand and agree to pay all DMV fees including: Commercial Class C (\$35), Commercial Permit (\$85), DOT Medical Examination (\$50-\$150), and retest fees (\$35).'],
      ['retestFeeAcknowledged', 'Retest Fee Acknowledged', 'I understand that a \$350.00 retest fee applies if I fail or no-show for my scheduled CDL test at the DMV.'],
      ['waiverRead', 'Accident Waiver & Release of Liability', 'I waive, release, and discharge CST from any and all liability for death, disability, personal injury, or property damage arising from participation in training activities.'],
      ['physicallyFit', 'Physical Fitness Certification', 'I certify that I am physically fit, sufficiently prepared, and there are no health-related reasons that would preclude my participation.'],
      ['photoVideoConsent', 'Photo & Video Consent', 'I understand and agree that I may be photographed or filmed during training. I allow my photo/video likeness to be used for legitimate purposes by CST.'],
      ['studentAcknowledgement', 'Student Acknowledgement', 'I acknowledge that CST, its administration, staff, directors, officers, volunteers, and agents are NOT responsible for errors, omissions, or failures to act.'],
    ];

    final allChecked = data.dmvAndWaiver.values.every((v) => v);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionTitle('DMV Testing Fees & Accident Waiver'),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _light, border: Border.all(color: _border), borderRadius: BorderRadius.circular(8)),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Behind the Wheel Training — 251 S. G Street, San Bernardino Training Yard',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _navy)),
          SizedBox(height: 6),
          Text('This agreement covers: Pre-Trip | Skills | Driving Techniques | Instruction | DMV Testing',
            style: TextStyle(fontSize: 12, color: _muted, height: 1.5)),
        ]),
      ),
      const SizedBox(height: 12),
      ...items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _AppCheckbox(
          label: item[1], description: item[2],
          checked: data.dmvAndWaiver[item[0]] ?? false,
          onChanged: (v) { data.dmvAndWaiver[item[0]] = v; onChanged(); },
        ),
      )),
      if (allChecked) Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF0FDF4), border: Border.all(color: const Color(0xFF86EFAC)), borderRadius: BorderRadius.circular(8)),
        child: const Row(children: [
          Icon(Icons.check_circle, size: 16, color: _success),
          SizedBox(width: 8),
          Text('All items acknowledged', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _success)),
        ]),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STEP 9 — E-Signature
// ══════════════════════════════════════════════════════════════════════════════
class _Step9 extends StatelessWidget {
  final EnrollmentFormData data;
  final VoidCallback onChanged;
  final String studentName;
  const _Step9({required this.data, required this.onChanged, required this.studentName});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dateStr = '${_monthName(today.month)} ${today.day}, ${today.year}';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionTitle('E-Signature & Final Submission'),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9EC),
          border: Border.all(color: const Color(0xFFFDE68A)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('THIS ENROLLMENT AGREEMENT IS A LEGALLY BINDING INSTRUMENT WHEN SIGNED BY THE STUDENT AND ACCEPTED BY THE SCHOOL.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF92400E))),
          SizedBox(height: 8),
          Text('I UNDERSTAND THAT THIS IS A LEGALLY BINDING CONTRACT. MY SIGNATURE BELOW CERTIFIES THAT I HAVE READ, UNDERSTOOD, AND AGREED TO MY RIGHTS AND RESPONSIBILITIES.',
            style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.6)),
        ]),
      ),
      const SizedBox(height: 16),
      _AppCheckbox(
        label: 'I agree to all terms and conditions',
        description: 'By checking this box, I confirm that I have read all 9 sections of this enrollment agreement and agree to be bound by its terms.',
        checked: data.agreed,
        onChanged: (v) { data.agreed = v; onChanged(); },
      ),
      const SizedBox(height: 16),
      _AppInput(
        label: 'Printed Name of Student',
        value: data.printedName,
        required: true,
        hint: studentName.isNotEmpty ? studentName : 'Enter your full legal name',
        onChanged: (v) { data.printedName = v; onChanged(); },
      ),
      const SizedBox(height: 16),
      const _FieldLabel('Signature of Student', required: true),
      const SizedBox(height: 4),
      const Text('Type your full name below as your electronic signature.',
        style: TextStyle(fontSize: 12, color: _muted)),
      const SizedBox(height: 8),
      // Signature as typed name (canvas drawing requires a plugin — using styled text field instead)
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          border: Border.all(color: data.printedName.isNotEmpty ? _purple : _border, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: data.printedName.isNotEmpty
            ? Text(data.printedName,
                style: const TextStyle(fontSize: 28, color: _navy, fontStyle: FontStyle.italic, fontFamily: 'serif'))
            : const Text('Your signature will appear here once you fill in your printed name above',
                style: TextStyle(fontSize: 13, color: _muted, fontStyle: FontStyle.italic)),
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _light, border: Border.all(color: _border), borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Date: $dateStr', style: const TextStyle(fontSize: 12, color: _muted)),
          const SizedBox(height: 4),
          const Text('California School of Trucking LLC', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _navy)),
          const SizedBox(height: 2),
          const Text('Corporate Office: 3787 Transport Street Suite 10, Ventura, CA 93003\nTraining Yard: 251 S. G Street, San Bernardino, CA 94210\nPhone: 909.906.3106 | Admin@caschooloftrucking.com',
            style: TextStyle(fontSize: 11, color: _muted, height: 1.6)),
        ]),
      ),
    ]);
  }

  String _monthName(int m) => ['January','February','March','April','May','June','July','August','September','October','November','December'][m-1];
}

// ══════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class EnrollmentAgreementScreen extends StatefulWidget {
  const EnrollmentAgreementScreen({super.key});

  @override
  State<EnrollmentAgreementScreen> createState() => _EnrollmentAgreementScreenState();
}

class _EnrollmentAgreementScreenState extends State<EnrollmentAgreementScreen> {
  int _step = 1;
  final _formData = EnrollmentFormData();
  bool _loading = true;
  bool _saving = false;
  bool _submitting = false;
  bool _submitted = false;
  bool _savedFlash = false;
  String? _agreementId;
  String _toastMsg = '';
  bool _showToast = false;
  String _toastType = 'success';

  String _studentName = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    try {
      final token = await _getToken();
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString('user') ?? '{}';
      try {
        final user = jsonDecode(userStr) as Map;
        _studentName = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
      } catch (_) {}

      final res = await http.get(Uri.parse(_enrollmentBase), headers: _authHeaders(token));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>?;
        if (data != null) {
          _agreementId = data['_id']?.toString();
          if (!mounted) return;
          setState(() {
            _step = (data['currentStep'] as int?) ?? 1;
            if (data['status'] == 'submitted' || data['status'] == 'approved') _submitted = true;
            _formData.mergeFromJson(data);
          });
        }
      }
    } catch (e) {
      debugPrint('Load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProgress(int toStep) async {
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      final token = await _getToken();
      final payload = jsonEncode({'currentStep': toStep, ..._formData.toJson()});
      http.Response res;
      if (_agreementId == null) {
        res = await http.post(Uri.parse(_enrollmentBase), headers: _authHeaders(token), body: payload);
        if (res.statusCode == 200 || res.statusCode == 201) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          _agreementId = body['_id']?.toString();
        }
      } else {
        res = await http.patch(Uri.parse(_enrollmentBase), headers: _authHeaders(token), body: payload);
      }
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        setState(() => _savedFlash = true);
        Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _savedFlash = false); });
      }
    } catch (e) {
      debugPrint('Save error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handleNext() async {
    await _saveProgress(_step + 1);
    if (!mounted) return;
    setState(() => _step = (_step + 1).clamp(1, 9));
    Scrollable.ensureVisible(context);
  }

  Future<void> _handleSubmit() async {
    if (!_formData.agreed || _formData.printedName.isEmpty) {
      _showToastMsg('Please complete your printed name and check the agreement box.', 'error');
      return;
    }
    setState(() => _submitting = true);
    try {
      await _saveProgress(9);
      final token = await _getToken();
      final res = await http.post(
        Uri.parse('$_enrollmentBase/submit'),
        headers: _authHeaders(token),
        body: jsonEncode({'signature': {'printedName': _formData.printedName, 'agreed': _formData.agreed}}),
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() => _submitted = true);
      } else {
        final d = jsonDecode(res.body) as Map?;
        _showToastMsg(d?['message'] ?? 'Submission failed.', 'error');
      }
    } catch (_) {
      _showToastMsg('Server error. Please try again.', 'error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showToastMsg(String msg, String type) {
    setState(() { _toastMsg = msg; _toastType = type; _showToast = true; });
    Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _showToast = false); });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _light,
        body: Center(child: CircularProgressIndicator(color: _purple)),
      );
    }

    if (_submitted) {
      return _buildSubmittedScreen();
    }

    return Scaffold(
      backgroundColor: _light,
      body: Stack(children: [
        CustomScrollView(
          slivers: [
            _buildHeader(),
            SliverToBoxAdapter(child: _buildStepProgress()),
            SliverToBoxAdapter(child: _buildStepContent()),
            SliverToBoxAdapter(child: _buildNavigation()),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
        if (_showToast) _buildToast(),
      ]),
    );
  }

  Widget _buildHeader() => SliverToBoxAdapter(
    child: Container(
      color: _white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: _purple.withValues(alpha: .10), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.description_outlined, color: _purple, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Enrollment Agreement',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _navy)),
          const Text('California School of Trucking LLC',
            style: TextStyle(fontSize: 12, color: _muted)),
        ])),
        if (_savedFlash) Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFFF0FDF4), border: Border.all(color: const Color(0xFF86EFAC)), borderRadius: BorderRadius.circular(20)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check, size: 12, color: _success),
            SizedBox(width: 4),
            Text('Saved', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _success)),
          ]),
        ),
        if (_saving) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _muted)),
      ]),
    ),
  );

  Widget _buildStepProgress() => Container(
    color: _white,
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: Column(children: [
      // Progress bar segments
      Row(children: List.generate(_steps.length, (i) {
        final stepNum = i + 1;
        Color barColor;
        if (stepNum < _step) {
          barColor = _success;
        } else if (stepNum == _step) {
          barColor = _purple;
        } else {
          barColor = _border;
        }
        return Expanded(child: Padding(
          padding: EdgeInsets.only(right: i < _steps.length - 1 ? 3 : 0),
          child: Container(height: 4, decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(2))),
        ));
      })),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Step $_step of ${_steps.length} — ${_steps[_step - 1]}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _navy)),
        Text('${((_step / _steps.length) * 100).round()}% complete',
          style: const TextStyle(fontSize: 12, color: _muted)),
      ]),
    ]),
  );

  Widget _buildStepContent() => Container(
    margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _white,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: _buildCurrentStep(),
  );

  Widget _buildCurrentStep() {
    final rebuild = () => setState(() {});
    switch (_step) {
      case 1:  return _Step1(data: _formData, onChanged: rebuild);
      case 2:  return _Step2(data: _formData, onChanged: rebuild);
      case 3:  return _Step3(data: _formData, onChanged: rebuild);
      case 4:  return _Step4(data: _formData, onChanged: rebuild);
      case 5:  return _Step5(data: _formData, onChanged: rebuild);
      case 6:  return _Step6(data: _formData, onChanged: rebuild);
      case 7:  return _Step7(data: _formData, onChanged: rebuild);
      case 8:  return _Step8(data: _formData, onChanged: rebuild);
case 9: return Step9WithDrawing(
  data: _formData,
  onChanged: rebuild,
  studentName: _studentName,
);      default: return const SizedBox();
    }
  }

  Widget _buildNavigation() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Column(children: [
      // Save Draft button
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _saving ? null : () => _saveProgress(_step),
          icon: _saving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _muted))
              : const Icon(Icons.save_outlined, size: 16, color: _muted),
          label: const Text('Save Draft', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _muted)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: const BorderSide(color: _border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      const SizedBox(height: 10),
      // Back / Next or Submit
      Row(children: [
        if (_step > 1) Expanded(
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _step = (_step - 1).clamp(1, 9)),
            icon: const Icon(Icons.chevron_left, size: 18),
            label: const Text('Previous'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: _border),
              foregroundColor: _navy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        if (_step > 1) const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: _step < 9
              ? ElevatedButton.icon(
                  onPressed: _saving ? null : _handleNext,
                  icon: const Icon(Icons.chevron_right, size: 18),
                  label: const Text('Next Step'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _purple, foregroundColor: _white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: _submitting ? null : _handleSubmit,
                  icon: _submitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _white))
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(_submitting ? 'Submitting...' : 'Submit Agreement'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _submitting ? _muted : _success, foregroundColor: _white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
        ),
      ]),
    ]),
  );

  Widget _buildToast() => Positioned(
    top: 20, right: 16, left: 16,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _toastType == 'error' ? _danger : _success,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .15), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Text(_toastMsg, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _white)),
    ),
  );

  Widget _buildSubmittedScreen() => Scaffold(
    backgroundColor: _light,
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(children: [
          const SizedBox(height: 40),
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              border: Border.all(color: const Color(0xFF86EFAC), width: 2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline, size: 38, color: _success),
          ),
          const SizedBox(height: 20),
          const Text('Agreement Submitted!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(height: 10),
          const Text(
            'Your enrollment agreement has been submitted and is pending review by the admissions team. You will be notified once it has been reviewed and approved.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _muted, height: 1.7),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: _white, border: Border.all(color: _border), borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('WHAT HAPPENS NEXT?',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _muted, letterSpacing: 0.8)),
              const SizedBox(height: 12),
              ...[
                'Admissions team reviews your agreement (1-2 business days)',
                'You receive email confirmation of approval',
                'Your enrollment becomes officially active',
                'You can begin your CDL training program',
              ].asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(color: _purple, borderRadius: BorderRadius.circular(11)),
                    child: Center(child: Text('${e.key + 1}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _white))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(e.value, style: const TextStyle(fontSize: 13, color: _navy))),
                ]),
              )),
            ]),
          ),
        ]),
      ),
    ),
  );
}