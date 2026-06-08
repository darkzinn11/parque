import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// Ocultamos 'Marker' do lottie para não conflitar com o do Google Maps
import 'package:lottie/lottie.dart' hide Marker;

import '../services/run_tracker_service.dart';
import '../widgets/app_toast.dart';

class RunTrackingScreen extends StatefulWidget {
  const RunTrackingScreen({super.key, this.activityType = 'corrida'});

  final String activityType;

  @override
  State<RunTrackingScreen> createState() => _RunTrackingScreenState();
}

class _RunTrackingScreenState extends State<RunTrackingScreen> {
  // Paleta padrão do app
  static const Color primaryGreen = Color(0xFF669340);
  static const Color darkText = Color(0xFF32384A);
  static const Color lightText = Color(0xFF8F959E);

  final RunService run = RunService.instance;
  GoogleMapController? _mapController;
  bool _starting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    run.addListener(_onRunUpdated);
    _startRun();
  }

  Future<void> _startRun() async {
    setState(() {
      _starting = true;
      _error = null;
    });

    try {
      await run.start(activityType: widget.activityType);
    } catch (e) {
      _error = e.toString();
      if (mounted) {
        AppToast.show(context, _error!, type: ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _starting = false);
      }
    }
  }

  void _onRunUpdated() {
    if (!mounted) return;

    // Move a câmera automaticamente para seguir o usuário
    if (_mapController != null && run.routeCoords.isNotEmpty) {
      final last = run.routeCoords.last;
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(last, 16),
      );
    }

    setState(() {});
  }

  @override
  void dispose() {
    run.removeListener(_onRunUpdated);
    super.dispose();
  }

  // Lógica de Encerrar com Modal Lottie
  Future<void> _finishRun() async {
    // 1. Para a gravação do serviço
    run.stop();

    // 2. Mostra o Modal de Sucesso
    await showDialog(
      context: context,
      barrierDismissible: false, // Obriga o usuário a clicar no botão para sair
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.white, // Garante fundo branco
          surfaceTintColor: Colors.white, // Remove o tint verde do Material 3
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- ANIMAÇÃO LOTTIE LOCAL ---
                SizedBox(
                  height: 280,
                  width: 280,
                  child: Lottie.asset(
                    'assets/lottie/success.json',
                    fit: BoxFit.contain,
                    repeat: true,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.check_circle_outline, 
                        size: 80, 
                        color: primaryGreen
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 24),
                
                const Text(
                  'Sucesso!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: primaryGreen,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Atividade realizada e gravada com sucesso!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: darkText,
                    height: 1.4,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop(); // Fecha o Modal
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Continuar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // 3. Após fechar o modal, volta para a tela anterior COM SINAL DE SUCESSO (true)
    if (mounted) {
      // Alterado aqui: passamos true
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRoute = run.routeCoords.isNotEmpty;
    final LatLng initialPos =
        hasRoute ? run.routeCoords.first : const LatLng(0, 0);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: primaryGreen,
        ),
        title: const Text(
          'Gravando atividade',
          style: TextStyle(
            color: primaryGreen,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialPos,
              zoom: hasRoute ? 16 : 3,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            polylines: {
              Polyline(
                polylineId: const PolylineId('route'),
                points: run.routeCoords,
                width: 6,
                color: primaryGreen,
              ),
            },
            markers: {
              if (hasRoute)
                Marker(
                  markerId: const MarkerId('start'),
                  position: run.routeCoords.first,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen,
                  ),
                ),
              if (hasRoute)
                Marker(
                  markerId: const MarkerId('current'),
                  position: run.routeCoords.last,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed,
                  ),
                ),
            },
            onMapCreated: (controller) {
              _mapController = controller;
              if (hasRoute) {
                _mapController!.moveCamera(
                  CameraUpdate.newLatLngZoom(run.routeCoords.last, 16),
                );
              }
            },
          ),

          // CARD COM ESTATÍSTICAS
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: _buildInfoCard(),
          ),

          // BOTÕES DE CONTROLE
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _buildControls(),
          ),

          if (_starting)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  color: primaryGreen,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------- CARD SUPERIOR ----------

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Linha "Gravando..."
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: primaryGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Gravando atividade',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: lightText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem(
                label: 'Tempo',
                value: run.timeStr,
                icon: Icons.timer_outlined,
              ),
              _divider(),
              _statItem(
                label: 'Distância',
                value: '${run.distanceKmStr} km',
                icon: Icons.map_outlined,
              ),
              _divider(),
              _statItem(
                label: 'Ritmo',
                value: _formatPace(run.pace),
                icon: Icons.speed,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 32,
        color: const Color(0xFFE0E0E0),
      );

  Widget _statItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: primaryGreen, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: darkText,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: lightText,
          ),
        ),
      ],
    );
  }

  String _formatPace(String raw) {
    if (raw.isEmpty || raw == '--') return '--';
    var v = raw.toLowerCase().replaceAll('min/km', '').replaceAll('min', '').replaceAll('km', '').trim();
    if (v.endsWith('/km')) return v;
    return '$v /km';
  }

  Widget _buildControls() {
    final isPaused = run.isPaused;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              if (isPaused) {
                run.resume();
              } else {
                run.pause();
              }
              setState(() {});
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: darkText,
              side: const BorderSide(color: primaryGreen),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            child: Text(isPaused ? 'Retomar' : 'Pausar'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () => _finishRun(),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            child: const Text('Encerrar'),
          ),
        ),
      ],
    );
  }
}