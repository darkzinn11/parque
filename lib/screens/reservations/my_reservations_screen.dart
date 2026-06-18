// lib/screens/reservations/my_reservations_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/reservation.dart';
import '../../data/repositories/go_reservation_repository.dart';
import '../../widgets/app_toast.dart';

const _green = Color(0xFF669340);
const _dark = Color(0xFF32384A);
const _lightGray = Color(0xFF8F959E);
const _cardBg = Color(0xFFF9FAE8);

class MyReservationsScreen extends StatefulWidget {
  const MyReservationsScreen({super.key});

  @override
  State<MyReservationsScreen> createState() => _MyReservationsScreenState();
}

class _MyReservationsScreenState extends State<MyReservationsScreen>
    with SingleTickerProviderStateMixin {
  final _repo = GoReservationRepository();
  late final TabController _tabController;
  bool _isLoading = true;
  List<Reservation> _reservations = [];
  Timer? _ticker;

  static const _pageSize = 5;
  int _historicoPage = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _reservations.any((r) => r.canResubmit)) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final list = await _repo.fetchMine();
    if (mounted) {
      list.sort((a, b) {
        const order = ['Pendente', 'Aprovada', 'Rejeitada', 'Expirada', 'Cancelada'];
        final ia = order.indexOf(a.status);
        final ib = order.indexOf(b.status);
        if (ia != ib) return ia.compareTo(ib);
        return b.data.compareTo(a.data);
      });
      setState(() {
        _reservations = list;
        _isLoading = false;
        _historicoPage = 1; // reset paginação ao recarregar
      });
    }
  }

  List<Reservation> get _atuais => _reservations
      .where((r) => ['Pendente', 'Aprovada', 'Rejeitada'].contains(r.status))
      .toList();

  List<Reservation> get _historico {
    final list = _reservations
        .where((r) => ['Expirada', 'Cancelada'].contains(r.status))
        .toList();
    list.sort((a, b) {
      final dateCmp = b.data.compareTo(a.data);
      if (dateCmp != 0) return dateCmp;
      return b.horaInicio.compareTo(a.horaInicio);
    });
    return list;
  }

  Future<void> _goEdit(Reservation r) async {
    await context.push('/tabs/user/minhas-reservas/${r.id}/editar', extra: r);
    if (mounted) _load();
  }

  Future<void> _cancelReservation(Reservation r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cancelar reserva',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Text(
          'Tem certeza que deseja cancelar sua reserva em ${r.spaceName}?',
          style: GoogleFonts.poppins(fontSize: 13, color: _dark, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Não', style: GoogleFonts.poppins(color: _lightGray)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Sim, cancelar', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await _repo.cancel(r.id);
    if (mounted) {
      if (result.success) {
        _load();
      } else {
        AppToast.show(context, result.error ?? 'Erro ao cancelar.', type: ToastType.error);
      }
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
          'Minhas Reservas',
          style: GoogleFonts.poppins(color: _green, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w400),
          labelColor: _green,
          unselectedLabelColor: _lightGray,
          indicatorColor: _green,
          indicatorWeight: 2.5,
          tabs: const [
            Tab(text: 'Reservas Atuais'),
            Tab(text: 'Histórico de Reservas'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_atuais, paginated: false, isHistory: false),
                _buildList(_historico, paginated: true, isHistory: true),
              ],
            ),
    );
  }

  Widget _buildList(List<Reservation> list, {required bool paginated, required bool isHistory}) {
    if (list.isEmpty) return _buildEmpty(isHistory: isHistory);

    final visible = paginated
        ? list.take(_historicoPage * _pageSize).toList()
        : list;
    final hasMore = paginated && visible.length < list.length;

    return RefreshIndicator(
      color: _green,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        itemCount: visible.length + (hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          if (index == visible.length) {
            // Botão "Ver mais"
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: OutlinedButton(
                onPressed: () => setState(() => _historicoPage++),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _green,
                  side: const BorderSide(color: _green),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Ver mais (${list.length - visible.length} restantes)',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            );
          }
          return _ReservationCard(
            reservation: visible[index],
            onResubmit: () => _goEdit(visible[index]),
            onCancel: () => _cancelReservation(visible[index]),
          );
        },
      ),
    );
  }

  Widget _buildEmpty({bool isHistory = false}) {
    final title = isHistory ? 'Nenhum histórico ainda' : 'Nenhuma reserva aqui';
    final subtitle = isHistory
        ? 'Suas reservas concluídas, canceladas e\nexpiradas aparecerão aqui.'
        : 'Reserve um espaço pela tela de\nReservas na Home.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note_outlined, size: 64, color: _lightGray.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: _dark),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: _lightGray, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Card ─────────────────────────────────────────────────────────────────────

class _ReservationCard extends StatefulWidget {
  const _ReservationCard({
    required this.reservation,
    required this.onResubmit,
    required this.onCancel,
  });
  final Reservation reservation;
  final VoidCallback onResubmit;
  final VoidCallback onCancel;

  @override
  State<_ReservationCard> createState() => _ReservationCardState();
}

class _ReservationCardState extends State<_ReservationCard> {
  bool _expanded = false;

  String _formattedDate(String data) {
    final dt = DateTime.tryParse(data);
    if (dt == null) return data;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _fmtCountdown(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  ({String label, Color bg, Color fg, bool showCheck}) _badge(Reservation r) {
    switch (r.status) {
      case 'Pendente':
        return (label: 'Em análise', bg: const Color(0xFFFFEFBA), fg: const Color(0xFFB8860B), showCheck: false);
      case 'Aprovada':
        return (label: 'Confirmada', bg: const Color(0xFF4CAF50), fg: Colors.white, showCheck: true);
      case 'Rejeitada':
        return r.canResubmit
            ? (label: 'Recusada', bg: const Color(0xFFFFCDD2), fg: const Color(0xFFE53935), showCheck: false)
            : (label: 'Expirada', bg: const Color(0xFFEEEEEE), fg: _lightGray, showCheck: false);
      case 'Cancelada':
        return (label: 'Cancelada', bg: const Color(0xFFEEEEEE), fg: _lightGray, showCheck: false);
      default:
        return (label: 'Expirada', bg: const Color(0xFFEEEEEE), fg: _lightGray, showCheck: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reservation;
    final b = _badge(r);
    final left = r.resubmitTimeLeft;
    final totalPessoas = r.participants.length + 1;
    final canCancel = r.status == 'Pendente' || r.status == 'Aprovada';

    return GestureDetector(
      onTap: () {
        if (r.participants.isNotEmpty) setState(() => _expanded = !_expanded);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badge + lixeira
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: b.bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(b.label,
                          style: GoogleFonts.poppins(
                              fontSize: 12, fontWeight: FontWeight.w600, color: b.fg)),
                      if (b.showCheck) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.check, size: 13, color: b.fg),
                      ],
                    ],
                  ),
                ),
                const Spacer(),
                if (canCancel)
                  GestureDetector(
                    onTap: widget.onCancel,
                    child: const Icon(Icons.delete_outline, color: Color(0xFFE53935), size: 22),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Nome do espaço
            Text(
              r.spaceName,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _green,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 8),

            // Data
            Text(
              _formattedDate(r.data),
              style: GoogleFonts.poppins(fontSize: 13, color: _dark),
            ),

            const SizedBox(height: 4),

            // Horário
            Text(
              'Das ${r.horaInicio} às ${r.horaFim} horas',
              style: GoogleFonts.poppins(fontSize: 13, color: _dark),
            ),

            const SizedBox(height: 4),

            // Pessoas
            Text(
              '$totalPessoas ${totalPessoas == 1 ? 'pessoa' : 'pessoas'}',
              style: GoogleFonts.poppins(fontSize: 13, color: _dark),
            ),

            // Motivo de rejeição
            if (r.status == 'Rejeitada' && r.motivoRejeicao.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: Color(0xFFE53935)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Motivo: ${r.motivoRejeicao}',
                        style: GoogleFonts.poppins(fontSize: 12, color: _dark, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Motivo de cancelamento (só quando cancelado pelo gestor)
            if (r.status == 'Cancelada' &&
                r.canceladoPor == 'gestor' &&
                r.motivoCancelamento.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: Color(0xFFF57C00)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Cancelado pelo parque. Motivo: ${r.motivoCancelamento}',
                        style: GoogleFonts.poppins(fontSize: 12, color: _dark, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Contagem regressiva + reenvio
            if (r.canResubmit && left != null) ...[
              const SizedBox(height: 12),
              Text(
                'Tempo para reenviar: ${_fmtCountdown(left)}',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: const Color(0xFFE53935), fontWeight: FontWeight.w600),
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

            // Participantes expandidos (tap no card)
            if (_expanded && r.participants.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFE0E0D0)),
              const SizedBox(height: 12),
              Text('Participantes',
                  style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w700, color: _dark)),
              const SizedBox(height: 6),
              ...r.participants.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• ${p.nome} — ${p.cpf}',
                      style: GoogleFonts.poppins(fontSize: 12, color: _lightGray)),
                ),
              ),
            ],

            if (r.participants.isNotEmpty) ...[
              const SizedBox(height: 8),
              Center(
                child: Icon(
                  _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: _lightGray,
                  size: 20,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
