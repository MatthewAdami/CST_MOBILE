// lib/widgets/history_sidebar.dart
import 'package:flutter/material.dart';
import '../models/route_models.dart';
import '../services/map_service.dart';
import '../theme.dart';

class HistorySidebar extends StatefulWidget {
  final bool open;
  final String? token;
  final void Function(RouteHistoryEntry) onReplay;
  final VoidCallback onClose;

  const HistorySidebar({
    super.key,
    required this.open,
    required this.token,
    required this.onReplay,
    required this.onClose,
  });

  @override
  State<HistorySidebar> createState() => _HistorySidebarState();
}

class _HistorySidebarState extends State<HistorySidebar> {
  List<RouteHistoryEntry> _routes  = [];
  bool   _loading  = false;
  bool   _hasLoaded = false; // guard so we don't double-load
  String? _error;

  @override
  void initState() {
    super.initState();
    // Load immediately if the sidebar opens with a token already available.
    if (widget.open && widget.token != null) {
      _load();
    }
  }

  @override
  void didUpdateWidget(HistorySidebar old) {
    super.didUpdateWidget(old);

    // FIX: three cases that require a (re)load:
    //  1. Sidebar just became visible and we have a token.
    //  2. Sidebar was already open but token just resolved from null → value
    //     (SharedPreferences async race — this was the root cause of the
    //      empty history: token was null on first open so _load was never called).
    //  3. Sidebar re-opened after being closed (reset _hasLoaded so we get
    //     fresh data each time).
    final justOpened    = !old.open && widget.open;
    final tokenArrived  = old.token == null && widget.token != null;
    final reopened      = !old.open && widget.open;

    if (reopened) _hasLoaded = false; // reset so re-open always fetches fresh

    if (widget.open && widget.token != null && (!_hasLoaded || tokenArrived)) {
      _load();
    }
  }

  Future<void> _load() async {
    final token = widget.token;
    if (token == null || _loading) return;
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final result = await MapService.fetchHistory(token);
      if (mounted) {
        setState(() {
          _routes   = result;
          _loading  = false;
          _hasLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error   = 'Failed to load history';
          _hasLoaded = true;
        });
      }
    }
  }

  Future<void> _deleteOne(String id) async {
    final token = widget.token;
    if (token == null) return;
    final ok = await MapService.deleteHistory(token, id);
    if (ok && mounted) {
      setState(() => _routes.removeWhere((r) => r.id == id));
    }
  }

  Future<void> _clearAll() async {
    final token = widget.token;
    if (token == null) return;
    final ok = await MapService.clearHistory(token);
    if (ok && mounted) setState(() => _routes.clear());
  }

  String _fmtDuration(int mins) {
    if (mins >= 60) return '${mins ~/ 60}h ${mins % 60}m';
    return '${mins}m';
  }

  String _fmtDate(DateTime d) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = d.hour.toString().padLeft(2,'0');
    final m = d.minute.toString().padLeft(2,'0');
    return '${months[d.month-1]} ${d.day}, ${d.year} · $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.open) return const SizedBox.shrink();

    return Stack(children: [
      // ── Backdrop ──────────────────────────────────────────────
      GestureDetector(
        onTap: widget.onClose,
        child: Container(color: Colors.black.withValues(alpha: 0.45)),
      ),

      // ── Drawer ────────────────────────────────────────────────
      Positioned(
        top: 0, right: 0, bottom: 0,
        width: 320,
        child: Container(
          decoration: BoxDecoration(
            color: kBG2,
            border: Border(left: BorderSide(color: kAccent.withValues(alpha: 0.2))),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 40)],
          ),
          child: Column(children: [

            // Header
            _buildHeader(),

            // Body
            Expanded(child: _buildBody()),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kBorder))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kAccent.withValues(alpha: 0.25)),
            ),
            child: Icon(Icons.history_rounded, color: kAccent, size: 16),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Route History',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
            Text('${_routes.length} saved trip${_routes.length != 1 ? "s" : ""}',
                style: TextStyle(color: kTextMuted, fontSize: 11)),
          ]),
          const Spacer(),
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: kBorder),
              ),
              child: Icon(Icons.close_rounded, color: kTextMuted, size: 14),
            ),
          ),
        ]),

        // FIX: show token-missing warning so user knows why list is empty
        if (widget.token == null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: kRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: kRed.withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded, color: kRed, size: 13),
              const SizedBox(width: 6),
              Text('Not signed in — history unavailable',
                  style: TextStyle(color: kRed, fontSize: 11)),
            ]),
          ),
        ],

        if (_routes.isNotEmpty) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _clearAll,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: kRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kRed.withValues(alpha: 0.2)),
              ),
              child: Text('Clear All History',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kRed, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kAccent, strokeWidth: 2));
    }

    // FIX: show a retry button when token was null at load time
    if (widget.token == null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.lock_outline_rounded, color: kTextMuted, size: 32),
        const SizedBox(height: 12),
        Text('Sign in to view history',
            style: TextStyle(color: kTextMuted, fontSize: 13)),
      ]));
    }

    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.wifi_off_rounded, color: kTextMuted, size: 32),
        const SizedBox(height: 12),
        Text(_error!, style: TextStyle(color: kTextMuted, fontSize: 13)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () { _hasLoaded = false; _load(); },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kAccent.withValues(alpha: 0.3)),
            ),
            child: const Text('Retry', style: TextStyle(color: kAccent, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ),
      ]));
    }

    if (_routes.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.route_outlined, color: kTextMuted, size: 36),
        const SizedBox(height: 12),
        Text('No trips saved yet.',
            style: TextStyle(color: kTextMuted, fontSize: 13)),
        const SizedBox(height: 4),
        Text('Complete a drive to see it here.',
            style: TextStyle(color: kTextMuted, fontSize: 11)),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _routes.length,
      itemBuilder: (_, i) => _buildCard(_routes[i]),
    );
  }

  Widget _buildCard(RouteHistoryEntry r) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(children: [

        // Route from/to
        Padding(
          padding: const EdgeInsets.fromLTRB(13, 11, 13, 9),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              const SizedBox(height: 3),
              Container(width: 8, height: 8, decoration: const BoxDecoration(
                  color: kGreen, shape: BoxShape.circle)),
              Container(width: 1.5, height: 18,
                  color: Colors.white.withValues(alpha: 0.12)),
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(2))),
            ]),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.fromName,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Text(r.toName,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: kAccentLight, fontSize: 12, fontWeight: FontWeight.w600)),
            ])),
          ]),
        ),

        // Stats
        Container(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: kBorder))),
          child: Row(children: [
            _stat('Distance', '${r.distanceKm.toStringAsFixed(1)} km', border: true),
            _stat('Duration', _fmtDuration(r.durationMin), border: true),
            _stat('Date', _fmtDate(r.createdAt)),
          ]),
        ),

        // Actions
        Container(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: kBorder))),
          child: Row(children: [
            Expanded(child: GestureDetector(
              onTap: () { widget.onReplay(r); widget.onClose(); },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.play_arrow_rounded, color: kAccentLight, size: 14),
                  const SizedBox(width: 4),
                  Text('Replay Route',
                      style: TextStyle(color: kAccentLight, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
            )),
            Container(width: 1, height: 36, color: kBorder),
            GestureDetector(
              onTap: () => _deleteOne(r.id),
              child: Container(
                width: 42,
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Icon(Icons.delete_outline_rounded, color: kRed, size: 16),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _stat(String label, String value, {bool border = false}) {
    return Expanded(child: Container(
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
      decoration: border ? BoxDecoration(border: Border(right: BorderSide(color: kBorder))) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: TextStyle(color: kTextMuted, fontSize: 9, letterSpacing: 0.08)),
        const SizedBox(height: 1),
        Text(value,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    ));
  }
}