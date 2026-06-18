// lib/data/repositories/event_repository.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/api/api_client.dart';
import '../models/app_event.dart';

abstract class EventRepository {
  Future<List<AppEvent>> fetchAll();
  Future<AppEvent?> fetchById(String id);
  Future<void> toggleInteresse(String id, bool registrar);
}

class GoEventRepository implements EventRepository {
  final ApiClient _api;

  GoEventRepository({ApiClient? api}) : _api = api ?? ApiClient();

  @override
  Future<List<AppEvent>> fetchAll() async {
    try {
      final res = await _api.get('/eventos');
      if (res.statusCode == 200) {
        final List items = jsonDecode(res.body);
        return items.map((e) => AppEvent.fromMap(e)).toList();
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erro GoEventRepository.fetchAll: $e');
    }
    return [];
  }

  @override
  Future<AppEvent?> fetchById(String id) async {
    try {
      final res = await _api.get('/eventos/$id');
      if (res.statusCode == 200) {
        return AppEvent.fromMap(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> toggleInteresse(String id, bool registrar) async {
    try {
      if (registrar) {
        await _api.post('/eventos/$id/interesse', body: {});
      } else {
        await _api.delete('/eventos/$id/interesse');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erro GoEventRepository.toggleInteresse: $e');
      rethrow;
    }
  }
}
