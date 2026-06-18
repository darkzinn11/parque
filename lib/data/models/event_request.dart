// lib/data/models/event_request.dart

class EventRequest {
  final int id;
  final int parkId;
  final String parkName;
  final int spaceId;
  final String spaceName;
  final String dataEvento;        // "YYYY-MM-DD"
  final String horaInicio;
  final String horaFim;
  final String tipoAtividade;
  final int quantidadePessoas;
  final String objetivo;
  final String nomeResponsavel;
  final String contatoResponsavel;
  final bool apoioBPA;
  final String status;            // Pendente, Aprovada, Rejeitada, Cancelada
  final String motivoRejeicao;
  final String motivoCancelamento;
  final String createdAt;

  const EventRequest({
    required this.id,
    required this.parkId,
    required this.parkName,
    required this.spaceId,
    required this.spaceName,
    required this.dataEvento,
    required this.horaInicio,
    required this.horaFim,
    required this.tipoAtividade,
    required this.quantidadePessoas,
    required this.objetivo,
    required this.nomeResponsavel,
    required this.contatoResponsavel,
    required this.apoioBPA,
    required this.status,
    required this.motivoRejeicao,
    required this.motivoCancelamento,
    required this.createdAt,
  });

  factory EventRequest.fromJson(Map<String, dynamic> json) {
    return EventRequest(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id'] ?? 0}') ?? 0,
      parkId: json['park_id'] is int ? json['park_id'] : int.tryParse('${json['park_id'] ?? 0}') ?? 0,
      parkName: (json['park_name'] ?? json['parque_nome'] ?? '').toString(),
      spaceId: json['space_id'] is int ? json['space_id'] : int.tryParse('${json['space_id'] ?? 0}') ?? 0,
      spaceName: (json['space_name'] ?? json['espaco_nome'] ?? '').toString(),
      dataEvento: (json['data_evento'] ?? json['data'] ?? '').toString(),
      horaInicio: (json['hora_inicio'] ?? '').toString(),
      horaFim: (json['hora_fim'] ?? '').toString(),
      tipoAtividade: (json['tipo_atividade'] ?? '').toString(),
      quantidadePessoas: json['quantidade_pessoas'] is int
          ? json['quantidade_pessoas']
          : int.tryParse('${json['quantidade_pessoas'] ?? 0}') ?? 0,
      objetivo: (json['objetivo'] ?? '').toString(),
      nomeResponsavel: (json['nome_responsavel'] ?? '').toString(),
      contatoResponsavel: (json['contato_responsavel'] ?? '').toString(),
      apoioBPA: json['apoio_bpa'] == true,
      status: (json['status'] ?? 'Pendente').toString(),
      motivoRejeicao: (json['motivo_rejeicao'] ?? '').toString(),
      motivoCancelamento: (json['motivo_cancelamento'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}
