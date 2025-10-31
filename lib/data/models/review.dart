// lib/data/models/review.dart

class Review {
  final int id;
  final String? authorName;
  final int rating; // 1..5
  final String? text;
  final DateTime? createdAt;

  Review({
    required this.id,
    required this.rating,
    this.authorName,
    this.text,
    this.createdAt,
  });

  factory Review.fromStrapi(Map<String, dynamic> json) {
    // No Strapi, os campos ficam dentro de 'attributes'
    final attr = json['attributes'] as Map<String, dynamic>;
    
    return Review(
      id: json['id'],
      rating: (attr['rating'] as num?)?.toInt() ?? 0,
      authorName: attr['authorName']?.toString(),
      text: attr['text']?.toString(),
      createdAt: attr['createdAt'] != null ? DateTime.tryParse(attr['createdAt']) : null,
    );
  }
}