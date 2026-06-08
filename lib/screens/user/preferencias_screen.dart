import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../widgets/app_toast.dart';

const _green = Color(0xFF669340);
const _dark = Color(0xFF32384A);
const _lightGray = Color(0xFF8F959E);
const _divider = Color(0xFFEEEEEE);

class PreferenciasScreen extends StatefulWidget {
  const PreferenciasScreen({super.key});

  @override
  State<PreferenciasScreen> createState() => _PreferenciasScreenState();
}

class _PreferenciasScreenState extends State<PreferenciasScreen>
    with WidgetsBindingObserver {
  bool _notificacoes = false;
  bool _localizacao = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Recarrega status quando o usuário volta das configurações do SO
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final notif = await Permission.notification.status;
    final loc = await Geolocator.checkPermission();

    if (!mounted) return;
    setState(() {
      _notificacoes = notif.isGranted;
      _localizacao = loc == LocationPermission.always ||
          loc == LocationPermission.whileInUse;
      _loading = false;
    });
  }

  // ── Notificações ──────────────────────────────────────────────────────────

  Future<void> _toggleNotificacoes(bool val) async {
    if (val) {
      final status = await Permission.notification.request();
      if (!mounted) return;
      if (status.isGranted) {
        setState(() => _notificacoes = true);
        AppToast.show(context, 'Notificações ativadas!', type: ToastType.success);
      } else if (status.isPermanentlyDenied) {
        _abrirConfiguracoes('notificações');
      } else {
        AppToast.show(context, 'Permissão de notificações negada.',
            type: ToastType.warning);
      }
    } else {
      // Não é possível revogar permissão programaticamente — abre configurações
      _abrirConfiguracoes('notificações');
    }
  }

  // ── Localização ───────────────────────────────────────────────────────────

  Future<void> _toggleLocalizacao(bool val) async {
    if (val) {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        if (!mounted) return;
        AppToast.show(
          context,
          'Ative o GPS nas configurações do dispositivo.',
          type: ToastType.warning,
        );
        return;
      }

      final status = await Geolocator.requestPermission();
      if (!mounted) return;
      if (status == LocationPermission.always ||
          status == LocationPermission.whileInUse) {
        setState(() => _localizacao = true);
        AppToast.show(context, 'Localização ativada!', type: ToastType.success);
      } else if (status == LocationPermission.deniedForever) {
        _abrirConfiguracoes('localização');
      } else {
        AppToast.show(context, 'Permissão de localização negada.',
            type: ToastType.warning);
      }
    } else {
      _abrirConfiguracoes('localização');
    }
  }

  // ── Dialog de configurações ───────────────────────────────────────────────

  void _abrirConfiguracoes(String permissao) {
    final isNotif = permissao == 'notificações';
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícone circular com fundo verde suave
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isNotif
                      ? Icons.notifications_outlined
                      : Icons.location_on_outlined,
                  color: _green,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),

              // Título
              Text(
                'Permissão de $permissao',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: _dark,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),

              // Descrição
              Text(
                'Para alterar o acesso à $permissao, acesse as Configurações do seu dispositivo.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: _lightGray,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // Botão principal — Abrir configurações
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    openAppSettings();
                  },
                  child: Text(
                    'Abrir configurações',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Cancelar discreto
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: _lightGray,
                      fontWeight: FontWeight.w500,
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _green),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          'Preferências',
          style: GoogleFonts.poppins(
            color: _green,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              children: [
                _SwitchRow(
                  label: 'Permitir notificações',
                  subtitle:
                      'Receba avisos de reservas, eventos e novidades dos parques.',
                  value: _notificacoes,
                  onChanged: _toggleNotificacoes,
                ),
                const _FullDivider(),
                _SwitchRow(
                  label: 'Serviços de localização',
                  subtitle:
                      'Mostra os parques mais próximos de você na tela inicial.',
                  value: _localizacao,
                  onChanged: _toggleLocalizacao,
                ),
                const _FullDivider(),
              ],
            ),
    );
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────

class _FullDivider extends StatelessWidget {
  const _FullDivider();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Divider(height: 1, thickness: 1, color: _divider),
      );
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: _dark,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    color: _lightGray,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Theme(
            data: Theme.of(context).copyWith(
              cupertinoOverrideTheme:
                  const CupertinoThemeData(primaryColor: _green),
            ),
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: _green,
              inactiveTrackColor: const Color(0xFFECEFF1),
            ),
          ),
        ],
      ),
    );
  }
}
