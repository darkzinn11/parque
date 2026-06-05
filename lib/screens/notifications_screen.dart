import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/app_notification.dart';
import '../providers/notification_provider.dart';

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
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          if (notifications.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClear(context, provider),
              child: const Text('Limpar tudo'),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 72),
              itemBuilder: (context, i) {
                final n = notifications[i];
                return _NotificationTile(
                  key: ValueKey(n.id),
                  notification: n,
                  onDismissed: () => provider.delete(n.id),
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
        title: const Text('Limpar notificações'),
        content: const Text('Remover todas as notificações?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (confirmed == true) provider.clearAll();
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    super.key,
    required this.notification,
    required this.onDismissed,
    this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onDismissed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red.shade400,
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      child: ListTile(
        tileColor: notification.isRead ? null : const Color(0xFFF5F7EB),
        onTap: onTap,
        leading: _TypeIcon(type: notification.type),
        title: Text(
          notification.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          notification.body,
          style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          _relativeTime(notification.createdAt),
          style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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

class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (type) {
      'reservation_status' => (Icons.calendar_today, const Color(0xFF669340)),
      'event' => (Icons.event, const Color(0xFFE07B39)),
      _ => (Icons.campaign_outlined, const Color(0xFF999999)),
    };

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_outlined,
              size: 64, color: Color(0xFFCCCCCC)),
          SizedBox(height: 16),
          Text(
            'Nenhuma notificação ainda',
            style: TextStyle(fontSize: 16, color: Color(0xFF999999)),
          ),
        ],
      ),
    );
  }
}
