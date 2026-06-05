// lib/screens/reservations/spaces_catalog_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../../data/models/space.dart';
import '../../data/repositories/space_repository.dart';
import '../../core/api/api_config.dart';

const _green = Color(0xFF669340);
const _dark = Color(0xFF32384A);
const _lightGray = Color(0xFF8F959E);

class SpacesCatalogScreen extends StatefulWidget {
  const SpacesCatalogScreen({super.key, required this.parkId});
  final int parkId;

  @override
  State<SpacesCatalogScreen> createState() => _SpacesCatalogScreenState();
}

class _SpacesCatalogScreenState extends State<SpacesCatalogScreen> {
  final _repository = SpaceRepository();
  bool _isLoading = true;
  List<Space> _filteredSpaces = [];

  final List<String> _categories = [
    'Quadras',
    'Áreas de Pique-nique',
    'Palcos',
    'Auditórios',
    'Trilhas Guiadas',
    'Playgrounds',
    'Campos'
  ];

  // Map user-friendly category labels to API keys
  final Map<String, String> _categoryApiMap = {
    'Quadras': 'quadras',
    'Áreas de Pique-nique': 'piquenique',
    'Palcos': 'palcos',
    'Auditórios': 'auditorios',
    'Trilhas Guiadas': 'trilhas',
    'Playgrounds': 'playgrounds',
    'Campos': 'campos'
  };

  int _selectedCategoryIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadSpaces();
  }

  Future<void> _loadSpaces() async {
    setState(() => _isLoading = true);
    final selectedCategoryKey = _categoryApiMap[_categories[_selectedCategoryIndex]];
    final spaces = await _repository.fetchSpaces(
      category: selectedCategoryKey,
      parkId: widget.parkId,
    );
    
    if (mounted) {
      setState(() {
        _filteredSpaces = spaces;
        _isLoading = false;
      });
    }
  }

  String? _toImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    final baseUrl = ApiConfig.baseUrl.replaceAll('/api/v1', '');
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$baseUrl/$cleanPath';
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
          icon: const Icon(Icons.arrow_back_ios_new, color: _green),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Reserve seu espaço',
          style: GoogleFonts.poppins(
            color: _green,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Subtítulo descritivo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Text(
              'Escolha, agende e aproveite os parques de forma simples e rápida.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: _lightGray,
                height: 1.4,
              ),
            ),
          ),

          // Categorias Horizontais
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final isSelected = index == _selectedCategoryIndex;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      if (_selectedCategoryIndex != index) {
                        setState(() {
                          _selectedCategoryIndex = index;
                        });
                        _loadSpaces();
                      }
                    },
                    borderRadius: BorderRadius.circular(19),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? _green : Colors.white,
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(
                          color: _green,
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        _categories[index],
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? Colors.white : _green,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Grid de Espaços
          Expanded(
            child: _isLoading
                ? _buildShimmerGrid()
                : _filteredSpaces.isEmpty
                    ? _buildEmptyState()
                    : GridView.builder(
                        padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.82,
                        ),
                        itemCount: _filteredSpaces.length,
                        itemBuilder: (context, index) {
                          final space = _filteredSpaces[index];
                          return _SpaceGridCard(
                            space: space,
                            imageUrl: _toImageUrl(space.imageURL),
                            onTap: () => context.push('/tabs/home/reservas/espaco/${space.id}'),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[100]!,
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.82,
        ),
        itemCount: 4,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_seat_outlined, size: 48, color: _lightGray.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'Nenhum espaço disponível',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _dark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Não encontramos espaços ativos nesta categoria no momento.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: _lightGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpaceGridCard extends StatefulWidget {
  const _SpaceGridCard({
    required this.space,
    required this.imageUrl,
    required this.onTap,
  });

  final Space space;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  State<_SpaceGridCard> createState() => _SpaceGridCardState();
}

class _SpaceGridCardState extends State<_SpaceGridCard> {

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Stack
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: widget.imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: widget.imageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: Colors.grey[100]),
                              errorWidget: (_, __, ___) => Container(
                                color: Colors.grey[100],
                                child: const Icon(Icons.image_not_supported, color: Colors.grey),
                              ),
                            )
                          : Container(color: Colors.grey[100]),
                    ),
                  ),
                ],
              ),
            ),
            // Details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.space.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                      height: 1.3,
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
