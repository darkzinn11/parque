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
  final String? endereco;
  final String? cidade;

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
    this.endereco,
    this.cidade,
  });

  /// Factory para o novo backend Go (JSON plano)
  factory Park.fromMap(Map<String, dynamic> map) {
    double? toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return Park(
      id: map['id'] is int ? map['id'] : int.tryParse('${map['id'] ?? 0}') ?? 0,
      documentId: (map['documentId'] ?? map['id'] ?? '').toString(),
      name: (map['nome'] ?? map['name'] ?? '').toString(),
      status: map['status']?.toString() ?? map['situacao']?.toString(),
      description: map['descricao']?.toString() ?? map['description']?.toString(),
      rating: toDouble(map['rating'] ?? map['nota'] ?? map['avaliacao']),
      // No Go o campo é imagem_url
      heroImage: map['imagem_url']?.toString() ?? map['imagem']?.toString() ?? map['hero_image']?.toString(),
      latitude: toDouble(map['latitude'] ?? map['lat']),
      longitude: toDouble(map['longitude'] ?? map['lng']),
      endereco: map['endereco']?.toString(),
      cidade: map['cidade']?.toString(),
    );
  }
}
