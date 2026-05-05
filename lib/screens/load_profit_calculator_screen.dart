import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Constants ───────────────────────────────────────────────────────────────
const kNavy      = Color(0xFF0B1F3A);
const kAccent    = Color(0xFF7C3AED);
const kGold      = Color(0xFFB8963E);
const kGoldLight = Color(0xFFD4AE5A);
const kSuccess   = Color(0xFF2D8A4E);
const kDanger    = Color(0xFFC0392B);
const kWarn      = Color(0xFFB8963E);
const kBorder    = Color(0xFFE9ECEF);
const kMuted     = Color(0xFF6C757D);
const kWhite     = Color(0xFFFFFFFF);
const kLightBg   = Color(0xFFF8F9FA);
const kTeal      = Color(0xFF0E9F8E);
const kRed       = Color(0xFFE53935);

// ─── Defaults ────────────────────────────────────────────────────────────────
class Defaults {
  static const double loadedMiles  = 570;
  static const double dhMiles      = 191;
  static const double offeredRate  = 1400;
  static const double fuelCpm      = 0.58;
  static const double tireCpm      = 0.055;
  static const double maintCpm     = 0.031;
  static const double defCpm       = 0.015;
  static const double fixedCpm     = 0.485;
  static const double tolls        = 0;
  static const double wdTax        = 11;
  static const double dispatchPct  = 8;
  static const double tripHours    = 26;
  static const double hourlyTarget = 16;
  static const double annualGoal   = 80000;
  static const double seTax        = 14.13;
  static const double fedTax       = 12;
  static const double stateTax     = 5;
  static const String origin       = '';
  static const String destination  = '';
}

// ─── Calc Result ─────────────────────────────────────────────────────────────
class CalcResult {
  final double netProfit, profitPerHour, roiPct, pctOfTarget;
  final double inclExpenses, initialProfit, taxesOwed;
  final double fuelCost, tireCost, maintCost, defCost, fixedCost;
  final double dispatchFee, hiddenCost;
  final double grossPerLDMile, netPerLDMile, totalMi;
  final double timeBased, mileBased, tbNet, mbNet, tbPH, mbPH;
  final String winner;
  final int?    loadsNeeded;
  final String? loadsPerWeek;

  const CalcResult({
    required this.netProfit,      required this.profitPerHour,
    required this.roiPct,         required this.pctOfTarget,
    required this.inclExpenses,   required this.initialProfit,
    required this.taxesOwed,      required this.fuelCost,
    required this.tireCost,       required this.maintCost,
    required this.defCost,        required this.fixedCost,
    required this.dispatchFee,    required this.hiddenCost,
    required this.grossPerLDMile, required this.netPerLDMile,
    required this.totalMi,        required this.timeBased,
    required this.mileBased,      required this.tbNet,
    required this.mbNet,          required this.tbPH,
    required this.mbPH,           required this.winner,
    this.loadsNeeded, this.loadsPerWeek,
  });
}

// ─── All max() calls use dmax() to guarantee double return ───────────────────
double dmax(double a, double b) => a > b ? a : b;

CalcResult runCalc({
  required double loadedMiles,
  required double dhMiles,
  required double offeredRate,
  required double fuelCpm,
  required double tireCpm,
  required double maintCpm,
  required double defCpm,
  required double fixedCpm,
  required double tolls,
  required double wdTax,
  required double dispatchPct,
  required double tripHours,
  required double hourlyTarget,
  required double annualGoal,
  required double seTax,
  required double fedTax,
  required double stateTax,
}) {
  final double totalMi      = loadedMiles + dhMiles;
  final double fuelCost     = fuelCpm  * totalMi;
  final double tireCost     = tireCpm  * totalMi;
  final double maintCost    = maintCpm * totalMi;
  final double defCost      = defCpm   * totalMi;
  final double fixedCost    = fixedCpm * totalMi;
  final double dispatchFee  = offeredRate * (dispatchPct / 100.0);
  final double hiddenCost   = tolls + wdTax;
  final double inclExpenses = fuelCost + tireCost + maintCost + defCost +
                              fixedCost + dispatchFee + hiddenCost;
  final double initialProfit = offeredRate - inclExpenses;
  final double taxRate       = (seTax + fedTax + stateTax) / 100.0;
  final double taxesOwed     = dmax(initialProfit, 0.0) * taxRate;
  final double netProfit     = initialProfit - taxesOwed;
  final double hours         = tripHours == 0.0 ? 1.0 : tripHours;
  final double profitPerHour = netProfit / hours;
  final double roiPct        = inclExpenses == 0.0
      ? 0.0
      : (netProfit / inclExpenses) * 100.0;
  final double pctOfTarget   = hourlyTarget > 0.0
      ? (profitPerHour / hourlyTarget) * 100.0
      : 0.0;
  final double grossPerLDMile = offeredRate / (loadedMiles == 0.0 ? 1.0 : loadedMiles);
  final double netPerLDMile   = netProfit   / (loadedMiles == 0.0 ? 1.0 : loadedMiles);

  final double timeBased = offeredRate +
      (hourlyTarget * hours * (dhMiles / dmax(loadedMiles, 1.0)));
  final double mileBased = offeredRate + (fuelCpm * dhMiles * 1.1);

  double calcNet(double rate) {
    final double exp = fuelCost + tireCost + maintCost + defCost + fixedCost +
        (rate * dispatchPct / 100.0) + hiddenCost;
    final double ip = rate - exp;
    return ip - dmax(ip, 0.0) * taxRate;
  }

  final double tbNet = calcNet(timeBased);
  final double mbNet = calcNet(mileBased);
  final double tbPH  = tbNet / hours;
  final double mbPH  = mbNet / hours;

  // Use our dmax() so the result is always double
  final double best   = dmax(profitPerHour, dmax(tbPH, mbPH));
  final String winner = best == tbPH
      ? 'time'
      : best == mbPH
          ? 'mile'
          : 'offered';

  int?    loadsNeeded;
  String? loadsPerWeek;
  if (netProfit > 0.0) {
    loadsNeeded  = (annualGoal / netProfit).ceil();
    loadsPerWeek = (loadsNeeded / 50.0).toStringAsFixed(1);
  }

  return CalcResult(
    netProfit: netProfit,         profitPerHour: profitPerHour,
    roiPct: roiPct,               pctOfTarget: pctOfTarget,
    inclExpenses: inclExpenses,   initialProfit: initialProfit,
    taxesOwed: taxesOwed,         fuelCost: fuelCost,
    tireCost: tireCost,           maintCost: maintCost,
    defCost: defCost,             fixedCost: fixedCost,
    dispatchFee: dispatchFee,     hiddenCost: hiddenCost,
    grossPerLDMile: grossPerLDMile, netPerLDMile: netPerLDMile,
    totalMi: totalMi,             timeBased: timeBased,
    mileBased: mileBased,         tbNet: tbNet,
    mbNet: mbNet,                 tbPH: tbPH,
    mbPH: mbPH,                   winner: winner,
    loadsNeeded: loadsNeeded,     loadsPerWeek: loadsPerWeek,
  );
}

// ─── Formatting helpers ───────────────────────────────────────────────────────
String fmt(double n) {
  final double abs = n.abs();
  final String formatted = abs.toStringAsFixed(2).replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  return n < 0 ? '-\$$formatted' : '\$$formatted';
}

String fmtShort(double n) {
  final double abs = n.abs();
  return n < 0 ? '-\$${abs.toStringAsFixed(2)}' : '\$${abs.toStringAsFixed(2)}';
}

// ─── Screen wrapper (drop main() / LoadProfitApp when using inside dashboard) ─
class LoadCalculatorScreen extends StatelessWidget {
  const LoadCalculatorScreen({super.key});
  @override
  Widget build(BuildContext context) => const CalculatorPage();
}

// ─── Calculator Page ──────────────────────────────────────────────────────────
class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});
  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  late final Map<String, TextEditingController> _ctrl;
  CalcResult? result;
  String activeTab = 'breakdown';
  OverlayEntry? _toastEntry;

  @override
  void initState() {
    super.initState();
    _ctrl = {
      'loaded_miles' : TextEditingController(text: Defaults.loadedMiles.toString()),
      'dh_miles'     : TextEditingController(text: Defaults.dhMiles.toString()),
      'offered_rate' : TextEditingController(text: Defaults.offeredRate.toString()),
      'fuel_cpm'     : TextEditingController(text: Defaults.fuelCpm.toString()),
      'tire_cpm'     : TextEditingController(text: Defaults.tireCpm.toString()),
      'maint_cpm'    : TextEditingController(text: Defaults.maintCpm.toString()),
      'def_cpm'      : TextEditingController(text: Defaults.defCpm.toString()),
      'fixed_cpm'    : TextEditingController(text: Defaults.fixedCpm.toString()),
      'tolls'        : TextEditingController(text: Defaults.tolls.toString()),
      'wd_tax'       : TextEditingController(text: Defaults.wdTax.toString()),
      'dispatch_pct' : TextEditingController(text: Defaults.dispatchPct.toString()),
      'trip_hours'   : TextEditingController(text: Defaults.tripHours.toString()),
      'hourly_target': TextEditingController(text: Defaults.hourlyTarget.toString()),
      'annual_goal'  : TextEditingController(text: Defaults.annualGoal.toString()),
      'se_tax'       : TextEditingController(text: Defaults.seTax.toString()),
      'fed_tax'      : TextEditingController(text: Defaults.fedTax.toString()),
      'state_tax'    : TextEditingController(text: Defaults.stateTax.toString()),
      'origin'       : TextEditingController(text: Defaults.origin),
      'destination'  : TextEditingController(text: Defaults.destination),
    };
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) c.dispose();
    super.dispose();
  }

  double _dbl(String key) => double.tryParse(_ctrl[key]!.text) ?? 0.0;

  void _calculate() {
    setState(() {
      result = runCalc(
        loadedMiles : _dbl('loaded_miles'),
        dhMiles     : _dbl('dh_miles'),
        offeredRate : _dbl('offered_rate'),
        fuelCpm     : _dbl('fuel_cpm'),
        tireCpm     : _dbl('tire_cpm'),
        maintCpm    : _dbl('maint_cpm'),
        defCpm      : _dbl('def_cpm'),
        fixedCpm    : _dbl('fixed_cpm'),
        tolls       : _dbl('tolls'),
        wdTax       : _dbl('wd_tax'),
        dispatchPct : _dbl('dispatch_pct'),
        tripHours   : _dbl('trip_hours'),
        hourlyTarget: _dbl('hourly_target'),
        annualGoal  : _dbl('annual_goal'),
        seTax       : _dbl('se_tax'),
        fedTax      : _dbl('fed_tax'),
        stateTax    : _dbl('state_tax'),
      );
      activeTab = 'breakdown';
    });
  }

  void _reset() {
    setState(() {
      result = null;
      _ctrl['loaded_miles']! .text = Defaults.loadedMiles.toString();
      _ctrl['dh_miles']!     .text = Defaults.dhMiles.toString();
      _ctrl['offered_rate']! .text = Defaults.offeredRate.toString();
      _ctrl['fuel_cpm']!     .text = Defaults.fuelCpm.toString();
      _ctrl['tire_cpm']!     .text = Defaults.tireCpm.toString();
      _ctrl['maint_cpm']!    .text = Defaults.maintCpm.toString();
      _ctrl['def_cpm']!      .text = Defaults.defCpm.toString();
      _ctrl['fixed_cpm']!    .text = Defaults.fixedCpm.toString();
      _ctrl['tolls']!        .text = Defaults.tolls.toString();
      _ctrl['wd_tax']!       .text = Defaults.wdTax.toString();
      _ctrl['dispatch_pct']! .text = Defaults.dispatchPct.toString();
      _ctrl['trip_hours']!   .text = Defaults.tripHours.toString();
      _ctrl['hourly_target']!.text = Defaults.hourlyTarget.toString();
      _ctrl['annual_goal']!  .text = Defaults.annualGoal.toString();
      _ctrl['se_tax']!       .text = Defaults.seTax.toString();
      _ctrl['fed_tax']!      .text = Defaults.fedTax.toString();
      _ctrl['state_tax']!    .text = Defaults.stateTax.toString();
      _ctrl['origin']!       .text = '';
      _ctrl['destination']!  .text = '';
    });
  }

  void _showToast(String message, {bool isError = false}) {
    _toastEntry?.remove();
    final overlay = Overlay.of(context);
    _toastEntry = OverlayEntry(builder: (_) => Positioned(
      top: 60, right: 24,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: isError ? kDanger : kSuccess,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
          ),
          child: Text(message,
            style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ),
    ));
    overlay.insert(_toastEntry!);
    Future.delayed(const Duration(seconds: 3), () {
      _toastEntry?.remove();
      _toastEntry = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width > 800;
    return Scaffold(
      backgroundColor: kLightBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildHeader(),
            const SizedBox(height: 20),
            if (isWide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 360, child: _buildInputPanel()),
                const SizedBox(width: 20),
                Expanded(child: _buildResultPanel()),
              ])
            else
              Column(children: [
                _buildInputPanel(),
                const SizedBox(height: 16),
                _buildResultPanel(),
              ]),
          ]),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Load Profit Calculator',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: kNavy)),
        const SizedBox(height: 4),
        const Text(
          'Know your real net profit before accepting a load — '
          'tolls, taxes, deadhead, and dispatch fees all included.',
          style: TextStyle(fontSize: 13, color: kMuted)),
      ])),
      const SizedBox(width: 12),
      OutlinedButton.icon(
        onPressed: _reset,
        icon: const Icon(Icons.refresh, size: 14),
        label: const Text('Reset'),
        style: OutlinedButton.styleFrom(
          foregroundColor: kMuted,
          side: const BorderSide(color: kBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    ]);
  }

  // ── Input panel ─────────────────────────────────────────────────────────────
  Widget _buildInputPanel() {
    return Column(children: [
      _buildCard('Route', kAccent, Column(children: [
        Row(children: [
          Expanded(child: _buildField('Origin',      'origin',      isText: true, hint: 'e.g. Arnold, MO')),
          const SizedBox(width: 10),
          Expanded(child: _buildField('Destination', 'destination', isText: true, hint: 'e.g. Atlanta, GA')),
        ]),
      ])),
      _buildCard('Rate & Time', kAccent, Column(children: [
        Row(children: [
          Expanded(child: _buildField('Loaded miles',   'loaded_miles')),
          const SizedBox(width: 10),
          Expanded(child: _buildField('Deadhead miles', 'dh_miles', hint: 'Empty miles to pickup')),
        ]),
        const SizedBox(height: 10),
        _buildField('Offered rate', 'offered_rate', prefix: '\$'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _buildField('Trip hours',    'trip_hours',    hint: 'Drive + wait time')),
          const SizedBox(width: 10),
          Expanded(child: _buildField('Hourly target', 'hourly_target', prefix: '\$', suffix: '/hr')),
        ]),
      ])),
      _buildCard('Operating Costs / Mile', kTeal, Column(children: [
        Row(children: [
          Expanded(child: _buildField('Fuel',  'fuel_cpm',  prefix: '\$')),
          const SizedBox(width: 10),
          Expanded(child: _buildField('Tires', 'tire_cpm',  prefix: '\$')),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _buildField('Maintenance', 'maint_cpm', prefix: '\$')),
          const SizedBox(width: 10),
          Expanded(child: _buildField('DEF fluid',   'def_cpm',   prefix: '\$')),
        ]),
        const SizedBox(height: 10),
        _buildField('Fixed costs', 'fixed_cpm', prefix: '\$', hint: 'Insurance, payment, etc.'),
      ])),
      _buildCard('Hidden Costs', kGold, Column(children: [
        Row(children: [
          Expanded(child: _buildField('Tolls',  'tolls',  prefix: '\$')),
          const SizedBox(width: 10),
          Expanded(child: _buildField('W/D Tax','wd_tax', prefix: '\$', hint: 'Weight/distance tax')),
        ]),
        const SizedBox(height: 10),
        _buildField('Dispatch / carrier fee', 'dispatch_pct', suffix: '%'),
      ])),
      _buildCard('Tax Profile', kRed, Column(children: [
        Row(children: [
          Expanded(child: _buildField('Self-employment %', 'se_tax',    suffix: '%')),
          const SizedBox(width: 10),
          Expanded(child: _buildField('Federal income %',  'fed_tax',   suffix: '%')),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _buildField('State income %', 'state_tax',   suffix: '%')),
          const SizedBox(width: 10),
          Expanded(child: _buildField('Annual goal',    'annual_goal', prefix: '\$', hint: 'For goal tracking')),
        ]),
      ])),
      const SizedBox(height: 4),
      SizedBox(width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _calculate,
          icon: const Icon(Icons.trending_up, size: 16),
          label: const Text('Calculate Real Profit'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kNavy,
            foregroundColor: kWhite,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
        ),
      ),
    ]);
  }

  Widget _buildCard(String title, Color accent, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: const BoxDecoration(
            color: kLightBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            border: Border(bottom: BorderSide(color: kBorder)),
          ),
          child: Row(children: [
            Container(width: 3, height: 14,
              decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text(title.toUpperCase(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: kNavy, letterSpacing: 1.0)),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(16), child: child),
      ]),
    );
  }

  Widget _buildField(String label, String key,
      {String? prefix, String? suffix, String? hint, bool isText = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
          color: kMuted, letterSpacing: 0.8)),
      const SizedBox(height: 4),
      TextField(
        controller: _ctrl[key],
        keyboardType: isText
            ? TextInputType.text
            : const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: isText
            ? []
            : [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        style: const TextStyle(fontSize: 13, color: kNavy),
        decoration: InputDecoration(
          prefixText: prefix,
          suffixText: suffix,
          hintText: hint,
          hintStyle: TextStyle(fontSize: 12, color: kMuted.withOpacity(0.6)),
          prefixStyle: const TextStyle(fontSize: 13, color: kMuted),
          suffixStyle: const TextStyle(fontSize: 13, color: kMuted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: kAccent),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          fillColor: kWhite,
          filled: true,
        ),
      ),
    ]);
  }

  // ── Result panel ────────────────────────────────────────────────────────────
  Widget _buildResultPanel() {
    if (result == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Column(children: [
          const Icon(Icons.trending_up, size: 40, color: kBorder),
          const SizedBox(height: 16),
          const Text('Enter load details and calculate',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kNavy)),
          const SizedBox(height: 8),
          const Text(
            'Fill in the form and click Calculate to see your complete profit '
            'breakdown, rate comparison, and annual goal tracker.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: kMuted, height: 1.6)),
        ]),
      );
    }

    final r            = result!;
    final profitColor  = r.netProfit >= 0.0 ? kSuccess : kDanger;
    final targetColor  = r.pctOfTarget >= 80.0
        ? kSuccess
        : r.pctOfTarget >= 50.0
            ? kWarn
            : kDanger;

    return Column(children: [
      // Metric cards
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.2,
        children: [
          _buildMetric('Net profit',    fmt(r.netProfit),
            profitColor,
            r.netProfit >= 0.0 ? 'After all costs' : 'Loss — consider countering'),
          _buildMetric('Profit / hour', fmt(r.profitPerHour),
            profitColor, '${_dbl('trip_hours').toInt()} hrs'),
          _buildMetric('ROI',           '${r.roiPct.toStringAsFixed(1)}%',
            r.roiPct >= 0.0 ? kSuccess : kDanger, 'On expenses'),
          _buildMetric('% of target',   '${r.pctOfTarget.toStringAsFixed(0)}%',
            targetColor, 'Target \$${_dbl('hourly_target').toStringAsFixed(0)}/hr'),
        ],
      ),
      const SizedBox(height: 12),

      // Recommendation banner
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(color: kNavy, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('RATE RECOMMENDATION',
              style: TextStyle(fontSize: 10, color: Color(0x80FFFFFF), letterSpacing: 1.0)),
            const SizedBox(height: 3),
            Text(
              r.winner == 'offered'
                  ? 'Offered Rate (${fmt(_dbl('offered_rate'))}) wins'
                  : r.winner == 'time'
                      ? 'Time-Based Rate (${fmt(r.timeBased)}) wins'
                      : 'Mile-Based Rate (${fmt(r.mileBased)}) wins',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kGoldLight),
            ),
          ])),
          Text(r.netProfit >= 0.0 ? 'Profitable load' : 'Consider countering',
            style: TextStyle(fontSize: 12,
              color: r.netProfit >= 0.0
                  ? const Color(0xFF86EFAC)
                  : const Color(0xFFFCA5A5))),
        ]),
      ),
      const SizedBox(height: 12),

      // Tab pills
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final tab in [
            ('breakdown', 'Cost Breakdown'),
            ('compare',   'Rate Comparison'),
            ('milerate',  'Per-Mile'),
            ('goal',      'Annual Goal'),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => setState(() => activeTab = tab.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: activeTab == tab.$1 ? kNavy : kWhite,
                    borderRadius: BorderRadius.circular(20),
                    border: activeTab == tab.$1
                        ? null
                        : Border.all(color: kBorder),
                  ),
                  child: Text(tab.$2,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: activeTab == tab.$1 ? kWhite : kMuted)),
                ),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 10),

      // Tab content
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: _buildTabContent(r, profitColor),
      ),
    ]);
  }

  Widget _buildMetric(String label, String value, Color color, String sub) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kLightBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label.toUpperCase(),
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
            color: kMuted, letterSpacing: 0.8)),
        const SizedBox(height: 4),
        Text(value,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Text(sub,
          style: const TextStyle(fontSize: 10, color: kMuted),
          textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildTabContent(CalcResult r, Color profitColor) {
    switch (activeTab) {
      case 'breakdown': return _buildBreakdown(r, profitColor);
      case 'compare':   return _buildCompare(r);
      case 'milerate':  return _buildMileRate(r);
      case 'goal':      return _buildGoal(r);
      default:          return const SizedBox();
    }
  }

  // ── Breakdown tab ───────────────────────────────────────────────────────────
  Widget _buildBreakdown(CalcResult r, Color profitColor) {
    final String total = r.totalMi.toStringAsFixed(0);
    return Column(children: [
      _bRow('Offered rate', fmt(_dbl('offered_rate')), bold: true),
      _bRow('Fuel (\$${_dbl('fuel_cpm').toStringAsFixed(3)}/mi × $total mi)',
            '-${fmt(r.fuelCost)}',  neg: true),
      _bRow('DEF (\$${_dbl('def_cpm').toStringAsFixed(3)}/mi)',
            '-${fmt(r.defCost)}',   neg: true),
      _bRow('Tires (\$${_dbl('tire_cpm').toStringAsFixed(3)}/mi)',
            '-${fmt(r.tireCost)}',  neg: true),
      _bRow('Maintenance (\$${_dbl('maint_cpm').toStringAsFixed(3)}/mi)',
            '-${fmt(r.maintCost)}', neg: true),
      _bRow('Fixed costs (\$${_dbl('fixed_cpm').toStringAsFixed(3)}/mi)',
            '-${fmt(r.fixedCost)}', neg: true),
      _bRow('Tolls',                '-${fmt(_dbl('tolls'))}',  neg: true),
      _bRow('Weight/distance tax',  '-${fmt(_dbl('wd_tax'))}', neg: true),
      _bRow('Dispatch fee (${_dbl('dispatch_pct').toStringAsFixed(0)}%)',
            '-${fmt(r.dispatchFee)}', neg: true),
      const Divider(height: 16, color: kBorder),
      _bRow('Initial profit (before tax)', fmt(r.initialProfit), bold: true),
      _bRow(
        'Taxes (SE ${_dbl('se_tax').toStringAsFixed(1)}% + '
        'Fed ${_dbl('fed_tax').toStringAsFixed(0)}% + '
        'State ${_dbl('state_tax').toStringAsFixed(0)}%)',
        '-${fmt(r.taxesOwed)}', neg: true),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Net profit',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kNavy)),
        Text(fmt(r.netProfit),
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: profitColor)),
      ]),
    ]);
  }

  Widget _bRow(String label, String value, {bool neg = false, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Text(label,
          style: TextStyle(fontSize: 13,
            color: bold ? kNavy : kMuted,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400))),
        Text(value,
          style: TextStyle(fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: neg ? kDanger : kNavy)),
      ]),
    );
  }

  // ── Compare tab ─────────────────────────────────────────────────────────────
  Widget _buildCompare(CalcResult r) {
    final items = [
      ('offered', 'Offered rate',    _dbl('offered_rate'), r.netProfit, r.profitPerHour,
        'The rate the broker quoted you'),
      ('time',    'Time-based rate', r.timeBased,          r.tbNet,     r.tbPH,
        'Adjusted for ${_dbl('dh_miles').toInt()} deadhead miles at your hourly target'),
      ('mile',    'Mile-based rate', r.mileBased,          r.mbNet,     r.mbPH,
        'Accounts for fuel cost of empty miles only'),
    ];
    return Column(children: items.map((item) {
      final bool isWinner = item.$1 == r.winner;
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
            color: isWinner ? kSuccess : kBorder,
            width: isWinner ? 2.0 : 1.0,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (isWinner)
            Align(alignment: Alignment.topRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: kSuccess,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('WINNER',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kWhite)),
              )),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.$2.toUpperCase(),
                style: const TextStyle(fontSize: 10, color: kMuted, letterSpacing: 0.6)),
              const SizedBox(height: 2),
              Text(fmt(item.$3),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kNavy)),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${fmt(item.$4)} net',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                  color: item.$4 >= 0.0 ? kSuccess : kDanger)),
              Text('${fmt(item.$5)}/hr',
                style: const TextStyle(fontSize: 12, color: kMuted)),
            ]),
          ]),
          const SizedBox(height: 6),
          Text(item.$6, style: const TextStyle(fontSize: 12, color: kMuted)),
        ]),
      );
    }).toList());
  }

  // ── Per-Mile tab ────────────────────────────────────────────────────────────
  Widget _buildMileRate(CalcResult r) {
    final double ldMiles = dmax(_dbl('loaded_miles'), 1.0); // ← dmax not max
    return Column(children: [
      Row(children: [
        Expanded(child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: kLightBg, borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('GROSS / LOADED MILE',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                color: kMuted, letterSpacing: 0.7)),
            const SizedBox(height: 6),
            Text('\$${r.grossPerLDMile.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: kNavy)),
          ]),
        )),
        const SizedBox(width: 12),
        Expanded(child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: kLightBg, borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('NET / LOADED MILE',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                color: kMuted, letterSpacing: 0.7)),
            const SizedBox(height: 6),
            Text('\$${r.netPerLDMile.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700,
                color: r.netPerLDMile >= 0.0 ? kSuccess : kDanger)),
          ]),
        )),
      ]),
      const SizedBox(height: 14),
      _bRow('Total miles (loaded + D/H)', '${r.totalMi.toStringAsFixed(0)} mi'),
      _bRow('Deadhead ratio',
        '${((_dbl('dh_miles') / r.totalMi) * 100.0).toStringAsFixed(1)}%'),
      _bRow('Cost per total mile',   fmtShort(r.inclExpenses / r.totalMi)),
      _bRow('Cost per loaded mile',  fmtShort(r.inclExpenses / ldMiles)),
      _bRow('Gross per total mile',  fmtShort(_dbl('offered_rate') / r.totalMi)),
    ]);
  }

  // ── Annual Goal tab ─────────────────────────────────────────────────────────
  Widget _buildGoal(CalcResult r) {
    final double goal = _dbl('annual_goal');
    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: kNavy, borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('ANNUAL INCOME GOAL',
            style: TextStyle(fontSize: 10, color: Color(0x80FFFFFF), letterSpacing: 1.0)),
          const SizedBox(height: 4),
          Text(
            '\$${goal.toStringAsFixed(0).replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: kGoldLight)),
        ]),
      ),
      const SizedBox(height: 14),
      if (r.netProfit > 0.0) ...[
        _bRow('Net profit per load',           fmt(r.netProfit)),
        _bRow('Loads needed to hit goal',      '${r.loadsNeeded}',   bold: true),
        _bRow('Loads per week (50-week year)', r.loadsPerWeek ?? '—', bold: true),
        _bRow('Gross revenue needed',
          fmt((r.loadsNeeded ?? 0) * _dbl('offered_rate'))),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Goal achievable',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kSuccess)),
            const SizedBox(height: 4),
            Text(
              'At ${fmt(r.profitPerHour)}/hr on this load type, you need '
              '${r.loadsPerWeek} similar loads per week to hit your '
              '\$${(goal / 1000.0).toStringAsFixed(0)}K goal.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF166534), height: 1.6)),
          ]),
        ),
      ] else
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFECDD3)),
          ),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('This load is not profitable',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kDanger)),
            SizedBox(height: 4),
            Text('Consider negotiating a higher rate or reducing costs before accepting this load.',
              style: TextStyle(fontSize: 13, color: Color(0xFF991B1B), height: 1.6)),
          ]),
        ),
    ]);
  }
}