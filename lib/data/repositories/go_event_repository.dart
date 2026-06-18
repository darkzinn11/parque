// lib/data/repositories/go_event_repository.dart
import 'dart:convert';

import '../../core/api/api_client.dart';
import '../models/event_request.dart';
import '../models/park_activity_type.dart';
import '../models/park_event_rule.dart';

class GoEventRepository {
  final ApiClient _api = ApiClient();

  /// GET /event-requests/rules?park_id=parkId
  Future<List<ParkEventRule>> fetchRules(int parkId) async {
    try {
      final res = await _api.get('event-requests/rules', query: {'park_id': parkId.toString()});
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list
            .whereType<Map<String, dynamic>>()
            .map(ParkEventRule.fromJson)
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// GET /parks/$parkId/activity-types
  Future<List<ParkActivityType>> fetchActivityTypes(int parkId) async {
    try {
      final res = await _api.get('parks/$parkId/activity-types');
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list
            .whereType<Map<String, dynamic>>()
            .map(ParkActivityType.fromJson)
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// POST /event-requests
  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    try {
      final res = await _api.post('event-requests', body: body);
      if (res.statusCode == 201 || res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return {'success': true, 'id': data['id']};
      }
      String? error;
      try {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        error = data['error']?.toString();
      } catch (_) {}
      return {'success': false, 'error': error ?? 'Erro ao enviar solicitação.'};
    } catch (_) {
      return {'success': false, 'error': 'Erro de conexão.'};
    }
  }

  /// POST /event-requests/$id/cancel
  Future<void> cancel(int id) async {
    try {
      await _api.post('event-requests/$id/cancel');
    } catch (_) {}
  }

  /// POST /event-requests/$id/resubmit
  Future<({bool success, String? error})> resubmit(int id) async {
    try {
      final res = await _api.post('event-requests/$id/resubmit');
      if (res.statusCode == 200) return (success: true, error: null);
      String? msg;
      try {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        msg = data['error']?.toString();
      } catch (_) {}
      return (success: false, error: msg ?? 'Erro ao reenviar.');
    } catch (_) {
      return (success: false, error: 'Erro de conexão.');
    }
  }

  /// PUT /event-requests/$id — edita campos e reenvia (Rejeitada → Pendente)
  Future<({bool success, String? error})> updateAndResubmit(
    int id,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _api.put('event-requests/$id', body: body);
      if (res.statusCode == 200) return (success: true, error: null);
      String? msg;
      try {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        msg = data['error']?.toString();
      } catch (_) {}
      return (success: false, error: msg ?? 'Erro ao atualizar solicitação.');
    } catch (_) {
      return (success: false, error: 'Erro de conexão.');
    }
  }

  /// GET /me/event-requests
  Future<List<EventRequest>> fetchMine() async {
    try {
      final res = await _api.get('me/event-requests');
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list
            .whereType<Map<String, dynamic>>()
            .map(EventRequest.fromJson)
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
