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
/// Modo edição (reenvio): recebe [reservation] rejeitada.
class ReservationFormScreen extends StatefulWidget {
  const ReservationFormScreen({super.key, this.bookingData, this.reservation});

  final Map<String, dynamic>? bookingData;
  final Reservation? reservation;

  bool get isEdit => reservation != null;

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
  Timer? _countdownTimer;
  Duration? _timeLeft;

  // Dados derivados
  late final int _spaceId;
  late final String _spaceName;
  late final String _parkName;
  late final int _capacityMax;
  late final String _data;
  late final String _horaInicio;
  late final String _horaFim;
  late final String _termsOfUse;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) {
      final r = widget.reservation!;
      _spaceId = r.spaceId;
      _spaceName = r.spaceName;
      _parkName = r.parkName;
      _capacityMax = r.capacityMax;
      _data = r.data;
      _horaInicio = r.horaInicio;
      _horaFim = r.horaFim;
      _termsOfUse = '';
      _agreeTerms = true; // termos já aceitos no envio original
      for (final p in r.participants) {
        final c = _ParticipantControllers();
        c.nome.text = p.nome;
        c.cpf.text = p.cpf;
        _participants.add(c);
      }
      _startCountdown();
    } else {
      final d = widget.bookingData ?? const {};
      _spaceId = (d['spaceId'] ?? 0) as int;
      _spaceName = (d['spaceName'] ?? 'Espaço').toString();
      _parkName = (d['parkName'] ?? '').toString();
      _capacityMax = (d['capacityMax'] ?? 0) as int;
      _data = (d['data'] ?? '').toString();
      _horaInicio = (d['horaInicio'] ?? '').toString();
      _horaFim = (d['horaFim'] ?? '').toString();
      _termsOfUse = (d['termsOfUse'] ?? '').toString();
    }
  }

  void _startCountdown() {
    _timeLeft = widget.reservation?.resubmitTimeLeft;
    if (_timeLeft == null) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = widget.reservation?.resubmitTimeLeft;
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

  List<Participant>? _collectParticipants() {
    final result = <Participant>[];
    for (final c in _participants) {
      final nome = c.nome.text.trim();
      final cpf = c.cpf.text.trim();
      if (nome.isEmpty || cpf.length < 14) {
        AppToast.show(context, 'Preencha nome e CPF de todos os participantes.', type: ToastType.error);
        return null;
      }
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
      result = await _repo.resubmit(id: widget.reservation!.id, participants: participants);
    } else {
      result = await _repo.create(
        spaceId: _spaceId,
        dateStr: _data,
        startTime: _horaInicio,
        participants: participants,
      );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.success) {
      _showSuccessDialog();
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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Center(child: Icon(Icons.hourglass_top_rounded, color: _green, size: 48)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Solicitação enviada!',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: _dark),
            ),
            const SizedBox(height: 12),
            Text(
              'Sua reserva foi enviada para análise dos gestores do parque. Você será notificado quando for aprovada.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: _lightGray, height: 1.4),
            ),
          ],
        ),
        actions: [
          Center(
            child: SizedBox(
              width: 160,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  // Volta para a Home.
                  context.go('/tabs/home');
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Entendido', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
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
    final me = AuthService.instance.currentUser ?? {};
    final responsavelNome = (me['nome'] ?? me['name'] ?? '').toString();
    final responsavelCpf = (me['cpf'] ?? '').toString();

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
          widget.isEdit ? 'Reenviar reserva' : 'Confirmar reserva',
          style: GoogleFonts.poppins(color: _green, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              children: [
                if (widget.isEdit) _buildRejectedBanner(),

                // Resumo
                _buildSummaryCard(),
                const SizedBox(height: 24),

                // Responsável
                _buildSectionTitle('Responsável'),
                const SizedBox(height: 8),
                _buildReadonlyRow(responsavelNome.isEmpty ? 'Você' : responsavelNome, responsavelCpf),
                const SizedBox(height: 24),

                // Participantes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionTitle('Participantes'),
                    TextButton.icon(
                      onPressed: _addParticipant,
                      icon: const Icon(Icons.add, size: 18, color: _green),
                      label: Text('Adicionar', style: GoogleFonts.poppins(color: _green, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                if (_participants.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Adicione os demais participantes (nome e CPF de cada um).',
                      style: GoogleFonts.poppins(fontSize: 12.5, color: _lightGray, height: 1.4),
                    ),
                  ),
                ..._participants.asMap().entries.map((e) => _buildParticipantCard(e.key)),

                const SizedBox(height: 16),

                // Termos (só no modo criação, se houver)
                if (!widget.isEdit && _termsOfUse.isNotEmpty) ...[
                  _buildSectionTitle('Termos de uso'),
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

          // Botão enviar
          Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 16),
            child: FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                disabledBackgroundColor: _green.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    final motivo = widget.reservation?.motivoRejeicao ?? '';
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

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _parkName.isEmpty ? _spaceName : '$_spaceName — $_parkName',
            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: _dark),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 16, color: _green),
              const SizedBox(width: 8),
              Text(
                '${_formattedDate()} · $_horaInicio${_horaFim.isNotEmpty ? ' – $_horaFim' : ''}',
                style: GoogleFonts.poppins(fontSize: 13, color: _dark, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: _dark),
    );
  }

  Widget _buildReadonlyRow(String nome, String cpf) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline, color: _green, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome, style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, color: _dark)),
                if (cpf.isNotEmpty)
                  Text('CPF: $cpf', style: GoogleFonts.poppins(fontSize: 12, color: _lightGray)),
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
