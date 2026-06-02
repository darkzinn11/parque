// lib/data/models/reservation.dart

class Participant {
  final String nome;
  final String cpf;

  const Participant({required this.nome, required this.cpf});

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      nome: (json['nome'] ?? '').toString(),
      cpf: (json['cpf'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {'nome': nome, 'cpf': cpf};
}

class Reservation {
  final int id;
  final int spaceId;
  final String spaceName;
  final String parkName;
  final int capacityMax;
  final String data; // YYYY-MM-DD
  final String horaInicio; // HH:MM
  final String horaFim; // HH:MM
  final String status; // Pendente | Aprovada | Rejeitada | Expirada
  final DateTime? rejectedAt;
  final List<Participant> participants;

  const Reservation({
    required this.id,
    required this.spaceId,
    required this.spaceName,
    required this.parkName,
    required this.capacityMax,
    required this.data,
    required this.horaInicio,
    required this.horaFim,
    required this.status,
    required this.rejectedAt,
    required this.participants,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) {
    final space = json['space'] as Map<String, dynamic>?;
    final park = space?['park'] as Map<String, dynamic>?;

    // data_reserva vem como ISO (ex: 2026-06-03T00:00:00Z) — pegamos só o dia.
    String dataStr = (json['data_reserva'] ?? '').toString();
    if (dataStr.contains('T')) dataStr = dataStr.split('T').first;

    DateTime? rejected;
    final rejectedRaw = json['rejected_at'];
    if (rejectedRaw != null && rejectedRaw.toString().isNotEmpty) {
      rejected = DateTime.tryParse(rejectedRaw.toString());
    }

    final rawParticipants = (json['participants'] as List?) ?? const [];

    return Reservation(
      id: _asInt(json['id']),
      spaceId: _asInt(json['space_id']),
      spaceName: (space?['nome'] ?? 'Espaço').toString(),
      parkName: (park?['nome'] ?? '').toString(),
      capacityMax: _asInt(space?['capacidade_max']),
      data: dataStr,
      horaInicio: (json['hora_inicio'] ?? '').toString(),
      horaFim: (json['hora_fim'] ?? '').toString(),
      status: (json['status'] ?? 'Pendente').toString(),
      rejectedAt: rejected,
      participants: rawParticipants
          .whereType<Map<String, dynamic>>()
          .map(Participant.fromJson)
          .toList(),
    );
  }

  /// Tempo restante para reenviar uma reserva rejeitada (janela de 2h).
  /// Retorna null se não estiver rejeitada ou se o prazo já expirou.
  Duration? get resubmitTimeLeft {
    if (status != 'Rejeitada' || rejectedAt == null) return null;
    final deadline = rejectedAt!.add(const Duration(hours: 2));
    final left = deadline.difference(DateTime.now());
    return left.isNegative ? null : left;
  }

  bool get canResubmit => resubmitTimeLeft != null;

  static int _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse('$v') ?? 0;
  }
}
