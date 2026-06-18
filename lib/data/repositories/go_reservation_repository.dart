// lib/data/repositories/go_reservation_repository.dart
import 'dart:convert';

import '../../core/api/api_client.dart';
import '../models/reservation.dart';

/// Resultado de uma operação de criação/reenvio de reserva.
class ReservationResult {
  final bool success;
  final int? id;
  final String? error;
  final int? statusCode;

  const ReservationResult({
    required this.success,
    this.id,
    this.error,
    this.statusCode,
  });
}

class GoReservationRepository {
  final ApiClient _api = ApiClient();

  /// Cria uma nova reserva (status sempre "Pendente" no backend).
  Future<ReservationResult> create({
    required int spaceId,
    required String dateStr,
    required String startTime,
    required List<Participant> participants,
    int duracaoHoras = 1,
  }) async {
    try {
      final res = await _api.post('reservations', body: {
        'space_id': spaceId,
        'data': dateStr,
        'hora_inicio': startTime,
        'duracao_horas': duracaoHoras,
        'participants': participants.map((p) => p.toJson()).toList(),
      });

      if (res.statusCode == 201) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return ReservationResult(success: true, id: data['id'] as int?);
      }
      return ReservationResult(
        success: false,
        statusCode: res.statusCode,
        error: _extractError(res.body),
      );
    } catch (_) {
      return const ReservationResult(success: false, error: 'Erro de conexão.');
    }
  }

  /// Reenvia uma reserva rejeitada (dentro da janela de 2h).
  Future<ReservationResult> resubmit({
    required int id,
    required List<Participant> participants,
  }) async {
    try {
      final res = await _api.put('reservations/$id', body: {
        'participants': participants.map((p) => p.toJson()).toList(),
      });

      if (res.statusCode == 200) {
        return ReservationResult(success: true, id: id);
      }
      return ReservationResult(
        success: false,
        statusCode: res.statusCode,
        error: _extractError(res.body),
      );
    } catch (_) {
      return const ReservationResult(success: false, error: 'Erro de conexão.');
    }
  }

  /// Lista as reservas do usuário logado.
  Future<List<Reservation>> fetchMine() async {
    try {
      final res = await _api.get('me/reservations');
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list
            .whereType<Map<String, dynamic>>()
            .map(Reservation.fromJson)
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Busca uma reserva pelo ID (usado ao abrir deeplink de notificação).
  Future<Reservation?> getById(int id) async {
    try {
      final res = await _api.get('reservations/$id');
      if (res.statusCode == 200) {
        return Reservation.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Cancela uma reserva do próprio usuário.
  Future<ReservationResult> cancel(int id) async {
    try {
      final res = await _api.post('reservations/$id/cancel');
      if (res.statusCode == 200) return ReservationResult(success: true, id: id);
      return ReservationResult(success: false, statusCode: res.statusCode, error: _extractError(res.body));
    } catch (_) {
      return const ReservationResult(success: false, error: 'Erro de conexão.');
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
