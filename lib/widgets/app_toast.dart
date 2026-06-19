import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum ToastType { success, error, warning, info }

class AppToast {
  static OverlayEntry? _current;

  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    _current?.remove();
    _current = null;

    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        message: message,
        type: type,
        duration: duration,
        onDismissed: () {
          entry.remove();
          if (_current == entry) _current = null;
        },
      ),
    );

    _current = entry;
    overlay.insert(entry);
  }
}

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismissed,
  });

  final String message;
  final ToastType type;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 260),
    );

    _slide = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );

    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.6)),
    );

    _ctrl.forward();

    Future.delayed(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 20,
      right: 20,
      // Acima da bottom bar (64px) + safe area
      bottom: 64 + bottomPadding + 12,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, _slide.value),
          child: Opacity(opacity: _fade.value, child: child),
        ),
        child: GestureDetector(
          onTap: _dismiss,
          child: _ToastCard(message: widget.message, type: widget.type),
        ),
      ),
    );
  }
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({required this.message, required this.type});

  final String message;
  final ToastType type;

  static const _configs = {
    ToastType.success: _ToastConfig(
      bg: Color(0xFFEEF7EC),
      border: Color(0xFF669340),
      icon: Icons.check_circle_rounded,
      iconColor: Color(0xFF669340),
    ),
    ToastType.error: _ToastConfig(
      bg: Color(0xFFFFF0F0),
      border: Color(0xFFE53935),
      icon: Icons.cancel_rounded,
      iconColor: Color(0xFFE53935),
    ),
    ToastType.warning: _ToastConfig(
      bg: Color(0xFF2C2C2E),
      border: Color(0xFF2C2C2E),
      icon: Icons.info_outline_rounded,
      iconColor: Color(0xFFAAAAAA),
      textColor: Colors.white,
    ),
    ToastType.info: _ToastConfig(
      bg: Color(0xFFF0F7FF),
      border: Color(0xFF3B82F6),
      icon: Icons.info_rounded,
      iconColor: Color(0xFF3B82F6),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final cfg = _configs[type]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cfg.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cfg.border.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: cfg.border.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(cfg.icon, color: cfg.iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cfg.textColor,
                height: 1.35,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToastConfig {
  const _ToastConfig({
    required this.bg,
    required this.border,
    required this.icon,
    required this.iconColor,
    this.textColor = const Color(0xFF32384A),
  });

  final Color bg;
  final Color border;
  final IconData icon;
  final Color iconColor;
  final Color textColor;
}
