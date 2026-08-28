import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../routes/app_router.dart';
import '../services/auth_service.dart';
import '../widgets/app_toast.dart';
import '../widgets/favorite_button.dart';

import '../data/park_repository.dart';
import '../data/repositories/go_reservation_repository.dart';
import '../data/models/park.dart';
import '../data/models/reservation.dart';
import '../core/api/api_config.dart';
import '../providers/notification_provider.dart';

const kBrandGreen = Color(0xFF669340);
const kDarkGray = Color(0xFF32384A);
const kWhite = Color(0xFFFFFFFF);

const kFigmaSearchHint = Color(0xFFBCC1A6);
const kFigmaSearchFill = Color(0xFFFFFFE9);
const kFigmaBellBg = Color(0xFFF5F7EB);

/* ================== HOME SCREEN ================== */

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final TextEditingController _search = TextEditingController();

  bool _isLoading = true;
  String? _error;

  List<_CardItem> explorar = [];

  String _query = '';

  List<Park> _allParks = [];
  Position? _currentPosition;
  Park? _closestPark;
  double? _closestDistanceKm;

  Reservation? _nextReservation;

  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAll();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (_router != router) {
      _router?.routerDelegate.removeListener(_onRouteChange);
      _router = router;
      _router!.routerDelegate.addListener(_onRouteChange);
    }
  }

  void _onRouteChange() {
    final location = _router?.routerDelegate.currentConfiguration.uri.toString() ?? '';
    if (location == '/tabs/home' || location == '/tabs/home/') {
      _loadNextReservation();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadNextReservation();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router?.routerDelegate.removeListener(_onRouteChange);
    super.dispose();
  }


  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final parkRepo = context.read<ParkRepository>();

      // parques
      final parksRaw = await parkRepo.fetchAll();
      final parks = parksRaw.map((p) => _CardItem(
        id: p.documentId,
        title: p.name,
        image: _toImageUrl(p.heroImage) ?? '',
        status: p.status,
        withFavorite: true,
      )).toList();

      _allParks = parksRaw;
      if (parksRaw.isNotEmpty) {
        _closestPark = parksRaw.first;
      }

      if (!mounted) return;
      setState(() {
        explorar = parks;
        _isLoading = false;
      });

      _loadNextReservation();

      _determinePosition();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao carregar dados: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNextReservation() async {
    if (!mounted) return;
    final isLogged = context.read<AuthService>().currentUser != null;
    if (!isLogged) {
      if (_nextReservation != null) setState(() => _nextReservation = null);
      return;
    }
    try {
      final reservations = await GoReservationRepository().fetchMine();
      if (!mounted) return;
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final upcoming = reservations.where((r) {
        if (r.status != 'Aprovada') return false;
        final parts = r.data.split('-');
        if (parts.length != 3) return false;
        final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        return !d.isBefore(todayDate);
      }).toList()
        ..sort((a, b) => a.data.compareTo(b.data));
      setState(() => _nextReservation = upcoming.isNotEmpty ? upcoming.first : null);
    } catch (_) {}
  }

  String? _toImageUrl(dynamic value) {
    if (value == null) return null;
    final v = value.toString().trim();
    if (v.isEmpty) return null;
    
    // Se já é uma URL completa
    if (v.startsWith('http://') || v.startsWith('https://')) {
      // FIX TEMPORÁRIO: Se a URL for do apps.sitw.com.br mas não tiver /backend-park
      if (v.contains('apps.sitw.com.br') && !v.contains('/backend-park/')) {
        return v.replaceFirst('apps.sitw.com.br/', 'apps.sitw.com.br/backend-park/');
      }
      return v;
    }
    
    // Se for um caminho relativo, usamos a base do backend-park
    final baseUrl = ApiConfig.baseUrl.replaceAll('/api/v1', '');
    final cleanPath = v.startsWith('/') ? v.substring(1) : v;
    return '$baseUrl/$cleanPath';
  }

  ImageProvider _imageProviderFrom(String src) {
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return CachedNetworkImageProvider(src);
    }
    return const AssetImage('assets/placeholder.png');
  }

  String _saudacaoDia() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'Bom dia';
    if (h >= 12 && h < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  List<_CardItem> _applyFilter(List<_CardItem> items) {
    if (_query.isEmpty) return items;
    final q = _query.toLowerCase();
    return items.where((e) => e.title.toLowerCase().contains(q)).toList();
  }

  /// Somente usuários logados podem reservar. Caso contrário, leva ao login.
  void _openReservas(BuildContext context) {
    final logged = context.read<AuthService>().currentUser != null;
    if (logged) {
      context.push(AppRoutes.homeReservas);
    } else {
      AppToast.show(
        context,
        'Faça login para reservar um espaço.',
        type: ToastType.warning,
      );
      context.go('/tabs/user/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    const headerTitleSize = 20.0;
    const headerTitleLineHeight = 1.5;
    const headerSubtitleSize = 16.0;

    const double exploreCardWidth = 282.0;
    const double exploreCardHeight = 300.0;
    const double exploreCardRadius = 8.0;

    final me = context.watch<AuthService>().currentUser;
    final saudacao = _saudacaoDia();
    String? firstName;
    if (me != null) {
      final nome = me['nome'] ?? me['name'] ?? me['username'] ?? me['first_name'];
      if (nome != null && nome.toString().trim().isNotEmpty) {
        final raw = nome.toString().trim().split(' ').first.toLowerCase();
        // Capitaliza a 1ª letra — backend pode salvar em caixa alta
        firstName = raw[0].toUpperCase() + raw.substring(1);
      }
    }

    final filteredExplorar = _applyFilter(explorar);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _error != null
            ? _ErrorHome(message: _error!, onRetry: _loadAll)
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // HEADER
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (me != null) ...[
                                    const _Avatar(),
                                    const SizedBox(width: 12),
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 400),
                                          transitionBuilder: (child, anim) =>
                                              FadeTransition(
                                            opacity: anim,
                                            child: SlideTransition(
                                              position: Tween<Offset>(
                                                begin: const Offset(0, 0.25),
                                                end: Offset.zero,
                                              ).animate(CurvedAnimation(
                                                parent: anim,
                                                curve: Curves.easeOut,
                                              )),
                                              child: child,
                                            ),
                                          ),
                                          child: Text.rich(
                                            key: ValueKey(firstName ?? saudacao),
                                            TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: 'Oi, ',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: headerTitleSize,
                                                    fontWeight: FontWeight.w400,
                                                    color: Colors.black,
                                                    height: headerTitleLineHeight,
                                                  ),
                                                ),
                                                // Logado: "Nilo!" em verde — não logado: "Boa noite" em verde
                                                TextSpan(
                                                  text: firstName != null
                                                      ? '$firstName!'
                                                      : saudacao,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: headerTitleSize,
                                                    fontWeight: FontWeight.w700,
                                                    color: kBrandGreen,
                                                    height: headerTitleLineHeight,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Para onde vamos hoje?',
                                          style: GoogleFonts.poppins(
                                            fontSize: headerSubtitleSize,
                                            color:
                                                kDarkGray.withValues(alpha: .7),
                                            height: 1.25,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const _NotificationBell(),
                                ],
                              ),
                              const SizedBox(height: 40),

                              // BUSCA
                              _SearchBar(
                                controller: _search,
                                hint: 'O que você está procurando?',
                                borderColor: kBrandGreen,
                                onSubmitted: (text) =>
                                    setState(() => _query = text.trim()),
                              ),
                              const SizedBox(height: 16),

                              // ATALHOS
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _QuickAction(
                                    iconAsset: 'assets/icons/denuncie.svg',
                                    label: 'Colabore',
                                    color: kBrandGreen,
                                    onTap: () =>
                                        context.push(AppRoutes.homeDenuncie),
                                  ),
                                  _QuickAction(
                                    iconAsset:
                                        'assets/icons/Calendar_Check.svg',
                                    label: 'Reservas',
                                    color: kBrandGreen,
                                    onTap: () => _openReservas(context),
                                  ),
                                  _QuickAction(
                                    iconAsset: 'assets/icons/calendar.svg',
                                    label: 'Eventos',
                                    color: kBrandGreen,
                                    onTap: () =>
                                        context.push(AppRoutes.homeEventos),
                                  ),
                                  _QuickAction(
                                    iconData: Icons.favorite_border,
                                    label: 'Favoritos',
                                    color: kBrandGreen,
                                    onTap: () => context
                                        .push(AppRoutes.homeFavorites),
                                  ),
                                  _QuickAction(
                                    iconAsset: 'assets/icons/info.svg',
                                    label: 'Info',
                                    color: kBrandGreen,
                                    onTap: () =>
                                        context.push(AppRoutes.homeInfo),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),

                              // IMAGEM DE DESTAQUE
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.asset(
                                  'assets/images/destaque.png',
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),

                              // CARD PRÓXIMA RESERVA
                              if (_nextReservation != null) ...[
                                const SizedBox(height: 16),
                                _NextReservationCard(
                                  reservation: _nextReservation!,
                                  onTap: () => context.push(AppRoutes.userReservations),
                                ),
                              ],

                              const SizedBox(height: 32),

                              // PERTO DE VOCÊ
                              if (!_isLoading && _closestPark != null) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const _SectionHeader(
                                      label: 'Perto de você',
                                      color: kBrandGreen,
                                    ),
                                    GestureDetector(
                                      onTap: () => context.push(AppRoutes.map),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Ver todos',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: kBrandGreen,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.arrow_forward_ios,
                                            size: 10,
                                            color: kBrandGreen,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _NearYouCard(
                                  park: _closestPark!,
                                  imageUrl: _toImageUrl(_closestPark!.heroImage) ?? '',
                                  distanceKm: _closestDistanceKm,
                                  imageProviderFrom: _imageProviderFrom,
                                  onTap: () => context.push(
                                    AppRoutes.parkDetail(_closestPark!.id.toString()),
                                  ),
                                ),
                                const SizedBox(height: 40),
                              ],

                              // TÍTULO VEM EXPLORAR
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const _SectionHeader(
                                    label: 'Vem explorar',
                                    color: kBrandGreen,
                                  ),
                                  GestureDetector(
                                    onTap: () => context.push(AppRoutes.map),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Ver todos',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: kBrandGreen,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 10,
                                          color: kBrandGreen,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),

                        // LISTA VEM EXPLORAR
                        SizedBox(
                          height: exploreCardHeight,
                          child: _isLoading
                              ? _ShimmerCardList(
                                  width: exploreCardWidth,
                                  height: exploreCardHeight,
                                  radius: exploreCardRadius,
                                )
                              : filteredExplorar.isEmpty
                                  ? const _EmptyLane()
                                  : ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20),
                                      itemBuilder: (context, i) {
                                        final item =
                                            filteredExplorar[i];
                                        return _ExploreCard(
                                          item: item,
                                          color: kBrandGreen,
                                          badgeColor: kWhite,
                                          width: exploreCardWidth,
                                          height: exploreCardHeight,
                                          radius: exploreCardRadius,
                                          imageProviderFrom:
                                              _imageProviderFrom,
                                          onTap: () => context.push(
                                            AppRoutes.parkDetail(item.id),
                                          ),
                                          heroTag: 'park_${item.id}',
                                        )
                                          .animate(
                                            delay: Duration(milliseconds: 80 * i),
                                          )
                                          .fadeIn(duration: 350.ms)
                                          .slideX(
                                            begin: 0.2,
                                            end: 0,
                                            curve: Curves.easeOut,
                                          );
                                      },
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(width: 16),
                                      itemCount:
                                          filteredExplorar.length,
                                    ),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }


  Future<void> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _calculateClosestPark(fallbackLat: -2.53073, fallbackLng: -44.3068);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _calculateClosestPark(fallbackLat: -2.53073, fallbackLng: -44.3068);
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        _calculateClosestPark(fallbackLat: -2.53073, fallbackLng: -44.3068);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
        _calculateClosestPark();
      }
    } catch (e) {
      debugPrint('Erro ao obter GPS: $e');
      _calculateClosestPark(fallbackLat: -2.53073, fallbackLng: -44.3068);
    }
  }

  void _calculateClosestPark({double? fallbackLat, double? fallbackLng}) {
    if (_allParks.isEmpty) return;
    
    double refLat;
    double refLng;
    
    if (_currentPosition != null) {
      refLat = _currentPosition!.latitude;
      refLng = _currentPosition!.longitude;
    } else if (fallbackLat != null && fallbackLng != null) {
      refLat = fallbackLat;
      refLng = fallbackLng;
    } else {
      return;
    }
    
    Park? closest;
    double minDistance = double.infinity;
    
    for (final p in _allParks) {
      if (p.latitude != null && p.longitude != null) {
        final dist = Geolocator.distanceBetween(
          refLat,
          refLng,
          p.latitude!,
          p.longitude!,
        );
        if (dist < minDistance) {
          minDistance = dist;
          closest = p;
        }
      }
    }
    
    if (closest != null && mounted) {
      setState(() {
        _closestPark = closest;
        _closestDistanceKm = minDistance / 1000.0;
      });
    }
  }
}

/* ================== SUPORTE ================== */



class _ErrorHome extends StatelessWidget {
  const _ErrorHome({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: Colors.redAccent, size: 40),
            const SizedBox(height: 12),
            Text(
              'Não foi possível carregar os dados.',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.black54,
                  height: 1.3),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: kBrandGreen),
              onPressed: onRetry,
              child: const Text('Tentar novamente',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLane extends StatelessWidget {
  const _EmptyLane();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Nenhum item encontrado.',
        style: GoogleFonts.poppins(
            fontSize: 13, color: kDarkGray.withValues(alpha: .7)),
      ),
    );
  }
}

/* ================== COMPONENTES ================== */

class _Avatar extends StatelessWidget {
  const _Avatar();

  String? _getFullAvatarUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    
    if (url.startsWith('http')) {
      if (url.contains('apps.sitw.com.br') && !url.contains('/backend-park/')) {
        return url.replaceFirst('apps.sitw.com.br/', 'apps.sitw.com.br/backend-park/');
      }
      return url;
    }
    
    final baseUrl = ApiConfig.baseUrl.replaceAll('/api/v1', '');
    final cleanPath = url.startsWith('/') ? url.substring(1) : url;
    return '$baseUrl/$cleanPath';
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthService>().currentUser;
    String? avatarUrl;

    if (me != null) {
      avatarUrl = _getFullAvatarUrl(me['avatar_url']);
      
      // Fallback para caso seja o antigo objeto Strapi (Map)
      if (avatarUrl == null) {
        final avatarData = me['avatar'];
        if (avatarData is Map && avatarData['url'] != null) {
          avatarUrl = _getFullAvatarUrl(avatarData['url']);
        }
      }
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFFE1E1E5),
      backgroundImage:
          avatarUrl != null ? NetworkImage(avatarUrl) : null,
      child: avatarUrl == null
          ? const Icon(Icons.person,
              color: Colors.white70, size: 24)
          : null,
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, _) {
        return GestureDetector(
          onTap: () {
            provider.markAllRead();
            context.push('/tabs/home/notificacoes');
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: kFigmaBellBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_none_outlined,
                  color: kBrandGreen,
                  size: 24,
                ),
              ),
              if (provider.hasUnread)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.hint,
    required this.borderColor,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final Color borderColor;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide:
          const BorderSide(color: kBrandGreen, width: 2.0),
    );

    return TextField(
      controller: controller,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      style: GoogleFonts.poppins(
          fontSize: 14, color: kDarkGray),
      decoration: InputDecoration(
        filled: true,
        fillColor: kFigmaSearchFill,
        hintText: hint,
        hintStyle:
            GoogleFonts.poppins(color: kFigmaSearchHint),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 16),
        enabledBorder: border,
        focusedBorder: border,
        suffixIcon: const Padding(
          padding: EdgeInsets.only(right: 12.0),
          child: Icon(
            Icons.search_rounded,
            color: kDarkGray,
            size: 28,
          ),
        ),
      ),
    );
  }
}

// QUICK ACTION
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    this.iconAsset,
    this.iconData,
    required this.label,
    required this.color,
    this.onTap,
  }) : assert(
          iconAsset != null || iconData != null,
          'Informe iconAsset ou iconData',
        );

  final String? iconAsset;
  final IconData? iconData;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: iconAsset != null
                ? SvgPicture.asset(
                    iconAsset!,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                    width: 24,
                    height: 24,
                  )
                : Icon(
                    iconData,
                    color: Colors.white,
                    size: 24,
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF32384A),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}



class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: color,
        height: 1.1,
      ),
    );
  }
}

class _NearYouCard extends StatelessWidget {
  const _NearYouCard({
    required this.park,
    required this.imageUrl,
    required this.distanceKm,
    required this.imageProviderFrom,
    this.onTap,
  });

  final Park park;
  final String imageUrl;
  final double? distanceKm;
  final ImageProvider Function(String) imageProviderFrom;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.trim().isNotEmpty;

    final childImage = hasImage
        ? Image(image: imageProviderFrom(imageUrl), fit: BoxFit.cover)
        : Container(color: const Color(0xFFEFEFEF));

    final distanceStr = distanceKm != null
        ? '${distanceKm!.toStringAsFixed(1).replaceAll('.', ',')} km'
        : '2,4 km';

    final addressParts = [park.endereco, park.cidade]
        .where((e) => e != null && e.trim().isNotEmpty)
        .map((e) => e!.trim())
        .toList();
    final addressStr = addressParts.isNotEmpty ? addressParts.join(', ') : 'São Luís, MA';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: Hero(tag: 'park_near_${park.id}', child: childImage),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                ),
              ),

              Positioned(
                right: 16,
                top: 16,
                child: FavoriteButton(
                  parkDocumentId: park.documentId,
                  size: 36,
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            park.name,
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '$addressStr • $distanceStr',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: kBrandGreen,
                      ),
                    ),
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

/* ====== CARDS ====== */

class _ExploreCard extends StatelessWidget {
  const _ExploreCard({
    required this.item,
    required this.color,
    required this.badgeColor,
    required this.imageProviderFrom,
    required this.width,
    required this.height,
    required this.radius,
    this.onTap,
    this.heroTag,
  });

  final _CardItem item;
  final Color color;
  final Color badgeColor;
  final ImageProvider Function(String) imageProviderFrom;
  final double width;
  final double height;
  final double radius;
  final VoidCallback? onTap;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final hasImage = item.image.trim().isNotEmpty;

    final childImage = hasImage
        ? Image(image: imageProviderFrom(item.image), fit: BoxFit.cover)
        : Container(color: const Color(0xFFEFEFEF));

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            children: [
              Positioned.fill(
                child: heroTag == null
                    ? childImage
                    : Hero(tag: heroTag!, child: childImage),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.05),
                        Colors.black.withValues(alpha: 0.45),
                      ],
                    ),
                  ),
                ),
              ),
              if (item.withFavorite)
                Positioned(
                  right: 10,
                  top: 10,
                  child: FavoriteButton(
                    parkDocumentId: item.id,
                    size: 32,
                  ),
                ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              height: 1.1,
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              shadows: const [
                                Shadow(
                                  blurRadius: 10,
                                  color: Colors.black38,
                                  offset: Offset(0, 1),
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          if ((item.status ?? '').isNotEmpty)
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(alpha: .94),
                                borderRadius:
                                    BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    item.status!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: onTap,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: kWhite,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: kBrandGreen,
                        ),
                      ),
                    ),
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

class _CardItem {
  final String id; // documentId/slug/id
  final String title;
  final String image;
  final String? status;
  final bool withFavorite;

  const _CardItem({
    required this.id,
    required this.title,
    required this.image,
    this.status,
    this.withFavorite = false,
  });
}

// ── Shimmer placeholder para lista horizontal de cards ──────────────────────
class _ShimmerCardList extends StatelessWidget {
  const _ShimmerCardList({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8EDE4),
      highlightColor: const Color(0xFFF5F8F2),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, __) => ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            width: width,
            height: height,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _NextReservationCard extends StatelessWidget {
  const _NextReservationCard({required this.reservation, required this.onTap});

  final Reservation reservation;
  final VoidCallback onTap;

  bool get _isToday {
    final today = DateTime.now();
    final parts = reservation.data.split('-');
    if (parts.length != 3) return false;
    final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    return d.year == today.year && d.month == today.month && d.day == today.day;
  }

  String get _dateLabel {
    if (_isToday) return 'Hoje';
    final parts = reservation.data.split('-');
    if (parts.length != 3) return reservation.data;
    final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    const weekdays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    final wd = weekdays[d.weekday - 1];
    return '$wd, ${parts[2]}/${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final isToday = _isToday;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAE8),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: kBrandGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.calendar_month_rounded,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: kBrandGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isToday ? 'Hoje!' : 'Reserva confirmada',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: kBrandGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reservation.spaceName,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: kBrandGreen,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_dateLabel  •  ${reservation.horaInicio} às ${reservation.horaFim}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: kDarkGray.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: kBrandGreen),
          ],
        ),
      ),
    );
  }
}

