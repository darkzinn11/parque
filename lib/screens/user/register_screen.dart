import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';

/// ===== TOKENS =====
const kGreen   = Color(0xFF669340);
const kDark    = Color(0xFF32384A);
const kBg      = Color.fromARGB(255, 255, 255, 255);
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
      borderSide: BorderSide(color: Colors.red, width: 2),
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

  // Controllers
  final _name    = TextEditingController();
  final _cpf     = TextEditingController();
  final _email   = TextEditingController();
  final _phone   = TextEditingController();
  final _pass    = TextEditingController();
  final _confirm = TextEditingController();

  bool _loading = false;
  bool _triedSubmit = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _accept = false;
  String? _topError;

  @override
  void dispose() {
    _scroll.dispose();
    _name.dispose(); _cpf.dispose(); _email.dispose();
    _phone.dispose(); _pass.dispose(); _confirm.dispose();
    super.dispose();
  }

  // ---------- Validações ----------
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
    if (digits.length < 10 || digits.length > 11) return 'Celular inválido';
    return null;
  }

  String? _valPass(String? v) {
    if (!_triedSubmit) return null;
    final t = v ?? '';
    if (t.isEmpty) return 'Crie uma senha';
    if (t.length < 8) return 'Mínimo de 8 caracteres';
    return null;
  }

  String? _valConfirm(String? v) {
    if (!_triedSubmit) return null;
    if ((v ?? '').isEmpty) return 'Confirme a senha';
    if (v != _pass.text) return 'As senhas não conferem';
    return null;
  }

  // ---------- Util: valida CPF ----------
  bool _isValidCpf(String cpf) {
    if (cpf.length != 11) return false;
    if (RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) return false;
    List<int> n = cpf.split('').map(int.parse).toList();
    int d1 = 0, d2 = 0;
    for (int i = 0; i < 9; i++) {
      d1 += n[i] * (10 - i);
      d2 += n[i] * (11 - i);
    }
    d1 = (d1 * 10) % 11;
    if (d1 == 10) d1 = 0;
    d2 = (d2 + d1 * 2) * 10 % 11;
    if (d2 == 10) d2 = 0;
    return d1 == n[9] && d2 == n[10];
  }

  // ---------- Submit ----------
  Future<void> _doSignUp() async {
    FocusScope.of(context).unfocus();
    setState(() { _triedSubmit = true; _topError = null; });

    final valid = _form.currentState?.validate() ?? false;

    if (!_accept) {
      setState(() => _topError =
          'Você precisa aceitar os Termos de Uso e a Política de Privacidade.');
    }

    if (!valid || !_accept) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text("Corrija os campos em vermelho."),
        ),
      );
      return;
    }

    setState(() { _loading = true; _topError = null; });

    final ok = await _auth.signup(
      username: _name.text.trim(), // usado como username no Strapi
      email: _email.text.trim(),
      password: _pass.text,
      phone: _phone.text.trim(),
      cpf: _cpf.text.replaceAll(RegExp(r'\D'), ''),
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
            autovalidateMode: _triedSubmit ? AutovalidateMode.always : AutovalidateMode.disabled,
            child: Column(
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Cadastro',
                  style: TextStyle(
                    color: kGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Crie sua conta rapidinho e aproveite tudo o que o parque oferece.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kDark, fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('Já possui cadastro? ', style: TextStyle(color: kDark, fontSize: 16)),
                    _LoginLink(),
                  ],
                ),
                const SizedBox(height: 20),

                if (_topError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(.08),
                      border: Border.all(color: Colors.red),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_topError!, style: const TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  )
                ],

                _Labeled(
                  label: 'Nome completo',
                  child: TextFormField(controller: _name, validator: _valName, decoration: _box()),
                ),
                const SizedBox(height: 20),
                _Labeled(
                  label: 'CPF',
                  child: TextFormField(controller: _cpf, validator: _valCpf, decoration: _box(hint: "Apenas números")),
                ),
                const SizedBox(height: 20),
                _Labeled(
                  label: 'Email',
                  child: TextFormField(controller: _email, validator: _valEmail, decoration: _box(hint: "exemplo@email.com")),
                ),
                const SizedBox(height: 20),
                _Labeled(
                  label: 'Celular',
                  child: TextFormField(controller: _phone, validator: _valPhone, decoration: _box(hint: "DDD + número")),
                ),
                const SizedBox(height: 20),
                _Labeled(
                  label: 'Senha',
                  child: TextFormField(controller: _pass, obscureText: _obscurePass, validator: _valPass, decoration: _box(hint: "Digite sua senha")),
                ),
                const SizedBox(height: 20),
                _Labeled(
                  label: 'Confirmar senha',
                  child: TextFormField(controller: _confirm, obscureText: _obscureConfirm, validator: _valConfirm, decoration: _box(hint: "Repita a senha")),
                ),

                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: _accept,
                      onChanged: (v) => setState(() => _accept = v ?? false),
                      activeColor: kGreen,
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'Li e aceito os Termos de Uso e a Política de Privacidade.',
                        style: TextStyle(color: kDark, fontSize: 14),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _loading ? null : _doSignUp,
                    style: FilledButton.styleFrom(
                      backgroundColor: kGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white))
                        : const Text("Criar conta", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
          fontSize: 16,
        ),
      ),
    );
  }
}
