// lib/screens/events/event_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/event_request.dart';
import '../../data/repositories/go_event_repository.dart';
import '../../widgets/app_toast.dart';

const _green = Color(0xFF669340);
const _dark = Color(0xFF32384A);
const _lightGray = Color(0xFF8F959E);
const _cardBg = Color(0xFFF9FAE8);

/// Tela de edição de solicitação de evento rejeitada.
/// Mesma estrutura da ReservationFormScreen: tela cheia, scroll, botão fixo.
class EventEditScreen extends StatefulWidget {
  const EventEditScreen({super.key, required this.request});

  final EventRequest request;

  @override
  State<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends State<EventEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = GoEventRepository();

  late final TextEditingController _tipoCtrl;
  late final TextEditingController _qtdCtrl;
  late final TextEditingController _objCtrl;
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _contatoCtrl;
  late bool _apoioBPA;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.request;
    _tipoCtrl    = TextEditingController(text: r.tipoAtividade);
    _qtdCtrl     = TextEditingController(text: '${r.quantidadePessoas}');
    _objCtrl     = TextEditingController(text: r.objetivo);
    _nomeCtrl    = TextEditingController(text: r.nomeResponsavel);
    _contatoCtrl = TextEditingController(text: r.contatoResponsavel);
    _apoioBPA    = r.apoioBPA;
  }

  @override
  void dispose() {
    _tipoCtrl.dispose();
    _qtdCtrl.dispose();
    _objCtrl.dispose();
    _nomeCtrl.dispose();
    _contatoCtrl.dispose();
    super.dispose();
  }

  String _formatDate(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    const months = ['jan','fev','mar','abr','mai','jun','jul','ago','set','out','nov','dez'];
    const weekdays = ['Seg','Ter','Qua','Qui','Sex','Sáb','Dom'];
    return '${weekdays[dt.weekday - 1]}, ${dt.day.toString().padLeft(2,'0')} ${months[dt.month - 1]} ${dt.year}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final result = await _repo.updateAndResubmit(widget.request.id, {
      'tipo_atividade':      _tipoCtrl.text.trim(),
      'quantidade_pessoas':  int.tryParse(_qtdCtrl.text.trim()) ?? widget.request.quantidadePessoas,
      'objetivo':            _objCtrl.text.trim(),
      'nome_responsavel':    _nomeCtrl.text.trim(),
      'contato_responsavel': _contatoCtrl.text.trim(),
      'apoio_bpa':           _apoioBPA,
    });

    if (!mounted) return;
    setState(() => _saving = false);

    if (result.success) {
      Navigator.of(context).pop(true);
    } else {
      AppToast.show(context, result.error ?? 'Erro ao atualizar.', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;

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
        centerTitle: true,
        title: Text(
          'Editar solicitação',
          style: GoogleFonts.poppins(
            color: _green,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                children: [

                  // ── Banner motivo de rejeição ─────────────────────────
                  if (r.motivoRejeicao.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F0),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFFCDD2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFFE53935), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Motivo da rejeição',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFE53935),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  r.motivoRejeicao,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: _dark,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Informações fixas (espaço + data + horário) ───────
                  Text(
                    r.tipoAtividade,
                    style: GoogleFonts.poppins(
                      color: _green,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${r.parkName}${r.spaceName.isNotEmpty ? ' · ${r.spaceName}' : ''}',
                    style: GoogleFonts.poppins(fontSize: 14, color: _lightGray),
                  ),
                  const SizedBox(height: 16),

                  _infoRow(Icons.calendar_today_outlined, _formatDate(r.dataEvento)),
                  const SizedBox(height: 6),
                  _infoRow(Icons.access_time_outlined, 'Das ${r.horaInicio} às ${r.horaFim}'),
                  const SizedBox(height: 6),
                  _infoRow(Icons.place_outlined, 'Espaço e data não podem ser alterados aqui'),

                  const SizedBox(height: 28),
                  _sectionTitle('Editar dados'),
                  const SizedBox(height: 14),

                  // ── Tipo de atividade ─────────────────────────────────
                  _formField(
                    controller: _tipoCtrl,
                    label: 'Tipo de atividade',
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                  ),
                  const SizedBox(height: 14),

                  // ── Quantidade de pessoas ─────────────────────────────
                  _formField(
                    controller: _qtdCtrl,
                    label: 'Quantidade de pessoas',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Informe um número válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // ── Objetivo ──────────────────────────────────────────
                  _formField(
                    controller: _objCtrl,
                    label: 'Objetivo do evento',
                    maxLines: 4,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                  ),
                  const SizedBox(height: 14),

                  // ── Nome responsável ──────────────────────────────────
                  _formField(
                    controller: _nomeCtrl,
                    label: 'Nome do responsável',
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                  ),
                  const SizedBox(height: 14),

                  // ── Contato ───────────────────────────────────────────
                  _formField(
                    controller: _contatoCtrl,
                    label: 'Contato (telefone)',
                    keyboardType: TextInputType.phone,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                  ),
                  const SizedBox(height: 20),

                  // ── BPA switch ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.security_outlined, color: _green, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Apoio BPA',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _dark,
                                ),
                              ),
                              Text(
                                'Batalhão de Polícia Ambiental',
                                style: GoogleFonts.poppins(
                                    fontSize: 12, color: _lightGray),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _apoioBPA,
                          onChanged: (v) => setState(() => _apoioBPA = v),
                          activeThumbColor: Colors.white,
                          activeTrackColor: _green,
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: const Color(0xFFCCCCCC),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // ── Botão fixo no rodapé ─────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
              24, 12, 24, 24 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _green.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        'Salvar e Reenviar',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700, fontSize: 16),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: _lightGray),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(fontSize: 13, color: _lightGray),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: _dark,
      ),
    );
  }

  Widget _formField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      validator: validator,
      style: GoogleFonts.poppins(fontSize: 14, color: _dark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(fontSize: 13, color: _lightGray),
        filled: true,
        fillColor: _cardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _green, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53935)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
