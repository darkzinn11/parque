// lib/screens/favorites_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/favorites_service.dart'; // Importa o serviço
import '../data/park_repository.dart';      // Importa o repositório
import '../data/models/park.dart';      // Importa o modelo Park
import '../widgets/favorite_button.dart';  // Importa o botão

const kBrandGreen = Color(0xFF669340);
const kDarkGray = Color(0xFF32384A);

// Configurações do Strapi
const String kStrapiBaseUrl = 'http://192.168.15.12:1337';
const String? kStrapiStaticToken = null;

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  // Repositório de parques
  final ParkRepository _repo = StrapiParkRepository(
    baseUrl: kStrapiBaseUrl,
    collection: 'parks', 
    staticToken: kStrapiStaticToken,
  );

  bool _isLoading = true;
  List<Park> _favoriteParks = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    // Ouve por mudanças
    FavoritesService.instance.addListener(_loadFavorites);
  }

  @override
  void dispose() {
    FavoritesService.instance.removeListener(_loadFavorites);
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    // Pega os IDs do serviço
    final docIds = FavoritesService.instance.parkDocumentIds;

    if (docIds.isEmpty) {
      if (!mounted) return;
      setState(() {
        _favoriteParks = [];
        _isLoading = false;
      });
      return;
    }

    try {
      // Busca os parques usando a lista de IDs
      final parks = await _repo.fetchByDocumentIds(docIds.toList());

      if (!mounted) return;
      setState(() {
        _favoriteParks = parks;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint('❌ Erro ao carregar favoritos: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Meus Favoritos',
          style: GoogleFonts.poppins(
            color: kDarkGray,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kBrandGreen))
          : _favoriteParks.isEmpty
              ? Center( 
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_border, size: 64, color: kDarkGray.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text(
                        'Você ainda não tem favoritos.',
                        style: GoogleFonts.poppins(
                          color: kDarkGray.withOpacity(0.5),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated( 
                  padding: const EdgeInsets.all(20),
                  itemCount: _favoriteParks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 20),
                  itemBuilder: (context, index) {
                    return _FavoriteCard(park: _favoriteParks[index]);
                  },
                ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({required this.park});
  final Park park;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/tabs/home/park/${park.documentId}'),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: SizedBox(
                width: 100,
                height: 100,
                child: (park.heroImage != null && park.heroImage!.isNotEmpty)
                    ? Image.network(
                        park.heroImage!, 
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: Colors.grey[100]),
                      )
                    : Container(color: Colors.grey[100]),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      park.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: kDarkGray,
                        height: 1.2,
                      ),
                    ),
                    if (park.status != null && park.status!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.circle, size: 8, color: kBrandGreen),
                          const SizedBox(width: 6),
                          Text(
                            park.status!,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: kDarkGray.withOpacity(0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: FavoriteButton(parkDocumentId: park.documentId),
            ),
          ],
        ),
      ),
    );
  }
}