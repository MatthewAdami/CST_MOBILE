// lib/screens/pdf_viewer_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _navy   = Color(0xFF0B1F3A);
const _accent = Color(0xFF7C3AED);
const _white  = Color(0xFFFFFFFF);
const _gray50 = Color(0xFFF8F9FA);
const _gray200= Color(0xFFE9ECEF);
const _gray400= Color(0xFFADB5BD);
const _gray600= Color(0xFF6C757D);
const _red    = Color(0xFFEF4444);

class PdfViewerScreen extends StatefulWidget {
  final String url, title;
  const PdfViewerScreen({super.key, required this.url, required this.title});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  // ── state ─────────────────────────────────────────────────────────────────
  String?  _localPath;
  bool     _loading     = true;
  String   _error       = '';
  int      _totalPages  = 0;
  int      _currentPage = 0;
  double   _progress    = 0;   // download progress 0–1
  String   _status      = 'Connecting...';

  final PdfViewerController _ctrl = PdfViewerController();

  @override
  void initState() {
    super.initState();
    _downloadAndLoad();
  }

  // ── Download PDF bytes (with auth token) then save to temp file ───────────
  Future<void> _downloadAndLoad() async {
    setState(() {
      _loading  = true;
      _error    = '';
      _progress = 0;
      _status   = 'Connecting...';
    });

    try {
      // Get stored auth token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      debugPrint('📥 Downloading PDF: ${widget.url}');
      debugPrint('🔑 Auth token: ${token.isNotEmpty ? '${token.substring(0, 10)}...' : 'EMPTY'}');

      setState(() => _status = 'Downloading...');

      // Use a streamed request so we can show download progress
      final request = http.Request('GET', Uri.parse(widget.url));
      if (token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Accept'] = 'application/pdf,*/*';

      final streamedResponse = await request.send()
          .timeout(const Duration(seconds: 60));

      debugPrint('📥 Response status: ${streamedResponse.statusCode}');
      debugPrint('📥 Content-Type: ${streamedResponse.headers['content-type']}');
      debugPrint('📥 Content-Length: ${streamedResponse.contentLength}');

      if (streamedResponse.statusCode != 200) {
        throw Exception(
          'Server returned ${streamedResponse.statusCode}. '
          'Check the file URL and permissions.');
      }

      // Check content type
      final contentType = streamedResponse.headers['content-type'] ?? '';
      if (!contentType.contains('pdf') &&
          !contentType.contains('octet-stream') &&
          !contentType.contains('application')) {
        debugPrint('⚠️ Unexpected content-type: $contentType');
      }

      // Read bytes with progress
      final contentLength = streamedResponse.contentLength ?? 0;
      final bytes = <int>[];

      await for (final chunk in streamedResponse.stream) {
        bytes.addAll(chunk);
        if (contentLength > 0 && mounted) {
          setState(() {
            _progress = bytes.length / contentLength;
            _status   = 'Downloading ${(_progress * 100).toStringAsFixed(0)}%...';
          });
        }
      }

      debugPrint('📥 Downloaded ${bytes.length} bytes');

      if (bytes.isEmpty) {
        throw Exception('Downloaded file is empty. The file may not exist on the server.');
      }

      // Verify PDF signature (%PDF-)
      if (bytes.length >= 4) {
        final header = String.fromCharCodes(bytes.take(5));
        debugPrint('📄 File header: $header');
        if (!header.startsWith('%PDF')) {
          // Try to show what we got (might be an error JSON/HTML)
          final preview = String.fromCharCodes(
              bytes.take(bytes.length < 200 ? bytes.length : 200));
          debugPrint('❌ Not a PDF! Content preview: $preview');
          throw Exception(
            'The server did not return a PDF file.\n'
            'Response starts with: "${header.trim()}".\n'
            'Check that the file URL points to a real PDF.');
        }
      }

      // Save to temp file
      setState(() => _status = 'Preparing viewer...');
      final dir  = await getTemporaryDirectory();
      final safe = widget.title
          .replaceAll(RegExp(r'[^\w\s-]'), '_')
          .replaceAll(' ', '_');
      final file = File('${dir.path}/${safe}_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(bytes, flush: true);

      debugPrint('✅ Saved to: ${file.path}');

      if (mounted) {
        setState(() {
          _localPath = file.path;
          _loading   = false;
          _progress  = 1;
        });
      }
    } catch (e) {
      debugPrint('❌ PDF load error: $e');
      if (mounted) {
        setState(() {
          _error   = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: _buildAppBar(),
      body: _loading
          ? _buildLoading()
          : _error.isNotEmpty
              ? _buildError()
              : _buildViewer(),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: _navy,
    foregroundColor: _white,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back, color: _white),
      onPressed: () => Navigator.pop(context)),
    title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.title,
        style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w700, color: _white),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      if (_totalPages > 0)
        Text('Page ${_currentPage + 1} of $_totalPages',
          style: TextStyle(
            fontSize: 11, color: _white.withOpacity(0.55))),
    ]),
    actions: [
      if (!_loading && _error.isEmpty) ...[
        IconButton(
          icon: const Icon(Icons.navigate_before, color: _white),
          tooltip: 'Previous page',
          onPressed: () {
            if (_currentPage > 0) _ctrl.previousPage();
          }),
        IconButton(
          icon: const Icon(Icons.navigate_next, color: _white),
          tooltip: 'Next page',
          onPressed: () {
            if (_currentPage < _totalPages - 1) _ctrl.nextPage();
          }),
        IconButton(
          icon: const Icon(Icons.zoom_in, color: _white, size: 22),
          tooltip: 'Zoom in',
          onPressed: () => _ctrl.zoomLevel =
              (_ctrl.zoomLevel + 0.25).clamp(0.5, 5.0)),
        IconButton(
          icon: const Icon(Icons.zoom_out, color: _white, size: 22),
          tooltip: 'Zoom out',
          onPressed: () => _ctrl.zoomLevel =
              (_ctrl.zoomLevel - 0.25).clamp(0.5, 5.0)),
      ],
    ],
  );

  // ── Loading ────────────────────────────────────────────────────────────────
  Widget _buildLoading() => Container(
    color: const Color(0xFF1A1A1A),
    child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Progress ring
        SizedBox(
          width: 64, height: 64,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value:       _progress > 0 ? _progress : null,
              color:       _accent,
              strokeWidth: 3),
            if (_progress > 0)
              Text('${(_progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: _white)),
          ])),
        const SizedBox(height: 20),
        Text(_status,
          style: TextStyle(fontSize: 14, color: _white.withOpacity(0.7))),
        const SizedBox(height: 8),
        Text(widget.title,
          style: TextStyle(fontSize: 12, color: _white.withOpacity(0.4)),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    ),
  );

  // ── Error ──────────────────────────────────────────────────────────────────
  Widget _buildError() => Container(
    color: const Color(0xFF1A1A1A),
    padding: const EdgeInsets.all(32),
    child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: _red.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.picture_as_pdf_outlined,
            size: 30, color: _red)),
        const SizedBox(height: 16),
        const Text('Failed to Load PDF',
          style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w800, color: _white)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _red.withOpacity(0.08),
            border: Border.all(color: _red.withOpacity(0.25)),
            borderRadius: BorderRadius.circular(10)),
          child: Text(_error,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13, color: _red.withOpacity(0.9), height: 1.5))),
        const SizedBox(height: 20),
        // Debug URL display
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8)),
          child: Column(children: [
            Text('URL attempted:',
              style: TextStyle(
                fontSize: 10, color: _white.withOpacity(0.4),
                fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(widget.url,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10, color: _white.withOpacity(0.55)),
              maxLines: 3, overflow: TextOverflow.ellipsis),
          ])),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ElevatedButton.icon(
            onPressed: _downloadAndLoad,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: _white,
              padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)))),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back,
              size: 16, color: _white.withOpacity(0.6)),
            label: Text('Go Back',
              style: TextStyle(color: _white.withOpacity(0.6))),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _white.withOpacity(0.2)),
              padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)))),
        ]),
      ]),
    ),
  );

  // ── PDF Viewer ─────────────────────────────────────────────────────────────
  Widget _buildViewer() => SfPdfViewer.file(
    File(_localPath!),
    controller: _ctrl,
    onDocumentLoaded: (details) {
      if (mounted) {
        setState(() {
          _totalPages  = details.document.pages.count;
          _currentPage = 0;
        });
      }
    },
    onPageChanged: (details) {
      if (mounted) {
        setState(() => _currentPage = details.newPageNumber - 1);
      }
    },
    onDocumentLoadFailed: (details) {
      if (mounted) {
        setState(() {
          _error     = 'Viewer error: ${details.description}';
          _localPath = null;
        });
      }
    },
  );
}