// lib/data/models/app_event.dart

class AppEvent {
  final String id;
  final String title;
  final String? description;
  final String? image;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? location;
  final String? horario;
  final bool? meuInteresse;

  AppEvent({
    required this.id,
    required this.title,
    this.description,
    this.image,
    this.startDate,
    this.endDate,
    this.location,
    this.horario,
    this.meuInteresse,
  });

  factory AppEvent.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v)?.toLocal();
      return null;
    }

    String? resolveUrl(dynamic raw) {
      if (raw == null) return null;
      final s = raw.toString();
      if (s.isEmpty) return null;
      if (s.startsWith('http://') || s.startsWith('https://')) return s;
      return 'https://apps.sitw.com.br/backend-park$s';
    }

    return AppEvent(
      id: (map['id'] ?? '').toString(),
      title: (map['titulo'] ?? map['name'] ?? map['title'] ?? 'Sem título').toString(),
      description: map['conteudo']?.toString() ?? map['descricao']?.toString() ?? map['description']?.toString(),
      image: resolveUrl(map['banner_url'] ?? map['capa_url'] ?? map['image']),
      startDate: parseDate(map['data_inicio'] ?? map['start_date']),
      endDate: parseDate(map['data_fim'] ?? map['end_date']),
      location: map['local']?.toString() ?? map['location']?.toString(),
      horario: map['horario']?.toString(),
      meuInteresse: map['meu_interesse'] as bool?,
    );
  }
}
