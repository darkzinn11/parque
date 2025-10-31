import 'package:flutter/material.dart';
import '../../services/reservations_service.dart';
import '../../widgets/login_required.dart';

const _green = Color(0xFF669340);

class MyReservationsScreen extends StatefulWidget {
  const MyReservationsScreen({super.key});
  @override
  State<MyReservationsScreen> createState() => _MyReservationsScreenState();
}

class _MyReservationsScreenState extends State<MyReservationsScreen> {
  final _svc = ReservationsService();
  late Future<List<MyReservation>> _future;

  @override
  void initState() {
    super.initState();
    _future = _svc.myReservations();
  }

  Future<void> _refresh() async {
    setState(() => _future = _svc.myReservations());
    await _future;
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'confirmed': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.orange; // pending
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minhas reservas')),
      body: FutureBuilder<List<MyReservation>>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const Center(child: Text('Você ainda não tem reservas.'));
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final r = list[i];
                final date = '${r.date.day.toString().padLeft(2,'0')}/${r.date.month.toString().padLeft(2,'0')}/${r.date.year}';
                final time = '${r.startTime}–${r.endTime}';
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 8, offset: const Offset(0,3))],
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.event_available, color: _green),
                    title: Text(r.spaceTitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${r.parkName ?? ''}\n$date · $time'),
                    isThreeLine: true,
                    trailing: Chip(
                      label: Text(r.status),
                      backgroundColor: _statusColor(r.status).withOpacity(.15),
                      labelStyle: TextStyle(color: _statusColor(r.status), fontWeight: FontWeight.w700),
                    ),
                    onLongPress: () async {
                      // Cancelar (opcional): press & hold
                      final okLogin = await requireLogin(context, featureName: 'cancelar reserva');
                      if (!okLogin) return;
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Cancelar reserva?'),
                          content: Text('${r.spaceTitle}\n$date · $time'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Manter')),
                            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cancelar')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        final ok = await _svc.cancel(r.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(ok ? 'Reserva cancelada.' : 'Falha ao cancelar.')),
                          );
                          if (ok) _refresh();
                        }
                      }
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
