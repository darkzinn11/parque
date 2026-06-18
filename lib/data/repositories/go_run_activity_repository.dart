import 'dart:convert';

import '../../core/api/api_client.dart';
import '../../services/run_tracker_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GoRunActivityRepository {
  final ApiClient _api = ApiClient();

  /// POST /me/run-activities — idempotente via client_id.
  /// Retorna o server ID atribuído, ou null em caso de falha.
  Future<int?> create(RunActivity activity) async {
    try {
      final body = {
        'client_id':     activity.id,
        'activity_type': activity.activityType,
        'start_time':    activity.startTime.toUtc().toIso8601String(),
        'end_time':      activity.endTime.toUtc().toIso8601String(),
        'duration_secs': activity.duration.inSeconds,
        'distance_km':   activity.distanceKm,
        'pace_str':      activity.paceStr,
        'route': activity.route
            .map((p) => [p.latitude, p.longitude])
            .toList(),
      };
      final res = await _api.post('me/run-activities', body: body);
      if (res.statusCode == 201 || res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['id'] as num?)?.toInt();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// GET /me/run-activities — lista atividades do usuário no servidor.
  Future<List<RunActivity>> fetchMine() async {
    try {
      final res = await _api.get('me/run-activities');
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list
            .whereType<Map<String, dynamic>>()
            .map(_fromServerJson)
            .whereType<RunActivity>()
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  RunActivity? _fromServerJson(Map<String, dynamic> j) {
    try {
      final rawRoute = (j['route'] as List? ?? []);
      final route = rawRoute
          .whereType<List>()
          .where((p) => p.length >= 2)
          .map((p) => LatLng(
                (p[0] as num).toDouble(),
                (p[1] as num).toDouble(),
              ))
          .toList();
      return RunActivity(
        id:           j['client_id'] as String? ?? '${DateTime.parse(j['start_time'] as String).millisecondsSinceEpoch}',
        serverId:     (j['id'] as num?)?.toInt(),
        startTime:    DateTime.parse(j['start_time'] as String),
        endTime:      DateTime.parse(j['end_time'] as String),
        duration:     Duration(seconds: (j['duration_secs'] as num).toInt()),
        distanceKm:   (j['distance_km'] as num).toDouble(),
        paceStr:      j['pace_str'] as String? ?? '--',
        activityType: j['activity_type'] as String? ?? 'corrida',
        route:        route,
        // synced é derivado de serverId (não-nulo aqui) — campo removido do modelo
      );
    } catch (_) {
      return null;
    }
  }
}
