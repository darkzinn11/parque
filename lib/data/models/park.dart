// lib/data/models/park.dart

class Park {
  final int id;
  final String name;
  final String? status;
  final double? rating;
  final String? description;
  final String? heroImage;
  final double? latitude;
  final double? longitude;

  // Removido 'slug', 'reviewsCount', etc., para corresponder ao seu Strapi
  Park({
    required this.id,
    required this.name,
    this.status,
    this.rating,
    this.description,
    this.heroImage,
    this.latitude,
    this.longitude,
  });

  // Nova factory para "ler" a resposta do Strapi
  factory Park.fromStrapi(Map<String, dynamic> json) {
    const String baseUrl = 'http://192.168.15.3:1337';

    // Helper para construir a URL da imagem
    String? buildImageUrl(dynamic imageData) {
      if (imageData is! Map || imageData['url'] == null) return null;
      final url = imageData['url'] as String;
      return url.startsWith('/') ? '$baseUrl$url' : url;
    }

    // Helper para extrair a descrição dos blocos de texto
    String parseDescription(dynamic descriptionData) {
      if (descriptionData is! List) return '';
      final buffer = StringBuffer();
      for (final block in descriptionData) {
        if (block is Map && block['type'] == 'paragraph' && block['children'] is List) {
          for (final child in block['children']) {
            if (child is Map && child['text'] is String) {
              buffer.write(child['text']);
            }
          }
        }
      }
      return buffer.toString().trim();
    }

    // Extrai os dados de geolocalização da relação 'park'
    final mapPointData = json['park'] as Map<String, dynamic>?;

    return Park(
      id: json['id'],
      name: json['nome'] ?? 'Parque sem nome',
      description: parseDescription(json['descricao']),
      heroImage: buildImageUrl(json['imagem']),
      status: json['publishedAt'] != null ? 'Publicado' : 'Rascunho',
      rating: 4.5, // Valor Fixo: seu JSON não tem 'rating'. Pode ajustar/remover.
      latitude: mapPointData != null ? double.tryParse(mapPointData['latitude']?.toString() ?? '') : null,
      longitude: mapPointData != null ? double.tryParse(mapPointData['longitude']?.toString() ?? '') : null,
    );
  }
}