// ══════════════════════════════════════════════════════════════════════════════
// SIGNATURE PAD WIDGET
// Drop-in replacement for the typed signature in Step 9.
// Uses GestureDetector + CustomPainter — no external packages needed.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:typed_data';

const _navy    = Color(0xFF0B1F3A);
const _purple  = Color(0xFF7C3AED);
const _danger  = Color(0xFFC0392B);
const _muted   = Color(0xFF6C757D);
const _white   = Color(0xFFFFFFFF);
const _light   = Color(0xFFF8F9FA);
const _border  = Color(0xFFE9ECEF);
const _success = Color(0xFF2D8A4E);

// ── Single stroke ─────────────────────────────────────────────────────────────
class _Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  _Stroke({ required this.points, required this.color, required this.width });
}

// ── Painter ───────────────────────────────────────────────────────────────────
class _SignaturePainter extends CustomPainter {
  final List<_Stroke> strokes;
  final _Stroke? current;

  _SignaturePainter({ required this.strokes, this.current });

  void _drawStroke(Canvas canvas, _Stroke stroke) {
    if (stroke.points.isEmpty) return;
    final paint = Paint()
      ..color       = stroke.color
      ..strokeWidth = stroke.width
      ..strokeCap   = StrokeCap.round
      ..strokeJoin  = StrokeJoin.round
      ..style       = PaintingStyle.stroke;

    final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (int i = 1; i < stroke.points.length; i++) {
      if (i == 1) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      } else {
        // Smooth curve through midpoints
        final prev = stroke.points[i - 1];
        final curr = stroke.points[i];
        final mid  = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
        path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) { _drawStroke(canvas, s); }
    if (current != null)      { _drawStroke(canvas, current!); }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}

// ── Signature Pad ─────────────────────────────────────────────────────────────
class SignaturePad extends StatefulWidget {
  /// Called whenever the signature changes (has strokes or is cleared).
  final ValueChanged<bool> onChanged;
  final double height;

  const SignaturePad({
    super.key,
    required this.onChanged,
    this.height = 160,
  });

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final List<_Stroke> _strokes = [];
  List<Offset> _current        = [];
  bool _hasSignature            = false;

  static const _inkColor = _navy;
  static const _inkWidth = 2.8;

  bool get hasSignature => _hasSignature;

  void clear() {
    setState(() {
      _strokes.clear();
      _current.clear();
      _hasSignature = false;
    });
    widget.onChanged(false);
  }

  /// Exports the signature as a PNG byte array (for upload if needed).
  Future<Uint8List?> toBytes({ double pixelRatio = 2.0 }) async {
    final boundary = _repaintKey.currentContext
        ?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data  = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  final _repaintKey = GlobalKey();

  void _onPanStart(DragStartDetails d) {
    setState(() {
      _current = [d.localPosition];
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() {
      _current = [..._current, d.localPosition];
    });
  }

  void _onPanEnd(DragEndDetails _) {
    if (_current.length < 2) {
      // Tap — draw a dot
      if (_current.isNotEmpty) {
        final p = _current.first;
        _strokes.add(_Stroke(
          points: [p, p.translate(0.1, 0.1)],
          color: _inkColor, width: _inkWidth,
        ));
      }
    } else {
      _strokes.add(_Stroke(
        points: List.from(_current),
        color: _inkColor, width: _inkWidth,
      ));
    }
    setState(() {
      _current    = [];
      _hasSignature = true;
    });
    widget.onChanged(true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Canvas area
        RepaintBoundary(
          key: _repaintKey,
          child: GestureDetector(
            onPanStart:  _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd:    _onPanEnd,
            child: Container(
              height: widget.height,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFF),
                border: Border.all(
                  color: _hasSignature ? _purple : _border,
                  width: _hasSignature ? 2 : 1.5,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Stack(
                  children: [
                    // Baseline
                    Positioned(
                      bottom: 36, left: 20, right: 20,
                      child: Container(height: 1, color: _border),
                    ),
                    // Hint text when empty
                    if (!_hasSignature && _current.isEmpty)
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.draw_outlined,
                              size: 28, color: _muted.withOpacity(0.4)),
                            const SizedBox(height: 6),
                            Text('Sign here',
                              style: TextStyle(fontSize: 13, color: _muted.withOpacity(0.5),
                                fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                    // Signature strokes
                    CustomPaint(
                      painter: _SignaturePainter(
                        strokes: _strokes,
                        current: _current.isNotEmpty
                            ? _Stroke(points: _current, color: _inkColor, width: _inkWidth)
                            : null,
                      ),
                      size: Size.infinite,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Bottom bar: label + clear button
        Row(
          children: [
            const Icon(Icons.draw_outlined, size: 13, color: _muted),
            const SizedBox(width: 5),
            const Expanded(
              child: Text('Draw your signature above using your finger',
                style: TextStyle(fontSize: 11, color: _muted)),
            ),
            if (_hasSignature)
              GestureDetector(
                onTap: clear,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _danger.withOpacity(0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.refresh, size: 12, color: _danger),
                    const SizedBox(width: 4),
                    const Text('Clear', style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: _danger)),
                  ]),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STEP 9 — E-Signature (with drawing pad)
// Replace the old _Step9 class in enrollment_agreement_screen.dart with this.
// ══════════════════════════════════════════════════════════════════════════════
class Step9WithDrawing extends StatefulWidget {
  final dynamic data;          // EnrollmentFormData
  final VoidCallback onChanged;
  final String studentName;

  const Step9WithDrawing({
    super.key,
    required this.data,
    required this.onChanged,
    required this.studentName,
  });

  @override
  State<Step9WithDrawing> createState() => _Step9WithDrawingState();
}

class _Step9WithDrawingState extends State<Step9WithDrawing> {
  final _padKey = GlobalKey<SignaturePadState>();
  bool _hasSig  = false;

  String _monthName(int m) =>
    ['January','February','March','April','May','June',
     'July','August','September','October','November','December'][m-1];

  @override
  Widget build(BuildContext context) {
    final data    = widget.data;
    final today   = DateTime.now();
    final dateStr = '${_monthName(today.month)} ${today.day}, ${today.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Legal banner ────────────────────────────────────────────────────
        const _SectionTitle('E-Signature & Final Submission'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9EC),
            border: Border.all(color: const Color(0xFFFDE68A)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'THIS ENROLLMENT AGREEMENT IS A LEGALLY BINDING INSTRUMENT WHEN SIGNED BY THE STUDENT AND ACCEPTED BY THE SCHOOL.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E)),
              ),
              SizedBox(height: 8),
              Text(
                'I UNDERSTAND THAT THIS IS A LEGALLY BINDING CONTRACT. MY SIGNATURE BELOW CERTIFIES THAT I HAVE READ, UNDERSTOOD, AND AGREED TO MY RIGHTS AND RESPONSIBILITIES.',
                style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Agreement checkbox ───────────────────────────────────────────────
        _AppCheckbox(
          label: 'I agree to all terms and conditions',
          description:
              'By checking this box, I confirm that I have read all 9 sections of this enrollment agreement and agree to be bound by its terms.',
          checked: data.agreed,
          onChanged: (v) { data.agreed = v; widget.onChanged(); },
        ),
        const SizedBox(height: 16),

        // ── Printed name ─────────────────────────────────────────────────────
        _AppInput(
          label: 'Printed Name of Student',
          value: data.printedName,
          required: true,
          hint: widget.studentName.isNotEmpty ? widget.studentName : 'Enter your full legal name',
          onChanged: (v) { data.printedName = v; widget.onChanged(); setState(() {}); },
        ),
        const SizedBox(height: 20),

        // ── Signature pad ────────────────────────────────────────────────────
        _SectionTitle('Signature of Student'),
        const Text(
          'Draw your signature below using your finger or stylus.',
          style: TextStyle(fontSize: 12, color: _muted),
        ),
        const SizedBox(height: 10),

        SignaturePad(
          key: _padKey,
          height: 180,
          onChanged: (hasSig) {
            setState(() => _hasSig = hasSig);
            widget.onChanged();
          },
        ),

        // Status indicator
        if (!_hasSig && data.agreed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded, size: 14, color: _danger.withOpacity(0.8)),
              const SizedBox(width: 6),
              const Text('Please draw your signature above',
                style: TextStyle(fontSize: 12, color: _danger)),
            ]),
          ),
        if (_hasSig)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              const Icon(Icons.check_circle_outline, size: 14, color: _success),
              const SizedBox(width: 6),
              const Text('Signature captured',
                style: TextStyle(fontSize: 12, color: _success, fontWeight: FontWeight.w600)),
            ]),
          ),

        const SizedBox(height: 20),

        // ── Date & school info ───────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _light,
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Date: $dateStr',
                style: const TextStyle(fontSize: 12, color: _muted)),
              const SizedBox(height: 4),
              const Text('California School of Trucking LLC',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _navy)),
              const SizedBox(height: 2),
              const Text(
                'Corporate Office: 3787 Transport Street Suite 10, Ventura, CA 93003\n'
                'Training Yard: 251 S. G Street, San Bernardino, CA 94210\n'
                'Phone: 909.906.3106 | Admin@caschooloftrucking.com',
                style: TextStyle(fontSize: 11, color: _muted, height: 1.6),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Reused widgets (copy from enrollment_agreement_screen.dart) ───────────────
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(children: [
      Container(width: 4, height: 18,
        decoration: BoxDecoration(color: _purple, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      Expanded(child: Text(text.toUpperCase(),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
            color: _navy, letterSpacing: 0.8))),
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
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
          color: _muted, letterSpacing: 0.7),
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
    this.required = false, this.hint,
    this.keyboardType = TextInputType.text, this.obscure = false,
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: _border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: _border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: _purple)),
          filled: true, fillColor: _white,
        ),
      ),
    ],
  );
}

class _AppCheckbox extends StatelessWidget {
  final String label;
  final bool checked;
  final ValueChanged<bool> onChanged;
  final String? description;

  const _AppCheckbox({
    required this.label, required this.checked,
    required this.onChanged, this.description,
  });

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
          child: checked
              ? const Icon(Icons.check, size: 13, color: _white)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 13,
              fontWeight: FontWeight.w600, color: _navy)),
          if (description != null) ...[
            const SizedBox(height: 3),
            Text(description!, style: const TextStyle(fontSize: 12,
                color: _muted, height: 1.5)),
          ],
        ])),
      ]),
    ),
  );
}