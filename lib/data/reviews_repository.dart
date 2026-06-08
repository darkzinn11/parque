// lib/data/reviews_repository.dart
import 'models/review.dart';

abstract class ReviewsRepository {
  Future<List<Review>> fetchForPark(int parkId, {int limit = 20});
  Future<List<Review>> fetchMineForPark(int parkId);
  Future<String?> uploadMedia(String filePath);
  Future<Review?> createReview({
    required int parkId,
    required int rating,
    String? text,
    String? authorName,
    String? midiaUrl,
  });
}
