import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../core/api/api_client.dart';
import '../../widgets/app_toast.dart';
import 'change_password_screen.dart';

const _green = Color(0xFF669340);
const _dark = Color(0xFF32384A);
const _lightGray = Color(0xFF8F959E);

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cidadeCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _userData;
  final _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final data = await AuthService.instance.me();
    if (!mounted) return;
    setState(() {
      _userData = data;
      _nameCtrl.text = data?['nome'] ?? data?['name'] ?? '';
      _emailCtrl.text = data?['email'] ?? '';
      _phoneCtrl.text = data?['telefone'] ?? data?['phone'] ?? '';
      _cidadeCtrl.text = data?['cidade'] ?? '';
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final Map<String, dynamic> body = {};

      final nome = _nameCtrl.text.trim();
      final email = _emailCtrl.text.trim();
      final telefone = _phoneCtrl.text.trim();
      final cidade = _cidadeCtrl.text.trim();

      if (nome != (_userData?['nome'] ?? _userData?['name'] ?? '')) {
        body['nome'] = nome;
      }
      if (email != (_userData?['email'] ?? '')) body['email'] = email;
      if (telefone != (_userData?['telefone'] ?? _userData?['phone'] ?? '')) {
        body['telefone'] = telefone;
      }
      if (cidade != (_userData?['cidade'] ?? '')) body['cidade'] = cidade;

      if (body.isEmpty) {
        AppToast.show(context, 'Nenhuma alteração detectada.', type: ToastType.warning);
        return;
      }

      final res = await _api.put('/me', body: body);

      if (!mounted) return;

      if (res.statusCode == 200) {
        await AuthService.instance.me();
        if (!mounted) return;
        AppToast.show(context, 'Dados salvos com sucesso!', type: ToastType.success);
        Navigator.of(context).pop();
      } else {
        final msg = _extractError(res.body) ?? 'Falha ao salvar.';
        AppToast.show(context, msg, type: ToastType.error);
      }
    } catch (e) {
      if (mounted) AppToast.show(context, 'Erro de conexão.', type: ToastType.error);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _extractError(String body) {
    try {
      final j = jsonDecode(body);
      return j['error']?.toString();
    } catch (_) {
      return null;
    }
  }

  String _obfuscateEmail(String email) {
    if (email.isEmpty || !email.contains('@')) return '';
    final parts = email.split('@');
    final local = parts[0];
    final domain = parts[1];
    if (local.length <= 3) {
      return '${local[0]}***@$domain';
    }
    return '${local.substring(0, 3)}***@$domain';
  }

  String _obfuscatePhone(String phone) {
    if (phone.isEmpty) return '';
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length < 10) return phone;
    final ddd = clean.substring(0, 2);
    final lastPart = clean.substring(clean.length - 2);
    final middleStart = clean.substring(2, 5);
    return '($ddd)$middleStart**-**$lastPart';
  }

  String _formatShortName(String name) {
    if (name.isEmpty) return '';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length <= 2) return name;
    return '${parts.first} ${parts.last}';
  }


  void _editField({
    required String title,
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    final tempController = TextEditingController(text: controller.text);
    final sheetFormKey = GlobalKey<FormState>();

    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
            child: Form(
              key: sheetFormKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            color: _green,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: _lightGray),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: tempController,
                      keyboardType: keyboardType,
                      textCapitalization: textCapitalization,
                      inputFormatters: inputFormatters,
                      validator: validator,
                      autofocus: true,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _dark,
                      ),
                      decoration: InputDecoration(
                        labelText: label,
                        labelStyle: GoogleFonts.poppins(color: _lightGray, fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFFFFFFE9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFBCC1A6)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFECECEC)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _green, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () {
                        if (sheetFormKey.currentState?.validate() ?? false) {
                          // Retorna o valor e fecha — sem tocar no estado do pai enquanto o sheet está aberto
                          Navigator.pop(sheetCtx, tempController.text);
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Confirmar',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ).then((newValue) {
      // Sheet fechou completamente — seguro atualizar estado e descartar o controller
      if (newValue != null && mounted) {
        setState(() => controller.text = newValue);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => tempController.dispose());
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _cidadeCtrl.dispose();
    super.dispose();
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Dados pessoais',
          style: GoogleFonts.poppins(
            color: _green,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
                children: [
                  _ProfileEditRow(
                    label: 'Alterar nome',
                    value: _nameCtrl.text.isNotEmpty ? _formatShortName(_nameCtrl.text) : 'Não informado',
                    onTap: () => _editField(
                      title: 'Alterar nome',
                      label: 'Nome completo',
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe seu nome'
                          : null,
                    ),
                  ),
                  const _DividerRow(),
                  _ProfileEditRow(
                    label: 'Alterar e-mail',
                    value: _emailCtrl.text.isNotEmpty 
                        ? _obfuscateEmail(_emailCtrl.text) 
                        : 'Não informado',
                    onTap: () => _editField(
                      title: 'Alterar e-mail',
                      label: 'E-mail',
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Informe seu e-mail';
                        }
                        if (!v.contains('@')) return 'E-mail inválido';
                        return null;
                      },
                    ),
                  ),
                  const _DividerRow(),
                  _ProfileEditRow(
                    label: 'Alterar telefone',
                    value: _phoneCtrl.text.isNotEmpty 
                        ? _obfuscatePhone(_phoneCtrl.text) 
                        : 'Não informado',
                    onTap: () => _editField(
                      title: 'Alterar telefone',
                      label: 'Telefone',
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe seu telefone'
                          : null,
                    ),
                  ),
                  const _DividerRow(),
                  _ProfileEditRow(
                    label: 'Alterar cidade',
                    value: _cidadeCtrl.text.isNotEmpty ? _cidadeCtrl.text : 'Não informado',
                    onTap: () => _editField(
                      title: 'Alterar cidade',
                      label: 'Cidade',
                      controller: _cidadeCtrl,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe sua cidade'
                          : null,
                    ),
                  ),
                  const _DividerRow(),
                  _ProfileEditRow(
                    label: 'Alterar senha',
                    value: '................',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ChangePasswordScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFECECEC)),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      disabledBackgroundColor: _green.withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Salvar alterações',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.save_outlined, color: Colors.white, size: 18),
                            ],
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProfileEditRow extends StatelessWidget {
  const _ProfileEditRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _dark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _lightGray,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7EB), // kFigmaBellBg
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.chevron_right,
                        color: _green,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DividerRow extends StatelessWidget {
  const _DividerRow();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: Color(0xFFF5F5F5),
    );
  }
}
