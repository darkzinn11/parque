import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../data/models/app_notification.dart';
import '../providers/notification_provider.dart';

const _green = Color(0xFF669340);
const _dark = Color(0xFF32384A);
const _lightGray = Color(0xFF8F959E);

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

  // Group notifications chronologically by relative day
  Map<String, List<AppNotification>> _groupNotifications(List<AppNotification> list) {
    final Map<String, List<AppNotification>> groups = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var n in list) {
      final nDate = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
      final diffDays = today.difference(nDate).inDays;

      String category;
      if (diffDays == 0) {
        category = 'Hoje';
      } else if (diffDays == 1) {
        category = 'Ontem';
      } else if (diffDays > 1 && diffDays <= 7) {
        category = '$diffDays dias atrás';
      } else {
        category = 'Mais antigas';
      }

      groups.putIfAbsent(category, () => []).add(n);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final notifications = provider.notifications;

    final grouped = _groupNotifications(notifications);
    final List<Widget> listItems = [];

    grouped.forEach((category, items) {
      // Add category section header
      listItems.add(
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 8),
          child: Text(
            category,
            style: GoogleFonts.poppins(
              color: _green,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );

      // Add items for this category
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        listItems.add(
          _NotificationCard(
            key: ValueKey(item.id),
            notification: item,
            onDelete: () => provider.delete(item.id),
            onTap: item.deeplink != null
                ? () => context.push(item.deeplink!)
                : null,
          ),
        );

        // Divider between items of the same group
        if (i < items.length - 1) {
          listItems.add(
            const Padding(
              padding: EdgeInsets.only(left: 60), // Align with start of text (48 icon width + 12 gap)
              child: Divider(
                color: Color(0xFFF1F5F9),
                height: 1,
                thickness: 1,
              ),
            ),
          );
        }
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _green, size: 20),
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
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: listItems,
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
            child: Text('Cancelar',
                style: GoogleFonts.poppins(color: _lightGray)),
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
    // Determine icon based on notification type and content
    IconData iconData = Icons.event_outlined;
    if (notification.type == 'reservation_status') {
      if (notification.title.toLowerCase().contains('cancel') ||
          notification.body.toLowerCase().contains('cancel')) {
        iconData = Icons.event_busy_outlined;
      } else {
        iconData = Icons.event_available_outlined;
      }
    } else if (notification.type == 'event_request_status' || notification.type == 'event') {
      iconData = Icons.celebration_outlined;
    } else if (notification.type == 'alert') {
      iconData = Icons.info_outline;
    } else {
      // General/fallback checks
      final t = notification.title.toLowerCase();
      if (t.contains('lembrete') || t.contains('agenda')) {
        iconData = Icons.access_time_rounded;
      } else if (t.contains('cancel')) {
        iconData = Icons.event_busy_outlined;
      } else {
        iconData = Icons.notifications_none_rounded;
      }
    }

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
      ),
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.black.withValues(alpha: 0.02),
        highlightColor: Colors.black.withValues(alpha: 0.01),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Circular icon with overlapping status dot
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9), // Soft slate background
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      iconData,
                      color: const Color(0xFF1E293B), // Dark slate icon
                      size: 22,
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: notification.isRead
                              ? const Color(0xFFCBD5E1) // Gray dot for read
                              : const Color(0xFF10B981), // Green dot for unread
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Text Content
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
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A), // Dark slate title
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _relativeTime(notification.createdAt),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF94A3B8), // Muted date color
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF475569), // Secondary text color
                        height: 1.4,
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

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min atrás';
    if (diff.inHours < 24) return '${diff.inHours}h atrás';
    if (diff.inDays == 1) return 'ontem';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString().substring(2);
    return '$d/$m/$y';
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
            child: const Icon(Icons.notifications_none_rounded,
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
