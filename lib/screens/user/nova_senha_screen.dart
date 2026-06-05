import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_client.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/password_strength_indicator.dart';

const _green = Color(0xFF669340);
const _dark = Color(0xFF32384A);
const _lightGray = Color(0xFF8F959E);
const _inputBg = Color(0xFFFFFFE9);

class NovaSenhaScreen extends StatefulWidget {
  final String email;
  final String code;
  const NovaSenhaScreen({super.key, required this.email, required this.code});

  @override
  State<NovaSenhaScreen> createState() => _NovaSenhaScreenState();
}

class _NovaSenhaScreenState extends State<NovaSenhaScreen> {
  final _api = ApiClient();
  final _formKey = GlobalKey<FormState>();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  bool _triedSubmit = false;
  String _passValue = '';

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _triedSubmit = true);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);

    try {
      final res = await _api.post('reset-password', body: {
        'email': widget.email,
        'code': widget.code,
        'senha': _passCtrl.text,
      });

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final token = data['token']?.toString();
        final user = data['usuario'] as Map<String, dynamic>?;

        if (token != null) {
          // Login automático com o token retornado
          await AuthService.instance.loginWithToken(token, user);
        } else {
          // Fallback: faz login manual
          await AuthService.instance.login(widget.email, _passCtrl.text);
        }

        if (!mounted) return;
        AppToast.show(context, 'Senha redefinida com sucesso!',
            type: ToastType.success);
        context.go('/tabs/user');
      } else {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        AppToast.show(
          context,
          data['error']?.toString() ?? 'Erro ao redefinir senha.',
          type: ToastType.error,
        );
      }
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Erro de conexão. Tente novamente.',
            type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
          'Nova senha',
          style: GoogleFonts.poppins(
              color: _green, fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Form(
          key: _formKey,
          autovalidateMode: _triedSubmit
              ? AutovalidateMode.always
              : AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ícone
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_reset_outlined,
                      color: _green, size: 36),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Crie uma nova senha para sua conta.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 14, color: _lightGray, height: 1.4),
              ),
              const SizedBox(height: 32),

              // Nova senha
              _Labeled(
                label: 'Nova senha',
                child: TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscurePass,
                  onChanged: (v) => setState(() => _passValue = v),
                  validator: (v) => PasswordRules.validate(v),
                  style: GoogleFonts.poppins(fontSize: 15, color: _dark),
                  decoration: _inputDecoration(
                    hint: 'Mínimo 8 caracteres',
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePass
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: _lightGray, size: 22,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                ),
              ),

              // Indicador de força
              PasswordStrengthIndicator(password: _passValue),
              const SizedBox(height: 16),

              // Confirmar senha
              _Labeled(
                label: 'Confirmar senha',
                child: TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirm,
                  validator: (v) {
                    if ((v ?? '').isEmpty) return 'Confirme a senha';
                    if (v != _passCtrl.text) return 'As senhas não conferem';
                    return null;
                  },
                  style: GoogleFonts.poppins(fontSize: 15, color: _dark),
                  decoration: _inputDecoration(
                    hint: 'Repita a nova senha',
                    suffix: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: _lightGray, size: 22,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    disabledBackgroundColor: _green.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26)),
                  ),
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          'Salvar nova senha',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration({String? hint, Widget? suffix}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: _lightGray, fontSize: 15),
    filled: true,
    fillColor: _inputBg,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    constraints: const BoxConstraints(minHeight: 56),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: _green, width: 2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: _green, width: 2),
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
        Text(label,
            style: GoogleFonts.poppins(
                color: _dark, fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
