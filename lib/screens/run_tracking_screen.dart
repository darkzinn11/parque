import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
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

  // Distância mínima (metros) para mover a câmera — 3m é suficiente para seguir suavemente
  static const double _cameraMoveThresholdMeters = 3.0;

  final RunService run = RunService.instance;
  GoogleMapController? _mapController;
  bool _starting = true;
  String? _error;

  // Flag para centralizar a câmera apenas uma vez no primeiro fix real
  bool _initialCameraSet = false;

  // Última posição onde a câmera foi centrada — evita animações desnecessárias
  LatLng? _lastCameraLatLng;

  // Sets persistentes de polylines e markers — não recriados a cada build().
  // O GoogleMaps SDK compara por referência; recriar a cada frame causa piscar.
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};

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

  /// Chamado pelo RunService (via notifyListeners) a cada tick do timer (1s).
  /// Atualiza polylines/markers nos campos persistentes e move a câmera
  /// apenas quando necessário — sem jitter.
  void _onRunUpdated() {
    if (!mounted) return;

    final coords = run.routeCoords;
    final hasRoute = coords.isNotEmpty;

    // ── Atualiza Polyline no campo persistente ─────────────────────────
    _polylines
      ..clear()
      ..add(Polyline(
        polylineId: const PolylineId('route'),
        points: List<LatLng>.from(coords), // snapshot imutável
        width: 6,
        color: primaryGreen,
      ));

    // ── Atualiza Markers no campo persistente ──────────────────────────
    // O SDK reutiliza markers com o mesmo MarkerId em vez de remove+add,
    // eliminando o piscar do marcador atual.
    _markers.clear();
    if (hasRoute) {
      _markers.add(Marker(
        markerId: const MarkerId('start'),
        position: coords.first,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
      _markers.add(Marker(
        markerId: const MarkerId('current'),
        position: coords.last,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }

    // ── Move câmera apenas quando necessário ──────────────────────────
    if (_mapController != null && hasRoute) {
      final last = coords.last;

      if (!_initialCameraSet) {
        // Primeira posição real — centraliza com animação
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(last, 16),
        );
        _initialCameraSet = true;
        _lastCameraLatLng = last;
      } else if (_lastCameraLatLng != null) {
        final dist = Geolocator.distanceBetween(
          _lastCameraLatLng!.latitude,
          _lastCameraLatLng!.longitude,
          last.latitude,
          last.longitude,
        );

        // Só move quando o usuário saiu do centro por mais de 15m —
        // elimina o jitter de câmera causado por micro-movimentos do GPS.
        // Usa moveCamera (sem animação) para não interferir com gestos do usuário.
        if (dist > _cameraMoveThresholdMeters) {
          // Usa newLatLng sem forçar zoom — preserva o zoom do usuário
          _mapController!.moveCamera(
            CameraUpdate.newLatLng(last),
          );
          _lastCameraLatLng = last;
        }
      }
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
                        color: primaryGreen,
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
          // GoogleMap recebe os Sets persistentes — não recriados a cada build().
          // onMapCreated não move câmera para evitar race condition com GPS frio:
          // a câmera é centralizada no primeiro fix real dentro de _onRunUpdated().
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialPos,
              zoom: hasRoute ? 16 : 3,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            polylines: _polylines,
            markers: _markers,
            onMapCreated: (controller) {
              _mapController = controller;
              // Não move câmera aqui — GPS pode ainda não ter fix.
              // O primeiro fix real é detectado em _onRunUpdated() via _initialCameraSet.
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
          // Linha de status — "Gravando" ou "Aguardando GPS"
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: run.awaitingGpsFix ? Colors.orange : primaryGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                run.awaitingGpsFix
                    ? 'Aguardando sinal GPS...'
                    : 'Gravando atividade',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: run.awaitingGpsFix ? Colors.orange : lightText,
                ),
              ),
              if (run.awaitingGpsFix) ...[
                const SizedBox(width: 6),
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.orange,
                  ),
                ),
              ],
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
    var v = raw
        .toLowerCase()
        .replaceAll('min/km', '')
        .replaceAll('min', '')
        .replaceAll('km', '')
        .trim();
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32)),
              textStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32)),
              textStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            child: const Text('Encerrar'),
          ),
        ),
      ],
    );
  }
}
