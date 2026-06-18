import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import '../data/repositories/go_run_activity_repository.dart';

class RunService extends ChangeNotifier {
  // ── Singleton ──────────────────────────────────────────────────────────────
  RunService._internal();
  static final RunService instance = RunService._internal();

  final _cloudRepo = GoRunActivityRepository();

  // ── Precisão máxima aceitável de um fix GPS (metros) ──────────────────────
  static const double _maxAccuracyMeters = 30.0;

  // ── Limites de velocidade por atividade (m/s) ─────────────────────────────
  static const Map<String, double> _maxSpeedMs = {
    'caminhada': 4.0,   // ~14 km/h
    'corrida':   12.0,  // ~43 km/h
    'ciclismo':  22.0,  // ~79 km/h
  };

  // ── Estado da sessão ───────────────────────────────────────────────────────
  bool _isRunning = false;
  bool _isPaused  = false;
  DateTime? _startTime;
  DateTime? _pauseStart;
  Duration  _pausedDuration = Duration.zero;
  Duration  _elapsed        = Duration.zero;
  double    _distanceMeters = 0;
  List<LatLng> _routeCoords = [];
  String    _activityType   = 'corrida';
  LatLng?   _lastAcceptedPoint;

  String _paceCache    = '--';
  String _timeStrCache = '00:00';
  double _lastAccuracy = 999;

  Timer? _timer;
  StreamSubscription<Position>? _positionSub;

  // ── Histórico ─────────────────────────────────────────────────────────────
  final List<RunActivity> _activities = [];
  static const _prefsKey = 'run_activities_v2'; // v2 — novo schema com id/serverId

  // ── Getters públicos ──────────────────────────────────────────────────────
  bool get isRunning  => _isRunning;
  bool get isPaused   => _isPaused;
  List<LatLng> get routeCoords => List.unmodifiable(_routeCoords);
  String get timeStr    => _timeStrCache;
  String get pace       => _paceCache;
  double get distanceKm => _distanceMeters / 1000.0;
  String get distanceKmStr => distanceKm.toStringAsFixed(2);
  double get lastAccuracy  => _lastAccuracy;
  bool get awaitingGpsFix => _isRunning && !_isPaused && _routeCoords.isEmpty;

  // ── Persistência local ────────────────────────────────────────────────────
  Future<void> loadActivities() async {
    await _loadLocal();

    // Se logado, busca da nuvem e mescla em background
    if (AuthService.instance.tokenSync != null) {
      _mergeFromCloud(); // não awaita — offline-first
      // Sobe pendentes no cold start (sem awaitar — offline-first)
      unawaited(syncPending());
    }
  }

  Future<void> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final list = jsonDecode(raw) as List;
      final loaded = <RunActivity>[];
      for (final item in list) {
        try {
          loaded.add(RunActivity.fromJson(item as Map<String, dynamic>));
        } catch (_) {
          // ignora entradas corrompidas individualmente
        }
      }
      _activities
        ..clear()
        ..addAll(loaded);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _activities.take(200).map((a) => a.toJson()).toList();
      await prefs.setString(_prefsKey, jsonEncode(list));
    } catch (_) {}
  }

  // ── Sincronização com a nuvem ─────────────────────────────────────────────

  /// Envia atividade para a nuvem e atualiza serverId localmente.
  Future<void> _syncActivityToCloud(RunActivity activity) async {
    if (AuthService.instance.tokenSync == null) return;
    try {
      final serverId = await _cloudRepo.create(activity);
      if (serverId != null) {
        final idx = _activities.indexWhere((a) => a.id == activity.id);
        if (idx != -1) {
          _activities[idx] = _activities[idx].copyWith(serverId: serverId);
          await _saveLocal();
        }
      }
    } catch (_) {}
  }

  /// Busca atividades da nuvem e adiciona as que não existem localmente.
  Future<void> _mergeFromCloud() async {
    try {
      final remote = await _cloudRepo.fetchMine();
      if (remote.isEmpty) return;

      final localIds = _activities.map((a) => a.id).toSet();
      final newOnes = remote.where((r) => !localIds.contains(r.id)).toList();
      if (newOnes.isEmpty) return;

      // Insere as novas da nuvem, mantendo ordem cronológica inversa
      _activities.addAll(newOnes);
      _activities.sort((a, b) => b.startTime.compareTo(a.startTime));
      await _saveLocal();
      notifyListeners();
    } catch (_) {}
  }

  /// Guard de in-flight: evita uploads concorrentes da mesma atividade
  /// (o listener de auth no main.dart chama syncPending a cada notificação).
  bool _syncing = false;

  /// Sincroniza todas as atividades pendentes (sem serverId) para a nuvem.
  Future<void> syncPending() async {
    if (AuthService.instance.tokenSync == null) return;
    if (_syncing) return;
    _syncing = true;
    try {
      final pending = _activities.where((a) => !a.synced).toList();
      for (final a in pending) {
        await _syncActivityToCloud(a);
      }
    } finally {
      _syncing = false;
    }
  }

  // ── Estatísticas da semana ────────────────────────────────────────────────
  List<RunActivity> get activities => List.unmodifiable(_activities);

  double get weekDistanceKm =>
      _activitiesThisWeek().fold(0.0, (s, a) => s + a.distanceKm);

  Duration get weekDuration =>
      _activitiesThisWeek().fold(Duration.zero, (s, a) => s + a.duration);

  int get weekActivitiesCount => _activitiesThisWeek().length;

  List<RunActivity> _activitiesThisWeek() {
    if (_activities.isEmpty) return const [];
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    return _activities.where((a) => !a.startTime.isBefore(startOfWeek)).toList();
  }

  // ── Início ────────────────────────────────────────────────────────────────
  Future<void> start({String activityType = 'corrida'}) async {
    if (_isRunning) return;

    _activityType = activityType;

    if (!await _ensureLocationPermission()) {
      throw Exception('Permissão de localização negada.');
    }

    _isRunning        = true;
    _isPaused         = false;
    _startTime        = DateTime.now();
    _elapsed          = Duration.zero;
    _pausedDuration   = Duration.zero;
    _pauseStart       = null;
    _distanceMeters   = 0;
    _routeCoords      = [];
    _lastAcceptedPoint = null;
    _lastAccuracy     = 999;
    _paceCache        = '--';
    _timeStrCache     = '00:00';

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isRunning || _isPaused || _startTime == null) return;
      _elapsed        = DateTime.now().difference(_startTime!) - _pausedDuration;
      _timeStrCache   = _formatDuration(_elapsed);
      _paceCache      = _computePace();
      notifyListeners();
    });

    _positionSub?.cancel();
    _positionSub = _buildStream().listen(_onPosition);

    notifyListeners();
  }

  // ── Stream por plataforma ─────────────────────────────────────────────────
  Stream<Position> _buildStream() {
    if (Platform.isIOS) {
      return Geolocator.getPositionStream(
        locationSettings: AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 1,
          pauseLocationUpdatesAutomatically: false,
          allowBackgroundLocationUpdates: true,
          activityType: ActivityType.fitness,
          showBackgroundLocationIndicator: true,
        ),
      );
    }
    return Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
        intervalDuration: const Duration(milliseconds: 500),
        forceLocationManager: false,
      ),
    );
  }

  // ── Processamento de cada fix GPS ─────────────────────────────────────────
  void _onPosition(Position pos) {
    if (!_isRunning || _isPaused) return;

    // Descarta fixes imprecisos ANTES de aceitar qualquer ponto (inclusive o 1º)
    if (pos.accuracy > 0 && pos.accuracy > _maxAccuracyMeters) return;

    _lastAccuracy = pos.accuracy;
    final newPoint = LatLng(pos.latitude, pos.longitude);

    if (_lastAcceptedPoint == null) {
      _routeCoords.add(newPoint);
      _lastAcceptedPoint = newPoint;
      notifyListeners();
      return;
    }

    final delta = Geolocator.distanceBetween(
      _lastAcceptedPoint!.latitude,
      _lastAcceptedPoint!.longitude,
      newPoint.latitude,
      newPoint.longitude,
    );

    if (delta < 1) return;

    final maxMs = _maxSpeedMs[_activityType] ?? _maxSpeedMs['corrida']!;
    if (pos.speed >= 0 && pos.speed > maxMs) return;

    _distanceMeters   += delta;
    _routeCoords.add(newPoint);
    _lastAcceptedPoint = newPoint;
    notifyListeners();
  }

  // ── Pausa / Retomada ──────────────────────────────────────────────────────
  void pause() {
    if (!_isRunning || _isPaused) return;
    _isPaused   = true;
    _pauseStart = DateTime.now();
    _positionSub?.cancel();
    _positionSub = null;
    notifyListeners();
  }

  void resume() {
    if (!_isRunning || !_isPaused) return;
    if (_pauseStart != null) {
      _pausedDuration += DateTime.now().difference(_pauseStart!);
      _pauseStart = null;
    }
    _isPaused          = false;
    _lastAcceptedPoint = _routeCoords.isNotEmpty ? _routeCoords.last : null;
    _positionSub = _buildStream().listen(_onPosition);
    notifyListeners();
  }

  // ── Encerramento ──────────────────────────────────────────────────────────
  void stop() {
    if (!_isRunning) return;
    _positionSub?.cancel();
    _positionSub = null;
    _timer?.cancel();
    _timer = null;

    _isRunning = false;
    _isPaused  = false;

    final endTime       = DateTime.now();
    final start         = _startTime ?? endTime;
    final duration      = _elapsed;
    final distKm        = distanceKm;
    final routeSnapshot = List<LatLng>.from(_routeCoords);

    if (distKm >= 0.02 && duration.inSeconds >= 5) {
      final activity = RunActivity(
        id:           start.millisecondsSinceEpoch.toString(),
        startTime:    start,
        endTime:      endTime,
        duration:     duration,
        distanceKm:   distKm,
        route:        routeSnapshot,
        paceStr:      _paceCache,
        activityType: _activityType,
      );
      _activities.insert(0, activity);
      _saveLocal(); // sem await — UI não deve esperar

      // Sincroniza com a nuvem em background, se logado
      _syncActivityToCloud(activity);
    }

    _resetCurrent();
    notifyListeners();
  }

  void _resetCurrent() {
    _startTime         = null;
    _pauseStart        = null;
    _pausedDuration    = Duration.zero;
    _elapsed           = Duration.zero;
    _distanceMeters    = 0;
    _routeCoords       = [];
    _lastAcceptedPoint = null;
    _activityType      = 'corrida';
    _paceCache         = '--';
    _timeStrCache      = '00:00';
    _lastAccuracy      = 999;
  }

  // ── Cálculos internos ─────────────────────────────────────────────────────
  String _computePace() {
    if (distanceKm <= 0 || _elapsed.inSeconds == 0) return '--';
    final minPerKm = (_elapsed.inSeconds / 60.0) / distanceKm;
    final m = minPerKm.floor();
    final s = ((minPerKm - m) * 60).round();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')} min/km';
  }

  Future<bool> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm != LocationPermission.denied &&
           perm != LocationPermission.deniedForever;
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
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

// ── Modelo de atividade ───────────────────────────────────────────────────────

class RunActivity {
  final String id;          // startTime.ms — chave local de deduplicação
  final int?   serverId;    // ID no banco do servidor (null = ainda não sincronizado)

  /// Derivado: já está na nuvem se possui serverId. Evita divergência com serverId.
  bool get synced => serverId != null;

  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final double distanceKm;
  final List<LatLng> route;
  final String paceStr;
  final String activityType;

  const RunActivity({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.distanceKm,
    required this.route,
    required this.paceStr,
    this.activityType = 'corrida',
    this.serverId,
  });

  String get pace => paceStr;

  RunActivity copyWith({int? serverId}) => RunActivity(
    id:           id,
    startTime:    startTime,
    endTime:      endTime,
    duration:     duration,
    distanceKm:   distanceKm,
    route:        route,
    paceStr:      paceStr,
    activityType: activityType,
    serverId:     serverId ?? this.serverId,
  );

  Map<String, dynamic> toJson() => {
    'id':           id,
    'serverId':     serverId,
    'startTime':    startTime.toIso8601String(),
    'endTime':      endTime.toIso8601String(),
    'durationSecs': duration.inSeconds,
    'distanceKm':   distanceKm,
    'paceStr':      paceStr,
    'activityType': activityType,
    'route': route.map((p) => [p.latitude, p.longitude]).toList(),
  };

  factory RunActivity.fromJson(Map<String, dynamic> j) {
    final rawRoute = (j['route'] as List? ?? []);
    final route = rawRoute
        .whereType<List>()
        .where((p) => p.length >= 2)
        .map((p) => LatLng(
              (p[0] as num).toDouble(),
              (p[1] as num).toDouble(),
            ))
        .toList();

    // Compatibilidade: registros antigos podem não ter 'id'
    final startTime = DateTime.parse(j['startTime'] as String);
    final id = j['id'] as String? ?? startTime.millisecondsSinceEpoch.toString();

    return RunActivity(
      id:           id,
      serverId:     j['serverId'] as int?,
      startTime:    startTime,
      endTime:      DateTime.parse(j['endTime'] as String),
      duration:     Duration(seconds: (j['durationSecs'] as num).toInt()),
      distanceKm:   (j['distanceKm'] as num).toDouble(),
      paceStr:      j['paceStr'] as String? ?? '--',
      activityType: j['activityType'] as String? ?? 'corrida',
      route:        route,
    );
  }
}
