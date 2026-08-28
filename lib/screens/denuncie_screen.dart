import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:geolocator/geolocator.dart';

import '../core/api/api_client.dart';
import '../core/api/api_config.dart';
import '../core/checksum.dart';
import '../core/formatters.dart';
import '../data/models/park.dart';
import '../data/repositories/go_park_repository.dart';
import '../services/auth_service.dart';
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

  // Localização do denunciante (GPS — opcional)
  double? _latitude;
  double? _longitude;
  String? _enderecoCapturado;
  bool _loadingGps = false;

  // Local da ocorrência — agora só parque + local específico opcional
  final _localEspecificoController = TextEditingController();

  // Parque relacionado (obrigatório)
  int? _selectedParkId;
  List<Park> _parks = [];
  bool _loadingParks = false;
  bool _parkDropdownOpen = false;
  bool _categoriaDropdownOpen = false;

  // Detalhes
  String _categoria = 'Infraestrutura';
  final _descricaoController = TextEditingController();

  // Fotos
  final List<XFile> _fotosLocais = [];

  // Termos
  bool _concordoTermos = false;
  bool _informacoesVerdadeiras = false;
  bool _confirmacaoError = false;

  bool _enviando = false;
  bool _success = false;
  bool _parkError = false;
  final _scrollController = ScrollController();
  final _parkSectionKey = GlobalKey();

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
    _localEspecificoController.dispose();
    _descricaoController.dispose();
    _scrollController.dispose();
    AuthService.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _preencherDadosUsuario();
    _loadParks();
    // Ouve login feito enquanto a tela já estava na pilha
    AuthService.instance.addListener(_onAuthChanged);
  }

  Future<void> _loadParks() async {
    setState(() => _loadingParks = true);
    final parks = await GoParkRepository().fetchAll();
    if (mounted) {
      setState(() {
        _parks = parks;
        _loadingParks = false;
      });
    }
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

  // ── GPS ───────────────────────────────────────────────────────────────────────

  Future<void> _capturarLocalizacao() async {
    setState(() => _loadingGps = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        AppToast.show(
          context,
          permission == LocationPermission.deniedForever
              ? 'Permissão bloqueada. Ative nas configurações do app.'
              : 'Permissão de localização negada.',
          type: ToastType.warning,
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final endereco = await _reverseGeocode(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _enderecoCapturado = endereco;
      });
      AppToast.show(context, 'Localização capturada!', type: ToastType.success);
    } catch (_) {
      if (!mounted) return;
      AppToast.show(context, 'Erro ao capturar localização.', type: ToastType.error);
    } finally {
      if (mounted) setState(() => _loadingGps = false);
    }
  }

  Future<String?> _reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&accept-language=pt-BR',
      );
      final res = await http.get(uri, headers: {'User-Agent': 'VemProParque/1.0'})
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final addr = data['address'] as Map<String, dynamic>?;
      if (addr == null) return data['display_name'] as String?;
      final parts = <String>[
        if (addr['road'] != null) addr['road'] as String,
        if (addr['suburb'] != null)
          addr['suburb'] as String
        else if (addr['neighbourhood'] != null)
          addr['neighbourhood'] as String,
        if (addr['city'] != null)
          addr['city'] as String
        else if (addr['town'] != null)
          addr['town'] as String,
      ];
      return parts.isNotEmpty ? parts.join(', ') : null;
    } catch (_) {
      return null;
    }
  }

  // ── Upload de fotos ──────────────────────────────────────────────────────────

  Future<void> _pickFotos() async {
    try {
      final picked = await ImagePicker().pickMultiImage(
        imageQuality: 75,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (picked.isEmpty) return;
      if (mounted) setState(() => _fotosLocais.addAll(picked));
    } catch (e) {
      // Android pode lançar PlatformException ('already_active' em toque duplo,
      // ou perda do resultado quando a Activity é recriada sob pressão de memória).
      if (mounted) {
        AppToast.show(context, 'Não foi possível abrir a galeria. Tente novamente.',
            type: ToastType.error);
      }
    }
  }

  Future<String?> _uploadFoto(XFile foto) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/denuncias/upload');
    final bytes = await foto.readAsBytes();
    final req = http.MultipartRequest('POST', uri)
      ..fields['entity_type'] = 'denuncia'
      ..fields['checksum'] = sha256Hex(bytes)
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: foto.name));
    // Quando o parque já foi escolhido, o backend organiza em parques/{id}/denuncias.
    if (_selectedParkId != null) {
      req.fields['park_id'] = _selectedParkId.toString();
    }
    final streamed = await req.send();
    if (streamed.statusCode != 200) return null;
    final body = await streamed.stream.bytesToString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final relUrl = data['url']?.toString();
    if (relUrl == null) return null;
    // Guarda o caminho RELATIVO (ex.: /uploads/parques/5/denuncias/x.jpg);
    // quem exibe (painel admin) prefixa a base.
    return relUrl;
  }

  // ── Submit ───────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    // Validate park first (not a form field)
    if (_selectedParkId == null) {
      setState(() => _parkError = true);
      AppToast.show(context, 'Selecione o parque da ocorrência.',
          type: ToastType.warning);
      final ctx = _parkSectionKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            alignment: 0.1);
      }
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
      return;
    }

    if (!_concordoTermos || !_informacoesVerdadeiras) {
      setState(() => _confirmacaoError = true);
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

      final selectedPark = _parks.where((p) => p.id == _selectedParkId).firstOrNull;
      final body = <String, dynamic>{
        'email': _emailController.text.trim(),
        'nome': _nomeController.text.trim(),
        'celular': _celularController.text.trim(),
        'cidade_denuncia': selectedPark?.name ?? '',
        'endereco_denuncia': selectedPark?.name ?? '',
        'ponto_referencia': _localEspecificoController.text.trim(),
        'categoria': _categoria,
        'descricao': _descricaoController.text.trim(),
        'fotos': fotosUrls,
        'aceitou_termos': _concordoTermos,
        if (_selectedParkId != null) 'park_id': _selectedParkId,
      };

      if (_latitude != null) {
        body['latitude'] = _latitude;
        body['longitude'] = _longitude;
      }

      final response = await ApiClient().post('denuncias', body: body);

      if (!mounted) return;

      if (response.statusCode == 201) {
        if (mounted) setState(() => _success = true);
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        AppToast.show(
          context,
          data['error']?.toString() ?? 'Erro ao enviar colaboração.',
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

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Text(
                'Colaboração enviada\ncom sucesso!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: kBrandGreen,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 220,
                child: SvgPicture.asset(
                  'assets/images/success.svg',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Sua colaboração foi enviada e será\nanalisada pela nossa equipe.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: kDarkGray,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () => context.go('/tabs/home'),
                  style: FilledButton.styleFrom(
                    backgroundColor: kBrandGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  icon: const Icon(Icons.home_outlined, size: 20),
                  label: Text(
                    'Ir para a Home',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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
    if (_success) return _buildSuccessScreen();

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
          'Colabore',
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
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Informe os dados abaixo para registrar sua colaboração.',
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

              // 2. Minha localização (GPS — opcional)
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionHeader(Icons.my_location_outlined, 'Minha localização'),
                    const SizedBox(height: 4),
                    Text(
                      'Opcional. Ajuda os gestores a localizar a sua área.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: kSubtitleColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_latitude != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: kBrandGreen.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: kBrandGreen, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _enderecoCapturado ?? 'Localização capturada',
                                style: GoogleFonts.poppins(fontSize: 13, color: kDarkGray),
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(() {
                                _latitude = null;
                                _longitude = null;
                                _enderecoCapturado = null;
                              }),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(60, 36),
                              ),
                              child: Text(
                                'Remover',
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      OutlinedButton.icon(
                        onPressed: _loadingGps ? null : _capturarLocalizacao,
                        icon: _loadingGps
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: kBrandGreen,
                                ),
                              )
                            : const Icon(Icons.my_location, color: kBrandGreen),
                        label: Text(
                          _loadingGps ? 'Capturando...' : 'Usar minha localização',
                          style: GoogleFonts.poppins(fontSize: 14, color: kBrandGreen),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: kBrandGreen),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
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
                        Icons.location_on_outlined, 'Local da ocorrência'),
                    const SizedBox(height: 20),
                    // Parque (obrigatório) — dropdown customizado inline
                    Container(
                      key: _parkSectionKey,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _parkError ? Colors.red.shade400 : kBrandGreen,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Column(
                        children: [
                          // Trigger
                          GestureDetector(
                            onTap: _loadingParks
                                ? null
                                : () => setState(
                                    () => _parkDropdownOpen = !_parkDropdownOpen),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Icon(Icons.park_outlined,
                                      color: _selectedParkId != null
                                          ? kBrandGreen
                                          : kSubtitleColor,
                                      size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _loadingParks
                                        ? Text(
                                            'Carregando parques...',
                                            style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                color: kSubtitleColor),
                                          )
                                        : Text(
                                            _selectedParkId != null
                                                ? _parks
                                                    .firstWhere((p) =>
                                                        p.id == _selectedParkId)
                                                    .name
                                                : 'Selecione o parque',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: _selectedParkId != null
                                                  ? FontWeight.w500
                                                  : FontWeight.w400,
                                              color: _selectedParkId != null
                                                  ? kDarkGray
                                                  : kSubtitleColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                  ),
                                  if (_loadingParks)
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: kBrandGreen),
                                    )
                                  else
                                    AnimatedRotation(
                                      turns: _parkDropdownOpen ? 0.5 : 0,
                                      duration:
                                          const Duration(milliseconds: 200),
                                      child: const Icon(
                                          Icons.keyboard_arrow_down,
                                          color: kDarkGray),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          // Lista de opções
                          if (_parkDropdownOpen) ...[
                            Divider(
                                height: 1,
                                thickness: 1,
                                color: kBrandGreen.withValues(alpha: 0.3)),
                            ConstrainedBox(
                              constraints:
                                  const BoxConstraints(maxHeight: 220),
                              child: ListView.separated(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: _parks.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: kBrandGreen.withValues(alpha: 0.15),
                                ),
                                itemBuilder: (_, i) {
                                  final p = _parks[i];
                                  final selected = p.id == _selectedParkId;
                                  return InkWell(
                                    onTap: () => setState(() {
                                      _selectedParkId = p.id;
                                      _parkDropdownOpen = false;
                                      _parkError = false;
                                    }),
                                    child: ColoredBox(
                                      color: selected
                                          ? kBrandGreen.withValues(alpha: 0.06)
                                          : Colors.white,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 13),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                p.name,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: selected
                                                      ? FontWeight.w600
                                                      : FontWeight.w400,
                                                  color: selected
                                                      ? kBrandGreen
                                                      : kDarkGray,
                                                ),
                                              ),
                                            ),
                                            if (selected)
                                              const Icon(Icons.check,
                                                  color: kBrandGreen, size: 18),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                        ),
                      ),
                    ),
                    // Local específico (opcional)
                    _buildField(
                      hint: 'Local específico no parque (opcional)',
                      controller: _localEspecificoController,
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

                    // Categoria — dropdown customizado inline
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kBrandGreen, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Column(
                        children: [
                          // Trigger
                          GestureDetector(
                            onTap: () => setState(() =>
                                _categoriaDropdownOpen = !_categoriaDropdownOpen),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _categoria,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: kDarkGray,
                                      ),
                                    ),
                                  ),
                                  AnimatedRotation(
                                    turns: _categoriaDropdownOpen ? 0.5 : 0,
                                    duration: const Duration(milliseconds: 200),
                                    child: const Icon(Icons.keyboard_arrow_down,
                                        color: kDarkGray),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Lista de opções
                          if (_categoriaDropdownOpen) ...[
                            Divider(
                                height: 1,
                                thickness: 1,
                                color: kBrandGreen.withValues(alpha: 0.3)),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.zero,
                              itemCount: _categorias.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                thickness: 1,
                                color: kBrandGreen.withValues(alpha: 0.15),
                              ),
                              itemBuilder: (_, i) {
                                final c = _categorias[i];
                                final selected = c == _categoria;
                                return InkWell(
                                  onTap: () => setState(() {
                                    _categoria = c;
                                    _categoriaDropdownOpen = false;
                                  }),
                                  child: ColoredBox(
                                    color: selected
                                        ? kBrandGreen.withValues(alpha: 0.06)
                                        : Colors.white,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 13),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              c,
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: selected
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                                color: selected
                                                    ? kBrandGreen
                                                    : kDarkGray,
                                              ),
                                            ),
                                          ),
                                          if (selected)
                                            const Icon(Icons.check,
                                                color: kBrandGreen, size: 18),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                        ),
                      ),
                    ),

                    // Descrição
                    _buildField(
                      hint: 'Descreva aqui o que você quer sinalizar ou sugerir...',
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
                                                    color: Colors.white,
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
                    _buildTermosCheckbox(),
                    const SizedBox(height: 4),
                    _buildCheckbox(
                      text: 'Afirmo que as informações aqui prestadas são verdadeiras.',
                      value: _informacoesVerdadeiras,
                      hasError: _confirmacaoError && !_informacoesVerdadeiras,
                      onChanged: (v) => setState(() {
                        _informacoesVerdadeiras = v;
                        if (_concordoTermos && _informacoesVerdadeiras) _confirmacaoError = false;
                      }),
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
        fillColor: Colors.white,
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

  void _mostrarTermos() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TermosSheet(),
    );
  }

  Widget _buildTermosCheckbox() {
    final recognizer = TapGestureRecognizer()..onTap = _mostrarTermos;
    final hasError = _confirmacaoError && !_concordoTermos;
    return GestureDetector(
      onTap: () => setState(() {
        _concordoTermos = !_concordoTermos;
        if (_concordoTermos && _informacoesVerdadeiras) _confirmacaoError = false;
      }),
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
                border: Border.all(
                  color: hasError ? Colors.red : kBrandGreen,
                  width: 2,
                ),
                color: _concordoTermos ? kBrandGreen : Colors.transparent,
              ),
              child: _concordoTermos
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Concordo com os ',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: kDarkGray,
                        height: 1.3,
                      ),
                    ),
                    TextSpan(
                      text: 'termos e condições',
                      recognizer: recognizer,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kBrandGreen,
                        height: 1.3,
                        decoration: TextDecoration.underline,
                        decorationColor: kBrandGreen,
                      ),
                    ),
                    TextSpan(
                      text: '.',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: kDarkGray,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckbox({
    required String text,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool hasError = false,
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
                  border: Border.all(
                    color: hasError ? Colors.red : kBrandGreen,
                    width: 2,
                  ),
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

// ─── Termos e Condições ───────────────────────────────────────────────────────

class _TermosSheet extends StatelessWidget {
  const _TermosSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDE3D5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Icon(Icons.article_outlined, color: kBrandGreen, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Termos e Condições de Uso',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: kDarkGray,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: kSubtitleColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _secao('1. Para que serve',
                        'O "Colabore" é um canal para você registrar problemas, sugestões ou melhorias nos parques públicos gerenciados pela Secretaria de Meio Ambiente e Recursos Hídricos do Maranhão (SEMA-MA).'),
                    _secao('2. O que fazemos com suas informações',
                        'Nome, e-mail, celular, localização e fotos são usados para analisar e responder à sua colaboração. Não repassamos nada disso a terceiros.'),
                    _secao('3. O que você confirma ao enviar',
                        'Ao enviar uma colaboração, você confirma que as informações são verdadeiras e que não está incluindo conteúdo falso, ofensivo ou ilegal. Informações falsas podem gerar responsabilidade civil e criminal.'),
                    _secao('4. Seus dados e a LGPD',
                        'Seus dados são tratados conforme a Lei Geral de Proteção de Dados (Lei nº 13.709/2018). Só compartilhamos informações com terceiros quando a lei exigir isso.'),
                    _secao('5. Sobre as fotos',
                        'As fotos devem mostrar apenas a situação que você está relatando. Não envie imagens que identifiquem pessoas sem a permissão delas.'),
                    _secao('6. Quando você recebe retorno',
                        'A equipe do parque analisa cada colaboração. O prazo varia conforme o caso.'),
                    const SizedBox(height: 8),
                    Text(
                      'Ao marcar "Concordo com os termos e condições", você confirma que leu e aceita o que está aqui.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: kSubtitleColor,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: kBrandGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        child: Text(
                          'Entendido',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _secao(String titulo, String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kDarkGray,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              texto,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: kSubtitleColor,
                height: 1.6,
              ),
            ),
          ],
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
