import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_client.dart';
import '../../widgets/app_toast.dart';

const _green = Color(0xFF669340);
const _dark = Color(0xFF32384A);
const _lightGray = Color(0xFF8F959E);
const _inputBg = Color(0xFFFFFFE9);

class VerificarCodigoScreen extends StatefulWidget {
  final String email;
  const VerificarCodigoScreen({super.key, required this.email});

  @override
  State<VerificarCodigoScreen> createState() => _VerificarCodigoScreenState();
}

class _VerificarCodigoScreenState extends State<VerificarCodigoScreen> {
  final _api = ApiClient();
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());

  bool _loading = false;
  bool _resending = false;
  int _cooldown = 0;
  Timer? _timer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_cooldown > 0) {
          _cooldown--;
        } else {
          t.cancel();
        }
      });
    });
  }

  String get _code => _controllers.map((c) => c.text).join();

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final local = parts[0];
    if (local.length <= 2) return email;
    return '${local.substring(0, 2)}${'*' * (local.length - 2)}@${parts[1]}';
  }

  Future<void> _verify() async {
    if (_code.length != 6) return;
    setState(() { _loading = true; _error = null; });

    try {
      final res = await _api.post('verify-reset-code', body: {
        'email': widget.email,
        'code': _code,
      });

      if (!mounted) return;

      if (res.statusCode == 200) {
        context.push('/nova-senha', extra: {'email': widget.email, 'code': _code});
      } else if (res.statusCode == 429) {
        setState(() => _error = 'Código bloqueado. Solicite um novo.');
      } else {
        setState(() => _error = 'Código inválido ou expirado.');
        _shakeFields();
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Erro de conexão.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_cooldown > 0 || _resending) return;
    setState(() => _resending = true);

    try {
      await _api.post('forgot-password', body: {'email': widget.email});
      if (!mounted) return;
      AppToast.show(context, 'Novo código enviado!', type: ToastType.success);
      _startCooldown();
      for (final c in _controllers) { c.clear(); }
      _focusNodes[0].requestFocus();
      setState(() => _error = null);
    } catch (_) {
      if (mounted) AppToast.show(context, 'Erro ao reenviar.', type: ToastType.error);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _shakeFields() {
    for (final c in _controllers) { c.clear(); }
    _focusNodes[0].requestFocus();
  }

  void _onDigit(int index, String value) {
    if (value.length == 1) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _verify();
      }
    }
  }

  void _onBackspace(int index) {
    if (_controllers[index].text.isEmpty && index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canVerify = _code.length == 6 && !_loading;

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
          'Verificar código',
          style: GoogleFonts.poppins(
            color: _green, fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
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
                child: const Icon(Icons.mark_email_unread_outlined,
                    color: _green, size: 36),
              ),
            ),
            const SizedBox(height: 24),

            // Texto explicativo
            Text(
              'Enviamos um código para',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: _lightGray),
            ),
            const SizedBox(height: 4),
            Text(
              _maskEmail(widget.email),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w700, color: _dark),
            ),
            const SizedBox(height: 32),

            // Campos OTP
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (i) => _OtpField(
                controller: _controllers[i],
                focusNode: _focusNodes[i],
                hasError: _error != null,
                onChanged: (v) => _onDigit(i, v),
                onBackspace: () => _onBackspace(i),
              )),
            ),

            // Erro
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: Colors.red.shade600),
              ),
            ],

            const SizedBox(height: 32),

            // Botão verificar
            SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  disabledBackgroundColor: _green.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26)),
                ),
                onPressed: canVerify ? _verify : null,
                child: _loading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text('Verificar',
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w700,
                            color: Colors.white)),
              ),
            ),

            const SizedBox(height: 24),

            // Reenviar
            Center(
              child: _cooldown > 0
                  ? Text(
                      'Reenviar código em ${_cooldown}s',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: _lightGray),
                    )
                  : GestureDetector(
                      onTap: _resending ? null : _resend,
                      child: Text(
                        _resending ? 'Enviando...' : 'Não recebi o código — Reenviar',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: _green,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpField extends StatelessWidget {
  const _OtpField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onBackspace,
    required this.hasError,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 58,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              controller.text.isEmpty) {
            onBackspace();
          }
        },
        child: TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: onChanged,
          style: GoogleFonts.poppins(
              fontSize: 22, fontWeight: FontWeight.w700, color: _dark),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: _inputBg,
            contentPadding: EdgeInsets.zero,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: hasError ? Colors.red : _green, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: hasError ? Colors.red : _green, width: 2.5),
            ),
          ),
        ),
      ),
    );
  }
}
