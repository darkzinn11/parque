import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/api/api_client.dart';
import '../../core/api/api_config.dart';
import '../../core/checksum.dart';
import '../../services/auth_service.dart';
import '../models/review.dart';
import '../reviews_repository.dart';

class GoReviewsRepository implements ReviewsRepository {
  final ApiClient _api;

  GoReviewsRepository({ApiClient? api}) : _api = api ?? ApiClient();

  @override
  Future<List<Review>> fetchForPark(int parkId, {int limit = 20}) async {
    try {
      final res = await _api.get('/parks/$parkId/reviews');
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((e) => Review.fromMap(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      if (kDebugMode) print('❌ fetchForPark: $e');
    }
    return [];
  }

  @override
  Future<List<Review>> fetchMineForPark(int parkId) async {
    try {
      final res = await _api.get('/parks/$parkId/reviews/mine');
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((e) => Review.fromMap(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      if (kDebugMode) print('❌ fetchMineForPark: $e');
    }
    return [];
  }

  @override
  Future<String?> uploadMedia(String filePath, {required int parkId}) async {
    try {
      final token = await AuthService.instance.token();
      final uri = Uri.parse('${ApiConfig.baseUrl}/reviews/media');
      final request = http.MultipartRequest('POST', uri);
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      // O backend usa park_id no índice media e o checksum (SHA-256) para
      // nomear/deduplicar o blob sem re-hashear no hot path.
      final bytes = await File(filePath).readAsBytes();
      request.fields['park_id'] = parkId.toString();
      request.fields['checksum'] = sha256Hex(bytes);
      request.files.add(http.MultipartFile.fromBytes(
        'media',
        bytes,
        filename: filePath.split('/').last,
      ));
      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['url']?.toString();
      }
    } catch (e) {
      if (kDebugMode) print('❌ uploadMedia: $e');
    }
    return null;
  }

  @override
  Future<Review?> createReview({
    required int parkId,
    required int rating,
    String? text,
    String? authorName,
    String? midiaUrl,
  }) async {
    try {
      final body = {
        'park_id': parkId,
        'rating': rating.toDouble(),
        'titulo': authorName ?? 'Visitante',
        'texto': text ?? '',
        if (midiaUrl != null && midiaUrl.isNotEmpty) 'midia_url': midiaUrl,
      };
      final res = await _api.post('/reviews', body: body);
      if (res.statusCode == 201) {
        return Review.fromMap(jsonDecode(res.body) as Map<String, dynamic>);
      }
      if (res.statusCode == 409) {
        // Usuário já tem review para este parque
        throw Exception('você já enviou uma avaliação para este parque');
      }
    } catch (e) {
      if (kDebugMode) print('❌ createReview: $e');
      rethrow;
    }
    return null;
  }
}
