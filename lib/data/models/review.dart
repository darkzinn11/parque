class Review {
  final int id;
  final String? title;
  final String? authorName;
  final String? authorNome;
  final String? authorAvatarUrl;
  final int rating;
  final String? text;
  final String? midiaUrl;
  final String status;
  final DateTime? createdAt;

  Review({
    required this.id,
    required this.rating,
    this.title,
    this.authorName,
    this.authorNome,
    this.authorAvatarUrl,
    this.text,
    this.midiaUrl,
    this.status = 'Pendente',
    this.createdAt,
  });

  bool get isPending => status == 'Pendente';
  bool get isRejected => status == 'Rejeitada';

  String get displayName {
    if (authorNome != null && authorNome!.isNotEmpty) return authorNome!;
    if (authorName != null && authorName!.isNotEmpty) return authorName!;
    return 'Visitante';
  }

  factory Review.fromMap(Map<String, dynamic> map) {
    final user = map['user'] as Map<String, dynamic>?;
    return Review(
      id: map['id'] is int ? map['id'] : int.tryParse('${map['id'] ?? 0}') ?? 0,
      rating: (map['rating'] as num?)?.toInt() ?? 0,
      title: map['titulo']?.toString(),
      authorName: map['titulo']?.toString(),
      authorNome: user?['nome']?.toString(),
      authorAvatarUrl: user?['avatar_url']?.toString(),
      text: map['texto']?.toString(),
      midiaUrl: map['midia_url']?.toString(),
      status: map['status']?.toString() ?? 'Pendente',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'])
          : null,
    );
  }
}
