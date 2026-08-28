import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/run_tracker_service.dart';
import '../widgets/app_toast.dart';

class AtividadeScreen extends StatefulWidget {
  const AtividadeScreen({super.key});

  @override
  State<AtividadeScreen> createState() => _AtividadeScreenState();
}

class _AtividadeScreenState extends State<AtividadeScreen> {
  static const Color darkText = Color(0xFF32384A);
  static const Color lightText = Color(0xFF8F959E);

  final RunService run = RunService.instance;

  // 0 = Caminhada, 1 = Corrida, 2 = Ciclismo
  int _selectedType = 0;

  static const _typeKeys = ['caminhada', 'corrida', 'ciclismo'];

  static const _typeIcons = [
    Icons.directions_walk,
    Icons.directions_run,
    Icons.directions_bike,
  ];

  static const _typeLabels = ['Caminhada', 'Corrida', 'Ciclismo'];

  // ── formatadores reutilizados em build e nos modais ──────────────────
  static String _fmtWeekDuration(Duration d) {
    if (d.inMinutes == 0) return '0 min';
    if (d.inHours == 0) return '${d.inMinutes} min';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  static String _fmtShortDuration(Duration d) {
    if (d.inMinutes == 0) return '0 min';
    if (d.inHours == 0) return '${d.inMinutes} min';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return m == 0 ? '${h} h' : '${h} h ${m} min';
  }

  static String _fmtDate(DateTime dt) {
    final now = DateTime.now();
    final dateOnly = DateTime(dt.year, dt.month, dt.day);
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final t =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (dateOnly == today) return 'Hoje, $t';
    if (dateOnly == yesterday) return 'Ontem, $t';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}, $t';
  }

  // ── filtro corrigido ── usa activityType direto do modelo ─────────────
  bool _matchesSelectedType(RunActivity a) {
    // Aba "Todos" futuramente: quando _selectedType == -1
    final t = a.activityType.toLowerCase();
    switch (_selectedType) {
      case 0:
        return t.contains('camin') || t.contains('walk');
      case 1:
        return t.contains('corr') || t.contains('run');
      case 2:
        return t.contains('cicl') || t.contains('bike') || t.contains('cycle');
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: run,
      builder: (context, _) {
        final weekDistance = run.weekDistanceKm;
        final weekDuration = run.weekDuration;
        final weekCount = run.weekActivitiesCount;
        final activities = run.activities;
        final filteredActivities =
            activities.where(_matchesSelectedType).toList();

        // Atividades da semana atual (todos os tipos — usado no modal "Ver tudo")
        final now = DateTime.now();
        final startOfWeek =
            DateTime(now.year, now.month, now.day - (now.weekday - 1));
        final weekActivities = run.activities
            .where((a) => !a.startTime.isBefore(startOfWeek))
            .toList();

        return Scaffold(
          backgroundColor: Colors.white,
          body: CustomScrollView(
            slivers: [
              // ── APP BAR + HERO SECTION ─────────────────────────────────
              SliverToBoxAdapter(
                child: _HeroSection(
                  selectedType: _selectedType,
                  typeLabels: _typeLabels,
                  typeIcons: _typeIcons,
                  onTypeChanged: (i) => setState(() => _selectedType = i),
                  onStart: () async {
                    // Captura contagem antes para detectar se nova atividade foi salva
                    final prevCount = run.activities.length;
                    final result = await context.pushNamed(
                      'atividade_tracking',
                      extra: _typeKeys[_selectedType],
                    );
                    if (result == true && context.mounted) {
                      await Future.delayed(
                          const Duration(milliseconds: 300));
                      if (!context.mounted) return;
                      // Só abre modal se uma nova atividade foi de fato salva
                      if (run.activities.length > prevCount) {
                        final latest = run.activities.first;
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => ActivityDetailModal(
                            activity: latest,
                            dateString: _fmtDate(latest.startTime),
                            durationString:
                                _fmtShortDuration(latest.duration),
                          ),
                        );
                      }
                    }
                  },
                ),
              ),

              // ── STATS DA SEMANA ────────────────────────────────────────
              SliverToBoxAdapter(
                child: _WeekStatsSection(
                  distance: weekDistance,
                  duration: weekDuration,
                  count: weekCount,
                  onVerTudo: () => _openWeekSummary(
                    context,
                    distance: weekDistance,
                    duration: weekDuration,
                    count: weekCount,
                    weekActivities: weekActivities,
                  ),
                ),
              ),

              // ── HISTÓRICO ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    'Histórico',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: lightText,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),

              if (filteredActivities.isEmpty)
                SliverToBoxAdapter(
                  child: _EmptyHistory(
                    hasAny: activities.isNotEmpty,
                    typeLabel: _typeLabels[_selectedType],
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  sliver: SliverList.separated(
                    itemCount: filteredActivities.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final a = filteredActivities[i];
                      return GestureDetector(
                        onTap: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => ActivityDetailModal(
                            activity: a,
                            dateString: _fmtDate(a.startTime),
                            durationString:
                                _fmtShortDuration(a.duration),
                          ),
                        ),
                        child: _HistoryItem(
                          date: _fmtDate(a.startTime),
                          distance:
                              '${a.distanceKm.toStringAsFixed(2)} km',
                          time: _fmtShortDuration(a.duration),
                          activityType: a.activityType,
                          pace: a.pace,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── "Ver tudo" — lista percursos da semana + métricas agregadas ──────
  void _openWeekSummary(
    BuildContext context, {
    required double distance,
    required Duration duration,
    required int count,
    required List<RunActivity> weekActivities,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (ctx, scrollController) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Cabeçalho fixo
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Atividades desta semana',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: darkText,
                      ),
                    ),
                    const SizedBox(height: 14),
                    IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(
                            child: _SummaryStatCard(
                              label: 'Distância',
                              value: distance.toStringAsFixed(2),
                              unit: 'km',
                              icon: Icons.map_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SummaryStatCard(
                              label: 'Tempo',
                              value: _fmtWeekDuration(duration),
                              unit: '',
                              icon: Icons.timer_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SummaryStatCard(
                              label: 'Atividades',
                              value: '$count',
                              unit: '',
                              icon: Icons.check_circle_outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Percursos',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: lightText,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

              // Lista rolável
              Expanded(
                child: weekActivities.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'Nenhuma atividade registrada nesta semana.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding:
                            const EdgeInsets.fromLTRB(20, 0, 20, 32),
                        itemCount: weekActivities.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (ctx2, i) {
                          final a = weekActivities[i];
                          return GestureDetector(
                            onTap: () {
                              // Abre detalhe em cima do modal da semana
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => ActivityDetailModal(
                                  activity: a,
                                  dateString: _fmtDate(a.startTime),
                                  durationString:
                                      _fmtShortDuration(a.duration),
                                ),
                              );
                            },
                            child: _HistoryItem(
                              date: _fmtDate(a.startTime),
                              distance:
                                  '${a.distanceKm.toStringAsFixed(2)} km',
                              time: _fmtShortDuration(a.duration),
                              activityType: a.activityType,
                              pace: a.pace,
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// ==================== MODAL DE DETALHES + COMPARTILHAR ======================
// ============================================================================

class ActivityDetailModal extends StatefulWidget {
  final RunActivity activity;
  final String dateString;
  final String durationString;

  const ActivityDetailModal({
    super.key,
    required this.activity,
    required this.dateString,
    required this.durationString,
  });

  @override
  State<ActivityDetailModal> createState() => _ActivityDetailModalState();
}

class _ActivityDetailModalState extends State<ActivityDetailModal> {
  final GlobalKey _shareCardKey = GlobalKey();
  final GlobalKey _shareButtonKey = GlobalKey();
  GoogleMapController? _mapController;
  Uint8List? _mapSnapshotBytes;

  static const Color primaryGreen = Color(0xFF669340);
  static const Color darkText = Color(0xFF32384A);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.6,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // ----- CARD CAPTURÁVEL -----
                      RepaintBoundary(
                        key: _shareCardKey,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Cabeçalho
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Detalhes da atividade',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: darkText,
                                        ),
                                      ),
                                      Text(
                                        widget.dateString,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Icon(Icons.directions_run,
                                      color: primaryGreen, size: 30),
                                ],
                              ),
                              const SizedBox(height: 20),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildStatItem('Tempo',
                                      widget.durationString, Icons.timer),
                                  _buildStatItem(
                                      'Distância',
                                      "${widget.activity.distanceKm.toStringAsFixed(2)} km",
                                      Icons.map),
                                  _buildStatItem(
                                      'Ritmo',
                                      widget.activity.pace,
                                      Icons.speed),
                                ],
                              ),
                              const SizedBox(height: 20),

                              const Text(
                                'Percurso',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: darkText,
                                ),
                              ),
                              const SizedBox(height: 12),

                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: SizedBox(
                                  height: 280,
                                  width: double.infinity,
                                  child: Stack(
                                    children: [
                                      if (_mapSnapshotBytes == null)
                                        GoogleMap(
                                          initialCameraPosition:
                                              const CameraPosition(
                                            target: LatLng(0, 0),
                                            zoom: 1,
                                          ),
                                          myLocationEnabled: false,
                                          zoomControlsEnabled: false,
                                          mapToolbarEnabled: false,
                                          rotateGesturesEnabled: false,
                                          tiltGesturesEnabled: false,
                                          polylines: {
                                            Polyline(
                                              polylineId:
                                                  const PolylineId('route'),
                                              points:
                                                  widget.activity.route,
                                              color: primaryGreen,
                                              width: 5,
                                            ),
                                          },
                                          markers: _buildMarkers(),
                                          onMapCreated: (controller) {
                                            _mapController = controller;
                                            _fitBounds(
                                                widget.activity.route);
                                          },
                                        ),
                                      if (_mapSnapshotBytes != null)
                                        Image.memory(
                                          _mapSnapshotBytes!,
                                          width: double.infinity,
                                          height: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      if (widget.activity.route.isEmpty)
                                        Container(
                                          color: Colors.grey[200],
                                          child: const Center(
                                            child: Text(
                                              "Sem dados de GPS",
                                              style: TextStyle(
                                                  color: Colors.grey),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),
                              const Center(
                                child: Text(
                                  "App Parque",
                                  style: TextStyle(
                                    color: primaryGreen,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Botões
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              key: _shareButtonKey,
                              icon: const Icon(Icons.share),
                              label: const Text('Compartilhar'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryGreen,
                                side: const BorderSide(color: primaryGreen),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              onPressed: () => _handleShare(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.download),
                              label: const Text('Salvar imagem'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryGreen,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              onPressed: () => _handleSave(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Set<Marker> _buildMarkers() {
    final route = widget.activity.route;
    if (route.isEmpty) return {};
    return {
      Marker(
        markerId: const MarkerId('start'),
        position: route.first,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueGreen,
        ),
      ),
      Marker(
        markerId: const MarkerId('end'),
        position: route.last,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueRed,
        ),
      ),
    };
  }

  void _fitBounds(List<LatLng> points) {
    if (points.isEmpty || _mapController == null) return;

    double? minLat, maxLat, minLng, maxLng;
    for (final p in points) {
      minLat = (minLat == null || p.latitude < minLat) ? p.latitude : minLat;
      maxLat = (maxLat == null || p.latitude > maxLat) ? p.latitude : maxLat;
      minLng = (minLng == null || p.longitude < minLng) ? p.longitude : minLng;
      maxLng = (maxLng == null || p.longitude > maxLng) ? p.longitude : maxLng;
    }

    if (minLat != null &&
        maxLat != null &&
        minLng != null &&
        maxLng != null) {
      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );

      Future.delayed(const Duration(milliseconds: 300), () {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 50),
        );
      });
    }
  }

  /// Captura o card como PNG.
  /// Etapas:
  /// 1. Tira screenshot nativo do GoogleMap (contorna limitação do Platform View)
  /// 2. Aguarda o rebuild com Image.memory substituindo o mapa
  /// 3. Captura o RepaintBoundary completo via toImage()
  Future<Uint8List?> _capturePng() async {
    try {
      // Passo 1: snapshot do mapa (necessário pois Platform Views não são capturáveis
      // diretamente pelo RepaintBoundary no iOS)
      if (_mapController != null && _mapSnapshotBytes == null) {
        final mapBytes = await _mapController!.takeSnapshot();
        if (mapBytes != null) {
          final completer = Completer<void>();
          setState(() {
            _mapSnapshotBytes = mapBytes;
          });
          // Aguarda o próximo frame para garantir que Image.memory está renderizado
          WidgetsBinding.instance.addPostFrameCallback((_) {
            completer.complete();
          });
          await completer.future;
          // Frame adicional de segurança
          await Future.delayed(const Duration(milliseconds: 80));
        }
      }

      final boundary = _shareCardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Erro ao capturar imagem: $e');
      return null;
    }
  }

  Future<void> _handleShare() async {
    try {
      final bytes = await _capturePng();
      if (!mounted) return;
      if (bytes == null || bytes.isEmpty) {
        _showError(context, 'Erro ao gerar imagem para compartilhar.');
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/atividade_parque.png');
      await file.writeAsBytes(bytes);
      // sharePositionOrigin é obrigatório no iOS para ancorar o popover.
      final box = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
      final origin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : const Rect.fromLTWH(0, 0, 1, 1);
      await Share.shareXFiles([XFile(file.path)], sharePositionOrigin: origin);
    } catch (e) {
      debugPrint('[Share] erro: $e');
      if (!mounted) return;
      _showError(context, 'Erro ao compartilhar.');
    }
  }

  Future<void> _handleSave() async {
    final bytes = await _capturePng();
    if (!mounted) return;
    if (bytes == null) {
      _showError(context, 'Erro ao gerar imagem.');
      return;
    }
    bool ok = false;
    try {
      final result = await ImageGallerySaverPlus.saveImage(
        bytes,
        quality: 95,
        name: 'atividade_parque_${DateTime.now().millisecondsSinceEpoch}',
      );
      ok = result != null &&
          (result['isSuccess'] == true ||
              result['isSuccess']?.toString() == 'true' ||
              result['isSuccess'] == 1 ||
              ((result['filePath'] ?? '').toString().isNotEmpty));
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    if (ok) {
      AppToast.show(context, 'Imagem salva na galeria!', type: ToastType.success);
    } else {
      _showError(context, 'Não foi possível salvar na galeria.');
    }
  }

  void _showError(BuildContext context, String msg) {
    AppToast.show(context, msg, type: ToastType.error);
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
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
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
      ],
    );
  }
}

// ============================================================================
// ==================== HERO SECTION ==========================================
// ============================================================================

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.selectedType,
    required this.typeLabels,
    required this.typeIcons,
    required this.onTypeChanged,
    required this.onStart,
  });

  final int selectedType;
  final List<String> typeLabels;
  final List<IconData> typeIcons;
  final ValueChanged<int> onTypeChanged;
  final VoidCallback onStart;

  static const _green = Color(0xFF669340);
  static const _lightText = Color(0xFF8F959E);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            children: [
              // Título
              const Text(
                'Atividade',
                style: TextStyle(
                  color: _green,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),

              // Tipo selecionado em destaque
              Text(
                typeLabels[selectedType],
                style: const TextStyle(
                  fontSize: 14,
                  color: _lightText,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),

              // Botão INICIAR
              GestureDetector(
                onTap: onStart,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    color: _green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _green.withValues(alpha: 0.45),
                        blurRadius: 28,
                        spreadRadius: 2,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(typeIcons[selectedType],
                          color: Colors.white, size: 32),
                      const SizedBox(height: 4),
                      const Text(
                        'INICIAR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Seletor de tipo — segmented control
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                ),
                child: Row(
                  children: List.generate(typeLabels.length, (i) {
                    final selected = selectedType == i;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onTypeChanged(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                typeIcons[i],
                                size: 16,
                                color: selected ? _green : _lightText,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                              child: Text(
                                typeLabels[i],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected ? _green : _lightText,
                                ),
                              ),
                            ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ==================== WEEK STATS SECTION ====================================
// ============================================================================

class _WeekStatsSection extends StatelessWidget {
  const _WeekStatsSection({
    required this.distance,
    required this.duration,
    required this.count,
    required this.onVerTudo,
  });

  final double distance;
  final Duration duration;
  final int count;
  final VoidCallback onVerTudo;

  static const _green = Color(0xFF669340);
  static const _darkText = Color(0xFF32384A);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFECECEC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Esta Semana',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _darkText,
                ),
              ),
              GestureDetector(
                onTap: onVerTudo,
                child: const Text(
                  'Ver tudo',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatItem(
                icon: Icons.map_outlined,
                value: distance.toStringAsFixed(2),
                unit: 'km',
                label: 'Distância',
              ),
              _vDivider(),
              _StatItem(
                icon: Icons.timer_outlined,
                value: _fmtMin(duration),
                unit: '',
                label: 'Tempo',
              ),
              _vDivider(),
              _StatItem(
                icon: Icons.check_circle_outline,
                value: '$count',
                unit: '',
                label: 'Atividades',
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmtMin(Duration d) {
    if (d.inMinutes == 0) return '0';
    if (d.inHours == 0) return '${d.inMinutes}';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return m == 0 ? '${h}h' : '${h}h${m}m';
  }

  Widget _vDivider() => Container(
        width: 1,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: const Color(0xFFEEEEEE),
      );
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF669340)),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(
                    CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                child: child,
              ),
            ),
            child: RichText(
              key: ValueKey(value + unit),
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF32384A),
                    ),
                  ),
                  if (unit.isNotEmpty)
                    TextSpan(
                      text: ' $unit',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8F959E),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF8F959E),
            ),
          ),
        ],
      ),
    );
  }
}

// Card usado dentro do modal "Ver tudo" — sem Spacer, altura intrínseca
class _SummaryStatCard extends StatelessWidget {
  const _SummaryStatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF669340),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: Colors.white),
          const SizedBox(height: 8),
          Text(
            unit.isEmpty ? value : '$value $unit',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ==================== EMPTY STATE ===========================================
// ============================================================================

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.hasAny, required this.typeLabel});

  final bool hasAny;
  final String typeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF669340),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.directions_run,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              hasAny
                  ? 'Nenhuma atividade de $typeLabel encontrada.\nTente selecionar outro modo.'
                  : 'Nenhuma atividade registrada ainda.\nVamos começar?',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF8F959E),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ==================== WIDGETS AUXILIARES (CHIPS/CARDS) ======================
// ============================================================================

class _HistoryItem extends StatelessWidget {
  final String date;
  final String distance;
  final String time;
  final String activityType;
  final String pace;

  const _HistoryItem({
    required this.date,
    required this.distance,
    required this.time,
    required this.activityType,
    required this.pace,
  });

  static IconData _iconForType(String t) {
    final lower = t.toLowerCase();
    if (lower.contains('camin') || lower.contains('walk')) {
      return Icons.directions_walk;
    }
    if (lower.contains('cicl') || lower.contains('bike')) {
      return Icons.directions_bike;
    }
    return Icons.directions_run;
  }

  static String _labelForType(String t) {
    final lower = t.toLowerCase();
    if (lower.contains('camin') || lower.contains('walk')) return 'Caminhada';
    if (lower.contains('cicl') || lower.contains('bike')) return 'Ciclismo';
    return 'Corrida';
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF669340);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_iconForType(activityType), color: green, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _labelForType(activityType),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF32384A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8F959E),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                distance,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color(0xFF32384A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8F959E),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right,
              color: Color(0xFFCCCCCC), size: 18),
        ],
      ),
    );
  }
}