import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../services/favorites_service.dart';

/// ===== TOKENS =====
const kGreen = Color(0xFF669340);
const kDark  = Color(0xFF32384A);
const kBg    = Color.fromARGB(255, 255, 255, 255);
const kHint  = Color(0xFF9AA3AF);
const kInputBg = Color(0xFFFFFFE9); // #FFFFE9

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

class Labeled extends StatelessWidget {
  const Labeled({super.key, required this.label, required this.child});
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

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.onLogged,
    this.onOpenRegister,
    this.onForgotDone,
  });

  final VoidCallback? onLogged;
  final VoidCallback? onOpenRegister; // mantido por compatibilidade
  final VoidCallback? onForgotDone;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService.instance;
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass  = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  String? _error;
  bool _triedSubmit = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    FocusScope.of(context).unfocus();
    setState(() => _triedSubmit = true);
    if (!_formKey.currentState!.validate()) return;

    setState(() { _loading = true; _error = null; });
    final ok = await _auth.login(_email.text.trim(), _pass.text);

    if (!mounted) return;
    setState(() { _loading = false; });

    if (ok) {
      await FavoritesService.instance.init();
      widget.onLogged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Login realizado')));
      }
    } else {
      setState(() => _error = 'E-mail ou senha inválidos.');
    }
  }

  Future<void> _forgot() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Digite seu e-mail para recuperar a senha.');
      return;
    }
    final sent = await _auth.requestPasswordReset(_email.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        sent ? 'Enviamos instruções para seu e-mail.'
             : 'Não foi possível enviar o e-mail.',
      ),
    ));
    widget.onForgotDone?.call();
  }

  String? _emailValidator(String? v) {
    if (!_triedSubmit) return null;
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Informe o e-mail';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(t)) return 'E-mail inválido';
    return null;
  }

  String? _passValidator(String? v) {
    if (!_triedSubmit) return null;
    if (v == null || v.isEmpty) return 'Informe a senha';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Login',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: kGreen,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 40),

                              const Text(
                                'Acesse para aproveitar tudo o que os parques têm a oferecer.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: kDark,
                                  fontSize: 16,
                                  height: 1.5,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),

                              const SizedBox(height: 40),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text(
                                    'É sua primeira vez? ',
                                    style: TextStyle(
                                      color: kDark,
                                      fontSize: 16,
                                      height: 1.5,
                                    ),
                                  ),
                                  _RegisterLink(), // navega pelo nome
                                ],
                              ),

                              const SizedBox(height: 20),

                              Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    Labeled(
                                      label: 'Email',
                                      child: TextFormField(
                                        controller: _email,
                                        keyboardType: TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        validator: _emailValidator,
                                        textAlignVertical: TextAlignVertical.center,
                                        decoration: _box(hint: 'exemplo@email.com'),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Labeled(
                                      label: 'Senha',
                                      child: TextFormField(
                                        controller: _pass,
                                        obscureText: _obscure,
                                        validator: _passValidator,
                                        textAlignVertical: TextAlignVertical.center,
                                        decoration: _box(
                                          hint: '********',
                                          helper: 'Digite a senha cadastrada',
                                          suffix: IconButton(
                                            onPressed: () => setState(() => _obscure = !_obscure),
                                            icon: Icon(
                                              _obscure ? Icons.visibility_off : Icons.visibility,
                                              color: kHint,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (_error != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 20),

                              Center(
                                child: TextButton(
                                  onPressed: _loading ? null : _forgot,
                                  style: TextButton.styleFrom(
                                    foregroundColor: kGreen,
                                    padding: EdgeInsets.zero,
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      height: 1.5,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  child: const Text('Esqueci minha senha'),
                                ),
                              ),

                              const SizedBox(height: 40),

                              SizedBox(
                                height: 52,
                                child: FilledButton.icon(
                                  icon: _loading
                                      ? const SizedBox(
                                          height: 20, width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(Colors.white),
                                          ),
                                        )
                                      : const Icon(Icons.login_rounded, size: 20),
                                  label: const Text(
                                    'Entrar',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: kGreen,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                  onPressed: _loading ? null : _doLogin,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RegisterLink extends StatelessWidget {
  const _RegisterLink();

  @override
  Widget build(BuildContext context) {
    final loginState = context.findAncestorStateOfType<_LoginScreenState>();
    final disabled = loginState?._loading == true;

    return InkWell(
      onTap: disabled ? null : () => context.pushNamed('user_register'),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 2),
        child: Text(
          'Faça seu cadastro.',
          style: TextStyle(
            color: kGreen,
            fontSize: 16,
            height: 1.5,
            fontWeight: FontWeight.w800,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}
