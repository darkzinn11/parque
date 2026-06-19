import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../widgets/app_toast.dart';
import '../widgets/favorite_button.dart';
import '../data/park_repository.dart';
import '../data/reviews_repository.dart';
import '../data/repositories/space_repository.dart';
import '../data/models/park.dart';
import '../data/models/review.dart';
import '../data/models/space.dart';
import '../core/api/api_config.dart';
import '../services/auth_service.dart';
import '../data/models/map_focus.dart';
import '../routes/app_router.dart';

// CORES
const kBrandGreen = Color(0xFF669340);
const kBrandLightGreen = Color(0xFFE5EFE2);
const kDarkGray = Color(0xFF32384A);
const kRatingStar = Color(0xFFFFB800);
const kStatusDotGreen = Color(0xFF389600);

class ParkDetailScreen extends StatefulWidget {
  const ParkDetailScreen({super.key, required this.parkId});
  final String parkId;

  @override
  State<ParkDetailScreen> createState() => _ParkDetailScreenState();
}

class _ParkDetailScreenState extends State<ParkDetailScreen> {
  late Future<Park?> _future;
  List<Review> _reviews = [];
  List<Review> _myReviews = [];
  List<Space> _spaces = [];
  bool _loadingReviews = true;
  bool _loadingSpaces = true;
  bool _descExpanded = false;
  Park? _loadedPark;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final repo = context.read<ParkRepository>();
    _future = repo.fetchBySlug(widget.parkId);
  }

  Future<void> _fetchReviews(int parkId) async {
    try {
      final repo = context.read<ReviewsRepository>();
      final isLogged = AuthService.instance.tokenSync != null;

      final results = await Future.wait([
        repo.fetchForPark(parkId),
        if (isLogged) repo.fetchMineForPark(parkId),
      ]);

      final approved = results[0];
      final mine = isLogged ? results[1] : <Review>[];

      // Mescla: próprias pendentes/rejeitadas no topo, sem duplicar aprovadas
      final approvedIds = approved.map((r) => r.id).toSet();
      final myExtra = mine.where((r) => !approvedIds.contains(r.id)).toList();
      final merged = [...myExtra, ...approved];

      if (mounted) {
        setState(() {
          _reviews = merged;
          _myReviews = mine;
          _loadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  Future<void> _fetchSpaces(int parkId) async {
    try {
      final spaces = await SpaceRepository().fetchSpaces(parkId: parkId);
      if (mounted) setState(() { _spaces = spaces; _loadingSpaces = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingSpaces = false);
    }
  }

  // Verifica se o usuário já tem review ativa (pendente ou publicada) para este parque
  bool get _hasActiveReview =>
      _myReviews.any((r) => r.status == 'Pendente' || r.status == 'Publicada');

  void _showAddReviewBottomSheet(BuildContext context, int parkId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddReviewBottomSheet(
        parkId: parkId,
        onSuccess: () {
          _fetchReviews(parkId);
        },
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    const bannerH = 320.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<Park?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _Loading();
          }
          if (snap.hasError || snap.data == null) {
            return _ErrorView(
              error: snap.error ?? 'Parque não encontrado',
              onRetry: () => setState(() => _loadData()),
            );
          }

          final park = snap.data!;
          final heroUrl = _toImageUrl(park.heroImage);

          // Dispara carregamento das avaliações do parque se ainda não carregou
          if (_loadedPark?.id != park.id) {
            _loadedPark = park;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fetchReviews(park.id);
              _fetchSpaces(park.id);
            });
          }

          final double dynamicRating = _reviews.isNotEmpty
              ? (_reviews.map((r) => r.rating).reduce((a, b) => a + b) / _reviews.length)
              : (park.rating ?? 0.0);
          final int dynamicReviewCount = _reviews.isNotEmpty
              ? _reviews.length
              : 0;

          return CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _ParallaxHeader(
                  url: heroUrl,
                  favoriteId: widget.parkId,
                  onBack: () => context.pop(),
                  maxHeight: bannerH,
                ),
              ),
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -24),
                  child: _WhiteCard(
                    radiusTop: 24,
                    padding: const EdgeInsets.fromLTRB(25, 32, 25, 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nome + chip de rating
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                park.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: kBrandGreen,
                                  height: 1.10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _ChipRating(rating: dynamicRating),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Status + contagem de avaliações na mesma linha
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (park.status != null)
                              Row(
                                children: [
                                  const Icon(Icons.circle, size: 8, color: kStatusDotGreen),
                                  const SizedBox(width: 6),
                                  Text(
                                    park.status!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: kBrandGreen,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              )
                            else
                              const SizedBox.shrink(),
                            Text(
                              '$dynamicReviewCount avaliações',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: kDarkGray.withValues(alpha: .6),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Descrição com "Ler mais" (só se truncar)
                        if (park.description != null) ...[
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final style = GoogleFonts.poppins(
                                fontSize: 14,
                                height: 1.45,
                                color: kDarkGray.withValues(alpha: .9),
                              );
                              final tp = TextPainter(
                                text: TextSpan(text: park.description!, style: style),
                                maxLines: 3,
                                textDirection: TextDirection.ltr,
                              )..layout(maxWidth: constraints.maxWidth);
                              final overflows = tp.didExceedMaxLines;
                              return GestureDetector(
                                onTap: overflows
                                    ? () => setState(() => _descExpanded = !_descExpanded)
                                    : null,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      park.description!,
                                      maxLines: _descExpanded ? null : 3,
                                      overflow: _descExpanded
                                          ? TextOverflow.visible
                                          : TextOverflow.ellipsis,
                                      style: style,
                                    ),
                                    if (overflows) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        _descExpanded ? 'Ler menos' : 'Ler mais',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: kBrandGreen,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Botão Vem conhecer
                        SizedBox(
                          width: double.infinity,
                          child: GestureDetector(
                            onTap: () {
                              context.go(
                                AppRoutes.map,
                                extra: MapFocus(
                                  parkId: park.id,
                                  name: park.name,
                                  lat: park.latitude,
                                  lng: park.longitude,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: kBrandGreen,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Vem conhecer',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const Icon(Icons.place_outlined, color: Colors.white, size: 24),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // ── Descubra mais sobre o parque (só se houver espaços) ──
                        if (!_loadingSpaces && _spaces.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          Text(
                            'Descubra mais sobre o parque',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: kBrandGreen,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Diversão para todas as idades, do nascer ao pôr do sol.',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF121726),
                              height: 20 / 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 260,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _spaces.length,
                              itemBuilder: (_, i) => _SpaceCard(
                                space: _spaces[i],
                                toImageUrl: _toImageUrl,
                              ),
                            ),
                          ),
                        ],

                        // ── O que os visitantes acharam? ──────────────────────
                        const SizedBox(height: 32),
                        Text(
                          'O que os visitantes acharam?',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: kBrandGreen,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _loadingReviews
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(color: kBrandGreen),
                                ),
                              )
                            : _reviews.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Text(
                                      'Ainda não há avaliações para este parque. Seja o primeiro a avaliar!',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.grey.shade500,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  )
                                : SizedBox(
                                    height: 242,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _reviews.length,
                                      itemBuilder: (_, index) => _ReviewCard(
                                        review: _reviews[index],
                                        parkHeroUrl: heroUrl,
                                        toImageUrl: _toImageUrl,
                                      ),
                                    ),
                                  ),

                        // Botão Avaliar
                        const SizedBox(height: 24),
                        if (!_hasActiveReview)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: kBrandGreen, width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () async {
                                final logged = await AuthService.instance.isLogged();
                                if (!logged) {
                                  if (context.mounted) context.go('/tabs/user');
                                  return;
                                }
                                if (context.mounted) {
                                  _showAddReviewBottomSheet(context, park.id);
                                }
                              },
                              icon: const Icon(Icons.star_border, color: kBrandGreen, size: 22),
                              label: Text(
                                'Avaliar este parque',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: kBrandGreen,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ParallaxHeader extends SliverPersistentHeaderDelegate {
  _ParallaxHeader({
    required this.url,
    required this.favoriteId,
    required this.onBack,
    required this.maxHeight,
  });

  final String? url;
  final String favoriteId;
  final VoidCallback onBack;
  final double maxHeight;

  @override
  double get minExtent => kToolbarHeight + 16;
  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final topSafe = MediaQuery.of(context).padding.top + 12;

    // Calcula o border radius dinamicamente baseado no scroll.
    // É 24.0 quando expandido (shrinkOffset = 0) e vai para 0.0 quando totalmente colapsado.
    final double maxScroll = maxExtent - minExtent;
    final double currentRadius = maxScroll > 0
        ? (1.0 - (shrinkOffset / maxScroll).clamp(0.0, 1.0)) * 24.0
        : 24.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Imagem plana (sem border radius) por baixo
        if (url != null)
          Hero(
            tag: 'park_$favoriteId',
            child: CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.grey.shade200),
              errorWidget: (context, url, error) => Container(color: Colors.grey.shade200, child: const Icon(Icons.error)),
            ),
          )
        else
          Container(color: Colors.grey.shade200),
        
        // Pílula branca com rounded corners que sobrepõe a imagem na base do header
        if (currentRadius > 0)
          Positioned(
            bottom: -1.0,
            left: -1.0,
            right: -1.0,
            child: Container(
              height: currentRadius + 1.0,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(currentRadius)),
              ),
            ),
          ),

        Positioned(
          top: topSafe,
          left: 16,
          child: _CircleButton(icon: Icons.arrow_back_ios_new, onTap: onBack),
        ),
        Positioned(
          top: topSafe,
          right: 16,
          child: _CircleFavorite(favoriteId: favoriteId),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _ParallaxHeader oldDelegate) => true;
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Center(
        child: IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            minimumSize: const Size(40, 40),
            maximumSize: const Size(40, 40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: onTap,
          icon: Icon(icon, color: kBrandGreen, size: 20),
        ),
      ),
    );
  }
}

class _CircleFavorite extends StatelessWidget {
  const _CircleFavorite({required this.favoriteId});
  final String favoriteId;

  @override
  Widget build(BuildContext context) {
    // SizedBox 48×48 iguala o tap-target do IconButton.filled (shrinkWrap não aplica aqui)
    return SizedBox(
      width: 48,
      height: 48,
      child: Center(
        child: FavoriteButton(parkDocumentId: favoriteId, size: 40),
      ),
    );
  }
}

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.child, required this.padding, required this.radiusTop});
  final Widget child;
  final EdgeInsets padding;
  final double radiusTop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(radiusTop),
          topRight: Radius.circular(radiusTop),
        ),
      ),
      child: child,
    );
  }
}

class _ChipRating extends StatelessWidget {
  const _ChipRating({required this.rating});
  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: kBrandGreen, width: 1.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 17, color: kBrandGreen),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: kDarkGray,
            ),
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator(color: kBrandGreen));
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Erro ao carregar: $error'),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Tentar novamente')),
        ],
      ),
    );
  }
}

// ── Card de review ──────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, this.parkHeroUrl, required this.toImageUrl});

  final Review review;
  final String? parkHeroUrl;
  final String? Function(String?) toImageUrl;

  @override
  Widget build(BuildContext context) {
    final imgUrl = toImageUrl(review.midiaUrl) ?? parkHeroUrl;
    final hasText = review.text != null && review.text!.isNotEmpty;
    final hasTitle = review.title != null && review.title!.isNotEmpty;

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        width: 240,
        height: 230,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE8E8E8),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagem e Badges
              Stack(
                children: [
                  SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: imgUrl != null
                        ? CachedNetworkImage(
                            imageUrl: imgUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const ColoredBox(color: Color(0xFFE5EFE2)),
                            errorWidget: (_, __, ___) => const ColoredBox(
                              color: Color(0xFFE5EFE2),
                              child: Center(child: Icon(Icons.park, color: kBrandGreen, size: 36)),
                            ),
                          )
                        : const ColoredBox(
                            color: Color(0xFFE5EFE2),
                            child: Center(child: Icon(Icons.park, color: kBrandGreen, size: 36)),
                          ),
                  ),
                  // Rating Badge
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 14, color: kBrandGreen),
                          const SizedBox(width: 4),
                          Text(
                            review.rating.toDouble().toStringAsFixed(1),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: kDarkGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Conteúdo do Card
              SizedBox(
                height: 106,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Título
                      if (hasTitle) ...[
                        Text(
                          review.title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kDarkGray,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      // Texto + "Ler mais"
                      if (hasText) ...[
                        Text(
                          review.text!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: kDarkGray.withValues(alpha: .75),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Ler mais',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: kBrandGreen,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 8,
                              color: kBrandGreen,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewDetailSheet(review: review, parkHeroUrl: parkHeroUrl, toImageUrl: toImageUrl),
    );
  }
}

// ── Modal de detalhe da review ───────────────────────────────────────────────

class _ReviewDetailSheet extends StatelessWidget {
  const _ReviewDetailSheet({required this.review, this.parkHeroUrl, required this.toImageUrl});
  final Review review;
  final String? parkHeroUrl;
  final String? Function(String?) toImageUrl;

  String _shortName(String full) {
    final parts = full.trim().split(RegExp(r'\s+'));
    if (parts.length <= 2) return full;
    return '${parts.first} ${parts.last}';
  }

  @override
  Widget build(BuildContext context) {
    final imgUrl = toImageUrl(review.midiaUrl) ?? parkHeroUrl;
    final hasText = review.text != null && review.text!.isNotEmpty;
    final hasTitle = review.title != null && review.title!.isNotEmpty;
    final dateStr = review.createdAt != null
        ? '${review.createdAt!.day.toString().padLeft(2, '0')}/${review.createdAt!.month.toString().padLeft(2, '0')}/${review.createdAt!.year}'
        : null;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: EdgeInsets.zero,
                children: [
                  // Imagem
                  if (imgUrl != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      child: SizedBox(
                        height: 220,
                        width: double.infinity,
                        child: CachedNetworkImage(
                          imageUrl: imgUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const ColoredBox(color: Color(0xFFE5EFE2)),
                          errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFFE5EFE2)),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Rating
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kBrandGreen, width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 16, color: kBrandGreen),
                              const SizedBox(width: 4),
                              Text(review.rating.toDouble().toStringAsFixed(1),
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700, fontSize: 14, color: kDarkGray)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Título
                        if (hasTitle) ...[
                          Text(review.title!,
                              style: GoogleFonts.poppins(
                                  fontSize: 18, fontWeight: FontWeight.w700, color: kDarkGray)),
                          const SizedBox(height: 10),
                        ],
                        // Texto completo
                        if (hasText) ...[
                          Text(review.text!,
                              style: GoogleFonts.poppins(
                                  fontSize: 14, color: kDarkGray.withValues(alpha: .85), height: 1.55)),
                          const SizedBox(height: 20),
                        ],
                        const Divider(),
                        const SizedBox(height: 14),
                        // Info do usuário
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: kBrandGreen.withValues(alpha: .12),
                              child: Text(
                                review.displayName.isNotEmpty
                                    ? review.displayName[0].toUpperCase()
                                    : 'V',
                                style: GoogleFonts.poppins(
                                    fontSize: 16, fontWeight: FontWeight.w700, color: kBrandGreen),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_shortName(review.displayName),
                                    style: GoogleFonts.poppins(
                                        fontSize: 15, fontWeight: FontWeight.w600, color: kDarkGray)),
                                if (dateStr != null)
                                  Text('Avaliou em $dateStr',
                                      style: GoogleFonts.poppins(
                                          fontSize: 12, color: kDarkGray.withValues(alpha: .55))),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card de ponto de interesse ───────────────────────────────────────────────

class _SpaceCard extends StatelessWidget {
  const _SpaceCard({required this.space, required this.toImageUrl});
  final Space space;
  final String? Function(String?) toImageUrl;

  void _showFullImage(BuildContext context, String imgUrl) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: imgUrl,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imgUrl = toImageUrl(space.imageURL);
    return SizedBox(
      width: 282,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: imgUrl != null ? () => _showFullImage(context, imgUrl) : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: imgUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imgUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const ColoredBox(color: Color(0xFFE5EFE2)),
                          errorWidget: (_, __, ___) => Container(
                            color: const Color(0xFFE5EFE2),
                            child: const Center(
                              child: Icon(Icons.park_outlined, color: kBrandGreen, size: 40),
                            ),
                          ),
                        )
                      : Container(
                          color: const Color(0xFFE5EFE2),
                          child: const Center(
                            child: Icon(Icons.park_outlined, color: kBrandGreen, size: 40),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              space.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kDarkGray,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom sheet de adicionar review ────────────────────────────────────────

class _AddReviewBottomSheet extends StatefulWidget {
  const _AddReviewBottomSheet({required this.parkId, required this.onSuccess});
  final int parkId;
  final VoidCallback onSuccess;

  @override
  State<_AddReviewBottomSheet> createState() => _AddReviewBottomSheetState();
}

class _AddReviewBottomSheetState extends State<_AddReviewBottomSheet> {
  int _selectedRating = 0;
  final _titleController = TextEditingController();
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  bool _isUploadingPhoto = false;
  XFile? _selectedPhoto;
  String? _uploadedPhotoUrl;

  final _picker = ImagePicker();

  @override
  void dispose() {
    _titleController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final repo = context.read<ReviewsRepository>();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: kBrandGreen),
              title: Text('Câmera', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: kBrandGreen),
              title: Text('Galeria', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    final XFile? file;
    try {
      file = await _picker.pickImage(source: source, imageQuality: 80);
    } catch (e) {
      // Android pode lançar PlatformException (câmera indisponível,
      // 'already_active', ou perda do resultado se a Activity é recriada).
      if (mounted) {
        AppToast.show(context, 'Não foi possível abrir a câmera/galeria.',
            type: ToastType.error);
      }
      return;
    }
    if (file == null) return;

    setState(() {
      _selectedPhoto = file;
      _isUploadingPhoto = true;
      _uploadedPhotoUrl = null;
    });

    try {
      final url = await repo.uploadMedia(file.path);
      if (mounted) {
        setState(() {
          _uploadedPhotoUrl = url;
          _isUploadingPhoto = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        AppToast.show(context, 'Erro ao enviar foto.', type: ToastType.error);
      }
    }
  }

  void _removePhoto() => setState(() {
        _selectedPhoto = null;
        _uploadedPhotoUrl = null;
        _isUploadingPhoto = false;
      });

  Future<void> _submit() async {
    if (_selectedRating == 0) {
      AppToast.show(context, 'Selecione uma nota de 1 a 5 estrelas.', type: ToastType.warning);
      return;
    }
    if (_titleController.text.trim().isEmpty) {
      AppToast.show(context, 'Insira um título para a avaliação.', type: ToastType.warning);
      return;
    }
    if (_isUploadingPhoto) {
      AppToast.show(context, 'Aguarde o envio da foto.', type: ToastType.warning);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = context.read<ReviewsRepository>();
      final review = await repo.createReview(
        parkId: widget.parkId,
        rating: _selectedRating,
        authorName: _titleController.text.trim(),
        text: _commentController.text.trim(),
        midiaUrl: _uploadedPhotoUrl,
      );

      if (mounted) {
        if (review != null) {
          AppToast.show(
            context,
            'Avaliação publicada com sucesso!',
            type: ToastType.success,
          );
          widget.onSuccess();
          Navigator.pop(context);
        } else {
          AppToast.show(context, 'Erro ao enviar avaliação. Tente novamente.', type: ToastType.error);
        }
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('já enviou')
            ? 'Você já enviou uma avaliação para este parque.'
            : 'Erro ao enviar avaliação.';
        AppToast.show(context, msg, type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset + bottomSafe),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Vem explorar',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: kBrandGreen,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Encontre o parque perfeito para sua próxima aventura!',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            
            // Estrelas
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starNum = index + 1;
                final isSelected = starNum <= _selectedRating;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedRating = starNum;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      isSelected ? Icons.star : Icons.star_border,
                      size: 40,
                      color: isSelected ? const Color(0xFFFFB800) : Colors.grey.shade300,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // Título
            Text(
              'Título',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: kDarkGray,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'O que você está procurando?',
                hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFFAFBF6),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBrandGreen),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBrandGreen, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Comentário
            Text(
              'Comentário',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: kDarkGray,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'O que você está procurando?',
                hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFFAFBF6),
                contentPadding: const EdgeInsets.all(16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBrandGreen),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBrandGreen, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Foto (opcional)
            Text(
              'Foto',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: kDarkGray,
              ),
            ),
            const SizedBox(height: 8),
            if (_selectedPhoto == null)
              GestureDetector(
                onTap: _pickPhoto,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFBF6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBrandGreen, width: 1.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt_outlined, size: 32, color: Color(0xFF9BA3A0)),
                      const SizedBox(height: 8),
                      Text(
                        'Toque para adicionar foto',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF9BA3A0),
                        ),
                      ),
                      Text(
                        '(opcional)',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFFB0B8B5),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Row(
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(_selectedPhoto!.path),
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 72,
                            height: 72,
                            color: const Color(0xFFE5EFE2),
                            child: const Icon(Icons.image, color: kBrandGreen),
                          ),
                        ),
                      ),
                      if (_isUploadingPhoto)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isUploadingPhoto
                          ? 'Enviando foto...'
                          : _uploadedPhotoUrl != null
                              ? 'Foto pronta ✓'
                              : 'Aguardando upload...',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: _uploadedPhotoUrl != null ? kBrandGreen : Colors.grey,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _removePhoto,
                    icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                  ),
                ],
              ),

            const SizedBox(height: 24),

            // Botão Enviar
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: kBrandGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)))
                    : Text(
                        'Enviar avaliação',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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
