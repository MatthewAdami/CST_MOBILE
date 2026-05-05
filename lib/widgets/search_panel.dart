// lib/widgets/search_panel.dart
import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/route_models.dart';
import '../services/map_service.dart';

class SearchPanel extends StatefulWidget {
  final bool useMyLocation;
  final String fromQuery;
  final String toQuery;
  final void Function(bool) onUseMyLocationChanged;
  final void Function(PlaceResult) onFromPicked;
  final void Function(PlaceResult) onToPicked;
  final void Function() onClearFrom;
  final void Function() onClearTo;
  final void Function() onSwap;

  const SearchPanel({
    super.key,
    required this.useMyLocation,
    required this.fromQuery,
    required this.toQuery,
    required this.onUseMyLocationChanged,
    required this.onFromPicked,
    required this.onToPicked,
    required this.onClearFrom,
    required this.onClearTo,
    required this.onSwap,
  });

  @override
  State<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<SearchPanel> {
  final _fromCtrl = TextEditingController();
  final _toCtrl   = TextEditingController();
  List<PlaceResult> _fromSugg = [];
  List<PlaceResult> _toSugg   = [];
  bool _fromSearching = false;
  bool _toSearching   = false;
  bool _fromOpen = false;
  bool _toOpen   = false;

  @override
  void didUpdateWidget(SearchPanel old) {
    super.didUpdateWidget(old);
    if (widget.fromQuery != old.fromQuery && _fromCtrl.text != widget.fromQuery) {
      _fromCtrl.text = widget.fromQuery;
    }
    if (widget.toQuery != old.toQuery && _toCtrl.text != widget.toQuery) {
      _toCtrl.text = widget.toQuery;
    }
  }

  Future<void> _searchFrom(String v) async {
    if (v.length < 2) { setState(() { _fromSugg = []; _fromOpen = false; }); return; }
    setState(() => _fromSearching = true);
    final r = await MapService.searchPlaces(v);
    if (mounted) setState(() { _fromSugg = r; _fromOpen = r.isNotEmpty; _fromSearching = false; });
  }

  Future<void> _searchTo(String v) async {
    if (v.length < 2) { setState(() { _toSugg = []; _toOpen = false; }); return; }
    setState(() => _toSearching = true);
    final r = await MapService.searchPlaces(v);
    if (mounted) setState(() { _toSugg = r; _toOpen = r.isNotEmpty; _toSearching = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kBG2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.5), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── FROM row ──────────────────────────────────────────
          _fromRow(),
          Divider(height: 1, color: kBorder),

          // ── SWAP button ───────────────────────────────────────
          SizedBox(
            height: 0,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: GestureDetector(
                  onTap: widget.onSwap,
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: kBG2.withOpacity(.95),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: kBorder),
                    ),
                    child: const Icon(Icons.swap_vert, size: 16, color: kTextSoft),
                  ),
                ),
              ),
            ),
          ),

          // ── TO row ────────────────────────────────────────────
          _toRow(),
        ],
      ),
    );
  }

  Widget _fromRow() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 46,
          child: Row(
            children: [
              const SizedBox(width: 12),
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: kGreen, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: kGreen.withOpacity(.5), blurRadius: 6)]),
              ),
              const SizedBox(width: 10),
              if (widget.useMyLocation) ...[
                Expanded(
                  child: Text(
                    'My Location',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    widget.onUseMyLocationChanged(false);
                    _fromCtrl.clear();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: kTextMuted,
                    textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Change'),
                ),
              ] else ...[
                Expanded(
                  child: TextField(
                    controller: _fromCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Choose starting point…',
                      hintStyle: TextStyle(color: kTextMuted, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: _searchFrom,
                  ),
                ),
                if (_fromSearching)
                  const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: kAccent)),
                if (!_fromSearching && _fromCtrl.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close, size: 14, color: kTextMuted),
                    onPressed: () {
                      _fromCtrl.clear();
                      setState(() { _fromSugg = []; _fromOpen = false; });
                      widget.onClearFrom();
                    },
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
              const SizedBox(width: 8),
            ],
          ),
        ),
        if (_fromOpen) _suggList(_fromSugg, widget.onFromPicked, kGreen, () {
          widget.onUseMyLocationChanged(true);
          _fromCtrl.clear();
          setState(() { _fromSugg = []; _fromOpen = false; });
        }),
      ],
    );
  }

  Widget _toRow() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 46,
          child: Row(
            children: [
              const SizedBox(width: 12),
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: kAccent, borderRadius: BorderRadius.circular(2),
                  boxShadow: [BoxShadow(color: kAccent.withOpacity(.5), blurRadius: 6)]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _toCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Search destination…',
                    hintStyle: TextStyle(color: kTextMuted, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: _searchTo,
                ),
              ),
              if (_toSearching)
                const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: kAccent)),
              if (!_toSearching && _toCtrl.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close, size: 14, color: kTextMuted),
                  onPressed: () {
                    _toCtrl.clear();
                    setState(() { _toSugg = []; _toOpen = false; });
                    widget.onClearTo();
                  },
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        if (_toOpen) _suggList(_toSugg, widget.onToPicked, kAccent, null),
      ],
    );
  }

  Widget _suggList(
    List<PlaceResult> sugg,
    void Function(PlaceResult) onPick,
    Color dotColor,
    VoidCallback? myLocOption,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: kBG2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dotColor.withOpacity(.35)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.6), blurRadius: 20)],
      ),
      margin: const EdgeInsets.only(top: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (myLocOption != null) ...[
            _myLocRow(myLocOption),
            Divider(height: 1, color: kBorder),
          ],
          ...sugg.asMap().entries.map((e) {
            final p = e.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (e.key > 0 || myLocOption != null) Divider(height: 1, color: kBorder),
                _suggRow(p, dotColor, onPick),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _myLocRow(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: kGreen.withOpacity(.12),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: kGreen.withOpacity(.25)),
              ),
              child: const Icon(Icons.my_location, size: 13, color: kGreen),
            ),
            const SizedBox(width: 9),
            const Text('Use my current location',
                style: TextStyle(color: kGreen, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _suggRow(PlaceResult p, Color dot, void Function(PlaceResult) onPick) {
    final parts = p.displayName.split(',');
    return InkWell(
      onTap: () {
        onPick(p);
        setState(() { _fromSugg = []; _toSugg = []; _fromOpen = false; _toOpen = false; });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: dot.withOpacity(.12),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: dot.withOpacity(.22)),
              ),
              child: Icon(Icons.location_on, size: 13, color: dot),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(parts.take(2).join(',').trim(),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                  if (parts.length > 2)
                    Text(parts.skip(2).take(2).join(',').trim(),
                        style: const TextStyle(color: kTextMuted, fontSize: 10),
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }
}