// lib/screens/document_screen.dart

import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart'; // add this import
import '../config/api_config.dart';

// ══════════════════════════════════════════════════════════════════
// COLOURS
// ══════════════════════════════════════════════════════════════════
class _C {
  static const navy    = Color(0xFF0B1F3A);
  static const purple  = Color(0xFF7C3AED);
  static const white   = Color(0xFFFFFFFF);
  static const gray50  = Color(0xFFF8F9FA);
  static const gray100 = Color(0xFFF1F3F5);
  static const gray200 = Color(0xFFE9ECEF);
  static const gray400 = Color(0xFFADB5BD);
  static const gray600 = Color(0xFF6C757D);
  static const gray800 = Color(0xFF343A40);
  static const green   = Color(0xFF28A745);
  static const red     = Color(0xFFDC3545);
  static const yellow  = Color(0xFFFFC107);
}

// ══════════════════════════════════════════════════════════════════
// DOC TYPE DEFINITIONS  (mirrors React DOC_TYPES)
// ══════════════════════════════════════════════════════════════════
class _DocTypeDef {
  final String docType, type, description;
  final IconData icon;
  final bool required;
  const _DocTypeDef({
    required this.docType, required this.type,
    required this.description, required this.icon,
    required this.required,
  });
}

const _docTypes = [
  _DocTypeDef(
    docType: 'government-id', type: 'Government ID',
    description: 'Valid US government-issued photo ID (US Passport, State ID, or Military ID)',
    icon: Icons.shield_outlined, required: true,
  ),
  _DocTypeDef(
    docType: 'drivers-license', type: "Driver's License",
    description: "Current valid US state driver's license",
    icon: Icons.directions_car_outlined, required: true,
  ),
  _DocTypeDef(
    docType: 'medical-certificate', type: 'DOT Medical Certificate',
    description: 'FMCSA DOT physical exam certificate (Form MCSA-5876)',
    icon: Icons.medical_services_outlined, required: true,
  ),
  _DocTypeDef(
    docType: 'proof-of-enrollment', type: 'Proof of Enrollment',
    description: 'Official enrollment confirmation letter from CST',
    icon: Icons.task_outlined, required: true,
  ),
  _DocTypeDef(
    docType: 'cdl-permit', type: "Commercial Learner's Permit (CLP)",
    description: 'CLP issued by your state DMV — required before CDL skills test',
    icon: Icons.credit_card_outlined, required: true,
  ),
  _DocTypeDef(
    docType: 'other', type: 'Additional Documents',
    description: 'Hazmat endorsement, drug test results, VA benefits letter, etc.',
    icon: Icons.workspace_premium_outlined, required: false,
  ),
];

// ══════════════════════════════════════════════════════════════════
// STATUS CONFIG
// ══════════════════════════════════════════════════════════════════
enum _DocStatus { approved, pending, rejected, missing }

class _StatusCfg {
  final String label;
  final Color color, bg;
  final IconData icon;
  const _StatusCfg(this.label, this.color, this.bg, this.icon);
}

const Map<_DocStatus, _StatusCfg> _statusCfg = {
  _DocStatus.approved: _StatusCfg('Approved',     _C.green,  Color(0xFFE8F5E9), Icons.check_circle),
  _DocStatus.pending:  _StatusCfg('Under Review', _C.yellow, Color(0xFFFFF8E1), Icons.access_time),
  _DocStatus.rejected: _StatusCfg('Rejected',     _C.red,    Color(0xFFFDECEA), Icons.cancel),
  _DocStatus.missing:  _StatusCfg('Missing',      _C.gray400, _C.gray100,       Icons.error_outline),
};

_DocStatus _parseStatus(String? s) => switch (s) {
  'approved' => _DocStatus.approved,
  'pending'  => _DocStatus.pending,
  'rejected' => _DocStatus.rejected,
  _          => _DocStatus.missing,
};

String _formatSize(int? bytes) {
  if (bytes == null) return '—';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

String _formatDate(String? iso) {
  if (iso == null) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return '—';
  const months = ['Jan','Feb','Mar','Apr','May','Jun',
                  'Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

// ══════════════════════════════════════════════════════════════════
// DOCUMENTS SCREEN
// ══════════════════════════════════════════════════════════════════
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});
  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<Map<String, dynamic>> _uploadedDocs = [];
  bool _loading = true;
  String _token = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token') ?? '';
    await _fetchDocs();
  }

  // ── GET /api/documents ───────────────────────────────────────
  Future<void> _fetchDocs() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.documents),
        headers: {'Authorization': 'Bearer $_token'},
      ).timeout(ApiConfig.timeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => _uploadedDocs = List<Map<String, dynamic>>.from(data));
      }
    } catch (_) {}
    finally { setState(() => _loading = false); }
  }

  Map<String, dynamic>? _getUploaded(String docType) =>
    _uploadedDocs.cast<Map<String, dynamic>?>()
      .firstWhere((d) => d?['docType'] == docType, orElse: () => null);

  // ── DELETE /api/documents/:id ────────────────────────────────
  Future<void> _delete(String id) async {
    try {
      await http.delete(
        Uri.parse(ApiConfig.documentDelete(id)),
        headers: {'Authorization': 'Bearer $_token'},
      ).timeout(ApiConfig.timeout);
      await _fetchDocs();
    } catch (_) {}
  }

  // ── Stats ────────────────────────────────────────────────────
  int _count(_DocStatus s) => _uploadedDocs
    .where((d) => _parseStatus(d['status']) == s).length;

  int get _missing => _docTypes
    .where((d) => _getUploaded(d.docType) == null).length;

  List<_DocTypeDef> get _reqTypes => _docTypes.where((d) => d.required).toList();
  int get _reqDone => _reqTypes
    .where((d) => _parseStatus(_getUploaded(d.docType)?['status']) == _DocStatus.approved).length;
  double get _completion => _reqTypes.isEmpty ? 0 : _reqDone / _reqTypes.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.gray100,
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: _C.purple))
        : RefreshIndicator(
            onRefresh: _fetchDocs,
            color: _C.purple,
            child: CustomScrollView(
              slivers: [

                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.description_outlined, color: _C.purple, size: 22),
                        SizedBox(width: 8),
                        Text('My Documents',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                            color: _C.navy)),
                      ]),
                      const SizedBox(height: 4),
                      const Text('Upload and manage your required enrollment documents.',
                        style: TextStyle(fontSize: 13, color: _C.gray600)),
                      const SizedBox(height: 16),
                      _CompletionBanner(
                        reqDone: _reqDone,
                        reqTotal: _reqTypes.length,
                        completion: _completion,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                )),

                // ── Stat pills ──────────────────────────────────
                SliverToBoxAdapter(child: SizedBox(
                  height: 62,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _StatPill(label: 'Approved',     value: _count(_DocStatus.approved), color: _C.green),
                      _StatPill(label: 'Under Review', value: _count(_DocStatus.pending),  color: _C.yellow),
                      _StatPill(label: 'Missing',      value: _missing,                    color: _C.gray400),
                      _StatPill(label: 'Rejected',     value: _count(_DocStatus.rejected), color: _C.red),
                    ],
                  ),
                )),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // ── Required ────────────────────────────────────
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: _SectionHeader(title: 'Required Documents',
                    count: _reqTypes.length),
                )),
                SliverList(delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final def = _reqTypes[i];
                    final uploaded = _getUploaded(def.docType);
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: _DocCard(
                        def: def,
                        uploaded: uploaded,
                        onUpload: () => _openUpload(def),
                        onDelete: uploaded != null
                          ? () => _delete(uploaded['_id']) : null,
                      ),
                    );
                  },
                  childCount: _reqTypes.length,
                )),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // ── Optional ────────────────────────────────────
                const SliverToBoxAdapter(child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text('Optional Documents',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                      color: _C.gray600)),
                )),
                SliverList(delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final def = _docTypes.where((d) => !d.required).toList()[i];
                    final uploaded = _getUploaded(def.docType);
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: _DocCard(
                        def: def,
                        uploaded: uploaded,
                        onUpload: () => _openUpload(def),
                        onDelete: uploaded != null
                          ? () => _delete(uploaded['_id']) : null,
                      ),
                    );
                  },
                  childCount: _docTypes.where((d) => !d.required).length,
                )),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
    );
  }

  // ── Upload bottom sheet ──────────────────────────────────────
  Future<void> _openUpload(_DocTypeDef def) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UploadSheet(
        def: def, token: _token,
        onUploaded: _fetchDocs,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// UPLOAD SHEET  — real file_picker + multipart POST
// ══════════════════════════════════════════════════════════════════
class _UploadSheet extends StatefulWidget {
  final _DocTypeDef def;
  final String token;
  final VoidCallback onUploaded;
  const _UploadSheet({required this.def, required this.token, required this.onUploaded});

  @override
  State<_UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends State<_UploadSheet> {
  PlatformFile? _picked;
  bool _uploading = false;
  bool _done      = false;
  String _error   = '';

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() { _picked = result.files.first; _error = ''; });
    }
  }

  // ── POST /api/documents/upload  (multipart) ──────────────────
 String _getMimeType(String filename) {
  final ext = filename.split('.').last.toLowerCase();
  return switch (ext) {
    'pdf'  => 'application/pdf',
    'jpg'  => 'image/jpeg',
    'jpeg' => 'image/jpeg',
    'png'  => 'image/png',
    _      => 'application/octet-stream',
  };
}

Future<void> _upload() async {
  if (_picked == null || _picked!.bytes == null) return;
  setState(() { _uploading = true; _error = ''; });

  try {
    final mimeType = _getMimeType(_picked!.name);
    print('📤 MIME type: $mimeType');

    final req = http.MultipartRequest(
      'POST', Uri.parse(ApiConfig.documentUpload),
    )
      ..headers['Authorization'] = 'Bearer ${widget.token}'
      ..fields['docType'] = widget.def.docType
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        _picked!.bytes!,
        filename:    _picked!.name,
        contentType: MediaType.parse(mimeType), // ← this is the fix
      ));

    final streamed = await req.send().timeout(const Duration(seconds: 30));
    final res      = await http.Response.fromStream(streamed);

    print('📥 Status: ${res.statusCode}');
    print('📥 Body: ${res.body}');

    if (res.statusCode == 200 || res.statusCode == 201) {
      setState(() { _uploading = false; _done = true; });
      await Future.delayed(const Duration(milliseconds: 800));
      widget.onUploaded();
      if (mounted) Navigator.of(context).pop();
    } else {
      // server returned non-200 but valid JSON
      try {
        final body = jsonDecode(res.body);
        setState(() {
          _uploading = false;
          _error = body['message'] ?? 'Upload failed. (${res.statusCode})';
        });
      } catch (_) {
        setState(() {
          _uploading = false;
          _error = 'Upload failed. (${res.statusCode})';
        });
      }
    }
  } catch (e) {
    print('❌ Upload error: $e');
    setState(() {
      _uploading = false;
      _error = 'Error: ${e.toString()}';
    });
  }
}
  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    decoration: const BoxDecoration(
      color: _C.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: _C.gray200, borderRadius: BorderRadius.circular(2)),
        )),
        const SizedBox(height: 18),

        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Upload Document',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
              color: _C.navy)),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _C.gray100, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.close, size: 16, color: _C.gray600),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text('${widget.def.type} — ${widget.def.description}',
          style: const TextStyle(fontSize: 13, color: _C.gray600)),
        const SizedBox(height: 20),

        // ── File picker zone ─────────────────────────────────
        GestureDetector(
          onTap: _pick,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: _picked != null ? const Color(0xFFF0FFF4) : _C.gray50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _picked != null ? _C.green : _C.gray200, width: 2),
            ),
            child: _picked == null
              ? const Column(children: [
                  Icon(Icons.upload_file_outlined, size: 36, color: _C.gray400),
                  SizedBox(height: 10),
                  Text('Tap to browse files',
                    style: TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w700, color: _C.navy)),
                  SizedBox(height: 4),
                  Text('Accepted: PDF, JPG, PNG — max 10 MB',
                    style: TextStyle(fontSize: 12, color: _C.gray400)),
                ])
              : Column(children: [
                  const Icon(Icons.check_circle, size: 36, color: _C.green),
                  const SizedBox(height: 10),
                  Text(_picked!.name,
                    style: const TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w700, color: _C.green)),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatSize(_picked!.size)}  ·  tap to change',
                    style: const TextStyle(fontSize: 12, color: _C.gray400)),
                ]),
          ),
        ),

        if (_error.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFDECEA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline, size: 14, color: _C.red),
              const SizedBox(width: 8),
              Expanded(child: Text(_error,
                style: const TextStyle(fontSize: 13, color: _C.red))),
            ]),
          ),
        ],

        const SizedBox(height: 20),

        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _C.gray200),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cancel',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                color: _C.gray600)),
          )),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: ElevatedButton(
            onPressed: (_picked == null || _uploading) ? null : _upload,
            style: ElevatedButton.styleFrom(
              backgroundColor: _done ? _C.green : _C.purple,
              disabledBackgroundColor: _C.gray200,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _done
              ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.check_circle, size: 16, color: _C.white),
                  SizedBox(width: 8),
                  Text('Uploaded!',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                      color: _C.white)),
                ])
              : _uploading
                ? const SizedBox(height: 18, width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _C.white))
                : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.upload_outlined, size: 16, color: _C.white),
                    SizedBox(width: 8),
                    Text('Upload Document',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                        color: _C.white)),
                  ]),
          )),
        ]),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════════
// DOC CARD
// ══════════════════════════════════════════════════════════════════
class _DocCard extends StatelessWidget {
  final _DocTypeDef def;
  final Map<String, dynamic>? uploaded;
  final VoidCallback onUpload;
  final VoidCallback? onDelete;
  const _DocCard({
    required this.def, required this.uploaded,
    required this.onUpload, required this.onDelete,
  });

  bool get _hasFile => uploaded != null;
  _DocStatus get _status => _parseStatus(uploaded?['status']);

  @override
  Widget build(BuildContext context) {
    final cfg = _statusCfg[_status]!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.gray200),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(.03), blurRadius: 4)],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: cfg.color),
              Expanded(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: _hasFile
                            ? _C.purple.withOpacity(.12) : _C.gray100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(def.icon, size: 20,
                          color: _hasFile ? _C.purple : _C.gray400),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Flexible(child: Text(def.type,
                              style: const TextStyle(fontSize: 14,
                                fontWeight: FontWeight.w700, color: _C.navy))),
                            if (!def.required) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _C.gray100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('OPTIONAL',
                                  style: TextStyle(fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: _C.gray400, letterSpacing: .8)),
                              ),
                            ],
                          ]),
                          const SizedBox(height: 3),
                          Text(def.description,
                            style: const TextStyle(fontSize: 12,
                              color: _C.gray600, height: 1.4)),
                          if (_hasFile) ...[
                            const SizedBox(height: 5),
                            Text(
                              '📄 ${uploaded!['fileName'] ?? ''}  ·  '
                              '${_formatSize(uploaded!['fileSize'])}  ·  '
                              'Uploaded ${_formatDate(uploaded!['createdAt'])}',
                              style: const TextStyle(
                                fontSize: 11, color: _C.gray400)),
                          ],
                          if (uploaded?['rejectionReason'] != null) ...[
                            const SizedBox(height: 5),
                            Row(children: [
                              const Icon(Icons.error_outline,
                                size: 11, color: _C.red),
                              const SizedBox(width: 4),
                              Expanded(child: Text(
                                uploaded!['rejectionReason'],
                                style: const TextStyle(fontSize: 12,
                                  color: _C.red, fontWeight: FontWeight.w600))),
                            ]),
                          ],
                        ],
                      )),
                    ]),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: _C.gray100),
                    const SizedBox(height: 10),
                    _StatusBadge(status: _status),
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      if (_hasFile) ...[
                        _ActionButton(
                          icon: Icons.visibility_outlined,
                          label: 'View',
                          onTap: () {
                            final url = uploaded?['cloudinaryUrl'];
                            // open url if available
                          },
                        ),
                        if (onDelete != null)
                          GestureDetector(
                            onTap: onDelete,
                            child: Container(
                              width: 34, height: 34,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF5F5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: const Icon(Icons.delete_outline,
                                size: 15, color: _C.red),
                            ),
                          ),
                      ],
                      GestureDetector(
                        onTap: onUpload,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _hasFile ? _C.gray100 : _C.purple,
                            borderRadius: BorderRadius.circular(8),
                            border: _hasFile
                              ? Border.all(color: _C.gray200) : null,
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.upload_outlined, size: 13,
                              color: _hasFile ? _C.gray600 : _C.white),
                            const SizedBox(width: 5),
                            Text(_hasFile ? 'Re-upload' : 'Upload',
                              style: TextStyle(fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _hasFile ? _C.gray600 : _C.white)),
                          ]),
                        ),
                      ),
                    ]),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ══════════════════════════════════════════════════════════════════
class _CompletionBanner extends StatelessWidget {
  final int reqDone, reqTotal;
  final double completion;
  const _CompletionBanner({
    required this.reqDone, required this.reqTotal, required this.completion});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _C.white, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _C.gray200),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 6)],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Required Documents Completion',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: _C.navy)),
          Text('$reqDone / $reqTotal approved',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
              color: _C.purple)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: completion, minHeight: 10,
            backgroundColor: _C.gray200,
            valueColor: AlwaysStoppedAnimation(
              completion >= 1.0 ? _C.green : _C.purple),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          completion >= 1.0
            ? '✅ All required documents submitted and approved!'
            : '${((1 - completion) * 100).round()}% remaining — please upload missing documents.',
          style: const TextStyle(fontSize: 12, color: _C.gray400)),
      ],
    ),
  );
}

class _StatPill extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 10),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    decoration: BoxDecoration(
      color: _C.white, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _C.gray200),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 4)],
    ),
    child: Row(children: [
      Text('$value',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(width: 10),
      Text(label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
          color: _C.gray600)),
    ]),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) => Row(children: [
    Text(title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
        color: _C.navy)),
    const SizedBox(width: 8),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _C.purple.withOpacity(.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$count',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          color: _C.purple)),
    ),
  ]);
}

class _StatusBadge extends StatelessWidget {
  final _DocStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final cfg = _statusCfg[status]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cfg.bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(cfg.icon, size: 11, color: cfg.color),
        const SizedBox(width: 5),
        Text(cfg.label.toUpperCase(),
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
            color: cfg.color, letterSpacing: .6)),
      ]),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: _C.gray50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.gray200),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: _C.gray600),
        const SizedBox(width: 4),
        Text(label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
            color: _C.gray600)),
      ]),
    ),
  );
}