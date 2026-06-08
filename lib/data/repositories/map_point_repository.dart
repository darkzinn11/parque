// lib/data/repositories/map_point_repository.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/api/api_client.dart';
import '../models/map_point.dart';

abstract class MapPointRepository {
  Future<List<MapPointModel>> fetchAll();
}

class GoMapPointRepository implements MapPointRepository {
  final ApiClient _api;

  GoMapPointRepository({ApiClient? api}) : _api = api ?? ApiClient();

  @override
  Future<List<MapPointModel>> fetchAll() async {
    try {
      final res = await _api.get('/map-points');
      if (res.statusCode == 200) {
        final List items = jsonDecode(res.body);
        return items.map((e) => MapPointModel.fromMap(e)).toList();
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erro GoMapPointRepository.fetchAll: $e');
    }
    return [];
  }
}
