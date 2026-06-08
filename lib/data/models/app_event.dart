// lib/data/models/app_event.dart

class AppEvent {
  final String id;
  final String title;
  final String? description;
  final String? image;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? location;

  AppEvent({
    required this.id,
    required this.title,
    this.description,
    this.image,
    this.startDate,
    this.endDate,
    this.location,
  });

  factory AppEvent.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v)?.toLocal();
      return null;
    }

    return AppEvent(
      id: (map['id'] ?? '').toString(),
      title: (map['titulo'] ?? map['name'] ?? map['title'] ?? 'Sem título').toString(),
      description: map['descricao']?.toString() ?? map['description']?.toString(),
      image: map['capa']?.toString() ?? map['image']?.toString() ?? map[' banner']?.toString(),
      startDate: parseDate(map['data_inicio'] ?? map['start_date']),
      endDate: parseDate(map['data_fim'] ?? map['end_date']),
      location: map['local']?.toString() ?? map['location']?.toString(),
    );
  }
}
