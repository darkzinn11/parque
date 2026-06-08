// lib/data/park_repository.dart
import 'models/park.dart';

abstract class ParkRepository {
  Future<Park?> fetchBySlug(String slugOrId);
  Future<Park?> fetchById(int id);
  Future<Park?> fetchByDocumentId(String docId);
  Future<List<Park>> fetchByDocumentIds(List<String> docIds);
  Future<List<Park>> fetchAll();
}
