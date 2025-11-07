// lib/data/models/park.dart

class Park {
  final int id;
  final String documentId;
  final String name;

  // Extras usados nas telas
  final String? status;       // <- ADICIONADO
  final String? description;
  final double? rating;
  final String? heroImage;
  final double? latitude;
  final double? longitude;

  Park({
    required this.id,
    required this.documentId,
    required this.name,
    this.status,          // <- ADICIONADO
    this.description,
    this.rating,
    this.heroImage,
    this.latitude,
    this.longitude,
  });

  /// Extrai texto de Rich Text (Blocks) ou de string simples
  static String? _extractDescription(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return raw;
    if (raw is List) {
      final buffer = StringBuffer();
      void walk(dynamic node) {
        if (node == null) return;
        if (node is Map<String, dynamic>) {
          final children = node['children'] ?? node['content'];
          final text = node['text'];
          if (text is String) buffer.write(text);
          if (children is List) for (final c in children) walk(c);
          if (node['type'] == 'paragraph') buffer.write('\n');
        } else if (node is List) {
          for (final c in node) walk(c);
        }
      }
      for (final n in raw) walk(n);
      final s = buffer.toString().trim();
      return s.isEmpty ? null : s;
    }
    return raw.toString();
  }

  /// Tenta achar latitude/longitude num relation "park" (Map Point)
  static (double?, double?) _extractLatLng(dynamic mapPoint) {
    double? lat;
    double? lng;

    Map<String, dynamic>? data;
    if (mapPoint is Map<String, dynamic>) {
      data = mapPoint;
      // v4: { data: { attributes: {...} } }
      if (data['data'] is Map && data['data']['attributes'] is Map) {
        data = data['data']['attributes'] as Map<String, dynamic>;
      }
    }

    if (data != null) {
      double? toDouble(dynamic v) {
        if (v == null) return null;
        if (v is num) return v.toDouble();
        return double.tryParse(v.toString());
      }

      lat = toDouble(
        data['lat'] ?? data['latitude'] ?? data['y'] ?? data['Lat'] ?? data['Latitude'],
      );
      lng = toDouble(
        data['lng'] ?? data['longitude'] ?? data['x'] ?? data['Lng'] ?? data['Longitude'],
      );
    }

    return (lat, lng);
  }

  factory Park.fromStrapi(Map<String, dynamic> json) {
    final attrs = json['attributes'] is Map<String, dynamic>
        ? json['attributes'] as Map<String, dynamic>
        : json;

    // Imagem (media)
    String? hero;
    final imagem = attrs['imagem'];
    if (imagem is Map<String, dynamic>) {
      hero = imagem['url']?.toString(); // v5
      hero ??= imagem['data']?['attributes']?['url']?.toString(); // v4
    }

    // Descrição (rich text ou string)
    final desc = _extractDescription(attrs['descricao'] ?? attrs['description']);

    // Nota (se houver no schema)
    double? rating;
    final rRaw = attrs['rating'] ?? attrs['nota'] ?? attrs['avaliacao'];
    if (rRaw is num) rating = rRaw.toDouble();
    if (rRaw is String) rating = double.tryParse(rRaw);

    // Coordenadas do relation "park" (Map Point)
    final (lat, lng) = _extractLatLng(attrs['park']);

    return Park(
      id: (json['id'] ?? attrs['id']) is int
          ? (json['id'] ?? attrs['id'])
          : int.tryParse('${json['id'] ?? attrs['id'] ?? 0}') ?? 0,
      documentId: (json['documentId'] ?? attrs['documentId'] ?? '').toString(),
      name: (attrs['nome'] ?? attrs['name'] ?? '').toString(),
      status: (attrs['status'] ?? attrs['situacao'])?.toString(),   // <- ADICIONADO
      description: desc,
      rating: rating,
      heroImage: hero,
      latitude: lat,
      longitude: lng,
    );
  }
}
