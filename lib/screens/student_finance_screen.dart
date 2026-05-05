import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Constants ─────────────────────────────────────────────────────
const Color kPurple = Color(0xFF7C3AED);
const Color kNavy = Color(0xFF0B1F3A);
const Color kGreen = Color(0xFF28A745);
const Color kRed = Color(0xFFDC3545);
const Color kYellow = Color(0xFFFFC107);
const Color kGrey = Color(0xFF6C757D);
const Color kLightGrey = Color(0xFFADB5BD);
const Color kBgGrey = Color(0xFFF1F3F5);
const Color kBorder = Color(0xFFE9ECEF);
const Color kRowAlt = Color(0xFFFAFAFA);

// ── Mock Data ─────────────────────────────────────────────────────
class TuitionInfo {
  final String program;
  final double totalFee;
  final double amountPaid;
  final String nextDueDate;
  final double nextDueAmount;
  final String plan;

  const TuitionInfo({
    required this.program,
    required this.totalFee,
    required this.amountPaid,
    required this.nextDueDate,
    required this.nextDueAmount,
    required this.plan,
  });
}

const kTuition = TuitionInfo(
  program: 'Class A CDL',
  totalFee: 6500,
  amountPaid: 3900,
  nextDueDate: 'Apr 15, 2026',
  nextDueAmount: 1300,
  plan: 'Installment — 5 payments of \$1,300',
);

class PaymentPlanItem {
  final int id;
  final String label;
  final double amount;
  final String dueDate;
  String status; // 'paid', 'due', 'upcoming'
  String? paidDate;

  PaymentPlanItem({
    required this.id,
    required this.label,
    required this.amount,
    required this.dueDate,
    required this.status,
    this.paidDate,
  });

  PaymentPlanItem copyWith({String? status, String? paidDate}) {
    return PaymentPlanItem(
      id: id,
      label: label,
      amount: amount,
      dueDate: dueDate,
      status: status ?? this.status,
      paidDate: paidDate ?? this.paidDate,
    );
  }
}

class PaymentTransaction {
  final int id;
  final String date;
  final String description;
  final double amount;
  final String method;
  final String ref;
  final String status;

  const PaymentTransaction({
    required this.id,
    required this.date,
    required this.description,
    required this.amount,
    required this.method,
    required this.ref,
    required this.status,
  });
}

List<PaymentPlanItem> get initialPlanItems => [
      PaymentPlanItem(id: 1, label: 'Down Payment', amount: 1300, dueDate: 'Mar 1, 2026', status: 'paid', paidDate: 'Mar 1, 2026'),
      PaymentPlanItem(id: 2, label: 'Payment 2', amount: 1300, dueDate: 'Mar 15, 2026', status: 'paid', paidDate: 'Mar 14, 2026'),
      PaymentPlanItem(id: 3, label: 'Payment 3', amount: 1300, dueDate: 'Apr 1, 2026', status: 'paid', paidDate: 'Apr 1, 2026'),
      PaymentPlanItem(id: 4, label: 'Payment 4', amount: 1300, dueDate: 'Apr 15, 2026', status: 'due', paidDate: null),
      PaymentPlanItem(id: 5, label: 'Final Payment', amount: 1300, dueDate: 'May 1, 2026', status: 'upcoming', paidDate: null),
    ];

const List<PaymentTransaction> kInitialHistory = [
  PaymentTransaction(id: 1, date: 'Apr 1, 2026', description: 'Payment 3 — Class A CDL Tuition', amount: 1300, method: 'Credit Card', ref: 'TXN-20260401-003', status: 'completed'),
  PaymentTransaction(id: 2, date: 'Mar 14, 2026', description: 'Payment 2 — Class A CDL Tuition', amount: 1300, method: 'Bank Transfer', ref: 'TXN-20260314-002', status: 'completed'),
  PaymentTransaction(id: 3, date: 'Mar 1, 2026', description: 'Down Payment — Class A CDL Tuition', amount: 1300, method: 'Credit Card', ref: 'TXN-20260301-001', status: 'completed'),
];

// ── Helpers ───────────────────────────────────────────────────────
String fmtMoney(double n) {
  return '\$${n.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => '${m[1]},')}';
}

// ── Entry Point ───────────────────────────────────────────────────
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Finances',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kPurple),
        fontFamily: 'sans-serif',
        useMaterial3: true,
      ),
      home: const StudentFinancesScreen(),
    );
  }
}

// ── Main Screen ───────────────────────────────────────────────────
class StudentFinancesScreen extends StatefulWidget {
  const StudentFinancesScreen({super.key});

  @override
  State<StudentFinancesScreen> createState() => _StudentFinancesScreenState();
}

class _StudentFinancesScreenState extends State<StudentFinancesScreen> {
  bool _showPlan = true;
  bool _showModal = false;
  List<PaymentPlanItem> _planItems = initialPlanItems;
  List<PaymentTransaction> _history = kInitialHistory;

  double get paidAmount =>
      _planItems.where((p) => p.status == 'paid').fold(0, (a, p) => a + p.amount);

  double get remaining => kTuition.totalFee - paidAmount;

  int get progress => ((paidAmount / kTuition.totalFee) * 100).round();

  void _handlePay() {
    setState(() {
      _planItems = _planItems.map((p) {
        if (p.status == 'due') {
          return p.copyWith(status: 'paid', paidDate: 'Apr 6, 2026');
        }
        return p;
      }).toList();

      final newTx = PaymentTransaction(
        id: _history.length + 1,
        date: 'Apr 6, 2026',
        description: 'Payment 4 — Class A CDL Tuition',
        amount: kTuition.nextDueAmount,
        method: 'Credit Card',
        ref: 'TXN-20260406-004',
        status: 'completed',
      );
      _history = [newTx, ..._history];
      _showModal = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgGrey,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildKpiCards(),
                  const SizedBox(height: 16),
                  _buildProgressCard(),
                  const SizedBox(height: 16),
                  _buildPaymentPlan(),
                  const SizedBox(height: 16),
                  _buildPaymentHistory(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          if (_showModal)
            PaymentModal(
              amount: kTuition.nextDueAmount,
              onClose: () => setState(() => _showModal = false),
              onPay: _handlePay,
            ),
        ],
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.attach_money_rounded, color: kPurple, size: 22),
            const SizedBox(width: 8),
            const Text(
              'My Finances',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: kNavy,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Manage your tuition payments and billing history.',
          style: TextStyle(color: kGrey, fontSize: 13),
        ),
      ],
    );
  }

  // ── KPI Cards ────────────────────────────────────────────────────
  Widget _buildKpiCards() {
    final cards = [
      _KpiData('Total Tuition', fmtMoney(kTuition.totalFee), kNavy, Icons.attach_money_rounded),
      _KpiData('Amount Paid', fmtMoney(paidAmount), kGreen, Icons.check_circle_outline),
      _KpiData('Remaining', fmtMoney(remaining), remaining > 0 ? kRed : kGreen, Icons.error_outline),
      _KpiData('Next Due', kTuition.nextDueDate, kYellow, Icons.calendar_today_outlined),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: cards.map((c) => _KpiCard(data: c)).toList(),
    );
  }

  // ── Progress Card ────────────────────────────────────────────────
  Widget _buildProgressCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Payment Progress',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kNavy)),
              Text('$progress%',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kPurple)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress / 100,
              minHeight: 10,
              backgroundColor: kBorder,
              valueColor: AlwaysStoppedAnimation<Color>(progress == 100 ? kGreen : kPurple),
            ),
          ),
          const SizedBox(height: 6),
          Text(kTuition.plan,
              style: const TextStyle(fontSize: 12, color: kLightGrey)),
          if (remaining > 0) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _showModal = true),
                icon: const Icon(Icons.credit_card, size: 16),
                label: Text('Pay ${fmtMoney(kTuition.nextDueAmount)}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  elevation: 4,
                  shadowColor: kPurple.withOpacity(0.4),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Payment Plan ─────────────────────────────────────────────────
  Widget _buildPaymentPlan() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _showPlan = !_showPlan),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: _showPlan ? const Border(bottom: BorderSide(color: kBorder)) : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Payment Plan Breakdown',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kNavy)),
                  Icon(_showPlan ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: kLightGrey),
                ],
              ),
            ),
          ),
          if (_showPlan) ...[
            // Table header
            Container(
              color: const Color(0xFFF8F9FA),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: const Row(
                children: [
                  Expanded(child: _TableHeader('Installment')),
                  SizedBox(width: 80, child: _TableHeader('Amount')),
                  SizedBox(width: 90, child: _TableHeader('Due Date')),
                  SizedBox(width: 90, child: _TableHeader('Status')),
                ],
              ),
            ),
            ..._planItems.asMap().entries.map((e) {
              final idx = e.key;
              final item = e.value;
              final isLast = idx == _planItems.length - 1;
              return Container(
                decoration: BoxDecoration(
                  color: item.status == 'due'
                      ? const Color(0xFFFFF8F8)
                      : idx % 2 == 0
                          ? Colors.white
                          : kRowAlt,
                  border: isLast
                      ? null
                      : const Border(bottom: BorderSide(color: Color(0xFFF1F3F5))),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.label,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600, color: kNavy)),
                          if (item.paidDate != null)
                            Text('Paid: ${item.paidDate}',
                                style: const TextStyle(fontSize: 11, color: kGreen)),
                        ],
                      ),
                    ),
                    SizedBox(
                        width: 80,
                        child: Text(fmtMoney(item.amount),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700, color: kNavy))),
                    SizedBox(
                        width: 90,
                        child: Text(item.dueDate,
                            style: const TextStyle(fontSize: 12, color: kGrey))),
                    SizedBox(width: 90, child: _StatusBadge(status: item.status)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ── Payment History ───────────────────────────────────────────────
  Widget _buildPaymentHistory() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                const Text('Payment History',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kNavy)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: kPurple.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${_history.length}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: kPurple)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: kBorder),
          ..._history.asMap().entries.map((e) {
            final idx = e.key;
            final tx = e.value;
            final isLast = idx == _history.length - 1;
            return Container(
              decoration: BoxDecoration(
                color: idx % 2 == 0 ? Colors.white : kRowAlt,
                border: isLast
                    ? null
                    : const Border(bottom: BorderSide(color: Color(0xFFF1F3F5))),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: kGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.receipt_long_outlined, color: kGreen, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tx.description,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600, color: kNavy)),
                        const SizedBox(height: 2),
                        Text('${tx.date} · ${tx.method}',
                            style: const TextStyle(fontSize: 11, color: kGrey)),
                        const SizedBox(height: 2),
                        Text(tx.ref,
                            style: const TextStyle(
                                fontSize: 10, color: kLightGrey, fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(fmtMoney(tx.amount),
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800, color: kGreen)),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            border: Border.all(color: kBorder),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.receipt_outlined, size: 11, color: kGrey),
                              SizedBox(width: 4),
                              Text('Receipt',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: kGrey)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── KPI Data & Card ───────────────────────────────────────────────
class _KpiData {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _KpiData(this.label, this.value, this.color, this.icon);
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;
  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: data.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(data.icon, color: data.color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(data.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800, color: data.color)),
                const SizedBox(height: 2),
                Text(data.label,
                    style: const TextStyle(
                        fontSize: 10, color: kLightGrey, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Table Header ──────────────────────────────────────────────────
class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
          fontSize: 10, fontWeight: FontWeight.w700, color: kLightGrey, letterSpacing: 0.6),
    );
  }
}

// ── Status Badge ──────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final cfg = switch (status) {
      'paid' => (label: 'Paid', color: kGreen, bg: const Color(0xFFE8F5E9), icon: Icons.check_circle),
      'due' => (label: 'Due', color: kRed, bg: const Color(0xFFFDECEA), icon: Icons.error),
      _ => (label: 'Upcoming', color: kLightGrey, bg: const Color(0xFFF1F3F5), icon: Icons.access_time),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cfg.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(cfg.icon, size: 10, color: cfg.color),
          const SizedBox(width: 3),
          Text(
            cfg.label.toUpperCase(),
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: cfg.color, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

// ── Payment Modal ─────────────────────────────────────────────────
class PaymentModal extends StatefulWidget {
  final double amount;
  final VoidCallback onClose;
  final VoidCallback onPay;

  const PaymentModal({
    super.key,
    required this.amount,
    required this.onClose,
    required this.onPay,
  });

  @override
  State<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<PaymentModal> {
  String _method = 'credit';
  bool _paying = false;
  bool _done = false;
  final _cardNumCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();

  @override
  void dispose() {
    _cardNumCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  void _handlePay() {
    setState(() => _paying = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _done = true);
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        widget.onPay();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: kNavy.withOpacity(0.5),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // absorb taps inside modal
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 60,
                      offset: const Offset(0, 20))
                ],
              ),
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Modal header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Make a Payment',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700, color: kNavy)),
                      GestureDetector(
                        onTap: widget.onClose,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                              color: kBgGrey, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.close, size: 16, color: kGrey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Payment 4 — Class A CDL Tuition',
                        style: TextStyle(fontSize: 13, color: kGrey)),
                  ),
                  const SizedBox(height: 16),

                  // Amount Due box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: kPurple.withOpacity(0.05),
                      border: Border.all(color: kPurple.withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Amount Due',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: kGrey)),
                        Text(fmtMoney(widget.amount),
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: kPurple)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Method tabs
                  Row(
                    children: [
                      _MethodTab(label: 'Credit Card', selected: _method == 'credit',
                          onTap: () => setState(() => _method = 'credit')),
                      const SizedBox(width: 8),
                      _MethodTab(label: 'Bank Transfer', selected: _method == 'bank',
                          onTap: () => setState(() => _method = 'bank')),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Card fields or bank info
                  if (_method == 'credit') ...[
                    _buildInput('Card Number', _cardNumCtrl, 'XXXX XXXX XXXX XXXX'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildInput('Expiry', _expiryCtrl, 'MM / YY')),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _buildInput('CVV', _cvvCtrl, '•••', obscure: true)),
                      ],
                    ),
                  ] else
                    _buildBankInfo(),
                  const SizedBox(height: 20),

                  // Pay button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _paying ? null : _handlePay,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _done ? kGreen : kPurple,
                        disabledBackgroundColor: kPurple.withOpacity(0.7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                        elevation: 4,
                        shadowColor: kPurple.withOpacity(0.4),
                      ),
                      child: _done
                          ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.check_circle, size: 16),
                              SizedBox(width: 8),
                              Text('Payment Successful!'),
                            ])
                          : _paying
                              ? const Text('Processing...')
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.credit_card, size: 16),
                                    const SizedBox(width: 8),
                                    Text(_method == 'credit'
                                        ? 'Pay ${fmtMoney(widget.amount)}'
                                        : 'Confirm Transfer'),
                                  ],
                                ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, String hint,
      {bool obscure = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: kGrey,
                letterSpacing: 0.6)),
        const SizedBox(height: 5),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: kLightGrey, fontSize: 13),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: kBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: kBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: kPurple, width: 1.5)),
          ),
          style: const TextStyle(fontSize: 14, color: kNavy),
        ),
      ],
    );
  }

  Widget _buildBankInfo() {
    final rows = [
      ('Bank Name', 'First National Bank'),
      ('Account Name', 'California School of Trucking'),
      ('Account Number', '****-****-7821'),
      ('Routing Number', '021000021'),
      ('Reference', 'CST-2024-001'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(r.$1,
                        style: const TextStyle(fontSize: 12, color: kLightGrey)),
                    Text(r.$2,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: kNavy)),
                  ],
                ),
              )),
          const Text(
            '⚠️ Please use your Student ID as the payment reference.',
            style: TextStyle(fontSize: 11, color: kLightGrey),
          ),
        ],
      ),
    );
  }
}

class _MethodTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _MethodTab(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? kPurple : const Color(0xFFF8F9FA),
            border: Border.all(
                color: selected ? kPurple : kBorder, width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : kGrey)),
          ),
        ),
      ),
    );
  }
}