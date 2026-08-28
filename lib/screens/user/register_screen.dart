import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/formatters.dart';
import '../../services/auth_service.dart';
import '../../services/cep_service.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/password_strength_indicator.dart';

const kGreen   = Color(0xFF669340);
const kDark    = Color(0xFF32384A);
const kBg      = Colors.white;
const kHint    = Color(0xFF9AA3AF);
const kInputBg = Color(0xFFFFFFE9);

InputDecoration _box({String? hint, String? helper, Widget? suffix}) {
  return InputDecoration(
    hintText: hint,
    helperText: helper,
    helperStyle: const TextStyle(fontSize: 12, height: 1.4, color: kHint),
    floatingLabelBehavior: FloatingLabelBehavior.never,
    filled: true,
    fillColor: kInputBg,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    constraints: const BoxConstraints(minHeight: 56),
    hintStyle: const TextStyle(color: kHint, fontSize: 16, height: 1.5),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: kGreen, width: 2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: kGreen, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Colors.red, width: 2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Colors.red, width: 2),
    ),
    suffixIcon: suffix,
    suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
  );
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: kDark,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _auth   = AuthService.instance;
  final _form   = GlobalKey<FormState>();
  final _scroll = ScrollController();

  // Dados pessoais
  final _name    = TextEditingController();
  final _cpf     = TextEditingController();
  final _email   = TextEditingController();
  final _phone   = TextEditingController();

  // Endereço
  final _cep         = TextEditingController();
  final _rua         = TextEditingController();
  final _numero      = TextEditingController();
  final _complemento = TextEditingController();
  final _bairro      = TextEditingController();
  final _cidade      = TextEditingController();

  // Senha
  final _pass    = TextEditingController();
  final _confirm = TextEditingController();

  bool _loading        = false;
  bool _triedSubmit    = false;
  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  bool _accept         = false;
  bool _loadingCep     = false;
  int  _cepSeq         = 0;
  String _passValue    = '';
  String? _topError;

  @override
  void dispose() {
    _scroll.dispose();
    _name.dispose(); _cpf.dispose(); _email.dispose(); _phone.dispose();
    _cep.dispose(); _rua.dispose(); _numero.dispose();
    _complemento.dispose(); _bairro.dispose(); _cidade.dispose();
    _pass.dispose(); _confirm.dispose();
    super.dispose();
  }

  // ── CEP auto-fill ───────────────────────────────────────────────────────────

  Future<void> _onCepChanged(String value) async {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) return;

    final seq = ++_cepSeq;
    setState(() => _loadingCep = true);
    final result = await CepService.fetch(digits);
    if (!mounted || seq != _cepSeq) return;
    setState(() => _loadingCep = false);

    if (result == null) {
      AppToast.show(context, 'CEP não encontrado.', type: ToastType.warning);
      return;
    }
    _rua.text    = result.logradouro;
    _bairro.text = result.bairro;
    _cidade.text = '${result.localidade} - ${result.uf}';
    if (_triedSubmit) _form.currentState?.validate();
  }

  // ── Validações ──────────────────────────────────────────────────────────────

  String? _valName(String? v) {
    if (!_triedSubmit) return null;
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Informe seu nome completo';
    if (t.length < 3) return 'Nome muito curto';
    return null;
  }

  String? _valCpf(String? v) {
    if (!_triedSubmit) return null;
    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Informe o CPF';
    if (!_isValidCpf(digits)) return 'CPF inválido';
    return null;
  }

  String? _valEmail(String? v) {
    if (!_triedSubmit) return null;
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Informe o e-mail';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(t)) return 'E-mail inválido';
    return null;
  }

  String? _valPhone(String? v) {
    if (!_triedSubmit) return null;
    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Informe o celular';
    if (digits.length < 10) return 'Celular inválido';
    return null;
  }

  String? _valCep(String? v) {
    if (!_triedSubmit) return null;
    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Informe o CEP';
    if (digits.length != 8) return 'CEP inválido';
    return null;
  }

  String? _valRequired(String? v, String label) {
    if (!_triedSubmit) return null;
    if ((v ?? '').trim().isEmpty) return 'Informe $label';
    return null;
  }

  String? _valPass(String? v) {
    if (!_triedSubmit) return null;
    return PasswordRules.validate(v);
  }

  String? _valConfirm(String? v) {
    if (!_triedSubmit) return null;
    if ((v ?? '').isEmpty) return 'Confirme a senha';
    if (v != _pass.text) return 'As senhas não conferem';
    return null;
  }

  bool _isValidCpf(String cpf) {
    if (cpf.length != 11) return false;
    if (RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) return false;
    final n = cpf.split('').map(int.parse).toList();
    int d1 = 0, d2 = 0;
    for (int i = 0; i < 9; i++) {
      d1 += n[i] * (10 - i);
      d2 += n[i] * (11 - i);
    }
    d1 = (d1 * 10) % 11; if (d1 == 10) d1 = 0;
    d2 = (d2 + d1 * 2) * 10 % 11; if (d2 == 10) d2 = 0;
    return d1 == n[9] && d2 == n[10];
  }

  // ── Submit ──────────────────────────────────────────────────────────────────

  Future<void> _doSignUp() async {
    FocusScope.of(context).unfocus();
    setState(() { _triedSubmit = true; _topError = null; });

    final valid = _form.currentState?.validate() ?? false;
    if (!_accept) {
      setState(() => _topError =
          'Você precisa aceitar os Termos de Uso e a Política de Privacidade.');
    }
    if (!valid || !_accept) {
      AppToast.show(context, 'Corrija os campos em vermelho.', type: ToastType.error);
      return;
    }

    setState(() { _loading = true; _topError = null; });

    final ok = await _auth.signup(
      username: _name.text.trim(),
      email: _email.text.trim(),
      password: _pass.text,
      phone: _phone.text.trim(),
      cpf: _cpf.text.replaceAll(RegExp(r'\D'), ''),
      cidade: _cidade.text.trim(),
      cep: _cep.text.replaceAll(RegExp(r'\D'), ''),
      rua: _rua.text.trim(),
      numero: _numero.text.trim(),
      complemento: _complemento.text.trim(),
      bairro: _bairro.text.trim(),
      aceitouTermos: _accept,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (ok == true) {
      context.go('/user/register-success');
    } else {
      final errMsg = (ok is String && ok.isNotEmpty)
          ? ok
          : 'Não foi possível cadastrar. Verifique os dados.';
      setState(() => _topError = errMsg);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Form(
            key: _form,
            autovalidateMode: _triedSubmit
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Cadastro',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: kGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Crie sua conta rapidinho e aproveite tudo o que o parque oferece.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kDark, fontSize: 15, height: 1.5),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('Já possui cadastro? ',
                        style: TextStyle(color: kDark, fontSize: 15)),
                    _LoginLink(),
                  ],
                ),
                const SizedBox(height: 24),

                if (_topError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: .08),
                      border: Border.all(color: Colors.red),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_topError!,
                              style: const TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Seção: Dados pessoais ──────────────────────────────────
                _SectionHeader(label: 'Dados pessoais'),
                const SizedBox(height: 16),

                _Labeled(
                  label: 'Nome completo',
                  child: TextFormField(
                    controller: _name,
                    validator: _valName,
                    textCapitalization: TextCapitalization.words,
                    decoration: _box(hint: 'Seu nome completo'),
                  ),
                ),
                const SizedBox(height: 16),

                _Labeled(
                  label: 'CPF',
                  child: TextFormField(
                    controller: _cpf,
                    validator: _valCpf,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CpfFormatter()],
                    decoration: _box(hint: '000.000.000-00'),
                  ),
                ),
                const SizedBox(height: 16),

                _Labeled(
                  label: 'E-mail',
                  child: TextFormField(
                    controller: _email,
                    validator: _valEmail,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _box(hint: 'exemplo@email.com'),
                  ),
                ),
                const SizedBox(height: 16),

                _Labeled(
                  label: 'Celular',
                  child: TextFormField(
                    controller: _phone,
                    validator: _valPhone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [PhoneFormatter()],
                    decoration: _box(hint: '(00) 00000-0000'),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Seção: Endereço ────────────────────────────────────────
                _SectionHeader(label: 'Endereço'),
                const SizedBox(height: 16),

                _Labeled(
                  label: 'CEP',
                  child: TextFormField(
                    controller: _cep,
                    validator: _valCep,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CepFormatter()],
                    onChanged: _onCepChanged,
                    decoration: _box(
                      hint: '00000-000',
                      suffix: _loadingCep
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: kGreen),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                _Labeled(
                  label: 'Rua / Logradouro',
                  child: TextFormField(
                    controller: _rua,
                    validator: (v) => _valRequired(v, 'a rua'),
                    textCapitalization: TextCapitalization.words,
                    decoration: _box(hint: 'Preenchido pelo CEP'),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 100,
                      child: _Labeled(
                        label: 'Número',
                        child: TextFormField(
                          controller: _numero,
                          validator: (v) => _valRequired(v, 'o número'),
                          keyboardType: TextInputType.number,
                          decoration: _box(hint: 'Nº'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Labeled(
                        label: 'Complemento',
                        child: TextFormField(
                          controller: _complemento,
                          textCapitalization: TextCapitalization.words,
                          decoration: _box(hint: 'Apto, bloco... (opcional)'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _Labeled(
                  label: 'Bairro',
                  child: TextFormField(
                    controller: _bairro,
                    validator: (v) => _valRequired(v, 'o bairro'),
                    textCapitalization: TextCapitalization.words,
                    decoration: _box(hint: 'Preenchido pelo CEP'),
                  ),
                ),
                const SizedBox(height: 16),

                _Labeled(
                  label: 'Cidade / Estado',
                  child: TextFormField(
                    controller: _cidade,
                    validator: (v) => _valRequired(v, 'a cidade'),
                    textCapitalization: TextCapitalization.words,
                    decoration: _box(hint: 'Preenchida pelo CEP'),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Seção: Senha ───────────────────────────────────────────
                _SectionHeader(label: 'Senha'),
                const SizedBox(height: 16),

                _Labeled(
                  label: 'Senha',
                  child: TextFormField(
                    controller: _pass,
                    obscureText: _obscurePass,
                    validator: _valPass,
                    onChanged: (v) => setState(() => _passValue = v),
                    decoration: _box(
                      hint: 'Mínimo 8 caracteres',
                      suffix: IconButton(
                        icon: Icon(
                          _obscurePass
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: kHint,
                          size: 22,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePass = !_obscurePass),
                      ),
                    ),
                  ),
                ),
                PasswordStrengthIndicator(password: _passValue),
                const SizedBox(height: 16),

                _Labeled(
                  label: 'Confirmar senha',
                  child: TextFormField(
                    controller: _confirm,
                    obscureText: _obscureConfirm,
                    validator: _valConfirm,
                    decoration: _box(
                      hint: 'Repita a senha',
                      suffix: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: kHint,
                          size: 22,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Termos ─────────────────────────────────────────────────
                GestureDetector(
                  onTap: () => setState(() => _accept = !_accept),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: kGreen, width: 2),
                            color: _accept ? kGreen : Colors.transparent,
                          ),
                          child: _accept
                              ? const Icon(Icons.check, color: Colors.white, size: 14)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(text: 'Li e aceito os '),
                                TextSpan(
                                  text: 'Termos de Uso',
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () => showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (_) => const _TermosAppSheet(),
                                        ),
                                  style: const TextStyle(
                                    color: kGreen,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                    decorationColor: kGreen,
                                  ),
                                ),
                                const TextSpan(text: ' e a '),
                                TextSpan(
                                  text: 'Política de Privacidade',
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () => showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (_) => const _TermosAppSheet(),
                                        ),
                                  style: const TextStyle(
                                    color: kGreen,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                    decorationColor: kGreen,
                                  ),
                                ),
                                const TextSpan(text: '.'),
                              ],
                              style: TextStyle(color: kDark, fontSize: 14, height: 1.4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _loading ? null : _doSignUp,
                    style: FilledButton.styleFrom(
                      backgroundColor: kGreen,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white))
                        : const Text(
                            'Criar conta',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Seção header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 4, height: 18, color: kGreen,
            margin: const EdgeInsets.only(right: 8)),
        Text(
          label,
          style: const TextStyle(
              color: kDark, fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
      ],
    );
  }
}

// ─── Login link ───────────────────────────────────────────────────────────────

class _LoginLink extends StatelessWidget {
  const _LoginLink();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.pushNamed('user_login'),
      child: const Text(
        'Fazer login',
        style: TextStyle(
          color: kGreen,
          fontWeight: FontWeight.w800,
          decoration: TextDecoration.underline,
          fontSize: 15,
        ),
      ),
    );
  }
}

// ─── Termos de Uso e Política de Privacidade ─────────────────────────────────

class _TermosAppSheet extends StatelessWidget {
  const _TermosAppSheet();

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
                  const Icon(Icons.article_outlined, color: kGreen, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Termos de Uso e Privacidade',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: kDark,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: kHint),
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
                    _secao('1. O aplicativo',
                        '"Vem pro Parque" é um app para explorar, reservar espaços e participar de eventos nos parques públicos.'),
                    _secao('2. Sua conta',
                        'Você é responsável pelas informações que cadastra. Nome, e-mail, CPF e telefone devem ser verídicos. Não compartilhe sua senha com outras pessoas.'),
                    _secao('3. O que fazemos com seus dados',
                        'Seus dados são usados para autenticação, reservas, eventos e colaborações. Não repassamos nada a terceiros sem necessidade legal.'),
                    _secao('4. LGPD',
                        'Tratamos seus dados conforme a Lei Geral de Proteção de Dados (Lei nº 13.709/2018). Você pode solicitar acesso, correção ou exclusão dos seus dados a qualquer momento pelo suporte do app.'),
                    _secao('5. Reservas e eventos',
                        'Estão sujeitos à aprovação pelo gestor do parque. A SEMA-MA pode cancelar reservas em casos de emergência ou manutenção, com aviso ao usuário.'),
                    _secao('6. Conta inativa',
                        'Contas sem acesso por mais de 2 anos podem ser encerradas. Seus dados serão removidos conforme a LGPD.'),
                    const SizedBox(height: 8),
                    Text(
                      'Ao criar sua conta, você confirma que leu e aceita estes termos.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: kHint,
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
                          backgroundColor: kGreen,
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
            Text(titulo,
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w700, color: kDark)),
            const SizedBox(height: 6),
            Text(texto,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: kHint, height: 1.6)),
          ],
        ),
      );
}
