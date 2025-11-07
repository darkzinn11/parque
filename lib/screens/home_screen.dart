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

// --- CORES DO FIGMA ---
const kFigmaSearchHint = Color(0xFFBCC1A6);
const kFigmaSearchFill = Color(0xFFFFFFE9); 
const kFigmaBellBg     = Color(0xFFF5F7EB);
// --- FIM NOVAS CORES ---

const String kStrapiBaseUrl = 'http://192.168.15.12:1337';

const String kParksCollection = 'parks';
const String kActivitiesCollection = 'activities';

const String? kStrapiStaticToken = null;

const _CollectionFields kParksFields = _CollectionFields(
  title: ['title', 'name', 'nome'],
  image: ['image', 'hero_image', 'capa', 'banner', 'foto', 'imagem'],
  status: ['status', 'situacao'],
  slug: ['slug', 'id_parque', 'id'], // 'slug' ou 'id_parque' é o documentId
);
const _CollectionFields kActivitiesFields = _CollectionFields(
  title: ['titulo', 'name', 'title', 'nome'],
  image: ['hero_image', 'image', 'capa', 'banner', 'foto', 'imagem'],
  status: ['status', 'situacao'],
  slug: ['slug', 'id_atividade', 'id'], // 'slug' ou 'id_atividade' é o documentId
);

/* ================== HOME SCREEN ================== */

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

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
    // Carrega os favoritos salvos no app
    await FavoritesService.instance.init(); 
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
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

      if (!mounted) return;
      setState(() {
        explorar = parks;
        divertir = activities;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
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

      final map = raw.cast<String, dynamic>();
      // v5: { id: 1, documentId: 'xxx', nome: '...', ... }
      final attributes = (map['attributes'] is Map) ? Map<String, dynamic>.from(map['attributes']) : map;

      final idNum = (map['id'] is int) ? map['id'] : int.tryParse('${map['id']}');
      
      // Usa o 'documentId' (slug) ou 'id' como o ID de navegação/favorito
      final docId = (map['documentId'] ?? attributes['documentId'] ?? _firstNonEmpty(attributes, fields.slug))?.toString();
      
      // Garante que temos um ID (seja o docId ou o numérico)
      final primaryId = (docId != null && docId.isNotEmpty) ? docId : idNum.toString();

      final title = _firstNonEmpty(attributes, fields.title) ?? 'Sem título';
      final status = _firstNonEmpty(attributes, fields.status);

      final imageVal = _resolveImageValue(attributes, fields.image);
      final imageUrl = _toImageUrl(imageVal);

      items.add(_CardItem(
        id: primaryId, // ID principal (usado para navegação E favoritos)
        title: title,
        image: imageUrl ?? '',
        status: status,
        withFavorite: isPark,
      ));
    }

    return items;
  }

  /// Tenta resolver campo de imagem em formatos comuns (url direta, media v4/v5, arrays)
  static dynamic _resolveImageValue(Map<String, dynamic> map, List<String> candidates) {
    for (final key in candidates) {
      if (!map.containsKey(key) || map[key] == null) continue;
      final val = map[key];

      if (val is String) return val;
      if (val is Map && val['url'] != null) return val['url'];

      if (val is Map && val['data'] != null) {
        final data = val['data'];
        if (data is Map) {
          final attrs = data['attributes'];
          if (attrs is Map && attrs['url'] != null) return attrs['url'];
        }
        if (data is List && data.isNotEmpty) {
          final first = data.first;
          if (first is Map) {
            final attrs = first['attributes'];
            if (attrs is Map && attrs['url'] != null) return attrs['url'];
          }
        }
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
    // Ajustado para o caminho de upload padrão do Strapi
    return '$kStrapiBaseUrl$v'; 
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

  List<_CardItem> _applyFilter(List<_CardItem> items) {
    if (_query.isEmpty) return items;
    final q = _query.toLowerCase();
    return items.where((e) => e.title.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    const headerTitleSize = 20.0;
    const headerTitleLineHeight = 1.5;
    const headerSubtitleSize = 16.0;

    const double exploreCardWidth = 282.0;
    const double exploreCardHeight = 300.0;
    const double exploreCardRadius = 8.0;

    const double smallCardWidth = 282.0;
    const double smallCardHeight = 300.0;
    const double smallCardRadius = 8.0;
    
    const quickSize = 80.0;
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // HEADER
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center, 
                                    children: [
                                      const _Avatar(), 
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            RichText(
                                              text: TextSpan(
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
                                                  WidgetSpan(
                                                    alignment: PlaceholderAlignment.baseline,
                                                    baseline: TextBaseline.alphabetic,
                                                    child: FutureBuilder<Map<String, dynamic>?>(
                                                      future: AuthService.instance.me(),
                                                      builder: (context, snapshot) {
                                                        String displayName = _saudacaoDia();
                                                        if (snapshot.hasData && snapshot.data != null) {
                                                          final me = snapshot.data!;
                                                          final nome = me['name'] ?? me['username'] ?? me['first_name'];
                                                          if (nome != null && nome.toString().isNotEmpty) {
                                                            displayName = nome.toString().split(' ').first;
                                                          }
                                                        }
                                                        return Text(
                                                          displayName,
                                                          style: GoogleFonts.poppins(
                                                            fontSize: headerTitleSize,
                                                            fontWeight: FontWeight.w700,
                                                            color: kBrandGreen,
                                                            height: headerTitleLineHeight,
                                                          ),
                                                        );
                                                      },
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
                                    onSubmitted: (text) => setState(() => _query = text.trim()),
                                  ),
                                  const SizedBox(height: 16), 

                                  // ATALHOS
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center, 
                                    children: [
                                      _QuickAction(
                                        iconAsset: 'assets/icons/Map.svg',
                                        label: 'Mapa',
                                        color: kBrandGreen,
                                        size: quickSize,
                                        radius: quickRadius,
                                        onTap: () => context.go(AppRoutes.map),
                                      ),
                                      const SizedBox(width: 20), 
                                      _QuickAction(
                                        iconAsset: 'assets/icons/Calendar_Check.svg',
                                        label: 'Reservas',
                                        color: kBrandGreen,
                                        size: quickSize,
                                        radius: quickRadius,
                                        onTap: () => context.push(AppRoutes.homeReservas),
                                      ),
                                      const SizedBox(width: 20), 
                                      _QuickAction(
                                        iconAsset: 'assets/icons/calendar.svg',
                                        label: 'Eventos',
                                        color: kBrandGreen,
                                        size: quickSize,
                                        radius: quickRadius,
                                        onTap: () => context.push(AppRoutes.homeEventos),
                                      ),
                                      const SizedBox(width: 20), 
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
                                  const SizedBox(height: 40), 

                                  // TÍTULO VEM EXPLORAR
                                  _SectionTitle(
                                    title: 'Vem explorar',
                                    subtitle: 'Encontre o parque perfeito para sua próxima aventura!',
                                    color: kBrandGreen,
                                    subtitleColor: kDarkGray.withOpacity(.7),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                            
                            // LISTA VEM EXPLORAR
                            SizedBox(
                              height: exploreCardHeight, 
                              child: _applyFilter(explorar).isEmpty
                                  ? const _EmptyLane()
                                  : ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
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

                            // TÍTULO VEM SE DIVERTIR
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 28),
                                  const _SectionHeader(label: 'Vem se divertir', color: kBrandGreen),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Diversão para todas as idades, do nascer ao pôr do sol.',
                                    style: GoogleFonts.poppins(fontSize: 14, color: kDarkGray.withOpacity(.7), height: 1.3),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                            
                            // LISTA VEM SE DIVERTIR
                            SizedBox(
                              height: smallCardHeight, 
                              child: _applyFilter(divertir).isEmpty
                                  ? const _EmptyLane()
                                  : ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
                                      itemBuilder: (context, i) {
                                        final item = _applyFilter(divertir)[i];
                                        return _ExploreCard(
                                          item: item,
                                          color: kBrandGreen,
                                          badgeColor: kWhite,
                                          width: smallCardWidth, 
                                          height: smallCardHeight, 
                                          radius: smallCardRadius, 
                                          imageProviderFrom: _imageProviderFrom,
                                          onTap: null, 
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
    return FutureBuilder<Map<String, dynamic>?>(
      future: AuthService.instance.me(),
      builder: (context, snapshot) {
        String? avatarUrl;
        if (snapshot.hasData && snapshot.data != null) {
          final me = snapshot.data!;
          final avatarData = me['avatar'];
          if (avatarData is Map && avatarData['url'] != null) {
             String url = avatarData['url'];
             if (!url.startsWith('http')) {
               url = '$kStrapiBaseUrl$url';
             }
             avatarUrl = url;
          }
        }

        return CircleAvatar(
          // --- CORREÇÃO: Raio 24 para ficar 48x48 ---
          radius: 24,
          backgroundColor: const Color(0xFFE1E1E5), // CSS #E1E1E5
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? const Icon(Icons.person, color: Colors.white70, size: 24) // Ícone menor
              : null,
        );
      },
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context) {
    return Container(
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
      borderSide: const BorderSide(color: kBrandGreen, width: 2.0),
    );

    return TextField(
      controller: controller,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      style: GoogleFonts.poppins(fontSize: 14, color: kDarkGray),
      decoration: InputDecoration(
        filled: true, 
        fillColor: kFigmaSearchFill, 
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: kFigmaSearchHint),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.iconAsset,
    required this.label,
    required this.color,
    this.size = 80, 
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 6))],
            ),
            child: Center(
              child: SvgPicture.asset(
                iconAsset,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
            ),
          ),
          const SizedBox(height: 4),
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
                  // --- CORREÇÃO: Passa o 'documentId' para o botão ---
                  child: FavoriteButton(parkDocumentId: item.id, size: 32),
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
                          Text( // Título
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
                          
                          const SizedBox(height: 16), 
                          if ((item.status ?? '').isNotEmpty) 
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: badgeColor.withOpacity(.94), borderRadius: BorderRadius.circular(14)), 
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.circle, size: 8, color: Colors.green),
                                  const SizedBox(width: 6),
                                  Text(item.status!, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
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
                        decoration: const BoxDecoration(color: kWhite, shape: BoxShape.circle), 
                        child: const Icon(Icons.arrow_forward_rounded, color: kBrandGreen), 
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
  final String id;           // 'slug' ou 'id_parque' (documentId)
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