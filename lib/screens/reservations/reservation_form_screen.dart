// lib/screens/reservations/reservation_form_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/reservation.dart';
import '../../data/repositories/go_reservation_repository.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_toast.dart';

const _green = Color(0xFF669340);
const _dark = Color(0xFF32384A);
const _lightGray = Color(0xFF8F959E);

/// Formulário de participantes + envio da reserva.
/// Modo criação: recebe [bookingData] (mapa vindo do calendário).
/// Modo edição (reenvio): recebe [reservation] rejeitada, ou apenas [reservationId]
/// quando aberto via deeplink de notificação (busca a reserva automaticamente).
class ReservationFormScreen extends StatefulWidget {
  const ReservationFormScreen({
    super.key,
    this.bookingData,
    this.reservation,
    this.reservationId,
  });

  final Map<String, dynamic>? bookingData;
  final Reservation? reservation;
  final int? reservationId;

  bool get isEdit => reservation != null || reservationId != null;

  @override
  State<ReservationFormScreen> createState() => _ReservationFormScreenState();
}

class _ParticipantControllers {
  final TextEditingController nome = TextEditingController();
  final TextEditingController cpf = TextEditingController();
  void dispose() {
    nome.dispose();
    cpf.dispose();
  }
}

class _ReservationFormScreenState extends State<ReservationFormScreen> {
  final _repo = GoReservationRepository();
  final List<_ParticipantControllers> _participants = [];

  bool _agreeTerms = false;
  bool _isSubmitting = false;
  bool _loadingReservation = false;
  String? _loadError;
  Reservation? _fetchedReservation;
  Timer? _countdownTimer;
  Duration? _timeLeft;

  // Dados derivados
  late int _spaceId;
  late String _spaceName;
  late int _capacityMax;
  late String _data;
  late String _horaInicio;
  late String _horaFim;
  late String _termsOfUse;
  int _duracaoHoras = 1;

  Reservation? get _reservation => widget.reservation ?? _fetchedReservation;

  @override
  void initState() {
    super.initState();
    if (widget.reservation != null) {
      _initFromReservation(widget.reservation!);
    } else if (widget.reservationId != null) {
      _fetchAndInit(widget.reservationId!);
    } else {
      _initFromBookingData();
    }
  }

  Future<void> _fetchAndInit(int id) async {
    setState(() => _loadingReservation = true);
    final r = await _repo.getById(id);
    if (!mounted) return;
    if (r == null) {
      setState(() {
        _loadingReservation = false;
        _loadError = 'Reserva não encontrada.';
      });
      return;
    }
    // Guard (code-review #5): só permite reenviar/editar reservas Rejeitadas.
    // Ao abrir via deeplink, a reserva pode já ter sido aprovada/cancelada/expirada.
    if (r.status != 'Rejeitada') {
      _fetchedReservation = r;
      _initFromReservation(r);
      setState(() {
        _loadingReservation = false;
        _loadError = 'Esta reserva não pode mais ser editada.';
      });
      AppToast.show(
        context,
        'Esta reserva não pode mais ser editada.',
        type: ToastType.warning,
      );
      return;
    }

    _fetchedReservation = r;
    _initFromReservation(r);
    setState(() => _loadingReservation = false);
  }

  void _initFromReservation(Reservation r) {
    _spaceId = r.spaceId;
    _spaceName = r.spaceName;
    _capacityMax = r.capacityMax;
    _data = r.data;
    _horaInicio = r.horaInicio;
    _horaFim = r.horaFim;
    _duracaoHoras = _durationFromRange(r.horaInicio, r.horaFim);
    _termsOfUse = '';
    _agreeTerms = true;
    for (final p in r.participants) {
      final c = _ParticipantControllers();
      c.nome.text = p.nome;
      c.cpf.text = p.cpf;
      _participants.add(c);
    }
    _startCountdown();
  }

  void _initFromBookingData() {
    final d = widget.bookingData ?? const {};
    _spaceId = (d['spaceId'] ?? 0) as int;
    _spaceName = (d['spaceName'] ?? 'Espaço').toString();
    _capacityMax = (d['capacityMax'] ?? 0) as int;
    _data = (d['data'] ?? '').toString();
    _horaInicio = (d['horaInicio'] ?? '').toString();
    _horaFim = (d['horaFim'] ?? '').toString();
    _duracaoHoras = (d['duracaoHoras'] ?? _durationFromRange(_horaInicio, _horaFim)) as int;
    _termsOfUse = (d['termsOfUse'] ?? '').toString();

    final numParticipants = (d['numParticipants'] ?? 1) as int;
    final count = numParticipants - 1;
    for (int i = 0; i < count; i++) {
      _participants.add(_ParticipantControllers());
    }
  }

  void _startCountdown() {
    _timeLeft = _reservation?.resubmitTimeLeft;
    if (_timeLeft == null) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = _reservation?.resubmitTimeLeft;
      if (!mounted) return;
      if (left == null) {
        _countdownTimer?.cancel();
        setState(() => _timeLeft = null);
      } else {
        setState(() => _timeLeft = left);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (final c in _participants) {
      c.dispose();
    }
    super.dispose();
  }

  void _addParticipant() {
    // Responsável já conta como 1.
    if (_capacityMax > 0 && _participants.length + 1 >= _capacityMax) {
      AppToast.show(context, 'Capacidade máxima do espaço atingida.', type: ToastType.warning);
      return;
    }
    setState(() => _participants.add(_ParticipantControllers()));
  }

  void _removeParticipant(int index) {
    setState(() {
      _participants[index].dispose();
      _participants.removeAt(index);
    });
  }

  String _stripCpf(String cpf) => cpf.replaceAll(RegExp(r'[^\d]'), '');

  List<Participant>? _collectParticipants() {
    if (_participants.isEmpty) {
      AppToast.show(context, 'Adicione ao menos um participante com nome e CPF.', type: ToastType.error);
      return null;
    }

    final leaderCpf = _stripCpf(
      AuthService.instance.currentUser?['cpf']?.toString() ?? '',
    );

    final result = <Participant>[];
    final seen = <String>{};

    for (final c in _participants) {
      final nome = c.nome.text.trim();
      final cpf = c.cpf.text.trim();
      if (nome.isEmpty || cpf.length < 14) {
        AppToast.show(context, 'Preencha nome e CPF de todos os participantes.', type: ToastType.error);
        return null;
      }
      final cpfDigits = _stripCpf(cpf);
      if (leaderCpf.isNotEmpty && cpfDigits == leaderCpf) {
        AppToast.show(context, 'O responsável não pode ser listado como participante.', type: ToastType.error);
        return null;
      }
      if (seen.contains(cpfDigits)) {
        AppToast.show(context, 'CPF duplicado na lista de participantes.', type: ToastType.error);
        return null;
      }
      seen.add(cpfDigits);
      result.add(Participant(nome: nome, cpf: cpf));
    }
    return result;
  }

  Future<void> _submit() async {
    if (!widget.isEdit && _termsOfUse.isNotEmpty && !_agreeTerms) {
      AppToast.show(context, 'Você precisa aceitar os termos de uso.', type: ToastType.error);
      return;
    }

    final participants = _collectParticipants();
    if (participants == null) return;

    setState(() => _isSubmitting = true);

    final ReservationResult result;
    if (widget.isEdit) {
      result = await _repo.resubmit(id: _reservation!.id, participants: participants);
    } else {
      result = await _repo.create(
        spaceId: _spaceId,
        dateStr: _data,
        startTime: _horaInicio,
        participants: participants,
        duracaoHoras: _duracaoHoras,
      );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.success) {
      _showSuccessScreen();
      return;
    }

    // Tratamento de erros específicos
    if (result.statusCode == 409) {
      final msg = result.error ?? 'Conflito ao reservar.';
      AppToast.show(context, msg, type: ToastType.error);
      // Se o slot foi tomado, volta ao calendário.
      if (msg.toLowerCase().contains('horário')) {
        Navigator.of(context).pop();
      }
    } else {
      AppToast.show(context, result.error ?? 'Falha ao enviar a solicitação.', type: ToastType.error);
    }
  }

  void _showSuccessScreen() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const _SuccessScreen()),
    );
  }

  /// Calcula a duração (em horas) a partir de "HH:MM" início/fim.
  /// Fallback para 1h se não conseguir parsear.
  int _durationFromRange(String inicio, String fim) {
    final iParts = inicio.split(':');
    final fParts = fim.split(':');
    if (iParts.length < 2 || fParts.length < 2) return 1;
    final iH = int.tryParse(iParts[0]);
    final fH = int.tryParse(fParts[0]);
    if (iH == null || fH == null) return 1;
    final diff = fH - iH;
    return diff >= 1 ? diff : 1;
  }

  String _formattedDate() {
    final parts = _data.split('-');
    if (parts.length != 3) return _data;
    final dt = DateTime.tryParse(_data);
    if (dt == null) return _data;
    const weekdays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    const months = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
    final wd = weekdays[dt.weekday - 1];
    final m = months[dt.month - 1];
    return '$wd, ${dt.day.toString().padLeft(2, '0')} $m';
  }

  String _fmtCountdown(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingReservation) {
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
          title: Text('Reenviar reserva',
              style: GoogleFonts.poppins(color: _green, fontSize: 20, fontWeight: FontWeight.w700)),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
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
          title: Text('Reenviar reserva',
              style: GoogleFonts.poppins(color: _green, fontSize: 20, fontWeight: FontWeight.w700)),
          centerTitle: true,
        ),
        body: Center(
          child: Text(_loadError!, style: GoogleFonts.poppins(color: _dark)),
        ),
      );
    }

    final totalPessoas = _participants.length + 1; // participantes + responsável

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
          widget.isEdit ? 'Reenviar reserva' : 'Confirmação',
          style: GoogleFonts.poppins(color: _green, fontSize: 20, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              children: [
                if (widget.isEdit) _buildRejectedBanner(),

                // Nome do espaço
                Text(
                  _spaceName,
                  style: GoogleFonts.poppins(
                    color: _green,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 24),

                // Data
                Text('Data:', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: _dark)),
                const SizedBox(height: 4),
                Text(
                  _formattedDate(),
                  style: GoogleFonts.poppins(fontSize: 15, color: _dark),
                ),
                const SizedBox(height: 20),

                // Horário
                Text('Horário:', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: _dark)),
                const SizedBox(height: 4),
                Text(
                  'Das $_horaInicio às $_horaFim horas · ${_duracaoHoras}h',
                  style: GoogleFonts.poppins(fontSize: 15, color: _dark),
                ),
                const SizedBox(height: 20),

                // Quantas pessoas
                Text(
                  'Quantas pessoas vão participar?',
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: _dark),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalPessoas ${totalPessoas == 1 ? 'pessoa' : 'pessoas'}',
                  style: GoogleFonts.poppins(fontSize: 15, color: _dark),
                ),
                const SizedBox(height: 28),

                // Participantes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Participantes',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: _dark),
                    ),
                    TextButton.icon(
                      onPressed: _addParticipant,
                      icon: const Icon(Icons.add, size: 18, color: _green),
                      label: Text('Adicionar', style: GoogleFonts.poppins(color: _green, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                if (_participants.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Obrigatório: adicione ao menos um participante com nome e CPF.',
                      style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.red.shade400, height: 1.4),
                    ),
                  ),
                ..._participants.asMap().entries.map((e) => _buildParticipantCard(e.key)),

                const SizedBox(height: 16),

                // Termos (só no modo criação, se houver)
                if (!widget.isEdit && _termsOfUse.isNotEmpty) ...[
                  Text('Termos de uso', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: _dark)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFECECEC)),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        _termsOfUse,
                        style: GoogleFonts.poppins(fontSize: 12.5, color: _lightGray, height: 1.4),
                      ),
                    ),
                  ),
                  CheckboxListTile(
                    value: _agreeTerms,
                    onChanged: (v) => setState(() => _agreeTerms = v ?? false),
                    activeColor: _green,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      'Li e concordo com os termos de uso do espaço.',
                      style: GoogleFonts.poppins(fontSize: 12, color: _dark, height: 1.4),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Botão confirmar
          Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 16),
            child: FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                disabledBackgroundColor: _green.withValues(alpha: 0.5),
                minimumSize: const Size(double.infinity, 54),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      widget.isEdit ? 'Reenviar solicitação' : 'Enviar solicitação',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedBanner() {
    final left = _timeLeft;
    final motivo = _reservation?.motivoRejeicao ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.error_outline, color: Color(0xFFE53935), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reserva recusada — edite e reenvie',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: _dark),
                ),
                if (motivo.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Motivo: $motivo',
                    style: GoogleFonts.poppins(fontSize: 12, color: _dark, height: 1.4),
                  ),
                ],
                const SizedBox(height: 4),
                if (left != null)
                  Text(
                    'Tempo restante: ${_fmtCountdown(left)}',
                    style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFFE53935), fontWeight: FontWeight.w600),
                  )
                else
                  Text(
                    'Prazo encerrado.',
                    style: GoogleFonts.poppins(fontSize: 12, color: _lightGray),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildParticipantCard(int index) {
    final c = _participants[index];
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('Participante ${index + 1}',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: _dark)),
              const Spacer(),
              InkWell(
                onTap: () => _removeParticipant(index),
                child: const Icon(Icons.close, size: 20, color: _lightGray),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: c.nome,
            textCapitalization: TextCapitalization.words,
            decoration: _fieldDecoration('Nome completo'),
            style: GoogleFonts.poppins(fontSize: 13.5, color: _dark),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: c.cpf,
            keyboardType: TextInputType.number,
            inputFormatters: [_CpfInputFormatter()],
            decoration: _fieldDecoration('CPF'),
            style: GoogleFonts.poppins(fontSize: 13.5, color: _dark),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFECECEC)),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 13, color: _lightGray),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: const BorderSide(color: _green)),
    );
  }
}

// ─── Tela de confirmação ──────────────────────────────────────────────────────

class _SuccessScreen extends StatelessWidget {
  const _SuccessScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              Text(
                'Agendamento\nem análise!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: _green,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 40),

              Image.asset(
                'assets/images/calendario.png',
                width: 260,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 40),

              Text(
                'Sua solicitação foi enviada.\nAguarde a aprovação do gestor.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: _dark,
                ),
              ),

              const Spacer(flex: 2),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.go('/tabs/user/minhas-reservas'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.calendar_today_outlined, size: 18, color: Colors.white),
                  label: Text(
                    'Ver meus agendamentos',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aplica a máscara 000.000.000-00 ao CPF.
class _CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.length > 11 ? digits.substring(0, 11) : digits;

    final buffer = StringBuffer();
    for (var i = 0; i < capped.length; i++) {
      buffer.write(capped[i]);
      if (i == 2 || i == 5) buffer.write('.');
      if (i == 8) buffer.write('-');
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
