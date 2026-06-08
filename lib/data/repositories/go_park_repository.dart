// lib/data/repositories/go_park_repository.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/api/api_client.dart';
import '../models/park.dart';
import '../park_repository.dart';

class GoParkRepository implements ParkRepository {
  final ApiClient _api;

  GoParkRepository({ApiClient? api}) : _api = api ?? ApiClient();

  @override
  Future<Park?> fetchById(int id) async {
    try {
      final res = await _api.get('/parks/$id');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return Park.fromMap(data);
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erro GoParkRepository.fetchById: $e');
    }
    return null;
  }

  @override
  Future<Park?> fetchBySlug(String slugOrId) async {
    if (RegExp(r'^\d+$').hasMatch(slugOrId)) {
      return fetchById(int.parse(slugOrId));
    }
    
    try {
      final res = await _api.get('/parks/', query: {'slug': slugOrId});
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (data.isNotEmpty) {
          return Park.fromMap(data.first);
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erro GoParkRepository.fetchBySlug: $e');
    }
    return null;
  }

  @override
  Future<Park?> fetchByDocumentId(String docId) async {
    return fetchBySlug(docId);
  }

  @override
  Future<List<Park>> fetchByDocumentIds(List<String> docIds) async {
    if (docIds.isEmpty) return [];
    
    try {
      final res = await _api.get('/parks/', query: {'ids': docIds.join(',')});
      if (res.statusCode == 200) {
        final List items = jsonDecode(res.body);
        return items.map((e) => Park.fromMap(e)).toList();
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erro GoParkRepository.fetchByDocumentIds: $e');
    }
    return [];
  }

  @override
  Future<List<Park>> fetchAll() async {
    try {
      final res = await _api.get('/parks/');
      if (res.statusCode == 200) {
        final List items = jsonDecode(res.body);
        return items.map((e) => Park.fromMap(e)).toList();
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erro GoParkRepository.fetchAll: $e');
    }
    return [];
  }
}
