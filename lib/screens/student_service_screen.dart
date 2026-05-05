import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────
// COLOURS  (inherits from dashboard palette)
// ─────────────────────────────────────────────────────────────────
class _C {
  static const navy        = Color(0xFF11233B);
  static const navySoft    = Color(0xFF1D3557);
  static const navyDeep    = Color(0xFF0D1B2D);
  static const gold        = Color(0xFFB8963E);
  static const goldLight   = Color(0xFFD4AE5A);
  static const sand        = Color(0xFFF3E7CC);
  static const white       = Color(0xFFFFFFFF);
  static const gray50      = Color(0xFFFAF8F4);
  static const gray100     = Color(0xFFF3F0E9);
  static const gray200     = Color(0xFFE5DFD4);
  static const gray400     = Color(0xFFA49D90);
  static const gray600     = Color(0xFF6D675F);
  static const gray800     = Color(0xFF2F2B27);
  static const green       = Color(0xFF2F7A55);
  static const red         = Color(0xFFB64B4B);
  static const orange      = Color(0xFFC97A2B);
  static const blue        = Color(0xFF365C88);

  // Step colours matching infographic
  static const step1 = Color(0xFF3A8B3A);   // green
  static const step2 = Color(0xFF2A6CB5);   // blue
  static const step3 = Color(0xFF7B3AC4);   // purple
  static const step4 = Color(0xFFC47A1A);   // orange
  static const step5 = Color(0xFFB83232);   // red
}

// ─────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────
const _usStates = [
  'Alabama','Alaska','Arizona','Arkansas','California','Colorado',
  'Connecticut','Delaware','Florida','Georgia','Hawaii','Idaho',
  'Illinois','Indiana','Iowa','Kansas','Kentucky','Louisiana',
  'Maine','Maryland','Massachusetts','Michigan','Minnesota',
  'Mississippi','Missouri','Montana','Nebraska','Nevada',
  'New Hampshire','New Jersey','New Mexico','New York',
  'North Carolina','North Dakota','Ohio','Oklahoma','Oregon',
  'Pennsylvania','Rhode Island','South Carolina','South Dakota',
  'Tennessee','Texas','Utah','Vermont','Virginia','Washington',
  'West Virginia','Wisconsin','Wyoming',
];

const _citiesByState = <String, List<String>>{
  'California':  ['Los Angeles','San Diego','San Jose','Sacramento','Fresno','Long Beach','Oakland'],
  'Texas':       ['Houston','San Antonio','Dallas','Austin','Fort Worth','El Paso','Arlington'],
  'New York':    ['New York City','Buffalo','Rochester','Yonkers','Syracuse','Albany','New Rochelle'],
  'Florida':     ['Jacksonville','Miami','Tampa','Orlando','St. Petersburg','Hialeah','Tallahassee'],
  'New Mexico':  ['Albuquerque','Las Cruces','Santa Fe','Roswell','Hobbs','Farmington','Clovis'],
};

const _serviceCategories = [
  (icon: Icons.car_repair,          label: 'Towing'),
  (icon: Icons.local_shipping,      label: 'Truck Repair'),
  (icon: Icons.settings,            label: 'Diesel Repair'),
  (icon: Icons.tire_repair,         label: 'Tires'),
  (icon: Icons.local_gas_station,   label: 'Fuel / Truck Stops'),
  (icon: Icons.local_parking,       label: 'Parking / Storage'),
  (icon: Icons.hotel,               label: 'Lodging / Hotels'),
  (icon: Icons.gavel,               label: 'Compliance'),
  (icon: Icons.medical_services,    label: 'Medical Services'),
];

// Mock results per service
const _mockResults = [
  (name: 'Desert Diesel Repair',    rating: 4.6, phone: '(505) 555-0101', dist: '2.1 mi', icon: Icons.settings),
  (name: 'City Towing & Recovery',  rating: 4.7, phone: '(505) 555-0199', dist: '3.4 mi', icon: Icons.car_repair),
  (name: 'Southwest Legal Group',   rating: 4.9, phone: '(505) 553-0122', dist: '1.8 mi', icon: Icons.gavel),
  (name: 'NM Compliance Services',  rating: 4.6, phone: '(505) 555-0155', dist: '2.6 mi', icon: Icons.business),
  (name: 'Route 66 Fuel Stop',      rating: 4.4, phone: '(505) 555-0177', dist: '0.9 mi', icon: Icons.local_gas_station),
];

// ─────────────────────────────────────────────────────────────────
// MAIN SCREEN  (renamed from StudentMapsScreen)
// ─────────────────────────────────────────────────────────────────
class StudentServiceScreen extends StatefulWidget {
  const StudentServiceScreen({super.key});

  @override
  State<StudentServiceScreen> createState() => _StudentServiceScreenState();
}

class _StudentServiceScreenState extends State<StudentServiceScreen> {
  // 0=map, 1=state, 2=city, 3=service, 4=results
  int     _step      = 0;
  String? _selState;
  String? _selCity;
  String? _selService;

  String _stateSearch = '';
  String _citySearch  = '';

  List<String> get _filteredStates => _usStates
      .where((s) => s.toLowerCase().contains(_stateSearch.toLowerCase()))
      .toList();

  List<String> get _filteredCities {
    final cities = _citiesByState[_selState] ??
        ['Central City', 'Northville', 'Eastside', 'Westport', 'Southgate'];
    return cities
        .where((c) => c.toLowerCase().contains(_citySearch.toLowerCase()))
        .toList();
  }

  void _reset() => setState(() {
    _step = 0; _selState = null; _selCity = null; _selService = null;
    _stateSearch = ''; _citySearch = '';
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.gray50,
      body: Column(children: [
        _StepHeader(
          step: _step, onReset: _reset,
          selState: _selState, selCity: _selCity, selService: _selService),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case 0: return _MapView(onTap: () => setState(() => _step = 1));
      case 1: return _StateList(
        search: _stateSearch,
        states: _filteredStates,
        onSearch: (v) => setState(() => _stateSearch = v),
        onSelect: (s) => setState(() { _selState = s; _step = 2; }),
      );
      case 2: return _CityList(
        state:  _selState!,
        search: _citySearch,
        cities: _filteredCities,
        onSearch: (v) => setState(() => _citySearch = v),
        onSelect: (c) => setState(() { _selCity = c; _step = 3; }),
      );
      case 3: return _ServiceGrid(
        onSelect: (s) => setState(() { _selService = s; _step = 4; }),
      );
      case 4: return _ResultsList(
        city:    _selCity!,
        state:   _selState!,
        service: _selService!,
      );
      default: return const SizedBox();
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// STEP HEADER BANNER
// ─────────────────────────────────────────────────────────────────
class _StepHeader extends StatelessWidget {
  final int _step;
  final VoidCallback onReset;
  final String? selState, selCity, selService;

  const _StepHeader({
    required int step, required this.onReset,
    required this.selState, required this.selCity, required this.selService,
  }) : _step = step;

  static const _steps = [
    (num: '1', label: 'USA Map',  color: _C.step1),
    (num: '2', label: 'State',    color: _C.step2),
    (num: '3', label: 'City',     color: _C.step3),
    (num: '4', label: 'Service',  color: _C.step4),
    (num: '5', label: 'Results',  color: _C.step5),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_C.navyDeep, _C.navySoft],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0,3))],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          // Title bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(children: [
              const Icon(Icons.local_shipping, color: _C.gold, size: 20),
              const SizedBox(width: 8),
              const Expanded(child: Text(
                'ONE CLICK – BACK ON THE ROAD',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                  color: _C.white, letterSpacing: 0.3),
              )),
              if (_step > 0)
                GestureDetector(
                  onTap: onReset,
                  child: const Icon(Icons.refresh, color: _C.gold, size: 18)),
            ]),
          ),
          // Step indicators
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(children: List.generate(_steps.length, (i) {
              final s = _steps[i];
              final active  = _step == i;
              final done    = _step > i;
              return Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: done ? s.color.withOpacity(.85)
                         : active ? s.color : _C.white.withOpacity(.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active || done ? s.color : _C.white.withOpacity(.18),
                      width: 1.5)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 18, height: 18,
                      decoration: BoxDecoration(
                        color: done || active
                          ? _C.white.withOpacity(.25) : s.color,
                        shape: BoxShape.circle),
                      child: Center(child: done
                        ? const Icon(Icons.check, size: 11, color: _C.white)
                        : Text(s.num, style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w800,
                            color: _C.white)))),
                    const SizedBox(width: 5),
                    Text(s.label, style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: active || done
                        ? _C.white : _C.white.withOpacity(.45))),
                  ]),
                ),
                if (i < _steps.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.chevron_right,
                      size: 14, color: _C.white.withOpacity(.3))),
              ]);
            })),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// STEP 0 – MAP VIEW
// ─────────────────────────────────────────────────────────────────
class _MapView extends StatelessWidget {
  final VoidCallback onTap;
  const _MapView({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _C.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _C.gray200),
              boxShadow: [BoxShadow(color: _C.navy.withOpacity(.08), blurRadius: 12)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(children: [
                CustomPaint(
                  size: const Size(double.infinity, double.infinity),
                  painter: _MapPainter()),
                Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _C.navyDeep.withOpacity(.85),
                        borderRadius: BorderRadius.circular(50)),
                      child: const Icon(Icons.map, color: _C.gold, size: 36)),
                    const SizedBox(height: 16),
                    const Text('UNITED STATES', style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900,
                      color: _C.navyDeep, letterSpacing: 2)),
                    const SizedBox(height: 6),
                    const Text('All 50 States • Tap Any State',
                      style: TextStyle(fontSize: 13, color: _C.gray600)),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.touch_app, size: 16),
                      label: const Text('Tap a State to Begin'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.navyDeep,
                        foregroundColor: _C.gold,
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30))),
                    ),
                  ],
                )),
              ]),
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _C.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.gray200)),
          child: const Row(children: [
            Icon(Icons.search, color: _C.gray400, size: 18),
            SizedBox(width: 8),
            Text('Tap a state above or tap here to search…',
              style: TextStyle(fontSize: 13, color: _C.gray400)),
          ]),
        ),
      ),
    ]);
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFD0E8F5)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), p);

    final colors = [
      const Color(0xFF5C8FC9), const Color(0xFF6BBF7A), const Color(0xFFE8A74A),
      const Color(0xFFD06060), const Color(0xFF9B7BC8), const Color(0xFF5ABFB0),
      const Color(0xFFF0C060), const Color(0xFF7095C8), const Color(0xFF8BC87A),
    ];
    final rng = [
      [0.05,0.3,0.18,0.22], [0.22,0.3,0.18,0.22], [0.39,0.3,0.18,0.22],
      [0.56,0.3,0.18,0.22], [0.73,0.3,0.18,0.22],
      [0.05,0.52,0.18,0.20], [0.22,0.52,0.18,0.20], [0.39,0.52,0.18,0.20],
      [0.56,0.52,0.18,0.20], [0.73,0.52,0.18,0.20],
      [0.05,0.72,0.18,0.20], [0.22,0.72,0.18,0.20], [0.39,0.72,0.18,0.20],
      [0.56,0.72,0.18,0.22], [0.73,0.72,0.18,0.22],
    ];
    for (int i = 0; i < rng.length; i++) {
      final r = rng[i];
      final rect = RRect.fromLTRBR(
        r[0] * size.width, r[1] * size.height,
        (r[0] + r[2]) * size.width, (r[1] + r[3]) * size.height,
        const Radius.circular(4));
      canvas.drawRRect(rect, Paint()..color = colors[i % colors.length]);
      canvas.drawRRect(rect,
        Paint()..color = Colors.white.withOpacity(.4)
               ..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }

    final pinX = size.width * 0.35, pinY = size.height * 0.55;
    canvas.drawCircle(Offset(pinX, pinY), 10,
      Paint()..color = const Color(0xFFB83232));
    canvas.drawCircle(Offset(pinX, pinY), 4,
      Paint()..color = Colors.white);
  }

  @override bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────
// STEP 1 – STATE LIST
// ─────────────────────────────────────────────────────────────────
class _StateList extends StatelessWidget {
  final String search;
  final List<String> states;
  final ValueChanged<String> onSearch, onSelect;
  const _StateList({
    required this.search, required this.states,
    required this.onSearch, required this.onSelect});

  @override
  Widget build(BuildContext context) => Column(children: [
    _SearchBar(hint: 'Search State…', value: search, onChanged: onSearch),
    Expanded(child: ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      itemCount: states.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: _C.gray100),
      itemBuilder: (_, i) => _ListTileRow(
        label: states[i],
        leading: _StepDot(color: _C.step2),
        onTap: () => onSelect(states[i]),
      ),
    )),
    _ViewAllButton(label: 'View All States (${_usStates.length})', color: _C.step2),
  ]);
}

// ─────────────────────────────────────────────────────────────────
// STEP 2 – CITY LIST
// ─────────────────────────────────────────────────────────────────
class _CityList extends StatelessWidget {
  final String state, search;
  final List<String> cities;
  final ValueChanged<String> onSearch, onSelect;
  const _CityList({
    required this.state, required this.search, required this.cities,
    required this.onSearch, required this.onSelect});

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      color: _C.step3.withOpacity(.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        const Icon(Icons.location_on, color: _C.step3, size: 16),
        const SizedBox(width: 6),
        Text(state.toUpperCase(), style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w800,
          color: _C.step3, letterSpacing: 0.5)),
      ]),
    ),
    _SearchBar(hint: 'Search City…', value: search, onChanged: onSearch),
    Expanded(child: ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      itemCount: cities.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: _C.gray100),
      itemBuilder: (_, i) => _ListTileRow(
        label: cities[i],
        leading: _StepDot(color: _C.step3),
        onTap: () => onSelect(cities[i]),
      ),
    )),
    _ViewAllButton(label: 'View All Cities', color: _C.step3),
  ]);
}

// ─────────────────────────────────────────────────────────────────
// STEP 3 – SERVICE GRID
// ─────────────────────────────────────────────────────────────────
class _ServiceGrid extends StatelessWidget {
  final ValueChanged<String> onSelect;
  const _ServiceGrid({required this.onSelect});

  static const _colors = [
    _C.step1, _C.step2, _C.step3, _C.step4, _C.step5,
    _C.blue, _C.green, _C.orange, _C.red,
  ];

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      color: _C.step4.withOpacity(.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Row(children: [
        Icon(Icons.category, color: _C.step4, size: 16),
        SizedBox(width: 6),
        Text('SERVICE CATEGORIES', style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w800,
          color: _C.step4, letterSpacing: 0.5)),
      ]),
    ),
    Expanded(
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10,
          childAspectRatio: 0.95),
        itemCount: _serviceCategories.length,
        itemBuilder: (_, i) {
          final svc   = _serviceCategories[i];
          final color = _colors[i % _colors.length];
          return GestureDetector(
            onTap: () => onSelect(svc.label),
            child: Container(
              decoration: BoxDecoration(
                color: _C.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.gray200),
                boxShadow: [BoxShadow(
                  color: color.withOpacity(.08), blurRadius: 8)]),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(.12),
                    shape: BoxShape.circle),
                  child: Icon(svc.icon, color: color, size: 22)),
                const SizedBox(height: 8),
                Text(svc.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: _C.navy),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            ),
          );
        },
      ),
    ),
  ]);
}

// ─────────────────────────────────────────────────────────────────
// STEP 4 – RESULTS
// ─────────────────────────────────────────────────────────────────
class _ResultsList extends StatelessWidget {
  final String city, state, service;
  const _ResultsList({
    required this.city, required this.state, required this.service});

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_C.navyDeep, _C.navySoft],
          begin: Alignment.centerLeft, end: Alignment.bottomRight),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(children: [
        const Icon(Icons.location_on, color: _C.gold, size: 16),
        const SizedBox(width: 6),
        Expanded(child: Text(
          '$city, $state  ·  $service'.toUpperCase(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
            color: _C.white, letterSpacing: 0.4),
          overflow: TextOverflow.ellipsis)),
      ]),
    ),
    Expanded(
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _mockResults.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final r = _mockResults[i];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _C.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.gray200),
              boxShadow: [BoxShadow(
                color: _C.navy.withOpacity(.05), blurRadius: 8)]),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _C.navyDeep.withOpacity(.06),
                  borderRadius: BorderRadius.circular(10)),
                child: Icon(r.icon, color: _C.navyDeep, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.name, style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _C.navy)),
                const SizedBox(height: 3),
                Row(children: [
                  _Stars(r.rating),
                  const SizedBox(width: 5),
                  Text('(${r.rating})', style: const TextStyle(
                    fontSize: 11, color: _C.gray600)),
                ]),
                const SizedBox(height: 3),
                Text(r.phone, style: const TextStyle(
                  fontSize: 12, color: _C.gray600)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(r.dist, style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: _C.gray600)),
                const SizedBox(height: 8),
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _C.green,
                    borderRadius: BorderRadius.circular(18)),
                  child: const Icon(Icons.phone, color: _C.white, size: 16)),
              ]),
            ]),
          );
        },
      ),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: _C.navyDeep,
            foregroundColor: _C.gold,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10))),
          child: const Text('View More Results',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        ),
      ),
    ),
  ]);
}

// ─────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final String hint, value;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.hint, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
    child: TextField(
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, color: _C.gray800),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _C.gray400, fontSize: 13),
        prefixIcon: const Icon(Icons.search, color: _C.gray400, size: 18),
        filled: true, fillColor: _C.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _C.gray200)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _C.gray200)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _C.gold, width: 1.5)),
      ),
    ),
  );
}

class _ListTileRow extends StatelessWidget {
  final String label;
  final Widget leading;
  final VoidCallback onTap;
  const _ListTileRow({required this.label, required this.leading, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        leading,
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w500, color: _C.gray800))),
        const Icon(Icons.chevron_right, size: 16, color: _C.gray400),
      ]),
    ),
  );
}

class _StepDot extends StatelessWidget {
  final Color color;
  const _StepDot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: 8, height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _ViewAllButton extends StatelessWidget {
  final String label;
  final Color color;
  const _ViewAllButton({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
    child: ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: _C.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10))),
      child: Text(label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
    ),
  );
}

class _Stars extends StatelessWidget {
  final double rating;
  const _Stars(this.rating);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (i) => Icon(
      i < rating.floor() ? Icons.star
        : (i < rating && rating - i >= 0.5)
          ? Icons.star_half : Icons.star_border,
      size: 12, color: _C.gold)));
}