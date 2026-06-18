// lib/data/repositories/space_repository.dart
import 'dart:convert';
import '../../core/api/api_client.dart';
import '../models/space.dart';

class SpaceRepository {
  final ApiClient _api = ApiClient();

  /// Fetches a list of spaces filtered by category and/or park ID.
  /// Pass [permiteReserva] = true to show only reservable spaces (reservations catalog).
  /// Pass [permiteReserva] = null (default) for no filter (admin / event flow).
  Future<List<Space>> fetchSpaces({String? category, int? parkId, bool? permiteReserva}) async {
    try {
      final query = <String, dynamic>{};
      if (category != null && category.isNotEmpty) {
        query['categoria'] = category;
      }
      if (parkId != null && parkId > 0) {
        query['park_id'] = parkId.toString();
      }
      if (permiteReserva != null) {
        query['permite_reserva'] = permiteReserva ? 'true' : 'false';
      }

      final res = await _api.get('spaces', query: query);
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body) as List;
        return list
            .whereType<Map<String, dynamic>>()
            .map((e) => Space.fromJson(e))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Fetches a specific space details by its ID.
  Future<Space?> fetchSpaceById(int id) async {
    try {
      final res = await _api.get('spaces/$id');
      if (res.statusCode == 200) {
        return Space.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Fetches available hourly slots for a specific space and date.
  Future<List<String>> fetchAvailability(int spaceId, String dateStr) async {
    try {
      final res = await _api.get('spaces/$spaceId/disponibilidade', query: {'data': dateStr});
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body) as List;
        return list.map((e) => e.toString()).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Attempts to submit a new reservation.
  /// Returns a Map containing success state, reservation id or error message.
  Future<Map<String, dynamic>> createReservation({
    required int spaceId,
    required String dateStr,
    required String startTime,
    required String endTime,
  }) async {
    try {
      final res = await _api.post(
        'spaces/reservations',
        body: {
          'space_id': spaceId,
          'data': dateStr,
          'hora_inicio': startTime,
          'hora_fim': endTime,
        },
      );

      if (res.statusCode == 201) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return {'success': true, 'id': data['id'], 'status': data['status']};
      } else {
        final errorMsg = _extractError(res.body) ?? 'Falha ao realizar agendamento.';
        return {'success': false, 'error': errorMsg};
      }
    } catch (_) {
      return {'success': false, 'error': 'Erro de conexão.'};
    }
  }

  String? _extractError(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['error']?.toString();
    } catch (_) {
      return null;
    }
  }
}
