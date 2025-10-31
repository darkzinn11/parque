// lib/screens/park_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../routes/app_router.dart';
import '../data/models/map_focus.dart';

import '../data/models/park.dart';
import '../data/park_repository.dart';
import '../data/models/review.dart';
import '../data/reviews_repository.dart';

import '../services/favorites_service.dart';
import '../widgets/favorite_button.dart';

// ======= CONFIG =======
const String kStrapiBaseUrl = 'http://192.168.15.17:1337';
const String kParksCollection = 'parks';
const String kReviewsCollection = 'reviews';

const String? kApiToken = null;

const kBrandGreen = Color(0xFF669340);
const kDarkGray = Color(0xFF32384A);

class ParkDetailScreen extends StatefulWidget {
  const ParkDetailScreen({
    super.key,
    required this.parkId,
    this.repository,
  });

  final String parkId;
  final ParkRepository? repository;

  @override
  State<ParkDetailScreen> createState() => _ParkDetailScreenState();
}

class _ParkDetailScreenState extends State<ParkDetailScreen> {
  Park? _park;
  List<Review> _reviews = [];
  bool _loading = true;
  String? _error;

  ParkRepository get _repo =>
      widget.repository ??
      StrapiParkRepository(
        baseUrl: kStrapiBaseUrl,
        collection: kParksCollection,
        staticToken: kApiToken,
      );
  
  ReviewsRepository get _reviewsRepo =>
      StrapiReviewsRepository(
        baseUrl: kStrapiBaseUrl,
        collection: kReviewsCollection,
        staticToken: kApiToken,
      );

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await FavoritesService.instance.init();
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final park = await _repo.fetchBySlug(widget.parkId);
      List<Review> revs = [];
      if (park != null) {
        // Busca de reviews REATIVADA com o novo repositório
        revs = await _reviewsRepo.fetchForPark(park.id);
      }
      if (!mounted) return;
      setState(() {
        _park = park;
        _reviews = revs;
        _loading = false;
        if (park == null) _error = 'Parque não encontrado.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _goToMap() {
    final p = _park;
    if (p == null) return;
    context.go(
      AppRoutes.map,
      extra: MapFocus(
        parkId: p.id,
        name: p.name,
        lat: p.latitude,
        lng: p.longitude,
      ),
    );
  }

  void _openNewReviewSheet() {
    if (_park == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => NewReviewSheet(
        onSubmit: (rating, text, author) async {
          try {
            final created = await _reviewsRepo.createReview(
              parkId: _park!.id,
              rating: rating,
              text: text,
              authorName: author,
            );
            if (created != null) {
              setState(() => _reviews = [created, ..._reviews]);
              if (mounted) Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Avaliação enviada!')),
              );
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Não foi possível enviar: $e')),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kBrandGreen))
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : _park == null
                  ? const _EmptyView()
                  : _DetailBody(
                      park: _park!,
                      reviews: _reviews,
                      onAddReview: _openNewReviewSheet,
                      onGo: _goToMap,
                    ),
    );
  }
}

// O restante do arquivo (toda a parte de UI) permanece o mesmo
class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.park,
    required this.reviews,
    required this.onAddReview,
    required this.onGo,
  });

  final Park park;
  final List<Review> reviews;
  final VoidCallback onAddReview;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    final imageUrl = park.heroImage;
    final rating = park.rating ?? 0.0;
    final reviewsCount = reviews.length;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          pinned: false,
          expandedHeight: 360,
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl != null && imageUrl.trim().isNotEmpty)
                  Positioned.fill(
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const ColoredBox(color: Color(0xFFEFEFEF)),
                    ),
                  )
                else
                  const ColoredBox(color: Color(0xFFEFEFEF)),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.35),
                          Colors.transparent,
                          Colors.black.withOpacity(0.45),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          leading: _CircleIconButton(
            icon: Icons.arrow_back,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          actions: [
            const SizedBox(width: 6),
            FavoriteButton(parkId: park.id.toString(), size: 40),
            const SizedBox(width: 12),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 24,
                    spreadRadius: 0,
                    offset: const Offset(0, 12),
                    color: Colors.black.withOpacity(0.10),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((park.status ?? '').isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.circle, size: 8, color: Colors.green),
                        const SizedBox(width: 6),
                        Text(
                          park.status!.trim(),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          park.name,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: kBrandGreen,
                            height: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _RatingPill(value: rating),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$reviewsCount reviews',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: kDarkGray.withOpacity(.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if ((park.description ?? '').isNotEmpty)
                    _ExpandableText(
                      text: park.description!,
                      trimLines: 4,
                      readMoreText: ' Leia mais',
                      readLessText: ' Mostrar menos',
                    ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.public_rounded, color: Colors.white),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kBrandGreen,
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: onGo,
                          label: Text(
                            'Vem conhecer',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Material(
                          color: const Color(0xFFEFF4EC),
                          child: InkWell(
                            onTap: onGo,
                            child: const SizedBox(
                              width: 46,
                              height: 46,
                              child: Icon(Icons.place_rounded, color: kBrandGreen),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Avaliações',
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: kDarkGray)),
                TextButton.icon(
                  onPressed: onAddReview,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Escrever avaliação'),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 200,
            child: _ReviewsLane(reviews: reviews),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton(
      {required this.icon, required this.onTap, this.size = 44});
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.12),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, color: kDarkGray),
        ),
      ),
    );
  }
}

class _RatingPill extends StatelessWidget {
  const _RatingPill({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBrandGreen, width: 1.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: kBrandGreen, size: 18),
          const SizedBox(width: 6),
          Text(
            value.toStringAsFixed(1),
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: kBrandGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableText extends StatefulWidget {
  const _ExpandableText({
    required this.text,
    this.trimLines = 4,
    this.readMoreText = ' Leia mais',
    this.readLessText = ' Mostrar menos',
  });

  final String text;
  final int trimLines;
  final String readMoreText;
  final String readLessText;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final baseStyle = GoogleFonts.poppins(
      fontSize: 14,
      height: 1.5,
      color: kDarkGray.withOpacity(.95),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: baseStyle),
          maxLines: widget.trimLines,
          textDirection: TextDirection.ltr,
          ellipsis: '…',
        )..layout(maxWidth: constraints.maxWidth);

        final overflow = painter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: baseStyle,
              maxLines: _expanded ? null : widget.trimLines,
              overflow:
                  _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            if (overflow || _expanded)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _expanded ? widget.readLessText : widget.readMoreText,
                    style: baseStyle.copyWith(
                      color: kBrandGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ReviewsLane extends StatelessWidget {
  const _ReviewsLane({required this.reviews});
  final List<Review> reviews;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return Center(
        child: Text('Seja o primeiro a avaliar!',
            style:
                GoogleFonts.poppins(fontSize: 13, color: Colors.black54)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      itemCount: reviews.length,
      itemBuilder: (_, i) {
        final r = reviews[i];
        return SizedBox(
          width: 260,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: const Color(0xFFF4F6F8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                            radius: 12, child: Icon(Icons.person, size: 14)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            r.authorName?.isNotEmpty == true
                                ? r.authorName!
                                : 'Visitante',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: kDarkGray,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.star_rounded,
                            size: 16, color: Color(0xFFFFC107)),
                        Text('${r.rating}.0',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      r.text?.isNotEmpty == true
                          ? r.text!
                          : 'Sem comentário.',
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        height: 1.35,
                        color: kDarkGray.withOpacity(.9),
                      ),
                    ),
                    if (r.createdAt != null) ...[
                      const SizedBox(height: 6),
                      Text('${r.createdAt}',
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: Colors.black45)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(width: 12),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: Colors.redAccent, size: 42),
            const SizedBox(height: 12),
            Text('Não foi possível carregar o parque.',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kBrandGreen),
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

class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Parque não encontrado.',
          style: GoogleFonts.poppins(fontSize: 14)),
    );
  }
}

class NewReviewSheet extends StatefulWidget {
  const NewReviewSheet({super.key, required this.onSubmit});
  final Future<void> Function(int rating, String text, String? authorName)
      onSubmit;

  @override
  State<NewReviewSheet> createState() => _NewReviewSheetState();
}

class _NewReviewSheetState extends State<NewReviewSheet> {
  int _rating = 5;
  final _text = TextEditingController();
  final _author = TextEditingController();
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sua avaliação',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (i) {
              final v = i + 1;
              final filled = v <= _rating;
              return IconButton(
                onPressed: () => setState(() => _rating = v),
                icon: Icon(Icons.star_rounded,
                    size: 28,
                    color: filled
                        ? const Color(0xFFFFC107)
                        : Colors.black26),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                    width: 36, height: 36),
              );
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _author,
            decoration: const InputDecoration(
              labelText: 'Seu nome (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _text,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Escreva um comentário (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kBrandGreen),
              onPressed: _sending
                  ? null
                  : () async {
                      setState(() => _sending = true);
                      try {
                        await widget.onSubmit(
                          _rating,
                          _text.text.trim(),
                          _author.text.trim().isEmpty
                              ? null
                              : _author.text.trim(),
                        );
                        if (mounted) Navigator.pop(context);
                      } finally {
                        if (mounted) setState(() => _sending = false);
                      }
                    },
              child: Text(_sending ? 'Enviando...' : 'Enviar avaliação',
                  style: const TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}