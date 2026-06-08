// lib/data/models/map_point.dart

class MapPointModel {
  final String id;
  final String nome;
  final String? descricao;
  final String? endereco;
  final String latitude;
  final String longitude;
  final String? imagemUrl;
  final String? imagemUrl2;
  final String? imagemUrl3;
  final String? imagemUrl4;
  final String categoria;
  final int parkId;
  final bool podeReservar;

  MapPointModel({
    required this.id,
    required this.nome,
    this.descricao,
    this.endereco,
    required this.latitude,
    required this.longitude,
    this.imagemUrl,
    this.imagemUrl2,
    this.imagemUrl3,
    this.imagemUrl4,
    required this.categoria,
    required this.parkId,
    this.podeReservar = false,
  });

  factory MapPointModel.fromMap(Map<String, dynamic> map) {
    return MapPointModel(
      id: (map['id'] ?? '').toString(),
      nome: (map['nome'] ?? 'Sem nome').toString(),
      descricao: map['descricao']?.toString(),
      endereco: map['endereco']?.toString(),
      latitude: (map['latitude'] ?? '0').toString(),
      longitude: (map['longitude'] ?? '0').toString(),
      imagemUrl: map['imagem_url']?.toString(),
      imagemUrl2: map['imagem_url_2']?.toString(),
      imagemUrl3: map['imagem_url_3']?.toString(),
      imagemUrl4: map['imagem_url_4']?.toString(),
      categoria: (map['categoria'] ?? 'divertir').toString(),
      parkId: int.tryParse((map['park_id'] ?? '0').toString()) ?? 0,
      podeReservar: map['pode_reservar'] == true,
    );
  }
}
