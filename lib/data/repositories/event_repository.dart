// lib/data/repositories/event_repository.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/api/api_client.dart';
import '../models/app_event.dart';

abstract class EventRepository {
  Future<List<AppEvent>> fetchAll();
  Future<AppEvent?> fetchById(String id);
}

class GoEventRepository implements EventRepository {
  final ApiClient _api;

  GoEventRepository({ApiClient? api}) : _api = api ?? ApiClient();

  @override
  Future<List<AppEvent>> fetchAll() async {
    try {
      // No Go, o módulo parece ser chamado de 'atividades' no dashboard
      // mas o usuário solicitou 'eventos'. Tentaremos o endpoint /atividades
      final res = await _api.get('/atividades');
      
      if (res.statusCode == 200) {
        final List items = jsonDecode(res.body);
        return items.map((e) => AppEvent.fromMap(e)).toList();
      }
      
      // Fallback para /eventos caso o backend siga o nome antigo
      if (res.statusCode == 404) {
        final res2 = await _api.get('/eventos');
        if (res2.statusCode == 200) {
          final List items = jsonDecode(res2.body);
          return items.map((e) => AppEvent.fromMap(e)).toList();
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erro GoEventRepository.fetchAll: $e');
    }
    return [];
  }

  @override
  Future<AppEvent?> fetchById(String id) async {
    try {
      final res = await _api.get('/atividades/$id');
      if (res.statusCode == 200) {
        return AppEvent.fromMap(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }
}
