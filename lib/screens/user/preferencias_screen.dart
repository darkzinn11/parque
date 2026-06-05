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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Permissão de $permissao',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700, fontSize: 16, color: _dark),
        ),
        content: Text(
          'Para alterar o acesso à $permissao, '
          'acesse as Configurações do seu dispositivo.',
          style: GoogleFonts.poppins(fontSize: 14, color: _lightGray, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style: GoogleFonts.poppins(color: _lightGray)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: Text('Abrir configurações',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
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
