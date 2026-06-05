// lib/screens/user/preferencias_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/app_toast.dart';

const _green = Color(0xFF669340);
const _dark = Color(0xFF32384A);
const _divider = Color(0xFFEEEEEE);

class PreferenciasScreen extends StatefulWidget {
  const PreferenciasScreen({super.key});
  @override
  State<PreferenciasScreen> createState() => _PreferenciasScreenState();
}

class _PreferenciasScreenState extends State<PreferenciasScreen> {
  bool _notificacoes = false;
  bool _localizacao = false;
  bool _isSaving = false;

  static const _kNotificacoes = 'pref_notificacoes';
  static const _kLocalizacao = 'pref_localizacao';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      _notificacoes = sp.getBool(_kNotificacoes) ?? false;
      _localizacao = sp.getBool(_kLocalizacao) ?? false;
    });
  }

  Future<void> _savePreferences() async {
    setState(() => _isSaving = true);
    final sp = await SharedPreferences.getInstance();
    await Future.wait([
      sp.setBool(_kNotificacoes, _notificacoes),
      sp.setBool(_kLocalizacao, _localizacao),
    ]);
    if (!mounted) return;
    setState(() => _isSaving = false);
    AppToast.show(context, 'Preferências salvas!', type: ToastType.success);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.poppins(
      color: _green,
      fontWeight: FontWeight.w700,
      fontSize: 20,
      height: 1.5, // 30px line-height
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _green),
          onPressed: () => context.pop(),
          tooltip: 'Voltar',
        ),
        centerTitle: true,
        title: Text('Preferências', style: titleStyle),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        children: [
          _SwitchRow(
            label: 'Permitir notificações',
            value: _notificacoes,
            onChanged: (v) => setState(() => _notificacoes = v),
          ),
          const _FullDivider(),
          _SwitchRow(
            label: 'Serviços de localização',
            value: _localizacao,
            onChanged: (v) => setState(() => _localizacao = v),
          ),
          const _FullDivider(),

          const SizedBox(height: 16),

          // Botão imediatamente abaixo da última seção (igual ao Figma)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _isSaving ? null : _savePreferences,
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
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
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.save_outlined,
                            size: 20, color: Colors.white),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 12), // respiro visual
        ],
      ),
    );
  }
}

class _FullDivider extends StatelessWidget {
  const _FullDivider();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6.0),
      child: Divider(height: 1, thickness: 1, color: _divider),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = GoogleFonts.poppins(
      color: _dark,
      fontSize: 16,
      fontWeight: FontWeight.w500,
    );

    // verde forte no ON
    const offTrack = Color(0xFFECEFF1);

    return SizedBox(
      height: 64,
      child: Row(
        children: [
          Expanded(child: Text(label, style: textStyle)),
          Theme(
            data: Theme.of(context).copyWith(
              cupertinoOverrideTheme:
                  const CupertinoThemeData(primaryColor: _green),
            ),
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: _green,          // iOS/Android
              activeTrackColor: _green,     // deixa o track bem forte
              inactiveTrackColor: offTrack, // off suave
            ),
          ),
        ],
      ),
    );
  }
}
