import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../routes/app_router.dart';
import '../services/auth_service.dart';
import '../services/favorites_service.dart';

class FavoriteButton extends StatefulWidget {
  const FavoriteButton({
    super.key,
    required this.parkDocumentId,
    this.size = 32,
  });

  final String parkDocumentId;
  final double size;

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool? _prevIsFav;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
    FavoritesService.instance.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    FavoritesService.instance.removeListener(_onServiceChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    if (!mounted) return;
    final isFav = FavoritesService.instance.isFavoriteByDoc(widget.parkDocumentId);
    _updateAnimation(isFav);
    setState(() {});
  }

  void _updateAnimation(bool isFav) {
    if (_prevIsFav == null) {
      if (_ctrl.duration != null && _ctrl.duration != Duration.zero) {
        _ctrl.value = isFav ? 1.0 : 0.0;
        _prevIsFav = isFav;
      }
      return;
    }
    if (isFav == _prevIsFav) return;
    _prevIsFav = isFav;
    if (isFav) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  void _onLottieLoaded(LottieComposition composition) {
    if (!mounted) return;
    _ctrl.duration = composition.duration;
    final isFav = FavoritesService.instance.isFavoriteByDoc(widget.parkDocumentId);
    _ctrl.value = isFav ? 1.0 : 0.0;
    _prevIsFav = isFav;
  }

  void _handleTap() {
    // Usuário não autenticado → mostra prompt de login (padrão Airbnb/Spotify)
    if (AuthService.instance.tokenSync == null) {
      _showLoginPrompt();
      return;
    }
    FavoritesService.instance.toggleByDocumentId(widget.parkDocumentId);
  }

  void _showLoginPrompt() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _LoginPromptSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFav = FavoritesService.instance.isFavoriteByDoc(widget.parkDocumentId);
    final isPending = FavoritesService.instance.isPending(widget.parkDocumentId);

    return GestureDetector(
      onTap: isPending ? null : _handleTap,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Lottie.asset(
          'assets/lottie/heart.json',
          controller: _ctrl,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          onLoaded: _onLottieLoaded,
          errorBuilder: (_, __, ___) => Icon(
            isFav ? Icons.favorite : Icons.favorite_border,
            color: isFav ? const Color(0xFFFF5A5F) : Colors.grey,
            size: widget.size * 0.6,
          ),
        ),
      ),
    );
  }
}

// ── Bottom sheet de prompt de login ──────────────────────────────────────────

class _LoginPromptSheet extends StatelessWidget {
  const _LoginPromptSheet();

  static const _green = Color(0xFF669340);
  static const _dark = Color(0xFF32384A);
  static const _gray = Color(0xFF8F959E);

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottomPadding),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(99),
            ),
          ),

          // Ícone
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_rounded, color: _green, size: 30),
          ),

          const SizedBox(height: 16),

          Text(
            'Salve seus parques favoritos',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Crie uma conta grátis e acesse seus\nparques favoritos a qualquer momento.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: _gray,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 28),

          // Botão principal — Criar conta
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                context.pop();
                context.go(AppRoutes.userRegister);
              },
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Criar conta grátis',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Botão secundário — Entrar
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                context.pop();
                context.go(AppRoutes.userLogin);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: _green,
                side: const BorderSide(color: _green),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Já tenho uma conta',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _green,
                ),
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Dispensar
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Agora não',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: _gray,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
