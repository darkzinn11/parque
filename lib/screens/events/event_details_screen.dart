// lib/screens/events/event_details_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../data/models/event_request.dart';
import '../../data/models/park_activity_type.dart';
import '../../data/models/park_event_rule.dart';
import '../../data/repositories/go_event_repository.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_toast.dart';

const _green = Color(0xFF669340);
const _dark = Color(0xFF32384A);
const _lightGray = Color(0xFF8F959E);
const _cardBg = Color(0xFFF9FAE8);

class EventDetailsScreen extends StatefulWidget {
  const EventDetailsScreen({
    super.key,
    required this.parkId,
    required this.spaceIds,
    required this.dataEvento,
    required this.horaInicio,
    required this.horaFim,
    this.editingRequest, // quando não-null, modo edição de rejeitada
  });

  final int parkId;
  final List<int> spaceIds;
  final String dataEvento; // "yyyy-MM-dd"
  final String horaInicio; // "HH:MM"
  final String horaFim;    // "HH:MM"
  final EventRequest? editingRequest;

  bool get isEditing => editingRequest != null;

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = GoEventRepository();

  // Controllers
  final _qtdPessoasCtrl = TextEditingController();
  final _objetivoCtrl = TextEditingController();
  final _nomeCtrl = TextEditingController();
  final _contatoCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _tipoAtividadeFreeCtrl = TextEditingController();

  // State
  bool _loadingTypes = true;
  bool _loadingRules = true;
  List<ParkActivityType> _activityTypes = [];
  List<ParkEventRule> _rules = [];
  ParkActivityType? _selectedType;
  bool _apoioBPA = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadActivityTypes();
    _loadRules();
    if (widget.isEditing) {
      // EventRequest não carrega cpf/email; preenche do usuário logado primeiro,
      // depois sobrescreve os demais campos com os dados da solicitação.
      _prefillUser();
      _prefillEditing(widget.editingRequest!);
    } else {
      _prefillUser();
    }

    // Recalcula regras ao alterar quantidade
    _qtdPessoasCtrl.addListener(() => setState(() {}));
    _tipoAtividadeFreeCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _qtdPessoasCtrl.dispose();
    _objetivoCtrl.dispose();
    _nomeCtrl.dispose();
    _contatoCtrl.dispose();
    _cpfCtrl.dispose();
    _emailCtrl.dispose();
    _tipoAtividadeFreeCtrl.dispose();
    super.dispose();
  }

  void _prefillEditing(EventRequest r) {
    _qtdPessoasCtrl.text  = '${r.quantidadePessoas}';
    _objetivoCtrl.text    = r.objetivo;
    _nomeCtrl.text        = r.nomeResponsavel;
    _contatoCtrl.text     = r.contatoResponsavel;
    _apoioBPA             = r.apoioBPA;
    // Tipo de atividade: tentará match após tipos carregarem (_loadActivityTypes)
    _tipoAtividadeFreeCtrl.text = r.tipoAtividade;
  }

  void _prefillUser() {
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;
    final nome = user['nome']?.toString() ?? user['name']?.toString() ?? '';
    final telefone = user['telefone']?.toString() ?? user['phone']?.toString() ?? '';
    final cpf = user['cpf']?.toString() ?? '';
    final email = user['email']?.toString() ?? '';
    if (nome.isNotEmpty) _nomeCtrl.text = nome;
    if (telefone.isNotEmpty) _contatoCtrl.text = telefone;
    if (cpf.isNotEmpty) _cpfCtrl.text = cpf;
    if (email.isNotEmpty) _emailCtrl.text = email;
  }

  Future<void> _loadActivityTypes() async {
    setState(() => _loadingTypes = true);
    final types = await _repo.fetchActivityTypes(widget.parkId);
    if (mounted) {
      ParkActivityType? preSelected;
      if (widget.isEditing && types.isNotEmpty) {
        final target = widget.editingRequest!.tipoAtividade.toLowerCase();
        preSelected = types.cast<ParkActivityType?>().firstWhere(
          (t) => t!.nome.toLowerCase() == target,
          orElse: () => null,
        );
      }
      setState(() {
        _activityTypes  = types;
        _loadingTypes   = false;
        if (preSelected != null) {
          _selectedType = preSelected;
          _tipoAtividadeFreeCtrl.clear(); // usa chip, não free-text
        }
      });
    }
  }

  Future<void> _loadRules() async {
    setState(() => _loadingRules = true);
    final rules = await _repo.fetchRules(widget.parkId);
    if (mounted) {
      setState(() {
        _rules = rules;
        _loadingRules = false;
      });
    }
  }

  List<ParkEventRule> _getApplicableRules() {
    final qty = int.tryParse(_qtdPessoasCtrl.text) ?? 0;
    final activity = _selectedType?.nome ?? _tipoAtividadeFreeCtrl.text;

    return _rules.where((r) {
      if (!r.ativo) return false;
      // Regra por quantidade: só mostra se qty >= thresholdMin
      if (r.thresholdMin > 0 && qty < r.thresholdMin) return false;
      // Regra por atividade: só mostra se atividade bater
      if (r.tipoAtividade.isNotEmpty) {
        final activities = r.tipoAtividade.split(',').map((s) => s.trim().toLowerCase());
        if (!activities.any((a) =>
            activity.toLowerCase().contains(a) || a.contains(activity.toLowerCase()))) {
          return false;
        }
      }
      return true;
    }).toList()
      ..sort((a, b) => a.ordem.compareTo(b.ordem));
  }

  bool _isBpaForced() {
    final activity = _selectedType?.nome ?? _tipoAtividadeFreeCtrl.text;
    if (activity.isEmpty) return false;
    return _rules.any((r) {
      if (!r.bpaObrigatorio) return false;
      if (r.tipoAtividade.isEmpty) return false;
      final activities = r.tipoAtividade.split(',').map((s) => s.trim().toLowerCase());
      return activities.any(
          (a) => activity.toLowerCase().contains(a) || a.contains(activity.toLowerCase()));
    });
  }

  void _onContinue() {
    if (!_formKey.currentState!.validate()) return;

    final String tipoAtividade;
    if (_activityTypes.isEmpty) {
      tipoAtividade = _tipoAtividadeFreeCtrl.text.trim();
      if (tipoAtividade.isEmpty) {
        AppToast.show(context, 'Informe o tipo de atividade.', type: ToastType.warning);
        return;
      }
    } else {
      if (_selectedType == null) {
        AppToast.show(context, 'Selecione o tipo de atividade.', type: ToastType.warning);
        return;
      }
      tipoAtividade = _selectedType!.nome;
    }

    // Exibe bottom sheet com regras
    _showRulesSheet();
  }

  void _showRulesSheet() {
    final applicableRules = _getApplicableRules();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (_, scrollCtrl) {
            return Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Regras do Parque',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Ao enviar, você declara ter lido e concordar com estas regras.',
                    style: GoogleFonts.poppins(fontSize: 12, color: _lightGray, height: 1.4),
                  ),
                ),

                const SizedBox(height: 12),

                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    children: applicableRules.isEmpty
                        ? [
                            const SizedBox(height: 24),
                            Icon(Icons.check_circle_outline,
                                size: 48, color: _lightGray.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(
                              'Nenhuma regra específica para esta solicitação.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(fontSize: 13, color: _lightGray),
                            ),
                          ]
                        : applicableRules.map((rule) => _buildRuleCard(rule)).toList(),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.fromLTRB(
                      20, 8, 20, MediaQuery.of(ctx).padding.bottom + 16),
                  child: FilledButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            Navigator.of(ctx).pop();
                            _submit();
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      minimumSize: const Size(double.infinity, 54),
                      shape:
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Confirmar e Enviar',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRuleCard(ParkEventRule rule) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: rule.obrigatoria ? _green.withValues(alpha: 0.35) : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    rule.titulo.isNotEmpty ? rule.titulo : 'Regra',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                ),
                if (rule.obrigatoria)
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
            ),
            if (rule.texto.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                rule.texto,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: _dark,
                  height: 1.45,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    final String tipoAtividade = _activityTypes.isEmpty
        ? _tipoAtividadeFreeCtrl.text.trim()
        : _selectedType!.nome;

    final body = <String, dynamic>{
      'tipo_atividade':      tipoAtividade,
      'quantidade_pessoas':  int.tryParse(_qtdPessoasCtrl.text.trim()) ?? 0,
      'objetivo':            _objetivoCtrl.text.trim(),
      'nome_responsavel':    _nomeCtrl.text.trim(),
      'contato_responsavel': _contatoCtrl.text.trim(),
      'apoio_bpa':           _apoioBPA,
    };

    if (widget.isEditing) {
      // Modo edição: atualiza campos e reenvía a solicitação rejeitada
      final result = await _repo.updateAndResubmit(widget.editingRequest!.id, body);
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      if (result.success) {
        Navigator.of(context).pop(true);
      } else {
        AppToast.show(context, result.error ?? 'Erro ao atualizar.', type: ToastType.error);
      }
    } else {
      // Modo criação: cria nova solicitação
      final fullBody = {
        ...body,
        'park_id':            widget.parkId,
        'space_ids':          widget.spaceIds,
        'data_evento':        widget.dataEvento,
        'hora_inicio':        widget.horaInicio,
        'hora_fim':           widget.horaFim,
        'tipo_atividade_id':  _selectedType?.id ?? 0,
        'cpf_responsavel':    _cpfCtrl.text.replaceAll(RegExp(r'\D'), ''),
        'email_responsavel':  _emailCtrl.text.trim(),
      };
      final result = await _repo.create(fullBody);
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      if (result['success'] == true) {
        context.pushReplacement('/tabs/home/eventos/sucesso');
      } else {
        final msg = result['error']?.toString() ?? 'Erro ao enviar solicitação.';
        AppToast.show(context, msg, type: ToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bpaForced = _isBpaForced();
    if (bpaForced && !_apoioBPA) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_apoioBPA) setState(() => _apoioBPA = true);
      });
    }

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
          widget.isEditing ? 'Editar Evento' : 'Detalhes do Evento',
          style: GoogleFonts.poppins(
            color: _green,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  // Banner resumo
                  _buildSummaryBanner(),
                  const SizedBox(height: 20),

                  // Tipo de atividade
                  _buildLabel('Tipo de Atividade'),
                  const SizedBox(height: 8),
                  _loadingTypes ? _buildLoadingDropdown() : _buildActivityDropdown(),

                  const SizedBox(height: 16),

                  // Quantidade de pessoas
                  _buildLabel('Quantidade de Pessoas'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _qtdPessoasCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.poppins(fontSize: 14, color: _dark),
                    decoration: _inputDecoration('Ex: 50', icon: Icons.people_outline),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Informe a quantidade';
                      final n = int.tryParse(v.trim());
                      if (n == null || n <= 0) return 'Informe um número válido';
                      return null;
                    },
                  ),

                  // Aviso dinâmico por quantidade
                  _buildQtyWarning(),

                  const SizedBox(height: 16),

                  // Objetivo do evento
                  _buildLabel('Objetivo do Evento'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _objetivoCtrl,
                    maxLines: 4,
                    minLines: 3,
                    style: GoogleFonts.poppins(fontSize: 14, color: _dark),
                    decoration: _inputDecoration(
                      'Descreva o objetivo do evento...',
                      icon: Icons.description_outlined,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Descreva o objetivo';
                      if (v.trim().length < 20) return 'Descreva com mais detalhes (mín. 20 caracteres)';
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Nome do responsável
                  _buildLabel('Nome do Responsável'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nomeCtrl,
                    textCapitalization: TextCapitalization.words,
                    style: GoogleFonts.poppins(fontSize: 14, color: _dark),
                    decoration: _inputDecoration('Nome completo', icon: Icons.person_outline),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Informe o nome do responsável';
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Contato do responsável
                  _buildLabel('Telefone do Responsável'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _contatoCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [PhoneFormatter()],
                    style: GoogleFonts.poppins(fontSize: 14, color: _dark),
                    decoration: _inputDecoration('(XX) XXXXX-XXXX', icon: Icons.phone_outlined),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Informe o telefone';
                      final digits = v.replaceAll(RegExp(r'\D'), '');
                      if (digits.length < 10) return 'Telefone inválido';
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // CPF do responsável
                  _buildLabel('CPF do Responsável'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _cpfCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CpfFormatter()],
                    style: GoogleFonts.poppins(fontSize: 14, color: _dark),
                    decoration: _inputDecoration('XXX.XXX.XXX-XX', icon: Icons.badge_outlined),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Informe o CPF';
                      final digits = v.replaceAll(RegExp(r'\D'), '');
                      if (digits.length != 11) return 'CPF inválido';
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Email do responsável
                  _buildLabel('E-mail do Responsável'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.poppins(fontSize: 14, color: _dark),
                    decoration: _inputDecoration('email@exemplo.com', icon: Icons.email_outlined),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Informe o e-mail';
                      if (!v.contains('@') || !v.contains('.')) return 'E-mail inválido';
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Switch BPA
                  Container(
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SwitchListTile.adaptive(
                      value: _apoioBPA,
                      activeThumbColor: Colors.white,
                      activeTrackColor: _green,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text(
                        'Solicitar apoio da BPA',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _dark,
                        ),
                      ),
                      subtitle: Text(
                        bpaForced
                            ? 'Obrigatório para esta atividade'
                            : 'Batalhão de Polícia Ambiental',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: bpaForced ? _green : _lightGray,
                          fontWeight: bpaForced ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      onChanged: bpaForced ? null : (val) => setState(() => _apoioBPA = val),
                    ),
                  ),
                ],
              ),
            ),

            // Botão Enviar Solicitação
            Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
              child: FilledButton(
                onPressed: _isSubmitting ? null : _onContinue,
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  disabledBackgroundColor: _green.withValues(alpha: 0.5),
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Enviar Solicitação',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBanner() {
    String formattedDate = widget.dataEvento;
    try {
      final parsed = DateTime.parse(widget.dataEvento);
      formattedDate = DateFormat("EEEE, dd 'de' MMMM 'de' yyyy", 'pt_BR').format(parsed);
      formattedDate = formattedDate[0].toUpperCase() + formattedDate.substring(1);
    } catch (_) {}

    final spacesLabel = widget.spaceIds.length == 1
        ? '1 espaço'
        : '${widget.spaceIds.length} espaços';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _green.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_outlined, color: _green, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formattedDate,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
                Text(
                  '${widget.horaInicio} às ${widget.horaFim}  •  $spacesLabel',
                  style: GoogleFonts.poppins(fontSize: 12, color: _lightGray),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyWarning() {
    final qty = int.tryParse(_qtdPessoasCtrl.text) ?? 0;
    if (qty <= 0 || _loadingRules) return const SizedBox.shrink();

    final triggeredRules = _rules.where((r) {
      if (!r.ativo) return false;
      return r.thresholdMin > 0 && qty >= r.thresholdMin;
    }).toList();

    if (triggeredRules.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB300), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Para $qty pessoas, regras adicionais serão aplicadas. Você poderá revisá-las antes de enviar.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF5D4037),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: _dark,
      ),
    );
  }

  Widget _buildLoadingDropdown() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _green, width: 1.2),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: _green),
          ),
          const SizedBox(width: 12),
          Text(
            'Carregando tipos de atividade...',
            style: GoogleFonts.poppins(fontSize: 14, color: _lightGray),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityDropdown() {
    if (_activityTypes.isEmpty) {
      return TextFormField(
        controller: _tipoAtividadeFreeCtrl,
        textCapitalization: TextCapitalization.sentences,
        style: GoogleFonts.poppins(fontSize: 14, color: _dark),
        decoration: _inputDecoration(
          'Ex: Show Cultural, Torneio Esportivo...',
          icon: Icons.category_outlined,
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Informe o tipo de atividade';
          return null;
        },
      );
    }

    return DropdownButtonFormField<ParkActivityType>(
      initialValue: _selectedType,
      decoration: _inputDecoration('Selecione o tipo de atividade', icon: Icons.category_outlined),
      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: _dark),
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(16),
      isExpanded: true,
      hint: Text(
        'Selecione o tipo de atividade',
        style: GoogleFonts.poppins(fontSize: 14, color: _lightGray),
      ),
      items: _activityTypes
          .map((t) => DropdownMenuItem(
                value: t,
                child: Text(
                  t.nome,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 14, color: _dark),
                ),
              ))
          .toList(),
      onChanged: (v) => setState(() => _selectedType = v),
      validator: (_) => _selectedType == null ? 'Selecione o tipo de atividade' : null,
    );
  }

  InputDecoration _inputDecoration(String hint, {IconData? icon}) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(fontSize: 14, color: _lightGray),
        prefixIcon: icon != null
            ? Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: Icon(icon, color: _green.withValues(alpha: 0.8), size: 20),
              )
            : null,
        prefixIconConstraints: const BoxConstraints(),
        filled: true,
        fillColor: _cardBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _green, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _green, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _green, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      );
}
