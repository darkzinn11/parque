import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../core/api/api_client.dart';
import '../core/api/api_config.dart';
import '../core/formatters.dart';
import '../services/auth_service.dart';
import '../services/cep_service.dart';
import '../widgets/app_toast.dart';

const kBrandGreen = Color(0xFF669340);
const kDarkGray = Color(0xFF32384A);
const kSubtitleColor = Color(0xFF6B7280);

// ─── Tela ─────────────────────────────────────────────────────────────────────

class DenuncieScreen extends StatefulWidget {
  const DenuncieScreen({super.key});

  @override
  State<DenuncieScreen> createState() => _DenuncieScreenState();
}

class _DenuncieScreenState extends State<DenuncieScreen> {
  final _formKey = GlobalKey<FormState>();

  // Dados pessoais
  final _emailController = TextEditingController();
  final _nomeController = TextEditingController();
  final _celularController = TextEditingController();

  // Endereço do denunciante (lazy — criados ao ativar o switch)
  bool _informarEndereco = false;
  TextEditingController? _cepController;
  TextEditingController? _ruaController;
  TextEditingController? _numeroController;
  TextEditingController? _complementoController;
  TextEditingController? _bairroController;

  // Local da denúncia
  final _cepLocalController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _enderecoDenunciaController = TextEditingController();
  final _pontoReferenciaController = TextEditingController();

  // Detalhes
  String _categoria = 'Infraestrutura';
  final _descricaoController = TextEditingController();

  // Fotos
  final List<XFile> _fotosLocais = [];

  // Termos
  bool _concordoTermos = false;
  bool _informacoesVerdadeiras = false;

  bool _enviando = false;
  bool _loadingCepEndereco = false;
  bool _loadingCepLocal = false;
  int _cepEnderecoSeq = 0;
  int _cepLocalSeq = 0;

  static const _categorias = [
    'Infraestrutura',
    'Vandalismo',
    'Descarte irregular',
    'Segurança',
    'Acessibilidade',
    'Animais',
    'Iluminação',
    'Outros',
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _nomeController.dispose();
    _celularController.dispose();
    _cepController?.dispose();
    _ruaController?.dispose();
    _numeroController?.dispose();
    _complementoController?.dispose();
    _bairroController?.dispose();
    _cepLocalController.dispose();
    _cidadeController.dispose();
    _enderecoDenunciaController.dispose();
    _pontoReferenciaController.dispose();
    _descricaoController.dispose();
    AuthService.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _preencherDadosUsuario();
    // Ouve login feito enquanto a tela já estava na pilha
    AuthService.instance.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    // Só preenche se os campos ainda estiverem vazios (não sobrescreve edição manual)
    if (AuthService.instance.currentUser != null &&
        _emailController.text.isEmpty) {
      _preencherDadosUsuario();
    }
  }

  void _preencherDadosUsuario() {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    _emailController.text = user['email']?.toString() ?? '';
    _nomeController.text = user['nome']?.toString() ?? '';
    _celularController.text = user['telefone']?.toString() ?? '';
  }

  // ── CEP ───────────────────────────────────────────────────────────────────────

  Future<void> _onCepEnderecoChanged(String value) async {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) return;

    final seq = ++_cepEnderecoSeq;
    setState(() => _loadingCepEndereco = true);
    final result = await CepService.fetch(digits);
    if (!mounted || seq != _cepEnderecoSeq) return;
    setState(() => _loadingCepEndereco = false);

    if (result == null) {
      AppToast.show(context, 'CEP não encontrado.', type: ToastType.warning);
      return;
    }
    _ruaController?.text = result.logradouro;
    _bairroController?.text = result.bairro;
  }

  Future<void> _onCepLocalChanged(String value) async {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) return;

    final seq = ++_cepLocalSeq;
    setState(() => _loadingCepLocal = true);
    final result = await CepService.fetch(digits);
    if (!mounted || seq != _cepLocalSeq) return;
    setState(() => _loadingCepLocal = false);

    if (result == null) {
      AppToast.show(context, 'CEP não encontrado.', type: ToastType.warning);
      return;
    }
    _cidadeController.text = '${result.localidade} - ${result.uf}';
    if (_enderecoDenunciaController.text.isEmpty) {
      _enderecoDenunciaController.text = result.logradouro;
    }
  }

  void _toggleEndereco(bool val) {
    if (val && _cepController == null) {
      _cepController = TextEditingController();
      _ruaController = TextEditingController();
      _numeroController = TextEditingController();
      _complementoController = TextEditingController();
      _bairroController = TextEditingController();
    }
    setState(() => _informarEndereco = val);
  }

  // ── Upload de fotos ──────────────────────────────────────────────────────────

  Future<void> _pickFotos() async {
    final picked = await ImagePicker().pickMultiImage(
      imageQuality: 75,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (picked.isEmpty) return;
    setState(() => _fotosLocais.addAll(picked));
  }

  Future<String?> _uploadFoto(XFile foto) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/denuncias/upload');
    final req = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', foto.path));
    final streamed = await req.send();
    if (streamed.statusCode != 200) return null;
    final body = await streamed.stream.bytesToString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final relUrl = data['url']?.toString();
    if (relUrl == null) return null;
    // relUrl is like /api/v1/uploads/filename.jpg
    return '${ApiConfig.baseUrl.replaceFirst('/api/v1', '')}$relUrl';
  }

  // ── Submit ───────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_concordoTermos || !_informacoesVerdadeiras) {
      AppToast.show(
        context,
        'Aceite os termos e confirme a veracidade das informações.',
        type: ToastType.warning,
      );
      return;
    }

    setState(() => _enviando = true);

    try {
      // Upload fotos primeiro
      final fotosUrls = <String>[];
      for (final foto in _fotosLocais) {
        final url = await _uploadFoto(foto);
        if (url != null) fotosUrls.add(url);
      }

      final body = <String, dynamic>{
        'email': _emailController.text.trim(),
        'nome': _nomeController.text.trim(),
        'celular': _celularController.text.trim(),
        'cidade_denuncia': _cidadeController.text.trim(),
        'endereco_denuncia': _enderecoDenunciaController.text.trim(),
        'ponto_referencia': _pontoReferenciaController.text.trim(),
        'categoria': _categoria,
        'descricao': _descricaoController.text.trim(),
        'fotos': fotosUrls,
      };

      if (_informarEndereco) {
        body['cep'] = _cepController?.text.trim() ?? '';
        body['rua'] = _ruaController?.text.trim() ?? '';
        body['numero'] = _numeroController?.text.trim() ?? '';
        body['complemento'] = _complementoController?.text.trim() ?? '';
        body['bairro'] = _bairroController?.text.trim() ?? '';
      }

      final response = await ApiClient().post('denuncias', body: body);

      if (!mounted) return;

      if (response.statusCode == 201) {
        _mostrarDialogoSucesso(context);
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        AppToast.show(
          context,
          data['error']?.toString() ?? 'Erro ao enviar denúncia.',
          type: ToastType.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, 'Falha de conexão. Tente novamente.', type: ToastType.error);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _mostrarDialogoSucesso(BuildContext outerContext) {
    showDialog(
      context: outerContext,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF0FDF4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Color(0xFF16A34A),
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Obrigado pelo seu relato!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: kDarkGray,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sua denúncia de $_categoria foi registrada com sucesso e nossa equipe já foi notificada.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: kDarkGray.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBrandGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    outerContext.pop();
                  },
                  child: Text(
                    'Entendido',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: kBrandGreen),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Faça sua denúncia',
          style: GoogleFonts.poppins(
            color: kBrandGreen,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Informe os dados abaixo para registrar sua denúncia.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: kSubtitleColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // 1. Dados pessoais
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionHeader(Icons.person_outline, 'Dados pessoais'),
                    const SizedBox(height: 20),
                    _buildField(
                      hint: 'E-mail',
                      controller: _emailController,
                      icon: Icons.mail_outlined,
                      type: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Informe o e-mail';
                        final valid = RegExp(
                          r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                        ).hasMatch(v.trim());
                        return valid ? null : 'E-mail inválido';
                      },
                    ),
                    _buildField(
                      hint: 'Nome completo',
                      controller: _nomeController,
                      icon: Icons.person_outline,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Informe o nome' : null,
                    ),
                    _buildField(
                      hint: 'Celular',
                      controller: _celularController,
                      icon: Icons.phone_outlined,
                      type: TextInputType.phone,
                      formatters: [PhoneFormatter()],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Informe o celular';
                        final digits = v.replaceAll(RegExp(r'\D'), '');
                        return digits.length < 10 ? 'Celular inválido' : null;
                      },
                    ),
                  ],
                ),
              ),

              // 2. Endereço (opcional)
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Informar meu endereço',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: kDarkGray,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Opcional. Selecione para informar.',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: _informarEndereco,
                          thumbColor: WidgetStateProperty.all(Colors.white),
                          trackColor: WidgetStateProperty.resolveWith((states) =>
                              states.contains(WidgetState.selected)
                                  ? kBrandGreen
                                  : const Color(0xFFE5E7EB)),
                          onChanged: _toggleEndereco,
                        ),
                      ],
                    ),
                    if (_informarEndereco) ...[
                      const SizedBox(height: 20),
                      _buildField(
                        hint: 'CEP',
                        controller: _cepController!,
                        type: TextInputType.number,
                        formatters: [CepFormatter()],
                        onChanged: _onCepEnderecoChanged,
                        suffixLoading: _loadingCepEndereco,
                      ),
                      _buildField(hint: 'Rua', controller: _ruaController!),
                      Row(
                        children: [
                          Expanded(
                            flex: 35,
                            child: _buildField(
                              hint: 'Número',
                              controller: _numeroController!,
                              type: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 65,
                            child: _buildField(
                              hint: 'Complemento',
                              controller: _complementoController!,
                            ),
                          ),
                        ],
                      ),
                      _buildField(hint: 'Bairro', controller: _bairroController!),
                    ],
                  ],
                ),
              ),

              // 3. Local da denúncia
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionHeader(
                        Icons.location_on_outlined, 'Local da denúncia'),
                    const SizedBox(height: 20),
                    _buildField(
                      hint: 'CEP do local (opcional)',
                      controller: _cepLocalController,
                      type: TextInputType.number,
                      formatters: [CepFormatter()],
                      onChanged: _onCepLocalChanged,
                      suffixLoading: _loadingCepLocal,
                    ),
                    _buildField(
                      hint: 'Cidade da denúncia',
                      controller: _cidadeController,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Informe a cidade' : null,
                    ),
                    _buildField(
                      hint: 'Endereço da denúncia',
                      controller: _enderecoDenunciaController,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Informe o endereço' : null,
                    ),
                    _buildField(
                      hint: 'Ponto de referência (opcional)',
                      controller: _pontoReferenciaController,
                    ),
                  ],
                ),
              ),

              // 4. Detalhes
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionHeader(
                        Icons.assignment_outlined, 'Detalhes e anexos'),
                    const SizedBox(height: 20),

                    // Categoria
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        value: _categoria,
                        decoration: _inputDecoration('Categoria'),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: kDarkGray,
                        ),
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        items: _categorias
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) => setState(() => _categoria = v!),
                        validator: (v) => v == null ? 'Selecione uma categoria' : null,
                      ),
                    ),

                    // Descrição
                    _buildField(
                      hint: 'Descreva a denúncia aqui...',
                      controller: _descricaoController,
                      maxLines: 4,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Descreva o problema' : null,
                    ),

                    const SizedBox(height: 4),

                    // Área de fotos
                    CustomPaint(
                      painter: const DashedRectPainter(),
                      child: InkWell(
                        onTap: _pickFotos,
                        borderRadius: BorderRadius.circular(16),
                        child: _fotosLocais.isEmpty
                            ? Container(
                                height: 110,
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_a_photo_outlined,
                                        color: kBrandGreen, size: 36),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Anexar fotos',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: kBrandGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: 80,
                                      child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: _fotosLocais.length + 1,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(width: 8),
                                        itemBuilder: (_, i) {
                                          if (i == _fotosLocais.length) {
                                            return GestureDetector(
                                              onTap: _pickFotos,
                                              child: Container(
                                                width: 80,
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                      color: kBrandGreen,
                                                      width: 1.5),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: const Icon(
                                                    Icons.add_photo_alternate_outlined,
                                                    color: kBrandGreen),
                                              ),
                                            );
                                          }
                                          return Stack(
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: Image.file(
                                                  File(_fotosLocais[i].path),
                                                  width: 80,
                                                  height: 80,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      Container(
                                                    width: 80,
                                                    height: 80,
                                                    color: const Color(0xFFF5F7EB),
                                                    child: const Icon(
                                                        Icons.image_outlined,
                                                        color: kBrandGreen),
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                top: 4,
                                                right: 4,
                                                child: GestureDetector(
                                                  onTap: () => setState(
                                                      () => _fotosLocais.removeAt(i)),
                                                  child: Container(
                                                    width: 20,
                                                    height: 20,
                                                    decoration: const BoxDecoration(
                                                      color: Colors.red,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(Icons.close,
                                                        color: Colors.white, size: 13),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${_fotosLocais.length} foto${_fotosLocais.length != 1 ? 's' : ''} selecionada${_fotosLocais.length != 1 ? 's' : ''}',
                                      style: GoogleFonts.poppins(
                                          fontSize: 12, color: kBrandGreen),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tamanho máximo por arquivo: 5 MB.',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: const Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              ),

              // 5. Confirmação
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionHeader(
                        Icons.check_circle_outline_rounded, 'Confirmação'),
                    const SizedBox(height: 20),
                    _buildCheckbox(
                      text: 'Concordo com os termos e condições.',
                      value: _concordoTermos,
                      onChanged: (v) => setState(() => _concordoTermos = v),
                    ),
                    const SizedBox(height: 4),
                    _buildCheckbox(
                      text: 'Afirmo que as informações aqui prestadas são verdadeiras.',
                      value: _informacoesVerdadeiras,
                      onChanged: (v) => setState(() => _informacoesVerdadeiras = v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBrandGreen,
                    disabledBackgroundColor: kBrandGreen.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _enviando ? null : _submit,
                  child: _enviando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Enviar ocorrência',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers de layout ────────────────────────────────────────────────────────

  Widget _buildCard({required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );

  Widget _buildSectionHeader(IconData icon, String title) => Row(
        children: [
          Icon(icon, color: kBrandGreen, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: kDarkGray,
            ),
          ),
        ],
      );

  InputDecoration _inputDecoration(String hint, {IconData? icon}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: const Color(0xFF9CA3AF),
        ),
        prefixIcon: icon != null
            ? Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: Icon(icon,
                    color: kBrandGreen.withValues(alpha: 0.8), size: 20),
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFFAFBF0),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: Color(0xFF669340), width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: Color(0xFF669340), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: Color(0xFF669340), width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: Colors.red, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      );

  Widget _buildField({
    required String hint,
    required TextEditingController controller,
    IconData? icon,
    TextInputType type = TextInputType.text,
    List<TextInputFormatter>? formatters,
    int maxLines = 1,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    bool suffixLoading = false,
  }) {
    final decoration = suffixLoading
        ? _inputDecoration(hint, icon: icon).copyWith(
            suffixIcon: const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: kBrandGreen),
              ),
            ),
          )
        : _inputDecoration(hint, icon: icon);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        maxLines: maxLines,
        inputFormatters: formatters,
        onChanged: onChanged,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: kDarkGray,
        ),
        decoration: decoration,
        validator: validator,
      ),
    );
  }

  Widget _buildCheckbox({
    required String text,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      GestureDetector(
        onTap: () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: kBrandGreen, width: 2),
                  color: value ? kBrandGreen : Colors.transparent,
                ),
                child: value
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: kDarkGray,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

// ─── DashedRectPainter ────────────────────────────────────────────────────────

class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dashLength;
  final double borderRadius;

  const DashedRectPainter({
    this.color = kBrandGreen,
    this.strokeWidth = 1.2,
    this.gap = 4.0,
    this.dashLength = 6.0,
    this.borderRadius = 16.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));

    canvas.drawPath(_dashedPath(path), paint);
  }

  Path _dashedPath(Path source) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final len = draw ? dashLength : gap;
        if (draw) {
          dest.addPath(
            metric.extractPath(distance, distance + len),
            Offset.zero,
          );
        }
        distance += len;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant DashedRectPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.gap != gap ||
      old.dashLength != dashLength ||
      old.borderRadius != borderRadius;
}
