// lib/screens/reservations/my_reservations_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/reservation.dart';
import '../../data/repositories/go_reservation_repository.dart';

const _green = Color(0xFF669340);
const _dark = Color(0xFF32384A);
const _lightGray = Color(0xFF8F959E);

class MyReservationsScreen extends StatefulWidget {
  const MyReservationsScreen({super.key});

  @override
  State<MyReservationsScreen> createState() => _MyReservationsScreenState();
}

class _MyReservationsScreenState extends State<MyReservationsScreen> {
  final _repo = GoReservationRepository();
  bool _isLoading = true;
  List<Reservation> _reservations = [];
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    // Atualiza contadores regressivos a cada segundo.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _reservations.any((r) => r.canResubmit)) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final list = await _repo.fetchMine();
    if (mounted) {
      setState(() {
        _reservations = list;
        _isLoading = false;
      });
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _green, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Minhas reservas',
          style: GoogleFonts.poppins(color: _green, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : RefreshIndicator(
              color: _green,
              onRefresh: _load,
              child: _reservations.isEmpty
                  ? _buildEmpty()
                  : ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: _reservations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) => _ReservationCard(
                        reservation: _reservations[index],
                        onResubmit: () => _goEdit(_reservations[index]),
                      ),
                    ),
            ),
    );
  }

  Future<void> _goEdit(Reservation r) async {
    await context.push('/tabs/user/minhas-reservas/${r.id}/editar', extra: r);
    if (mounted) _load();
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(Icons.event_note_outlined, size: 56, color: _lightGray.withValues(alpha: 0.5)),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Você ainda não tem reservas',
            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: _dark),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Reserve um espaço pela tela de Reservas na Home.',
            style: GoogleFonts.poppins(fontSize: 13, color: _lightGray),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge {
  final String label;
  final Color bg;
  final Color fg;
  const _StatusBadge(this.label, this.bg, this.fg);

  static _StatusBadge forStatus(Reservation r) {
    switch (r.status) {
      case 'Pendente':
        return const _StatusBadge('Aguardando aprovação', Color(0xFFFFF7E6), Color(0xFFB8860B));
      case 'Aprovada':
        return const _StatusBadge('Confirmada', Color(0xFFEEF7EC), _green);
      case 'Rejeitada':
        if (r.canResubmit) {
          return const _StatusBadge('Recusada', Color(0xFFFFF0F0), Color(0xFFE53935));
        }
        return const _StatusBadge('Expirada', Color(0xFFF0F0F0), _lightGray);
      default:
        return const _StatusBadge('Expirada', Color(0xFFF0F0F0), _lightGray);
    }
  }
}

class _ReservationCard extends StatefulWidget {
  const _ReservationCard({required this.reservation, required this.onResubmit});
  final Reservation reservation;
  final VoidCallback onResubmit;

  @override
  State<_ReservationCard> createState() => _ReservationCardState();
}

class _ReservationCardState extends State<_ReservationCard> {
  bool _expanded = false;

  String _formattedDate(String data) {
    final dt = DateTime.tryParse(data);
    if (dt == null) return data;
    const weekdays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    const months = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
    return '${weekdays[dt.weekday - 1]}, ${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]}';
  }

  String _fmtCountdown(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reservation;
    final badge = _StatusBadge.forStatus(r);
    final left = r.resubmitTimeLeft;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFECECEC)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    r.parkName.isEmpty ? r.spaceName : '${r.spaceName} — ${r.parkName}',
                    style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w700, color: _dark),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: badge.bg, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    badge.label,
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: badge.fg),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 15, color: _green),
                const SizedBox(width: 8),
                Text(
                  '${_formattedDate(r.data)} · ${r.horaInicio}${r.horaFim.isNotEmpty ? ' – ${r.horaFim}' : ''}',
                  style: GoogleFonts.poppins(fontSize: 12.5, color: _dark, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Text(
                  '${r.participants.length + 1} pessoa(s)',
                  style: GoogleFonts.poppins(fontSize: 12, color: _lightGray),
                ),
              ],
            ),

            // Contagem regressiva + botão de reenvio
            if (r.canResubmit && left != null) ...[
              const SizedBox(height: 12),
              Text(
                'Tempo para reenviar: ${_fmtCountdown(left)}',
                style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFFE53935), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: widget.onResubmit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _green,
                    side: const BorderSide(color: _green),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Editar e reenviar',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ),
            ],

            // Detalhes expandidos
            if (_expanded && r.participants.isNotEmpty) ...[
              const Divider(height: 24),
              Text('Participantes',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: _dark)),
              const SizedBox(height: 8),
              ...r.participants.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• ${p.nome} — ${p.cpf}',
                      style: GoogleFonts.poppins(fontSize: 12.5, color: _lightGray)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
