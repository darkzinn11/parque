// lib/screens/events/event_rules_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/park_event_rule.dart';
import '../../data/repositories/go_event_repository.dart';
import '../../widgets/app_toast.dart';

const _green = Color(0xFF669340);
const _dark = Color(0xFF32384A);
const _lightGray = Color(0xFF8F959E);
const _cardBg = Color(0xFFF9FAE8);

class EventRulesScreen extends StatefulWidget {
  const EventRulesScreen({
    super.key,
    required this.data,
  });

  /// Todos os dados acumulados nos passos anteriores
  final Map<String, dynamic> data;

  @override
  State<EventRulesScreen> createState() => _EventRulesScreenState();
}

class _EventRulesScreenState extends State<EventRulesScreen> {
  final _repo = GoEventRepository();

  bool _loadingRules = true;
  List<ParkEventRule> _rules = [];
  // Controle das checkboxes opcionais — indexed por rule.id
  final Map<int, bool> _checked = {};

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  int get _parkId => widget.data['parkId'] as int;
  String get _tipoAtividade => widget.data['tipoAtividade'] as String? ?? '';

  Future<void> _loadRules() async {
    setState(() => _loadingRules = true);
    final allRules = await _repo.fetchRules(_parkId);

    if (mounted) {
      // Filtra: regras sem tipo (todas) + regras do tipo selecionado
      final filtered = allRules.where((r) {
        return r.tipoAtividade.isEmpty || r.tipoAtividade == _tipoAtividade;
      }).toList();

      // Ordena por ordem
      filtered.sort((a, b) => a.ordem.compareTo(b.ordem));

      // Inicializa checkboxes
      final checked = <int, bool>{};
      for (final rule in filtered) {
        checked[rule.id] = rule.obrigatoria; // obrigatórias já marcadas
      }

      setState(() {
        _rules = filtered;
        _checked.addAll(checked);
        _loadingRules = false;
      });
    }
  }

  Future<void> _submit() async {
    // Verifica se todas as obrigatórias estão marcadas (garantia extra)
    for (final rule in _rules) {
      if (rule.obrigatoria && _checked[rule.id] != true) {
        AppToast.show(
          context,
          'Todas as regras obrigatórias devem ser aceitas.',
          type: ToastType.warning,
        );
        return;
      }
    }

    setState(() => _submitting = true);

    final body = <String, dynamic>{
      'park_id': widget.data['parkId'],
      'space_id': widget.data['spaceId'],
      'data_evento': widget.data['dataEvento'],
      'hora_inicio': widget.data['horaInicio'],
      'hora_fim': widget.data['horaFim'],
      'tipo_atividade': widget.data['tipoAtividade'],
      'quantidade_pessoas': widget.data['quantidadePessoas'],
      'objetivo': widget.data['objetivo'],
      'nome_responsavel': widget.data['nomeResponsavel'],
      'contato_responsavel': widget.data['contatoResponsavel'],
      'apoio_bpa': widget.data['apoioBPA'] ?? false,
    };

    final result = await _repo.create(body);

    if (!mounted) return;

    setState(() => _submitting = false);

    if (result['success'] == true) {
      AppToast.show(context, 'Solicitação enviada!', type: ToastType.success);
      context.go('/tabs/home/eventos/meus-pedidos');
    } else {
      final msg = result['error']?.toString() ?? 'Erro ao enviar solicitação.';
      AppToast.show(context, msg, type: ToastType.error);
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
          icon: const Icon(Icons.arrow_back_ios_new, color: _green),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          'Regras do Evento',
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
            child: _loadingRules
                ? const Center(child: CircularProgressIndicator(color: _green))
                : _buildContent(),
          ),
          _buildConfirmButton(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      children: [
        // Cabeçalho
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: Color(0xFFFFB300), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Leia e aceite as regras abaixo para confirmar sua solicitação de evento.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF5D4037),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        if (_rules.isEmpty)
          _buildNoRules()
        else
          ..._rules.map((rule) => _buildRuleItem(rule)),
      ],
    );
  }

  Widget _buildNoRules() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: _lightGray.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'Nenhuma regra específica',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _dark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Não há regras específicas para este tipo de atividade.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: _lightGray),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleItem(ParkEventRule rule) {
    final isChecked = _checked[rule.id] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: isChecked ? _green.withValues(alpha: 0.06) : _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isChecked ? _green.withValues(alpha: 0.4) : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: CheckboxListTile(
          value: isChecked,
          activeColor: _green,
          checkColor: Colors.white,
          controlAffinity: ListTileControlAffinity.leading,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          onChanged: rule.obrigatoria
              ? null // obrigatórias: desabilitado
              : (val) => setState(() => _checked[rule.id] = val ?? false),
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  rule.texto,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: _dark,
                    height: 1.45,
                  ),
                ),
              ),
              if (rule.obrigatoria) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Obrigatória',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _green,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
      child: FilledButton(
        onPressed: _submitting ? null : _submit,
        style: FilledButton.styleFrom(
          backgroundColor: _green,
          disabledBackgroundColor: _green.withValues(alpha: 0.5),
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _submitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Text(
                'Confirmar Solicitação',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
