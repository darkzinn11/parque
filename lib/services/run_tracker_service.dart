// lib/services/run_tracker_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class RunService extends ChangeNotifier {
  // --------- Singleton ---------
  RunService._internal();
  static final RunService instance = RunService._internal();

  // --------- Filtros anti-spike GPS ---------
  // Rejeita posições com precisão pior que este valor (metros).
  static const double _maxAccuracyMeters = 20.0;

  // Velocidade máxima aceitável por tipo de atividade (km/h).
  // Qualquer ponto que implique velocidade acima disso é descartado como spike.
  static const Map<String, double> _maxSpeedKmh = {
    'caminhada': 12.0,
    'corrida': 36.0,
    'ciclismo': 65.0,
  };

  // --------- Estado atual da corrida ---------
  bool _isRunning = false;
  bool _isPaused = false;
  DateTime? _startTime;
  Duration _elapsed = Duration.zero;
  double _distanceMeters = 0;
  List<LatLng> _routeCoords = [];
  String _activityType = 'corrida';
  DateTime? _lastPositionTime; // timestamp do último ponto aceito

  Timer? _timer;
  StreamSubscription<Position>? _positionSub;

  // --------- Histórico ---------
  final List<RunActivity> _activities = [];

  // --------- Getters públicos usados nas telas ---------
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;

  List<LatLng> get routeCoords => List.unmodifiable(_routeCoords);

  String get timeStr => _formatDuration(_elapsed);

  double get distanceKm => _distanceMeters / 1000.0;
  String get distanceKmStr => distanceKm.toStringAsFixed(2);

  /// Ritmo em min/km (ex.: 04:31 min/km)
  String get pace {
    if (distanceKm <= 0 || _elapsed.inSeconds == 0) return '--';
    final totalMinutes = _elapsed.inSeconds / 60.0;
    final pace = totalMinutes / distanceKm; // min / km
    final m = pace.floor();
    final s = ((pace - m) * 60).round();
    final sStr = s.toString().padLeft(2, '0');
    return '${m.toString().padLeft(2, '0')}:$sStr min/km';
  }

  // --------- Estatísticas da semana ---------
  List<RunActivity> get activities => List.unmodifiable(_activities);

  double get weekDistanceKm {
    final list = _activitiesThisWeek();
    return list.fold(0.0, (sum, a) => sum + a.distanceKm);
  }

  Duration get weekDuration {
    final list = _activitiesThisWeek();
    return list.fold<Duration>(
      Duration.zero,
      (sum, a) => sum + a.duration,
    );
  }

  int get weekActivitiesCount => _activitiesThisWeek().length;

  List<RunActivity> _activitiesThisWeek() {
    if (_activities.isEmpty) return const [];
    final now = DateTime.now();
    // últimos 7 dias
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    return _activities
        .where((a) => a.startTime.isAfter(sevenDaysAgo))
        .toList();
  }

  // --------- Controle de corrida ---------

  Future<void> start({String activityType = 'corrida'}) async {
    if (_isRunning) return;

    _activityType = activityType;

    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) {
      throw Exception('Permissão de localização negada.');
    }

    // Aguarda um fix com boa precisão antes de iniciar
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
      ),
    );

    _isRunning = true;
    _isPaused = false;
    _startTime = DateTime.now();
    _elapsed = Duration.zero;
    _distanceMeters = 0;
    _lastPositionTime = DateTime.now();
    _routeCoords = [LatLng(position.latitude, position.longitude)];

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isRunning || _isPaused || _startTime == null) return;
      _elapsed = DateTime.now().difference(_startTime!);
      notifyListeners();
    });

    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 3,
      ),
    ).listen((pos) {
      if (!_isRunning || _isPaused) return;

      // ── Filtro 1: precisão do GPS ──────────────────────────────────────
      // Rejeita posições com círculo de incerteza maior que o limite.
      // Quedas de satélite tipicamente aumentam accuracy antes do spike.
      if (pos.accuracy > _maxAccuracyMeters) return;

      final newPoint = LatLng(pos.latitude, pos.longitude);
      final now = DateTime.now();

      if (_routeCoords.isNotEmpty) {
        final last = _routeCoords.last;
        final delta = Geolocator.distanceBetween(
          last.latitude,
          last.longitude,
          newPoint.latitude,
          newPoint.longitude,
        );

        // ── Filtro 2: velocidade implícita ────────────────────────────────
        // Calcula km/h entre o último ponto aceito e este novo.
        // Se a velocidade for fisicamente impossível para o tipo de atividade,
        // o ponto é um spike de GPS e deve ser descartado.
        if (_lastPositionTime != null) {
          final seconds =
              now.difference(_lastPositionTime!).inMilliseconds / 1000.0;
          if (seconds > 0) {
            final impliedKmh = (delta / seconds) * 3.6;
            final maxKmh =
                _maxSpeedKmh[_activityType] ?? _maxSpeedKmh['corrida']!;
            if (impliedKmh > maxKmh) return; // spike descartado
          }
        }

        if (delta >= 2) _distanceMeters += delta;
      }

      _routeCoords.add(newPoint);
      _lastPositionTime = now;
      notifyListeners();
    });

    notifyListeners();
  }

  void pause() {
    if (!_isRunning || _isPaused) return;
    _isPaused = true;
    _positionSub?.pause();
    notifyListeners();
  }

  void resume() {
    if (!_isRunning || !_isPaused) return;
    _isPaused = false;
    _positionSub?.resume();
    notifyListeners();
  }

  void stop() {
    if (!_isRunning) return;

    _isRunning = false;
    _isPaused = false;
    _timer?.cancel();
    _positionSub?.cancel();
    _timer = null;
    _positionSub = null;

    final endTime = DateTime.now();
    final start = _startTime ?? endTime;
    final duration = _elapsed;
    final distKm = distanceKm;
    final paceStr = pace;
    final routeSnapshot = List<LatLng>.from(_routeCoords);

    if (distKm > 0 || duration.inSeconds > 0) {
      _activities.insert(
        0,
        RunActivity(
          startTime: start,
          endTime: endTime,
          duration: duration,
          distanceKm: distKm,
          route: routeSnapshot,
          paceStr: paceStr,
          activityType: _activityType,
        ),
      );
    }

    _resetCurrent();
    notifyListeners();
  }

  void _resetCurrent() {
    _startTime = null;
    _elapsed = Duration.zero;
    _distanceMeters = 0;
    _routeCoords = [];
    _lastPositionTime = null;
    _activityType = 'corrida';
  }

  // --------- Helpers ---------

  Future<bool> _ensureLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);

    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }
}

// ----------------------------------------------------------------------
// Modelo de atividade gravada
// ----------------------------------------------------------------------

class RunActivity {
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final double distanceKm;
  final List<LatLng> route;
  final String paceStr;
  final String activityType; // 'caminhada' | 'corrida' | 'ciclismo'

  const RunActivity({
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.distanceKm,
    required this.route,
    required this.paceStr,
    this.activityType = 'corrida',
  });

  String get pace => paceStr;
}
