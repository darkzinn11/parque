// lib/data/models/space.dart
import 'dart:convert';

class Space {
  final int id;
  final int parkId;
  final String name;
  final String category;
  final String? description;
  final String? imageURL;
  final String? imageUrl2;
  final String? imageUrl3;
  final String? imageUrl4;
  final int maxCapacity;
  final String? address;
  final SpaceRule? rule;
  final bool permiteEvento;
  final bool permiteReserva;

  /// Contorno do setor desenhado pelo gestor no painel. Cada ponto é [lat, lng].
  /// null quando o setor não tem polígono cadastrado.
  final List<List<double>>? areaPolygon;

  Space({
    required this.id,
    required this.parkId,
    required this.name,
    required this.category,
    this.description,
    this.imageURL,
    this.imageUrl2,
    this.imageUrl3,
    this.imageUrl4,
    required this.maxCapacity,
    this.address,
    this.rule,
    this.permiteEvento = false,
    this.permiteReserva = true,
    this.areaPolygon,
  });

  /// Tolera tanto JSON já decodificado (List) quanto String JSON, e
  /// aceita pontos como {"lat":..,"lng":..} ou [lat, lng]. Exige 3+ pontos.
  static List<List<double>>? _parsePolygon(dynamic raw) {
    if (raw == null) return null;
    dynamic data = raw;
    if (raw is String) {
      if (raw.trim().isEmpty) return null;
      try {
        data = jsonDecode(raw);
      } catch (_) {
        return null;
      }
    }
    if (data is! List) return null;
    final pts = <List<double>>[];
    for (final p in data) {
      double? lat, lng;
      if (p is Map) {
        lat = (p['lat'] as num?)?.toDouble();
        lng = (p['lng'] as num?)?.toDouble();
      } else if (p is List && p.length >= 2) {
        lat = (p[0] as num?)?.toDouble();
        lng = (p[1] as num?)?.toDouble();
      }
      if (lat != null && lng != null) pts.add([lat, lng]);
    }
    return pts.length >= 3 ? pts : null;
  }

  factory Space.fromJson(Map<String, dynamic> json) {
    return Space(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      parkId: json['park_id'] is int ? json['park_id'] : int.tryParse('${json['park_id']}') ?? 0,
      name: (json['nome'] ?? '').toString(),
      category: (json['categoria'] ?? '').toString(),
      description: json['descricao']?.toString(),
      imageURL: json['imagem_url']?.toString(),
      imageUrl2: json['imagem_url_2']?.toString(),
      imageUrl3: json['imagem_url_3']?.toString(),
      imageUrl4: json['imagem_url_4']?.toString(),
      maxCapacity: json['capacidade_max'] is int ? json['capacidade_max'] : int.tryParse('${json['capacidade_max']}') ?? 0,
      address: json['endereco']?.toString(),
      rule: json['rule'] != null ? SpaceRule.fromJson(json['rule'] as Map<String, dynamic>) : null,
      permiteEvento: json['permite_evento'] == true,
      permiteReserva: json['permite_reserva'] != false,
      areaPolygon: _parsePolygon(json['area_polygon']),
    );
  }
}

class SpaceRule {
  final int id;
  final int spaceId;
  final String workingDays;
  final String openingTime;
  final String closingTime;
  final int maxDurationMinutes;
  final bool requiresApproval;
  final String? termsOfUse;

  SpaceRule({
    required this.id,
    required this.spaceId,
    required this.workingDays,
    required this.openingTime,
    required this.closingTime,
    required this.maxDurationMinutes,
    required this.requiresApproval,
    this.termsOfUse,
  });

  factory SpaceRule.fromJson(Map<String, dynamic> json) {
    return SpaceRule(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      spaceId: json['space_id'] is int ? json['space_id'] : int.tryParse('${json['space_id']}') ?? 0,
      workingDays: (json['dias_funcionamento'] ?? 'seg-dom').toString(),
      openingTime: (json['horario_abertura'] ?? '08:00').toString(),
      closingTime: (json['horario_fechamento'] ?? '18:00').toString(),
      maxDurationMinutes: json['duracao_maxima_minutos'] is int ? json['duracao_maxima_minutos'] : int.tryParse('${json['duracao_maxima_minutos']}') ?? 60,
      requiresApproval: json['requer_aprovacao'] == true,
      termsOfUse: json['termos_uso']?.toString(),
    );
  }
}
