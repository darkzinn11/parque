// lib/screens/map_screen.dart
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/models/map_focus.dart';
import '../data/models/park.dart';
import '../data/park_repository.dart';
import '../core/api/api_config.dart';
import '../widgets/favorite_button.dart';

const kBrandGreen = Color(0xFF669340);
const kDarkGray   = Color(0xFF32384A);

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.target});

  final MapFocus? target;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _mapCtrl = Completer();
  final PageController _page = PageController(viewportFraction: 0.52);
  int _current = 0;
  bool _isLoading = true;

  List<Park> _parks = [];
  Set<Marker> _markers = {};
  Position? _userPosition;
  bool _locationGranted = false;

  static const _initial = CameraPosition(
    target: LatLng(-2.5269, -44.2477),
    zoom: 13.5,
  );

  @override
  void initState() {
    super.initState();
    _loadParks();
    _loadUserLocation();

    _page.addListener(() {
      final newPage = _page.page?.round() ?? 0;
      if (newPage != _current && newPage < _parks.length) {
        setState(() => _current = newPage);
        final p = _parks[newPage];
        if (p.latitude != null && p.longitude != null) {
          _animateMapTo(LatLng(p.latitude!, p.longitude!));
        }
      }
    });
  }

  Future<void> _loadUserLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      // Permissão concedida: agora é seguro habilitar a camada "minha localização"
      // do GoogleMap. No Android, ativá-la antes do grant lança PlatformException.
      if (mounted) setState(() => _locationGranted = true);

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      if (mounted) {
        setState(() {
          _userPosition = pos;
          _sortByDistance();
        });
      }
    } catch (_) {
      // Sem localização — omite badge silenciosamente
    }
  }

  void _sortByDistance() {
    if (_userPosition == null || _parks.isEmpty) return;
    _parks.sort((a, b) {
      final da = Geolocator.distanceBetween(
        _userPosition!.latitude, _userPosition!.longitude,
        a.latitude!, a.longitude!,
      );
      final db = Geolocator.distanceBetween(
        _userPosition!.latitude, _userPosition!.longitude,
        b.latitude!, b.longitude!,
      );
      return da.compareTo(db);
    });
    _current = 0;
    if (_page.hasClients) {
      _page.jumpToPage(0);
    }
  }

  String? _formatDistance(Park p) {
    if (_userPosition == null || p.latitude == null || p.longitude == null) {
      return null;
    }
    final meters = Geolocator.distanceBetween(
      _userPosition!.latitude,
      _userPosition!.longitude,
      p.latitude!,
      p.longitude!,
    );
    final km = meters / 1000;
    if (km < 10) {
      return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
    }
    return '${km.round()} km';
  }

  Future<void> _loadParks() async {
    try {
      final repo = context.read<ParkRepository>();
      final parks = await repo.fetchAll();

      final parksWithCoords = parks.where((p) => p.latitude != null && p.longitude != null).toList();

      if (mounted) {
        setState(() {
          _parks = parksWithCoords;
          _sortByDistance();
          _isLoading = false;
          _markers = _parks.map((p) => Marker(
            markerId: MarkerId(p.id.toString()),
            position: LatLng(p.latitude!, p.longitude!),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            onTap: () => _selectPark(p),
          )).toSet();
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _applyTargetFocus();
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar parques no mapa: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  String? _toImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) {
      if (path.contains('apps.sitw.com.br') && !path.contains('/backend-park/')) {
        return path.replaceFirst('apps.sitw.com.br/', 'apps.sitw.com.br/backend-park/');
      }
      return path;
    }
    final baseUrl = ApiConfig.baseUrl.replaceAll('/api/v1', '');
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$baseUrl/$cleanPath';
  }

  Future<void> _animateMapTo(LatLng target, {double zoom = 15.5}) async {
    final ctrl = await _mapCtrl.future;
    await ctrl.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: zoom),
      ),
    );
  }

  void _jumpToPark(Park p) {
    final idx = _parks.indexWhere((e) => e.id == p.id);
    if (idx != -1) {
      _page.animateToPage(
        idx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _selectPark(Park p) {
    _jumpToPark(p);
    if (p.latitude != null && p.longitude != null) {
      _animateMapTo(LatLng(p.latitude!, p.longitude!));
    }
    _showParkSheet(p);
  }

  Future<void> _applyTargetFocus() async {
    final t = widget.target;
    if (t == null) return;

    if (t.lat != null && t.lng != null) {
      final pos = LatLng(t.lat!, t.lng!);
      await _animateMapTo(pos, zoom: 16.5);

      setState(() {
        _markers.add(Marker(
          markerId: const MarkerId('focus'),
          position: pos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: t.name),
        ));
      });
    }
  }

  void _showParkSheet(Park p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (_) => _ParkBottomSheet(
        park: p,
        imageUrl: _toImageUrl(p.heroImage),
        distance: _formatDistance(p),
        onRoutes: () {
          Navigator.pop(context);
          _showRoutePicker(p);
        },
        onDetails: () {
          Navigator.pop(context);
          context.push('/parks/${p.documentId}');
        },
      ),
    );
  }

  void _showRoutePicker(Park p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RoutePickerSheet(
        lat: p.latitude!,
        lng: p.longitude!,
        parkName: p.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initial,
            onMapCreated: (c) {
              if (!_mapCtrl.isCompleted) _mapCtrl.complete(c);
            },
            markers: _markers,
            myLocationEnabled: _locationGranted,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
          ),

          // Search Bar
          Positioned(
            top: topPadding + 12,
            left: (MediaQuery.of(context).size.width - 334) / 2,
            child: SizedBox(
              width: 334,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        try {
                          context.go('/tabs/home');
                        } catch (_) {}
                      }
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: kBrandGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.chevron_left,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SearchPill(
                      hint: 'Buscar local...',
                      onTap: () async {
                        final picked = await Navigator.of(context).push<Park?>(
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) => _ParkSearchScreen(
                              parks: _parks,
                              userPosition: _userPosition,
                              toImageUrl: _toImageUrl,
                            ),
                            transitionsBuilder: (_, anim, __, child) =>
                                FadeTransition(opacity: anim, child: child),
                            transitionDuration: const Duration(milliseconds: 180),
                          ),
                        );
                        if (picked != null && mounted) {
                          _selectPark(picked);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Carousel
          if (!_isLoading && _parks.isNotEmpty)
            Positioned(
              left: 20,
              right: 0,
              bottom: 24 + MediaQuery.of(context).padding.bottom,
              child: SizedBox(
                height: 190,
                child: PageView.builder(
                  controller: _page,
                  padEnds: false,
                  clipBehavior: Clip.none,
                  itemCount: _parks.length,
                  itemBuilder: (_, i) {
                    final p = _parks[i];
                    final selected = i == _current;
                    return _ParkMapCard(
                      park: p,
                      selected: selected,
                      imageUrl: _toImageUrl(p.heroImage),
                      distance: _formatDistance(p),
                      onTap: () => _selectPark(p),
                    );
                  },
                ),
              ),
            ),

          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: kBrandGreen)),
        ],
      ),
    );
  }
}

// ── Search Pill ───────────────────────────────────────────────────────────────

class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.hint, this.onTap});
  final String hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBrandGreen, width: 2.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 50),
              child: Text(
                hint,
                style: GoogleFonts.poppins(
                  color: kDarkGray.withValues(alpha: .6),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            Positioned(
              right: -2,
              top: -2,
              bottom: -2,
              child: Container(
                width: 40,
                decoration: const BoxDecoration(
                  color: kBrandGreen,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.search,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card do carousel ──────────────────────────────────────────────────────────

class _ParkMapCard extends StatelessWidget {
  const _ParkMapCard({
    required this.park,
    required this.selected,
    required this.imageUrl,
    required this.onTap,
    this.distance,
  });

  final Park park;
  final bool selected;
  final String? imageUrl;
  final VoidCallback onTap;
  final String? distance;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.0 : 0.96,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 181,
          height: 181,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: 105,
                      width: double.infinity,
                      child: imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: Colors.grey[200]),
                            errorWidget: (_, __, ___) => Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.image_not_supported, color: Colors.grey),
                            ),
                          )
                        : Container(color: Colors.grey[200]),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: FavoriteButton(
                      parkDocumentId: park.documentId,
                      size: 28,
                    ),
                  ),
                  if (distance != null)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          distance!,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: kDarkGray,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    park.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: kDarkGray,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bottom sheet do parque ────────────────────────────────────────────────────

class _ParkBottomSheet extends StatelessWidget {
  const _ParkBottomSheet({
    required this.park,
    required this.onRoutes,
    required this.onDetails,
    this.imageUrl,
    this.distance,
  });

  final Park park;
  final String? imageUrl;
  final String? distance;
  final VoidCallback onRoutes;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.grey.shade200),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.park, color: kBrandGreen, size: 40),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  park.name,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: kBrandGreen,
                  ),
                ),
              ),
              if (park.rating != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5EFE2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 14, color: kBrandGreen),
                      const SizedBox(width: 4),
                      Text(
                        park.rating!.toStringAsFixed(1),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (park.status != null) ...[
                const Icon(Icons.circle, size: 8, color: Color(0xFF389600)),
                const SizedBox(width: 5),
                Text(
                  park.status!,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: kBrandGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (park.status != null && distance != null)
                Text(
                  '  ·  ',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                ),
              if (distance != null)
                Text(
                  distance!,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: kDarkGray.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kBrandGreen, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: onRoutes,
                  icon: const Icon(Icons.directions_outlined, color: kBrandGreen, size: 20),
                  label: Text(
                    'Rotas',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: kBrandGreen,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: kBrandGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: onDetails,
                  child: Text(
                    'Ver detalhes',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Picker de apps de rota ────────────────────────────────────────────────────

class _RoutePickerSheet extends StatefulWidget {
  const _RoutePickerSheet({
    required this.lat,
    required this.lng,
    required this.parkName,
  });

  final double lat;
  final double lng;
  final String parkName;

  @override
  State<_RoutePickerSheet> createState() => _RoutePickerSheetState();
}

class _RoutePickerSheetState extends State<_RoutePickerSheet> {
  static final _apps = [
    _NavApp(
      name: 'Waze',
      assetPath: 'assets/images/maps/waze.png',
      nativeUrl: (lat, lng) => 'waze://ul?ll=$lat,$lng&navigate=yes',
      webUrl: (lat, lng) => 'https://waze.com/ul?ll=$lat,$lng&navigate=yes',
    ),
    _NavApp(
      name: 'Google Maps',
      assetPath: 'assets/images/maps/google_maps.svg',
      isSvg: true,
      // iOS usa o scheme comgooglemaps://; Android usa google.navigation:
      nativeUrl: (lat, lng) => Platform.isIOS
          ? 'comgooglemaps://?daddr=$lat,$lng&directionsmode=driving'
          : 'google.navigation:q=$lat,$lng',
      webUrl: (lat, lng) => 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    ),
  ];

  Future<void> _launch(_NavApp app) async {
    final nativeUri = Uri.parse(app.nativeUrl(widget.lat, widget.lng));
    bool launched = false;
    try {
      launched = await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!launched) {
      // Fallback web também pode falhar no Android (sem navegador padrão);
      // protege para não derrubar a tela.
      try {
        final webUri = Uri.parse(app.webUrl(widget.lat, widget.lng));
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
    if (mounted) Navigator.pop(context);
  }

  Widget _buildCard(_NavApp app) {
    return Expanded(
      child: InkWell(
        onTap: () => _launch(app),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (app.isSvg)
                SvgPicture.asset(app.assetPath, width: 56, height: 56)
              else
                Image.asset(app.assetPath, width: 56, height: 56, fit: BoxFit.contain),
              const SizedBox(height: 10),
              Text(
                app.name,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kDarkGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Como quer ir?',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kDarkGray,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.parkName,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: kDarkGray.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildCard(_apps[0]),
                const SizedBox(width: 12),
                _buildCard(_apps[1]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NavApp {
  const _NavApp({
    required this.name,
    required this.assetPath,
    required this.nativeUrl,
    required this.webUrl,
    this.isSvg = false,
  });

  final String name;
  final String assetPath;
  final bool isSvg;
  final String Function(double lat, double lng) nativeUrl;
  final String Function(double lat, double lng) webUrl;
}

// ── Tela de busca customizada ─────────────────────────────────────────────────

class _ParkSearchScreen extends StatefulWidget {
  const _ParkSearchScreen({
    required this.parks,
    required this.toImageUrl,
    this.userPosition,
  });

  final List<Park> parks;
  final Position? userPosition;
  final String? Function(String?) toImageUrl;

  @override
  State<_ParkSearchScreen> createState() => _ParkSearchScreenState();
}

class _ParkSearchScreenState extends State<_ParkSearchScreen> {
  final _controller = TextEditingController();
  List<Park> _results = [];

  @override
  void initState() {
    super.initState();
    _results = widget.parks;
    _controller.addListener(_filter);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _filter() {
    final q = _controller.text.toLowerCase();
    setState(() {
      _results = widget.parks
          .where((p) => p.name.toLowerCase().contains(q))
          .toList();
    });
  }

  String? _formatDistance(Park p) {
    final pos = widget.userPosition;
    if (pos == null || p.latitude == null || p.longitude == null) return null;
    final meters = Geolocator.distanceBetween(
      pos.latitude, pos.longitude, p.latitude!, p.longitude!,
    );
    final km = meters / 1000;
    return km < 10
        ? '${km.toStringAsFixed(1).replaceAll('.', ',')} km'
        : '${km.round()} km';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: kBrandGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: GoogleFonts.poppins(fontSize: 15, color: kDarkGray),
          decoration: InputDecoration(
            hintText: 'Busque um parque...',
            hintStyle: GoogleFonts.poppins(
              fontSize: 15,
              color: kDarkGray.withValues(alpha: 0.4),
            ),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: kBrandGreen),
              onPressed: () => _controller.clear(),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE6E6E6)),
        ),
      ),
      body: _results.isEmpty
          ? Center(
              child: Text(
                'Nenhum parque encontrado',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: kDarkGray.withValues(alpha: 0.4),
                ),
              ),
            )
          : ListView.separated(
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                indent: 76,
                color: Color(0xFFF0F0F0),
              ),
              itemBuilder: (context, i) {
                final p = _results[i];
                final imageUrl = widget.toImageUrl(p.heroImage);
                final distance = _formatDistance(p);
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  Container(color: const Color(0xFFE5EFE2)),
                              errorWidget: (_, __, ___) => Container(
                                color: const Color(0xFFE5EFE2),
                                child: const Icon(Icons.park,
                                    color: kBrandGreen, size: 24),
                              ),
                            )
                          : Container(
                              color: const Color(0xFFE5EFE2),
                              child: const Icon(Icons.park,
                                  color: kBrandGreen, size: 24),
                            ),
                    ),
                  ),
                  title: Text(
                    p.name,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kDarkGray,
                    ),
                  ),
                  subtitle: distance != null
                      ? Text(
                          distance,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: kBrandGreen,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : null,
                  trailing: const Icon(Icons.chevron_right, color: kBrandGreen),
                  onTap: () => Navigator.pop(context, p),
                );
              },
            ),
    );
  }
}
