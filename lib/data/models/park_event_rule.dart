// lib/data/models/park_event_rule.dart

class ParkEventRule {
  final int id;
  final int parkId;
  final String titulo;
  final String tipoAtividade; // "" = todas
  final int thresholdMin; // 0 = sem mínimo; >0 = gatilho qtd pessoas
  final int thresholdMax;
  final String texto;
  final bool bpaObrigatorio;
  final int minParticipantes;
  final bool obrigatoria;
  final bool ativo;
  final int ordem;

  const ParkEventRule({
    required this.id,
    required this.parkId,
    required this.titulo,
    required this.tipoAtividade,
    required this.thresholdMin,
    required this.thresholdMax,
    required this.texto,
    required this.bpaObrigatorio,
    required this.minParticipantes,
    required this.obrigatoria,
    required this.ativo,
    required this.ordem,
  });

  factory ParkEventRule.fromJson(Map<String, dynamic> json) {
    return ParkEventRule(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id'] ?? 0}') ?? 0,
      parkId: json['park_id'] is int ? json['park_id'] : int.tryParse('${json['park_id'] ?? 0}') ?? 0,
      titulo: (json['titulo'] ?? '').toString(),
      tipoAtividade: (json['tipo_atividade'] ?? '').toString(),
      thresholdMin: json['threshold_min'] is int ? json['threshold_min'] : int.tryParse('${json['threshold_min'] ?? 0}') ?? 0,
      thresholdMax: json['threshold_max'] is int ? json['threshold_max'] : int.tryParse('${json['threshold_max'] ?? 0}') ?? 0,
      texto: (json['texto'] ?? '').toString(),
      bpaObrigatorio: json['bpa_obrigatorio'] == true,
      minParticipantes: json['min_participantes'] is int ? json['min_participantes'] : int.tryParse('${json['min_participantes'] ?? 0}') ?? 0,
      obrigatoria: json['obrigatoria'] == true,
      ativo: json['ativo'] != false, // default true se null
      ordem: json['ordem'] is int ? json['ordem'] : int.tryParse('${json['ordem'] ?? 0}') ?? 0,
    );
  }
}
