class Review {
  final int id;
  final String? authorName;
  final int rating; // 1..5
  final String? text;
  final String? midiaUrl;
  final String status; // 'Pendente' | 'Aprovada' | 'Rejeitada' | 'Ocultada'
  final DateTime? createdAt;

  Review({
    required this.id,
    required this.rating,
    this.authorName,
    this.text,
    this.midiaUrl,
    this.status = 'Aprovada',
    this.createdAt,
  });

  bool get isPending => status == 'Pendente';
  bool get isRejected => status == 'Rejeitada';

  factory Review.fromMap(Map<String, dynamic> map) {
    return Review(
      id: map['id'] is int ? map['id'] : int.tryParse('${map['id'] ?? 0}') ?? 0,
      rating: (map['rating'] as num?)?.toInt() ?? 0,
      authorName: map['titulo']?.toString() ?? 'Visitante',
      text: map['texto']?.toString(),
      midiaUrl: map['midia_url']?.toString(),
      status: map['status']?.toString() ?? 'Aprovada',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'])
          : null,
    );
  }
}
