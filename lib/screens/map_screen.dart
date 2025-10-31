// lib/screens/map_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../data/models/map_focus.dart';

const kBrandGreen = Color(0xFF669340);
const kDarkGray   = Color(0xFF32384A);

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.target});

  /// Foco opcional vindo da rota (ParkDetail → Map)
  final MapFocus? target;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _mapCtrl = Completer();
  final PageController _page = PageController(viewportFraction: 0.78);
  int _current = 0;

  // Lugares (mock)
  final List<_Place> _places = const [
    _Place(
      id: 'amor',
      name: 'Parque do Rangedor',
      latLng: LatLng(-2.4986319725913995, -44.26185574953524),
      image: 'assets/images/RANGEDOR.png',
    ),
    _Place(
      id: 'nasc',
      name: 'Praça das Nascentes',
      latLng: LatLng(-2.5241604530499973, -44.20572731508873),
      image: 'assets/images/itapiraco.png',
    ),
    _Place(
      id: 'rangedor',
      name: 'Parque do Rangedor',
      latLng: LatLng(-2.4986319725913995, -44.26185574953524),
      image: 'assets/images/RANGEDOR.png',
    ),
  ];

  Set<Marker> _markers = const <Marker>{};

  static const _initial = CameraPosition(
    target: LatLng(-2.5269, -44.2477), // centro aprox
    zoom: 15.2,
    tilt: 0,
    bearing: 0,
  );

  @override
  void initState() {
    super.initState();

    _markers = _places
        .map(
          (p) => Marker(
            markerId: MarkerId(p.id),
            position: p.latLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            onTap: () => _jumpToPlace(p),
          ),
        )
        .toSet();

    _page.addListener(() {
      final newPage = _page.page?.round() ?? 0;
      if (newPage != _current) {
        setState(() => _current = newPage);
        _animateMapTo(_places[newPage].latLng);
      }
    });
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _animateMapTo(LatLng target, {double zoom = 16.0}) async {
    final ctrl = await _mapCtrl.future;
    await ctrl.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: zoom),
      ),
    );
  }

  void _jumpToPlace(_Place p) {
    final idx = _places.indexWhere((e) => e.id == p.id);
    if (idx != -1) {
      _page.animateToPage(
        idx,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  /// Cria/atualiza o marcador de foco (verde) e centraliza o mapa
  Future<void> _focusOn(LatLng pos, {String? title}) async {
    setState(() {
      _markers = {
        ..._markers.where((m) => m.markerId.value != 'focus'),
        Marker(
          markerId: const MarkerId('focus'),
          position: pos,
          infoWindow: title != null ? InfoWindow(title: title) : const InfoWindow(),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      };
    });
    await _animateMapTo(pos);
  }

  /// Aplica o foco vindo do ParkDetail (se existir)
  Future<void> _applyTargetFocus() async {
    final t = widget.target;
    if (t == null) return;

    // 1) Se veio lat/lng do Directus, foca direto nelas
    if (t.lat != null && t.lng != null) {
      await _focusOn(LatLng(t.lat!, t.lng!), title: t.name);
      return;
    }

    // 2) Sem lat/lng? tenta casar pelo nome nos mocks
    final byName = _places.indexWhere(
      (p) => p.name.toLowerCase().trim() == t.name.toLowerCase().trim(),
    );
    if (byName != -1) {
      final p = _places[byName];
      _jumpToPlace(p);
      await _focusOn(p.latLng, title: p.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: _initial,
            onMapCreated: (c) async {
              if (!_mapCtrl.isCompleted) _mapCtrl.complete(c);
              // aplica o foco quando o mapa estiver pronto
              await _applyTargetFocus();
            },
            markers: _markers,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
          ),

          // Barra de busca flutuante
          Positioned(
            top: topPadding + 12,
            left: 20,
            right: 20,
            child: _SearchPill(
              hint: 'Buscar local...',
              onTap: () async {
                final picked = await showSearch<_Place?>(
                  context: context,
                  delegate: PlaceSearchDelegate(
                    places: _places,
                    hintText: 'Busque um local...',
                  ),
                );
                if (picked != null) {
                  _jumpToPlace(picked);
                  await _focusOn(picked.latLng, title: picked.name);
                }
              },
            ),
          ),

          // Carrossel inferior
          Positioned(
            left: 0,
            right: 0,
            bottom: 18 + MediaQuery.of(context).padding.bottom,
            child: SizedBox(
              height: 156,
              child: PageView.builder(
                controller: _page,
                itemCount: _places.length,
                padEnds: false,
                itemBuilder: (_, i) {
                  final p = _places[i];
                  final selected = i == _current;
                  return Padding(
                    padding: EdgeInsets.only(
                      left: i == 0 ? 20 : 12,
                      right: i == _places.length - 1 ? 20 : 0,
                    ),
                    child: _PlaceCard(
                      place: p,
                      selected: selected,
                      onTap: () async {
                        _jumpToPlace(p);
                        await _focusOn(p.latLng, title: p.name);
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------ UI helpers ------------------------ */

class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.hint, this.onTap});
  final String hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.08),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: kBrandGreen, width: 1.4),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: kBrandGreen),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hint,
                style: GoogleFonts.poppins(
                  color: kDarkGray.withOpacity(.6),
                  fontSize: 14,
                ),
              ),
            ),
            CircleAvatar(
              radius: 18,
              backgroundColor: kBrandGreen,
              child: const Icon(Icons.search, color: Colors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.place,
    required this.selected,
    required this.onTap,
  });

  final _Place place;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.0 : 0.96,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 260,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.10),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              // imagem
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: Image.asset(
                  place.image,
                  height: 96,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Color(0xFFEFEFEF),
                    child: SizedBox(height: 96, width: double.infinity),
                  ),
                ),
              ),
              // título
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: kDarkGray,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, color: kBrandGreen),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Place {
  final String id;
  final String name;
  final LatLng latLng;
  final String image;
  const _Place({
    required this.id,
    required this.name,
    required this.latLng,
    required this.image,
  });
}

/* ------------------------ SearchDelegate ------------------------ */

class PlaceSearchDelegate extends SearchDelegate<_Place?> {
  PlaceSearchDelegate({
    required this.places,
    this.hintText = 'Buscar',
  }) {
    query = ''; // valor inicial (opcional)
  }

  final List<_Place> places;
  final String hintText;

  @override
  String get searchFieldLabel => hintText;

  @override
  TextStyle? get searchFieldStyle =>
      GoogleFonts.poppins(color: kDarkGray, fontSize: 16);

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final q = query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? places
        : places.where((p) => p.name.toLowerCase().contains(q)).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'Nenhum resultado',
          style: GoogleFonts.poppins(color: kDarkGray.withOpacity(.6)),
        ),
      );
    }

    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final p = filtered[i];
        return ListTile(
          leading: const Icon(Icons.place, color: kBrandGreen),
          title: Text(
            p.name,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${p.latLng.latitude.toStringAsFixed(4)}, '
            '${p.latLng.longitude.toStringAsFixed(4)}',
            style: GoogleFonts.poppins(color: kDarkGray.withOpacity(.6)),
          ),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          onTap: () => close(context, p),
        );
      },
    );
  }
}
