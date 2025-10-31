// lib/screens/home_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:http/http.dart' as http;

import '../routes/app_router.dart';

// +++ FAVORITOS +++
import '../services/auth_service.dart';
import '../services/favorites_service.dart';
import '../widgets/favorite_button.dart';
// --- FAVORITOS ---

const kBrandGreen = Color(0xFF669340);
const kDarkGray   = Color(0xFF32384A);
const kWhite      = Color(0xFFFFFFFF);

const String kStrapiBaseUrl = 'http://192.168.15.17:1337';

const String kParksCollection = 'parks';
const String kActivitiesCollection = 'activities';

const String? kStrapiStaticToken = null;

const _CollectionFields kParksFields = _CollectionFields(
  title: ['title', 'name', 'nome'],
  image: ['image', 'hero_image', 'capa', 'banner', 'foto', 'imagem'],
  status: ['status', 'situacao'],
  slug: ['slug', 'id_parque', 'id'],
);
const _CollectionFields kActivitiesFields = _CollectionFields(
  title: ['titulo', 'name', 'title', 'nome'],
  image: ['hero_image', 'image', 'capa', 'banner', 'foto', 'imagem'],
  status: ['status', 'situacao'],
  slug: ['slug', 'id_atividade', 'id'],
);

/* ================== HOME SCREEN ================== */

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.userName,
    this.isLoggedIn = false,
  });

  final String? userName;
  final bool isLoggedIn;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _search = TextEditingController();

  bool _isLoading = true;
  String? _error;

  List<_CardItem> explorar = []; // parques
  List<_CardItem> divertir = []; // atividades

  String _query = '';

  @override
  void initState() {
    super.initState();
    _setupFavs();
    _loadAll();
  }

  Future<void> _setupFavs() async {
    await FavoritesService.instance.init();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final parks = await _fetchCollection(
        collection: kParksCollection,
        fields: kParksFields,
        limit: 12,
        sort: ['nome'],
        isPark: true, 
      );

      final activities = await _fetchCollection(
        collection: kActivitiesCollection,
        fields: kActivitiesFields,
        limit: 12,
        sort: ['titulo'],
        isPark: false,
      );

      setState(() {
        explorar = parks;
        divertir = activities;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<List<_CardItem>> _fetchCollection({
    required String collection,
    required _CollectionFields fields,
    int limit = 10,
    List<String> sort = const [],
    bool isPark = false,
  }) async {
    final qp = <String, String>{
      'limit': '$limit',
      'populate': '*', 
    };
    if (sort.isNotEmpty) qp['sort'] = sort.join(',');

    final uri = Uri.parse('$kStrapiBaseUrl/api/$collection').replace(
      queryParameters: qp,
    );

    final headers = <String, String>{
      'Accept': 'application/json',
      if (kStrapiStaticToken != null) 'Authorization': 'Bearer $kStrapiStaticToken',
    };

    final res = await http.get(uri, headers: headers);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Erro ${res.statusCode} ao buscar "$collection". Body: ${res.body}');
    }
    
    final body = json.decode(res.body);
    final List data = (body['data'] is List) ? body['data'] as List : [];

    final items = <_CardItem>[];
    for (final raw in data) {
      if (raw is! Map) continue;

      // <<-- CORREÇÃO FINAL AQUI -->>
      // Seus dados não usam 'attributes', então usamos o objeto 'raw' diretamente.
      final id = '${raw['id']}';
      final map = raw as Map<String, dynamic>;

      final title = _firstNonEmpty(map, fields.title) ?? 'Sem título';
      final status = _firstNonEmpty(map, fields.status);
      final slug = _firstNonEmpty(map, fields.slug) ?? id;

      final imageVal = _resolveImageValue(map, fields.image);
      final imageUrl = _toImageUrl(imageVal);

      items.add(_CardItem(
        id: slug,
        title: title,
        image: imageUrl ?? '',
        status: status,
        withFavorite: isPark,
      ));
    }

    return items;
  }

  static dynamic _resolveImageValue(Map<String, dynamic> map, List<String> candidates) {
    for (final key in candidates) {
      if (map.containsKey(key) && map[key] != null) {
        final val = map[key];

        // <<-- CORREÇÃO FINAL AQUI -->>
        // Acessa a URL da imagem diretamente, pois seus dados não usam 'data'/'attributes' aqui.
        if (val is Map && val.containsKey('url')) {
          return val['url'];
        }
        
        return val;
      }
    }
    return null;
  }

  static String? _toImageUrl(dynamic value) {
    if (value == null) return null;
    final v = value.toString().trim();
    if (v.isEmpty) return null;
    if (v.startsWith('http://') || v.startsWith('https://')) return v;
    if (v.startsWith('/')) return '$kStrapiBaseUrl$v';
    return '$kStrapiBaseUrl/assets/$v';
  }

  static String? _firstNonEmpty(Map<String, dynamic> map, List<String> candidates) {
    for (final key in candidates) {
      final v = map[key];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  ImageProvider _imageProviderFrom(String src) {
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return NetworkImage(src);
    }
    return const AssetImage('assets/placeholder.png');
  }

  String _saudacaoDia() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'Bom dia';
    if (h >= 12 && h < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  String _tituloDinamico() {
    final hasName = widget.isLoggedIn && (widget.userName?.trim().isNotEmpty ?? false);
    return hasName ? widget.userName!.trim() : _saudacaoDia();
  }

  List<_CardItem> _applyFilter(List<_CardItem> items) {
    if (_query.isEmpty) return items;
    final q = _query.toLowerCase();
    return items.where((e) => e.title.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    const headerTitleSize = 20.0;
    const headerTitleLineHeight = 1.5;
    const headerSubtitleSize = 16.0;

    final double exploreCardWidth = (w * 0.88).clamp(260.0, 320.0).toDouble();
    const exploreCardHeight = 240.0;
    const exploreCardRadius = 24.0;

    final double smallLaneWidth = (w - 40);
    final double smallCardWidth = (smallLaneWidth * 0.82).toDouble();
    const smallCardHeight = 220.0;
    const smallCardRadius = 22.0;

    const quickSize = 84.0;
    const quickRadius = 24.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const _LoadingHome()
            : _error != null
                ? _ErrorHome(message: _error!, onRetry: _loadAll)
                : CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        RichText(
                                          text: TextSpan(
                                            children: [
                                              TextSpan(
                                                text: 'Olá, ',
                                                style: GoogleFonts.poppins(
                                                  fontSize: headerTitleSize,
                                                  fontWeight: FontWeight.w400,
                                                  color: Colors.black,
                                                  height: headerTitleLineHeight,
                                                ),
                                              ),
                                              TextSpan(
                                                text: _tituloDinamico(),
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
                                        const SizedBox(height: 2),
                                        Text(
                                          'Para onde vamos hoje?',
                                          style: GoogleFonts.poppins(
                                            fontSize: headerSubtitleSize,
                                            color: kDarkGray.withOpacity(.7),
                                            height: 1.25,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const _Avatar(),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Busca
                              _SearchBar(
                                controller: _search,
                                hint: 'O que você está procurando?',
                                borderColor: kBrandGreen,
                                onSubmitted: (text) => setState(() => _query = text.trim()),
                              ),
                              const SizedBox(height: 12),

                              // Atalhos
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _QuickAction(
                                    iconAsset: 'assets/icons/Map.svg',
                                    label: 'Mapa',
                                    color: kBrandGreen,
                                    size: quickSize,
                                    radius: quickRadius,
                                    onTap: () => context.go(AppRoutes.map),
                                  ),
                                  _QuickAction(
                                    iconAsset: 'assets/icons/Calendar_Check.svg',
                                    label: 'Reservas',
                                    color: kBrandGreen,
                                    size: quickSize,
                                    radius: quickRadius,
                                    onTap: () => context.push(AppRoutes.homeReservas),
                                  ),
                                  _QuickAction(
                                    iconAsset: 'assets/icons/calendar.svg',
                                    label: 'Eventos',
                                    color: kBrandGreen,
                                    size: quickSize,
                                    radius: quickRadius,
                                    onTap: () => context.push(AppRoutes.homeEventos),
                                  ),
                                  _QuickAction(
                                    iconAsset: 'assets/icons/info.svg',
                                    label: 'Info',
                                    color: kBrandGreen,
                                    size: quickSize,
                                    radius: quickRadius,
                                    onTap: () => context.push(AppRoutes.homeInfo),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Vem explorar (Parques)
                              _SectionTitle(
                                title: 'Vem explorar',
                                subtitle: 'Encontre o parque perfeito para sua próxima aventura!',
                                color: kBrandGreen,
                                subtitleColor: kDarkGray.withOpacity(.7),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: exploreCardHeight,
                                child: _applyFilter(explorar).isEmpty
                                    ? const _EmptyLane()
                                    : ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        padding: const EdgeInsets.only(left: 20, right: 20),
                                        itemBuilder: (context, i) {
                                          final item = _applyFilter(explorar)[i];
                                          return _ExploreCard(
                                            item: item,
                                            color: kBrandGreen,
                                            badgeColor: kWhite,
                                            width: exploreCardWidth,
                                            height: exploreCardHeight,
                                            radius: exploreCardRadius,
                                            imageProviderFrom: _imageProviderFrom,
                                            onTap: () => context.push(AppRoutes.homePark(item.id)),
                                          );
                                        },
                                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                                        itemCount: _applyFilter(explorar).length,
                                      ),
                              ),
                              const SizedBox(height: 28),

                              // Vem se divertir (Atividades)
                              const _SectionHeader(label: 'Vem se divertir', color: kBrandGreen),
                              const SizedBox(height: 6),
                              Text(
                                'Diversão para todas as idades, do nascer ao pôr do sol.',
                                style: GoogleFonts.poppins(fontSize: 13, color: kDarkGray.withOpacity(.7), height: 1.3),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: smallCardHeight,
                                child: _applyFilter(divertir).isEmpty
                                    ? const _EmptyLane()
                                    : ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        padding: const EdgeInsets.only(left: 20, right: 20),
                                        itemBuilder: (context, i) {
                                          final item = _applyFilter(divertir)[i];
                                          return _ActivityCard(
                                            item: item,
                                            favoriteAccent: kBrandGreen,
                                            width: smallCardWidth,
                                            height: smallCardHeight,
                                            radius: smallCardRadius,
                                            imageProviderFrom: _imageProviderFrom,
                                          );
                                        },
                                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                                        itemCount: _applyFilter(divertir).length,
                                      ),
                              ),

                              const SizedBox(height: 28),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

/* ================== SUPORTES ================== */

class _CollectionFields {
  final List<String> title;
  final List<String> image;
  final List<String> status;
  final List<String> slug;
  const _CollectionFields({
    required this.title,
    required this.image,
    required this.status,
    required this.slug,
  });
}

class _LoadingHome extends StatelessWidget {
  const _LoadingHome();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.only(top: 80),
        child: CircularProgressIndicator(color: kBrandGreen),
      ),
    );
  }
}

class _ErrorHome extends StatelessWidget {
  const _ErrorHome({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
            const SizedBox(height: 12),
            Text(
              'Não foi possível carregar os dados.',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54, height: 1.3),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kBrandGreen),
              onPressed: onRetry,
              child: const Text('Tentar novamente', style: TextStyle(color: Colors.white)),
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
        style: GoogleFonts.poppins(fontSize: 13, color: kDarkGray.withOpacity(.7)),
      ),
    );
  }
}

/* ================== COMPONENTES ================== */

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    return const CircleAvatar(
      radius: 20,
      backgroundImage: NetworkImage(
        'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200',
      ),
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
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide(color: borderColor, width: 1.6),
    );

    return TextField(
      controller: controller,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF32384A)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: const Color(0xFF9AA0A6)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        enabledBorder: border,
        focusedBorder: border,
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Container(
            width: 44,
            height: 44,
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(22)),
            child: const Icon(Icons.search_rounded, color: Colors.white, size: 22),
          ),
        ),
        suffixIconConstraints: const BoxConstraints.tightFor(width: 58, height: 48),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.iconAsset,
    required this.label,
    required this.color,
    this.size = 84,
    this.radius = 24,
    this.onTap,
  });

  final String iconAsset;
  final String label;
  final Color color;
  final double size;
  final double radius;
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
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 6))],
            ),
            child: Center(
              child: SvgPicture.asset(
                iconAsset,
                width: 28,
                height: 28,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF32384A), height: 1.2),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    required this.color,
    this.subtitleColor,
  });

  final String title;
  final String subtitle;
  final Color color;
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: title, color: color),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: GoogleFonts.poppins(fontSize: 13, color: subtitleColor ?? const Color(0xFF6B6B6B), height: 1.3),
        ),
      ],
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
      style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, color: color, height: 1.1),
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
  });

  final _CardItem item;
  final Color color;
  final Color badgeColor;
  final ImageProvider Function(String) imageProviderFrom;
  final double width;
  final double height;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = item.image.trim().isNotEmpty;
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
                child: hasImage
                    ? Image(image: imageProviderFrom(item.image), fit: BoxFit.cover)
                    : Container(color: const Color(0xFFEFEFEF)),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.05), Colors.black.withOpacity(0.45)],
                    ),
                  ),
                ),
              ),
              if (item.withFavorite)
                Positioned(
                  right: 10,
                  top: 10,
                  child: FavoriteButton(parkId: item.id, size: 32),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if ((item.status ?? '').isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: kWhite.withOpacity(.94), borderRadius: BorderRadius.circular(14)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.circle, size: 8, color: Colors.green),
                                  const SizedBox(width: 6),
                                  Text(item.status!, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          const SizedBox(height: 10),
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              height: 1.1,
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              shadows: const [Shadow(blurRadius: 10, color: Colors.black38, offset: Offset(0, 1))],
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
                        decoration: const BoxDecoration(color: kBrandGreen, shape: BoxShape.circle),
                        child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
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

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.item,
    required this.favoriteAccent,
    required this.imageProviderFrom,
    required this.width,
    required this.height,
    required this.radius,
  });

  final _CardItem item;
  final Color favoriteAccent;
  final ImageProvider Function(String) imageProviderFrom;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final hasImage = item.image.trim().isNotEmpty;
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            Positioned.fill(
              child: hasImage
                  ? Image(image: imageProviderFrom(item.image), fit: BoxFit.cover)
                  : Container(color: const Color(0xFFEFEFEF)),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 44,
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, shadows: const [Shadow(blurRadius: 6, color: Colors.black54)]),
              ),
            ),
            if ((item.status ?? '').isNotEmpty)
              Positioned(
                left: 12,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(.94), borderRadius: BorderRadius.circular(14)),
                  child: Text('•  ${item.status!}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: kDarkGray)),
                ),
              ),
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(color: kBrandGreen, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ====== BOTÃO LOTTIE (mantive caso use em outra parte) ====== */
class _FavLottieButton extends StatefulWidget {
  const _FavLottieButton({
    super.key,
    this.initialValue = false,
    this.onChanged,
    this.size = 56,
  });

  final bool initialValue;
  final ValueChanged<bool>? onChanged;
  final double size;

  @override
  State<_FavLottieButton> createState() => _FavLottieButtonState();
}

class _FavLottieButtonState extends State<_FavLottieButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late bool _isFav;

  @override
  void initState() {
    super.initState();
    _isFav = widget.initialValue;
    _ctrl = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final next = !_isFav;
    setState(() => _isFav = next);

    if (next) {
      await _ctrl.forward(from: 0);
    } else {
      await _ctrl.reverse(from: 1);
    }

    widget.onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Lottie.asset(
          'assets/lottie/heart.json',
          controller: _ctrl,
          repeat: false,
          onLoaded: (comp) {
            _ctrl.duration = comp.duration;
            if (_isFav) _ctrl.value = 1.0;
          },
        ),
      ),
    );
  }
}

/* ================== MODELO ================== */
class _CardItem {
  final String id;
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