// lib/screens/events/my_event_requests_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/event_request.dart';
import '../../data/repositories/go_event_repository.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/login_required.dart';
import 'event_details_screen.dart';

const _green = Color(0xFF669340);
const _dark = Color(0xFF32384A);
const _lightGray = Color(0xFF8F959E);
const _cardBg = Color(0xFFF9FAE8);

class MyEventRequestsScreen extends StatefulWidget {
  const MyEventRequestsScreen({super.key});

  @override
  State<MyEventRequestsScreen> createState() => _MyEventRequestsScreenState();
}

class _MyEventRequestsScreenState extends State<MyEventRequestsScreen>
    with SingleTickerProviderStateMixin {
  final _repo = GoEventRepository();
  late final TabController _tabController;

  bool _isLoading = true;
  List<EventRequest> _requests = [];

  static const _pageSize = 5;
  int _historicoPage = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (AuthService.instance.tokenSync == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    final list = await _repo.fetchMine();
    if (mounted) {
      list.sort((a, b) {
        const order = ['Pendente', 'Aprovada', 'Rejeitada', 'Cancelada'];
        final ia = order.indexOf(a.status).clamp(0, order.length - 1);
        final ib = order.indexOf(b.status).clamp(0, order.length - 1);
        if (ia != ib) return ia.compareTo(ib);
        return b.dataEvento.compareTo(a.dataEvento);
      });
      setState(() {
        _requests = list;
        _isLoading = false;
        _historicoPage = 1;
      });
    }
  }

  // Ativos: Pendente + Rejeitada (pode reenviar) + Aprovada futura/hoje
  List<EventRequest> get _ativos {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    return _requests.where((r) {
      if (r.status == 'Pendente' || r.status == 'Rejeitada') return true;
      if (r.status == 'Aprovada') {
        final dt = DateTime.tryParse(r.dataEvento);
        if (dt == null) return true;
        final eventDay = DateTime(dt.year, dt.month, dt.day);
        return !eventDay.isBefore(todayStart); // hoje ou futuro
      }
      return false;
    }).toList();
  }

  // Histórico: Canceladas + Aprovadas cujo dia do evento já passou
  List<EventRequest> get _historico {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final list = _requests.where((r) {
      if (r.status == 'Cancelada') return true;
      if (r.status == 'Aprovada') {
        final dt = DateTime.tryParse(r.dataEvento);
        if (dt == null) return false;
        final eventDay = DateTime(dt.year, dt.month, dt.day);
        return eventDay.isBefore(todayStart); // já aconteceu
      }
      return false;
    }).toList();
    list.sort((a, b) => b.dataEvento.compareTo(a.dataEvento));
    return list;
  }

  Future<void> _resubmitRequest(EventRequest r) async {
    final result = await _repo.resubmit(r.id);
    if (!mounted) return;
    if (result.success) {
      AppToast.show(context, 'Solicitação reenviada!', type: ToastType.success);
      _load();
    } else {
      AppToast.show(context, result.error ?? 'Erro ao reenviar.', type: ToastType.error);
    }
  }

  Future<void> _editAndResubmit(EventRequest r) async {
    // Normaliza dataEvento para "yyyy-MM-dd" (pode vir como ISO full do backend)
    final dateOnly = r.dataEvento.length > 10 ? r.dataEvento.substring(0, 10) : r.dataEvento;

    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventDetailsScreen(
          parkId: r.parkId,
          spaceIds: [r.spaceId],
          dataEvento: dateOnly,
          horaInicio: r.horaInicio,
          horaFim: r.horaFim,
          editingRequest: r,
        ),
      ),
    );
    if (ok == true && mounted) {
      AppToast.show(context, 'Solicitação atualizada e reenviada!', type: ToastType.success);
      _load();
    }
  }

  Future<void> _cancelRequest(EventRequest r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Cancelar solicitação',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text(
          'Tem certeza que deseja cancelar a solicitação de "${r.tipoAtividade}" em ${r.parkName}?',
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
    await _repo.cancel(r.id);
    if (mounted) {
      AppToast.show(context, 'Solicitação cancelada.', type: ToastType.success);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = AuthService.instance.tokenSync != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _green),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          'Meus Pedidos de Evento',
          style: GoogleFonts.poppins(
            color: _green,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: isLoggedIn
            ? TabBar(
                controller: _tabController,
                labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle:
                    GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w400),
                labelColor: _green,
                unselectedLabelColor: _lightGray,
                indicatorColor: _green,
                indicatorWeight: 2.5,
                tabs: const [
                  Tab(text: 'Ativos'),
                  Tab(text: 'Histórico'),
                ],
              )
            : null,
      ),
      body: !isLoggedIn
          ? _buildLoginRequired()
          : _isLoading
              ? const Center(child: CircularProgressIndicator(color: _green))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList(_ativos, paginated: false, isHistory: false),
                    _buildList(_historico, paginated: true, isHistory: true),
                  ],
                ),
    );
  }

  Widget _buildLoginRequired() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 56, color: _lightGray.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'Login necessário',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Faça login para visualizar seus pedidos de evento.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: _lightGray, height: 1.5),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => requireLogin(context, featureName: 'meus pedidos'),
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              child: Text(
                'Fazer Login',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<EventRequest> list, {required bool paginated, required bool isHistory}) {
    if (list.isEmpty) return _buildEmpty(isHistory: isHistory);

    final visible = paginated ? list.take(_historicoPage * _pageSize).toList() : list;
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
          return _EventRequestCard(
            request: visible[index],
            onCancel: () => _cancelRequest(visible[index]),
            onResubmit: () => _resubmitRequest(visible[index]),
            onEdit: () => _editAndResubmit(visible[index]),
          );
        },
      ),
    );
  }

  Widget _buildEmpty({bool isHistory = false}) {
    final title = isHistory ? 'Nenhum histórico ainda' : 'Nenhum pedido ativo';
    final subtitle = isHistory
        ? 'Seus pedidos rejeitados e\ncancelados aparecerão aqui.'
        : 'Solicite um evento usando o botão\n"Solicitar Evento" na tela anterior.';

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
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _dark,
              ),
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

class _EventRequestCard extends StatelessWidget {
  const _EventRequestCard({
    required this.request,
    required this.onCancel,
    required this.onResubmit,
    required this.onEdit,
  });

  final EventRequest request;
  final VoidCallback onCancel;
  final VoidCallback onResubmit;
  final VoidCallback onEdit;

  String _formatDate(String data) {
    final dt = DateTime.tryParse(data);
    if (dt == null) return data;
    try {
      return DateFormat('dd/MM/yyyy', 'pt_BR').format(dt);
    } catch (_) {
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }
  }

  ({String label, Color bg, Color fg}) _badge(String status) {
    switch (status) {
      case 'Pendente':
        return (
          label: 'Em análise',
          bg: const Color(0xFFFFEFBA),
          fg: const Color(0xFFB8860B),
        );
      case 'Aprovada':
        return (
          label: 'Aprovada',
          bg: const Color(0xFFDCFCE7),
          fg: const Color(0xFF166534),
        );
      case 'Rejeitada':
        return (
          label: 'Rejeitada',
          bg: const Color(0xFFFFCDD2),
          fg: const Color(0xFFE53935),
        );
      case 'Cancelada':
        return (
          label: 'Cancelada',
          bg: const Color(0xFFEEEEEE),
          fg: _lightGray,
        );
      default:
        return (label: status, bg: const Color(0xFFEEEEEE), fg: _lightGray);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = request;
    final b = _badge(r.status);
    final canCancel = r.status == 'Pendente';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge + botão cancelar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: b.bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  b.label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: b.fg,
                  ),
                ),
              ),
              const Spacer(),
              if (canCancel)
                GestureDetector(
                  onTap: onCancel,
                  child: const Icon(Icons.delete_outline, color: Color(0xFFE53935), size: 22),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Tipo de atividade
          Text(
            r.tipoAtividade,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _green,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 4),

          // Parque e espaço
          Text(
            '${r.parkName}${r.spaceName.isNotEmpty ? ' · ${r.spaceName}' : ''}',
            style: GoogleFonts.poppins(fontSize: 13, color: _dark),
          ),

          const SizedBox(height: 4),

          // Data
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 13, color: _lightGray),
              const SizedBox(width: 4),
              Text(
                _formatDate(r.dataEvento),
                style: GoogleFonts.poppins(fontSize: 13, color: _dark),
              ),
            ],
          ),

          const SizedBox(height: 2),

          // Horário
          Row(
            children: [
              const Icon(Icons.access_time_outlined, size: 13, color: _lightGray),
              const SizedBox(width: 4),
              Text(
                'Das ${r.horaInicio} às ${r.horaFim}',
                style: GoogleFonts.poppins(fontSize: 13, color: _dark),
              ),
            ],
          ),

          const SizedBox(height: 2),

          // Pessoas
          Row(
            children: [
              const Icon(Icons.people_outline, size: 13, color: _lightGray),
              const SizedBox(width: 4),
              Text(
                '${r.quantidadePessoas} pessoas',
                style: GoogleFonts.poppins(fontSize: 13, color: _dark),
              ),
            ],
          ),

          // Motivo de rejeição + botão reenviar
          if (r.status == 'Rejeitada') ...[
            if (r.motivoRejeicao.isNotEmpty) ...[
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
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFFE53935),
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onResubmit,
                    icon: const Icon(Icons.refresh_rounded, size: 15),
                    label: Text(
                      'Reenviar',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _lightGray,
                      side: const BorderSide(color: Color(0xFFCCCCCC)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: Text(
                      'Editar e reenviar',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Motivo de cancelamento (gestor)
          if (r.status == 'Cancelada' && r.motivoCancelamento.isNotEmpty) ...[
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
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: _dark,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // BPA
          if (r.apoioBPA) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.security_outlined, size: 13, color: _green),
                const SizedBox(width: 4),
                Text(
                  'Apoio BPA solicitado',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: _green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
