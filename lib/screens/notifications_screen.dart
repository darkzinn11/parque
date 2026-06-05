import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../data/models/app_notification.dart';
import '../providers/notification_provider.dart';

const _green = Color(0xFF669340);
const _dark = Color(0xFF32384A);
const _lightGray = Color(0xFF8F959E);
const _cardBg = Color(0xFFF9FAE8);
const _orange = Color(0xFFE07B39);

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationProvider>().markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final notifications = provider.notifications;

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
          'Notificações',
          style: GoogleFonts.poppins(
            color: _green,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          if (notifications.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClear(context, provider),
              child: Text(
                'Limpar',
                style: GoogleFonts.poppins(
                  color: _green,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final n = notifications[i];
                return _NotificationCard(
                  key: ValueKey(n.id),
                  notification: n,
                  onDelete: () => provider.delete(n.id),
                  onTap: n.deeplink != null
                      ? () => context.push(n.deeplink!)
                      : null,
                );
              },
            ),
    );
  }

  Future<void> _confirmClear(
      BuildContext context, NotificationProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Limpar notificações',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700, color: _dark, fontSize: 16),
        ),
        content: Text(
          'Remover todas as notificações?',
          style: GoogleFonts.poppins(fontSize: 14, color: _lightGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(color: _lightGray),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Limpar', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
    if (confirmed == true) provider.clearAll();
  }
}

// ─── Card ──────────────────────────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    super.key,
    required this.notification,
    required this.onDelete,
    this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ícone por tipo
            _TypeIcon(type: notification.type),
            const SizedBox(width: 12),

            // Conteúdo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _dark,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Ponto de não-lido + tempo
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!notification.isRead)
                            Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.only(right: 4, top: 4),
                              decoration: const BoxDecoration(
                                color: _green,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Text(
                            _relativeTime(notification.createdAt),
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: _lightGray),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: _lightGray,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (onTap != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Ver detalhes →',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _green,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Lixeira
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(Icons.delete_outline,
                  color: Color(0xFFE53935), size: 20),
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'há ${diff.inHours}h';
    if (diff.inDays == 1) return 'ontem';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m';
  }
}

// ─── Ícone por tipo ────────────────────────────────────────────────────────────

class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (type) {
      'reservation_status' => (Icons.calendar_today_outlined, _green),
      'event' => (Icons.event_outlined, _orange),
      _ => (Icons.campaign_outlined, _lightGray),
    };

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

// ─── Estado vazio ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_none_outlined,
                size: 40, color: _green),
          ),
          const SizedBox(height: 20),
          Text(
            'Nenhuma notificação ainda',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _dark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Quando houver novidades,\naparecerão aqui.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 13, color: _lightGray),
          ),
        ],
      ),
    );
  }
}
