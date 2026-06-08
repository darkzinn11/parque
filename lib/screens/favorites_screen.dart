import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/favorites_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/park_repository.dart';
import '../widgets/favorite_button.dart'; 
import '../core/api/api_config.dart';

const kBrandGreen = Color(0xFF669340);
const kDarkGray = Color(0xFF32384A);
const kFavCardBg = Color(0xFFF7F7FC);
const kSubtitleColor = Color(0xFF121726);
const kFavCardTextColor = Color(0xFF121726);

class _FavParkItem {
  final String id;
  final String name;
  final String heroImage;

  const _FavParkItem({
    required this.id,
    required this.name,
    required this.heroImage,
  });
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool _isLoading = true;
  List<_FavParkItem> _favoriteParks = [];
  List<dynamic>? _allParksCache; // cache para não recarregar em cada toggle

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    FavoritesService.instance.addListener(_onFavoritesChanged);
  }

  @override
  void dispose() {
    FavoritesService.instance.removeListener(_onFavoritesChanged);
    super.dispose();
  }

  /// Chamado a cada notifyListeners() do FavoritesService.
  /// Usa o cache de parks — evita GET /parks em cada toggle.
  void _onFavoritesChanged() {
    if (!mounted) return;
    if (_allParksCache != null) {
      _filterFromCache();
    } else {
      _loadFavorites();
    }
  }

  void _filterFromCache() {
    final docIds = FavoritesService.instance.parkDocumentIds;
    final parks = (_allParksCache ?? [])
        .where((p) => docIds.contains(p.documentId)) // usa documentId, não id numérico
        .map((p) => _FavParkItem(
              id: p.documentId,
              name: p.name,
              heroImage: _toImageUrl(p.heroImage) ?? '',
            ))
        .toList();

    if (mounted) setState(() => _favoriteParks = parks);
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

  Future<void> _loadFavorites() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final repo = context.read<ParkRepository>();
      // Busca todos os parques uma única vez e guarda no cache
      _allParksCache = await repo.fetchAll();
      _filterFromCache();
    } catch (e) {
      debugPrint('❌ Erro ao carregar favoritos: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? _FavoritesShimmer()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, 
                children: [
                  const SizedBox(height: 16.0),
                  // Header Row with back arrow
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () => context.pop(),
                            behavior: HitTestBehavior.opaque,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                              child: Icon(
                                Icons.arrow_back_ios_new,
                                color: kBrandGreen,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          'Favoritos',
                          style: GoogleFonts.poppins(
                            color: kBrandGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24.0),
                  // Subtitle Left-Aligned
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      'Seus parques salvos em um só lugar.',
                      textAlign: TextAlign.center, 
                      style: GoogleFonts.poppins(
                        fontSize: 14,              
                        fontWeight: FontWeight.w400, 
                        color: kSubtitleColor,     
                        height: 1.428,             
                      ),
                    ),
                  ),
                  const SizedBox(height: 32.0),
                  Expanded(
                    child: _favoriteParks.isEmpty
                        ? Center( 
                            child: Text(
                              'Você ainda não favoritou nada',
                              style: GoogleFonts.poppins(
                                color: kDarkGray.withValues(alpha: 0.35),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadFavorites,
                            child: GridView.builder( 
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2, 
                                mainAxisSpacing: 20,
                                crossAxisSpacing: 20,
                                childAspectRatio: 0.80, 
                              ),
                              itemCount: _favoriteParks.length,
                              itemBuilder: (context, index) {
                                return _FavoriteGridCard(park: _favoriteParks[index])
                                    .animate(
                                      delay: Duration(milliseconds: 60 * index),
                                    )
                                    .fadeIn(duration: 300.ms)
                                    .slideY(
                                      begin: 0.2,
                                      end: 0,
                                      curve: Curves.easeOut,
                                    );
                              },
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _FavoriteGridCard extends StatelessWidget {
  const _FavoriteGridCard({required this.park});
  final _FavParkItem park; 

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/tabs/home/park/${park.id}'),
      child: Container(
        padding: const EdgeInsets.all(8.0), 
        decoration: BoxDecoration(
          color: kFavCardBg, 
          borderRadius: BorderRadius.circular(18.1), 
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF092500).withValues(alpha: 0.12),
              blurRadius: 13.575,
              offset: const Offset(0, 4.525),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 113.125, 
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9.05), 
                    child: (park.heroImage.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: park.heroImage,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const ColoredBox(color: Color(0xFFEFEFEF)),
                            errorWidget: (context, url, error) => const ColoredBox(color: Color(0xFFEFEFEF), child: Icon(Icons.error)),
                          )
                        : const ColoredBox(color: Color(0xFFEFEFEF)),
                  ),
                  Positioned(
                    right: 9, 
                    top: 9,
                    child: FavoriteButton(parkDocumentId: park.id, size: 30),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8.0), 
            Expanded(
              child: Text(
                park.name,
                maxLines: 2, 
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins( 
                  fontSize: 12,              
                  fontWeight: FontWeight.w700, 
                  color: kFavCardTextColor,    
                  height: 1.2,                 
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _FavoritesShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8EDE4),
      highlightColor: const Color(0xFFF5F8F2),
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          childAspectRatio: 0.80,
        ),
        itemCount: 4,
        itemBuilder: (_, __) => ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(color: Colors.white),
        ),
      ),
    );
  }
}
