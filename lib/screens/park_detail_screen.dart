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
import '../data/models/park.dart';
import '../data/models/review.dart';
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
  List<Review> _reviews = [];     // aprovadas
  List<Review> _myReviews = [];   // próprias (todos os status)
  bool _loadingReviews = true;
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

  // Verifica se o usuário já tem review ativa (pendente ou aprovada) para este parque
  bool get _hasActiveReview =>
      _myReviews.any((r) => r.status == 'Pendente' || r.status == 'Aprovada');

  void _showAddReviewBottomSheet(BuildContext context, int parkId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                  offset: const Offset(0, -16),
                  child: _WhiteCard(
                    radiusTop: 16,
                    padding: const EdgeInsets.fromLTRB(25, 32, 25, 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
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
                        const SizedBox(height: 4),
                        Text(
                          '$dynamicReviewCount reviews',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: kDarkGray.withValues(alpha: .6),
                          ),
                        ),
                        const SizedBox(height: 12),
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
                          ),
                        const SizedBox(height: 16),
                        if (park.description != null) ...[
                          Text(
                            park.description!,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              height: 1.45,
                              color: kDarkGray.withValues(alpha: .9),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
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

                        // Seção de Avaliações
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
                                    height: 210,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _reviews.length,
                                      itemBuilder: (context, index) {
                                        final review = _reviews[index];
                                        return _ReviewCard(
                                          review: review,
                                          parkHeroUrl: heroUrl,
                                        );
                                      },
                                    ),
                                  ),

                        // Botão Avaliar este parque — oculto se já tem review ativa
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

    return Stack(
      fit: StackFit.expand,
      children: [
        if (url != null)
          Hero(
            tag: 'park_${favoriteId}',
            child: CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.grey.shade200),
              errorWidget: (context, url, error) => Container(color: Colors.grey.shade200, child: const Icon(Icons.error)),
            ),
          )
        else
          Container(color: Colors.grey.shade200),
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
    return IconButton.filled(
      style: IconButton.styleFrom(backgroundColor: Colors.white),
      onPressed: onTap,
      icon: Icon(icon, color: kBrandGreen, size: 20),
    );
  }
}

class _CircleFavorite extends StatelessWidget {
  const _CircleFavorite({required this.favoriteId});
  final String favoriteId;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: FavoriteButton(parkDocumentId: favoriteId, size: 28),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: kBrandLightGreen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 16, color: kBrandGreen),
          const SizedBox(width: 4),
          Text(rating.toStringAsFixed(1), style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13)),
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

// ── Card de review com badge de status ──────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, this.parkHeroUrl});

  final Review review;
  final String? parkHeroUrl;

  @override
  Widget build(BuildContext context) {
    final isPending = review.isPending;
    final isRejected = review.isRejected;
    final hasMidia = review.midiaUrl != null && review.midiaUrl!.isNotEmpty;

    return Container(
      width: 250,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBF6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending
              ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
              : isRejected
                  ? Colors.grey.shade300
                  : const Color(0xFFE5EFE2),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge de status (só para review própria não aprovada)
            if (isPending || isRejected)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                color: isPending
                    ? const Color(0xFFFFFBEB)
                    : const Color(0xFFF5F5F5),
                child: Row(
                  children: [
                    Icon(
                      isPending ? Icons.schedule : Icons.cancel_outlined,
                      size: 12,
                      color: isPending
                          ? const Color(0xFFF59E0B)
                          : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPending ? 'Em análise' : 'Não publicada',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isPending
                            ? const Color(0xFFF59E0B)
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            // Imagem: foto da review (se tiver) ou imagem do parque
            Container(
              height: 80,
              width: double.infinity,
              color: const Color(0xFFE5EFE2),
              child: hasMidia
                  ? CachedNetworkImage(
                      imageUrl: review.midiaUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const ColoredBox(color: Color(0xFFE5EFE2)),
                      errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported, color: kBrandGreen),
                    )
                  : parkHeroUrl != null
                      ? CachedNetworkImage(imageUrl: parkHeroUrl!, fit: BoxFit.cover)
                      : const Icon(Icons.park, color: kBrandGreen, size: 36),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.authorName ?? 'Sem Título',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kDarkGray,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      review.text ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: kDarkGray.withValues(alpha: .7),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: kBrandLightGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, size: 12, color: kBrandGreen),
                          const SizedBox(width: 4),
                          Text(
                            review.rating.toDouble().toStringAsFixed(1),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              color: kDarkGray,
                            ),
                          ),
                        ],
                      ),
                    ),
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

    final file = await _picker.pickImage(source: source, imageQuality: 80);
    if (file == null) return;

    setState(() {
      _selectedPhoto = file;
      _isUploadingPhoto = true;
      _uploadedPhotoUrl = null;
    });

    try {
      final repo = context.read<ReviewsRepository>();
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
            'Avaliação enviada! Será publicada após análise.',
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

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
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
                  borderSide: const BorderSide(color: Color(0xFFE5EFE2)),
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
                  borderSide: const BorderSide(color: Color(0xFFE5EFE2)),
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
              OutlinedButton.icon(
                onPressed: _pickPhoto,
                style: OutlinedButton.styleFrom(
                  foregroundColor: kBrandGreen,
                  side: const BorderSide(color: Color(0xFFE5EFE2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.camera_alt_outlined, size: 20),
                label: Text(
                  'Adicionar foto (opcional)',
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
              )
            else
              Row(
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          _selectedPhoto!.path.startsWith('http')
                              ? _selectedPhoto!.path
                              : _selectedPhoto!.path,
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
