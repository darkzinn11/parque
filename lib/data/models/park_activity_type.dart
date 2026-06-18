// lib/data/models/park_activity_type.dart

class ParkActivityType {
  final int id;
  final int parkId;
  final String nome;
  final int ordem;

  const ParkActivityType({
    required this.id,
    required this.parkId,
    required this.nome,
    required this.ordem,
  });

  factory ParkActivityType.fromJson(Map<String, dynamic> json) {
    return ParkActivityType(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id'] ?? 0}') ?? 0,
      parkId: json['park_id'] is int ? json['park_id'] : int.tryParse('${json['park_id'] ?? 0}') ?? 0,
      nome: (json['nome'] ?? '').toString(),
      ordem: json['ordem'] is int ? json['ordem'] : int.tryParse('${json['ordem'] ?? 0}') ?? 0,
    );
  }
}
