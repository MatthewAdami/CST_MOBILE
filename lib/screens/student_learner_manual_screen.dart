// lib/screens/student/student_learner_manual_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:cst_mobile/config/api_config.dart';
import 'package:cst_mobile/screens/pdf_viewer_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _accent  = Color(0xFF7C3AED);
const _navy    = Color(0xFF0B1F3A);
const _white   = Color(0xFFFFFFFF);
const _gray50  = Color(0xFFF8F9FA);
const _gray100 = Color(0xFFF3F4F6);
const _gray200 = Color(0xFFE9ECEF);
const _gray400 = Color(0xFFADB5BD);
const _gray600 = Color(0xFF6C757D);
const _gray700 = Color(0xFF495057);
const _red     = Color(0xFFEF4444);

// ── Category badge colours ────────────────────────────────────────────────────
const _categoryColors = {
  'General':         (Color(0xFFEDE9FE), Color(0xFF5B21B6)),
  'CDL Training':    (Color(0xFFDBEAFE), Color(0xFF1E40AF)),
  'Safety':          (Color(0xFFFEF3C7), Color(0xFF92400E)),
  'HazMat':          (Color(0xFFFEE2E2), Color(0xFF991B1B)),
  'Code of Conduct': (Color(0xFFD1FAE5), Color(0xFF065F46)),
};
const _defaultBadge = (Color(0xFFF3F4F6), Color(0xFF374151));

(Color, Color) _badgeFor(String? cat) =>
    cat != null ? (_categoryColors[cat] ?? _defaultBadge) : _defaultBadge;

// ── Format file size ──────────────────────────────────────────────────────────
String _formatSize(int? bytes) {
  if (bytes == null || bytes == 0) return '';
  final mb = bytes / (1024 * 1024);
  return mb >= 1
      ? '${mb.toStringAsFixed(1)} MB'
      : '${(bytes / 1024).toStringAsFixed(0)} KB';
}

// ── URL resolver — turns relative paths into full URLs ────────────────────────
// ── URL resolver — turns relative paths into full URLs ────────────────────────
String _resolveUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  final String resolved;
  if (url.startsWith('http://') || url.startsWith('https://')) {
    resolved = url;
  } else {
    final base = ApiConfig.baseUrl;
    resolved = '$base${url.startsWith('/') ? '' : '/'}$url';
  }
  return _rewriteGoogleDriveUrl(resolved);
}

/// Converts any Google Drive sharing/preview URL into a direct-download URL.
/// Handles: /file/d/{ID}/view, /file/d/{ID}/preview, /open?id={ID}
String _rewriteGoogleDriveUrl(String url) {
  // Pattern: drive.google.com/file/d/{ID}/...
  final fileMatch = RegExp(
    r'https://drive\.google\.com/file/d/([^/?#]+)',
  ).firstMatch(url);
  if (fileMatch != null) {
    return 'https://drive.google.com/uc?export=download&id=${fileMatch.group(1)}';
  }

  // Pattern: drive.google.com/open?id={ID}
  final openMatch = RegExp(
    r'https://drive\.google\.com/open\?id=([^&]+)',
  ).firstMatch(url);
  if (openMatch != null) {
    return 'https://drive.google.com/uc?export=download&id=${openMatch.group(1)}';
  }

  return url; // not a Drive URL — return as-is
}

// ── Model ─────────────────────────────────────────────────────────────────────
class StudyMaterial {
  final String id, title;
  final String? category, description, fileUrl;
  final int? fileSize;

  const StudyMaterial({
    required this.id,
    required this.title,
    this.category,
    this.description,
    this.fileUrl,
    this.fileSize,
  });

  factory StudyMaterial.fromJson(Map<String, dynamic> j) {
    final rawUrl = j['fileUrl']?.toString();
    final resolved = _resolveUrl(rawUrl);
    debugPrint('📄 [Manual] title="${j['title']}" raw="$rawUrl" resolved="$resolved"');
    return StudyMaterial(
      id:          j['_id']?.toString() ?? '',
      title:       j['title']?.toString() ?? 'Untitled',
      category:    j['category']?.toString(),
      description: j['description']?.toString(),
      fileUrl:     resolved,
      fileSize:    (j['fileSize'] as num?)?.toInt(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class StudentLearnerManualScreen extends StatefulWidget {
  final String authToken;
  const StudentLearnerManualScreen({super.key, required this.authToken});

  @override
  State<StudentLearnerManualScreen> createState() =>
      _StudentLearnerManualScreenState();
}

class _StudentLearnerManualScreenState
    extends State<StudentLearnerManualScreen> {
  List<StudyMaterial> _materials      = [];
  bool                _loading        = true;
  String              _error          = '';
  String?             _openId;
  String              _activeCategory = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/study-materials'),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer ${widget.authToken}',
        },
      ).timeout(ApiConfig.timeout);

      debugPrint('📚 Status: ${res.statusCode}');
      debugPrint('📚 Body: ${res.body}');

      if (res.statusCode != 200) {
        throw Exception('Server returned ${res.statusCode}');
      }

      final decoded = jsonDecode(res.body);

      // Handle both [] and { data: [] } response shapes
      final List raw = decoded is List
          ? decoded
          : (decoded['data'] ?? decoded['materials'] ?? []) as List;

      final mats = raw.map((e) => StudyMaterial.fromJson(e)).toList();

      setState(() {
        _materials = mats;
        _loading   = false;
        if (mats.isNotEmpty) _openId = mats.first.id;
      });
    } catch (e) {
      debugPrint('❌ Manual load error: $e');
      setState(() {
        _error   = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<String> get _categories {
    final cats = _materials
        .map((m) => m.category ?? 'General')
        .toSet()
        .toList();
    return ['All', ...cats];
  }

  List<StudyMaterial> get _filtered => _activeCategory == 'All'
      ? _materials
      : _materials
          .where((m) => (m.category ?? 'General') == _activeCategory)
          .toList();

  void _toggle(String id) =>
      setState(() => _openId = _openId == id ? null : id);

  // ── Open inline PDF viewer ─────────────────────────────────────────────────
  void _openPdf(StudyMaterial material) {
    final url = material.fileUrl ?? '';
    if (url.isEmpty) {
      _showSnack('No file URL available for this document.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(url: url, title: material.title)));
  }

  // ── Download externally ────────────────────────────────────────────────────
  Future<void> _download(StudyMaterial material) async {
    final url = material.fileUrl ?? '';
    if (url.isEmpty) {
      _showSnack('No file URL available for this document.');
      return;
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnack('Could not open file. Check your connection.');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _gray100,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: _white,
        elevation: 0,
        title: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_accent, Color(0xFF9F67FA)],
                begin: Alignment.topLeft,
                end:   Alignment.bottomRight),
              borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.menu_book_outlined,
              size: 16, color: _white)),
          const SizedBox(width: 10),
          const Text("Learner's Manual",
            style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: _white)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined, color: _white, size: 20),
            onPressed: _load),
        ],
      ),
      body: _loading
          ? _buildLoading()
          : _error.isNotEmpty
              ? _buildError()
              : _materials.isEmpty
                  ? _buildEmpty()
                  : _buildContent(),
    );
  }

  // ── Loading ────────────────────────────────────────────────────────────────
  Widget _buildLoading() => const Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(color: _accent, strokeWidth: 2.5),
      SizedBox(height: 16),
      Text('Loading study materials...',
        style: TextStyle(fontSize: 14, color: _gray600)),
    ]),
  );

  // ── Error ──────────────────────────────────────────────────────────────────
  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, size: 40, color: _red),
        const SizedBox(height: 12),
        Text(_error,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: _red, height: 1.5)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Try Again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: _white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)))),
      ]),
    ),
  );

  // ── Empty ──────────────────────────────────────────────────────────────────
  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64, height: 64,
          decoration: const BoxDecoration(
            color: _gray100, shape: BoxShape.circle),
          child: const Icon(Icons.menu_book_outlined,
            size: 30, color: _gray400)),
        const SizedBox(height: 16),
        const Text('No study materials yet',
          style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 8),
        const Text(
          "Your instructor will upload your Learner's Manual soon.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: _gray600, height: 1.5)),
      ]),
    ),
  );

  // ── Main content ───────────────────────────────────────────────────────────
  Widget _buildContent() {
    final cats = _categories;
    return RefreshIndicator(
      onRefresh: _load,
      color: _accent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Count
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              '${_materials.length} '
              '${_materials.length == 1 ? 'document' : 'documents'} available',
              style: const TextStyle(fontSize: 13, color: _gray600))),

          // Info banner
          const _InfoBanner(),
          const SizedBox(height: 16),

          // Category filter
          if (cats.length > 2) ...[
            _CategoryFilter(
              categories: cats,
              active:     _activeCategory,
              onSelect:   (c) => setState(() => _activeCategory = c)),
            const SizedBox(height: 16),
          ],

          // Cards
          ..._filtered.map((m) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MaterialCard(
              material:   m,
              isOpen:     _openId == m.id,
              onToggle:   () => _toggle(m.id),
              onDownload: () => _download(m),
              onOpen:     () => _openPdf(m),
            ),
          )),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// INFO BANNER
// ══════════════════════════════════════════════════════════════════════════════
class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color:        _accent.withOpacity(0.06),
      border:       Border.all(color: _accent.withOpacity(0.18)),
      borderRadius: BorderRadius.circular(10)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.menu_book_outlined, size: 18, color: _accent),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            'Study these materials to prepare for your CDL knowledge and skills tests.',
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: _navy, height: 1.4)),
          const SizedBox(height: 4),
          RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 12, color: _gray600, height: 1.4),
              children: [
                TextSpan(text: 'Tap any card to expand it, then use '),
                TextSpan(text: 'Open PDF',
                  style: TextStyle(fontWeight: FontWeight.w700, color: _navy)),
                TextSpan(text: ' to read inline or '),
                TextSpan(text: 'Download',
                  style: TextStyle(fontWeight: FontWeight.w700, color: _navy)),
                TextSpan(text: ' to save for offline study.'),
              ],
            )),
        ])),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// CATEGORY FILTER CHIPS
// ══════════════════════════════════════════════════════════════════════════════
class _CategoryFilter extends StatelessWidget {
  final List<String>         categories;
  final String               active;
  final ValueChanged<String> onSelect;

  const _CategoryFilter({
    required this.categories,
    required this.active,
    required this.onSelect});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    child: ListView.separated(
      scrollDirection:  Axis.horizontal,
      itemCount:        categories.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final cat      = categories[i];
        final isActive = cat == active;
        return GestureDetector(
          onTap: () => onSelect(cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color:        isActive ? _accent : _white,
              borderRadius: BorderRadius.circular(20),
              border:       Border.all(
                color: isActive ? _accent : _gray200)),
            child: Text(cat,
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: isActive ? _white : _gray700))),
        );
      },
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// MATERIAL CARD
// ══════════════════════════════════════════════════════════════════════════════
class _MaterialCard extends StatefulWidget {
  final StudyMaterial material;
  final bool          isOpen;
  final VoidCallback  onToggle, onDownload, onOpen;

  const _MaterialCard({
    required this.material,
    required this.isOpen,
    required this.onToggle,
    required this.onDownload,
    required this.onOpen});

  @override
  State<_MaterialCard> createState() => _MaterialCardState();
}

class _MaterialCardState extends State<_MaterialCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _expand;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 250));
    _expand = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    if (widget.isOpen) _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(_MaterialCard old) {
    super.didUpdateWidget(old);
    if (widget.isOpen != old.isOpen) {
      widget.isOpen ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final m     = widget.material;
    final badge = _badgeFor(m.category);
    final size  = _formatSize(m.fileSize);

    return Container(
      decoration: BoxDecoration(
        color:        _white,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(
          color: widget.isOpen ? _accent.withOpacity(0.35) : _gray200),
        boxShadow: [BoxShadow(
          color: widget.isOpen
              ? _accent.withOpacity(0.08)
              : Colors.black.withOpacity(0.04),
          blurRadius: widget.isOpen ? 14 : 6,
          offset: const Offset(0, 2))]),
      child: Column(children: [

        // ── Tap header ─────────────────────────────────────────────────────
        InkWell(
          onTap:        widget.onToggle,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Icon
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color:        _accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.description_outlined,
                  size: 22, color: _accent)),
              const SizedBox(width: 12),

              // Title + meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(m.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _navy)),
                        if (m.category != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color:        badge.$1,
                              borderRadius: BorderRadius.circular(20)),
                            child: Text(m.category!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: badge.$2,
                                letterSpacing: 0.4))),
                      ]),
                    if (m.description != null && m.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(m.description!,
                        style: const TextStyle(
                          fontSize: 12, color: _gray600, height: 1.4),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'PDF${size.isNotEmpty ? ' · $size' : ''}',
                      style: const TextStyle(fontSize: 11, color: _gray400)),
                  ],
                )),
              const SizedBox(width: 8),

              // Chevron
              AnimatedRotation(
                turns:    widget.isOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 250),
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: widget.isOpen
                        ? _accent.withOpacity(0.1) : _gray50,
                    borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.keyboard_arrow_down,
                    size: 18,
                    color: widget.isOpen ? _accent : _gray400))),
            ]),
          ),
        ),

        // ── Action buttons ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Row(children: [
            Expanded(child: _ActionBtn(
              icon:      Icons.download_outlined,
              label:     'Download',
              onTap:     widget.onDownload,
              isPrimary: false)),
            const SizedBox(width: 10),
            Expanded(child: _ActionBtn(
              icon:      Icons.picture_as_pdf_outlined,
              label:     'Open PDF',
              onTap:     widget.onOpen,
              isPrimary: true)),
          ]),
        ),

        // ── Expandable panel ───────────────────────────────────────────────
        SizeTransition(
          sizeFactor: _expand,
          child: Column(children: [
            Container(height: 1, color: _gray200),
            _ExpandedPanel(material: m),
          ]),
        ),
      ]),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;
  final bool         isPrimary;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isPrimary});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color:        isPrimary ? _accent.withOpacity(0.09) : _gray50,
        border:       Border.all(
          color: isPrimary ? _accent.withOpacity(0.28) : _gray200),
        borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 15,
          color: isPrimary ? _accent : _gray700),
        const SizedBox(width: 6),
        Text(label,
          style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: isPrimary ? _accent : _gray700)),
      ]),
    ),
  );
}

// ── Expanded detail panel ─────────────────────────────────────────────────────
class _ExpandedPanel extends StatelessWidget {
  final StudyMaterial material;
  const _ExpandedPanel({required this.material});

  @override
  Widget build(BuildContext context) {
    final m    = material;
    final size = _formatSize(m.fileSize);

    return Container(
      width:   double.infinity,
      color:   _gray50,
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header
        Row(children: [
          const Icon(Icons.visibility_outlined, size: 14, color: _accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text('Reading: ${m.title}',
              style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: _navy),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 12),

        // Chips
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (m.category != null)
            _DetailChip(icon: Icons.label_outline, label: m.category!),
          if (size.isNotEmpty)
            _DetailChip(icon: Icons.insert_drive_file_outlined, label: size),
          const _DetailChip(
            icon:  Icons.picture_as_pdf_outlined,
            label: 'PDF Document'),
        ]),
        const SizedBox(height: 14),

        // Hint
        Container(
          width:   double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:        _accent.withOpacity(0.06),
            border:       Border.all(color: _accent.withOpacity(0.15)),
            borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 14, color: _accent),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 12, color: _gray600, height: 1.4),
                  children: [
                    TextSpan(text: 'Tap '),
                    TextSpan(text: 'Open PDF',
                      style: TextStyle(
                        fontWeight: FontWeight.w700, color: _accent)),
                    TextSpan(text: ' to read inside the app. Tap '),
                    TextSpan(text: 'Download',
                      style: TextStyle(
                        fontWeight: FontWeight.w700, color: _navy)),
                    TextSpan(text: ' to save for offline study.'),
                  ],
                ))),
          ]),
        ),

        // Description
        if (m.description != null && m.description!.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('About this document',
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: _gray400, letterSpacing: 0.6)),
          const SizedBox(height: 5),
          Text(m.description!,
            style: const TextStyle(
              fontSize: 13, color: _gray700, height: 1.65)),
        ],
      ]),
    );
  }
}

// ── Detail chip ───────────────────────────────────────────────────────────────
class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _DetailChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color:        _white,
      border:       Border.all(color: _gray200),
      borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: _gray400),
      const SizedBox(width: 5),
      Text(label,
        style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600, color: _gray700)),
    ]),
  );
}