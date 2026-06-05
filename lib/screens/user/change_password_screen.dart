import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api/api_client.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/password_strength_indicator.dart';

const _green = Color(0xFF669340);
const _dark = Color(0xFF32384A);
const _lightGray = Color(0xFF8F959E);

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _atualCtrl = TextEditingController();
  final _novaCtrl = TextEditingController();
  final _confirmaCtrl = TextEditingController();

  bool _showAtual = false;
  bool _showNova = false;
  bool _showConfirma = false;
  bool _isSaving = false;
  String _novaValue = '';
  String? _senhaAtualError;

  final _api = ApiClient();

  Future<void> _submit() async {
    setState(() => _senhaAtualError = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final res = await _api.post('/me/change-password', body: {
        'senha_atual': _atualCtrl.text,
        'senha_nova': _novaCtrl.text,
        'confirmacao': _confirmaCtrl.text,
      });

      if (!mounted) return;

      if (res.statusCode == 200) {
        AppToast.show(context, 'Senha alterada com sucesso!', type: ToastType.success);
        Navigator.of(context).pop();
      } else if (res.statusCode == 401) {
        setState(() {
          _senhaAtualError = 'Senha atual incorreta.';
        });
      } else {
        final msg = _extractError(res.body) ?? 'Erro ao alterar senha.';
        AppToast.show(context, msg, type: ToastType.error);
      }
    } catch (_) {
      if (mounted) AppToast.show(context, 'Erro de conexão. Tente novamente.', type: ToastType.error);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _extractError(String body) {
    try {
      return jsonDecode(body)['error']?.toString();
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _atualCtrl.dispose();
    _novaCtrl.dispose();
    _confirmaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new, color: _green),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Alterar senha',
          style: GoogleFonts.poppins(
            color: _green,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          children: [
            // Instrução
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _green.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: _green, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Mín. 8 caracteres, com maiúscula, número e caractere especial.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: _green,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Senha atual ───────────────────────────────────────────
            _SectionLabel(label: 'SENHA ATUAL'),
            const SizedBox(height: 8),
            _PasswordCard(
              children: [
                _PasswordField(
                  controller: _atualCtrl,
                  label: 'Senha atual',
                  show: _showAtual,
                  onToggle: () =>
                      setState(() => _showAtual = !_showAtual),
                  externalError: _senhaAtualError,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe a senha atual';
                    if (v.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                  onChanged: (_) {
                    if (_senhaAtualError != null) {
                      setState(() => _senhaAtualError = null);
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Nova senha ────────────────────────────────────────────
            _SectionLabel(label: 'NOVA SENHA'),
            const SizedBox(height: 8),
            _PasswordCard(
              children: [
                _PasswordField(
                  controller: _novaCtrl,
                  label: 'Nova senha',
                  show: _showNova,
                  onToggle: () => setState(() => _showNova = !_showNova),
                  onChanged: (v) => setState(() => _novaValue = v),
                  validator: (v) {
                    final err = PasswordRules.validate(v);
                    if (err != null) return err;
                    if (v == _atualCtrl.text) {
                      return 'A nova senha deve ser diferente da atual';
                    }
                    return null;
                  },
                ),
                if (_novaValue.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: PasswordStrengthIndicator(password: _novaValue),
                  ),
                _Divider(),
                _PasswordField(
                  controller: _confirmaCtrl,
                  label: 'Confirmar nova senha',
                  show: _showConfirma,
                  onToggle: () =>
                      setState(() => _showConfirma = !_showConfirma),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirme a nova senha';
                    if (v != _novaCtrl.text) return 'As senhas não coincidem';
                    return null;
                  },
                ),
              ],
            ),

            const SizedBox(height: 36),

            // ── Botão ─────────────────────────────────────────────────
            FilledButton(
              onPressed: _isSaving ? null : _submit,
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
                  : Text(
                      'Confirmar alteração',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _lightGray,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _PasswordCard extends StatelessWidget {
  const _PasswordCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
        height: 1, thickness: 1, indent: 52, color: Color(0xFFF0F0F0));
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.show,
    required this.onToggle,
    this.validator,
    this.externalError,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final bool show;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;
  final String? externalError;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextFormField(
        controller: controller,
        obscureText: !show,
        onChanged: onChanged,
        validator: validator,
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: _dark,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              GoogleFonts.poppins(fontSize: 14, color: _lightGray),
          prefixIcon: const Icon(Icons.lock_outline, color: _lightGray, size: 20),
          suffixIcon: IconButton(
            icon: Icon(
              show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: _lightGray,
              size: 20,
            ),
            onPressed: onToggle,
          ),
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 0),
          // Erro externo (401 do servidor)
          errorText: externalError,
          errorStyle: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.red.shade600,
          ),
        ),
      ),
    );
  }
}
