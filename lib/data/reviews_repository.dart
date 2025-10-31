// lib/data/reviews_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models/review.dart';

// Interface Abstrata
abstract class ReviewsRepository {
  Future<List<Review>> fetchForPark(int parkId, {int limit = 20});
  Future<Review?> createReview({
    required int parkId,
    required int rating,
    String? text,
    String? authorName,
  });
}

// Implementação para o Strapi
class StrapiReviewsRepository implements ReviewsRepository {
  final String baseUrl;
  final String collection;
  final String? staticToken;

  StrapiReviewsRepository({
    required this.baseUrl,
    this.collection = 'reviews',
    this.staticToken,
  });

  Map<String, String> _headers() => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (staticToken != null && staticToken!.isNotEmpty) 'Authorization': 'Bearer $staticToken',
  };

  @override
  Future<List<Review>> fetchForPark(int parkId, {int limit = 20}) async {
    // Sintaxe de filtro do Strapi para buscar reviews de um parque específico
    final qp = {
      'filters[park][id][\$eq]': '$parkId',
      'sort': 'createdAt:desc',
      'pagination[limit]': '$limit',
    };
    final uri = Uri.parse('$baseUrl/api/$collection').replace(queryParameters: qp);
    
    final res = await http.get(uri, headers: _headers());
    if (res.statusCode != 200) {
      throw Exception('Erro ${res.statusCode} ao listar reviews: ${res.body}');
    }
    final data = (json.decode(res.body)['data'] as List?) ?? const [];
    return data.map((e) => Review.fromStrapi(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<Review?> createReview({
    required int parkId,
    required int rating,
    String? text,
    String? authorName,
  }) async {
    final uri = Uri.parse('$baseUrl/api/$collection');
    
    // No Strapi, o corpo da requisição POST precisa ser envolvido por um objeto "data"
    final requestBody = {
      'data': {
        'park': parkId,
        'rating': rating,
        if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
        // ATENÇÃO: Verifique se o nome do campo no seu Strapi é 'authorName' ou 'author_name'
        if (authorName != null && authorName.trim().isNotEmpty) 'authorName': authorName.trim(),
      }
    };

    final res = await http.post(uri, headers: _headers(), body: json.encode(requestBody));

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception('Sem permissão para enviar avaliação (401/403).');
    }
    if (res.statusCode != 200) { // Strapi retorna 200 (OK) na criação
      throw Exception('Erro ${res.statusCode} ao criar review: ${res.body}');
    }
    final m = (json.decode(res.body)['data']) as Map<String, dynamic>;
    return Review.fromStrapi(m);
  }
}