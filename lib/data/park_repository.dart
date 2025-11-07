// lib/data/park_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models/park.dart';

abstract class ParkRepository {
  Future<Park?> fetchBySlug(String slugOrId);
  Future<Park?> fetchById(int id);

  // Novos (para favoritos v5)
  Future<Park?> fetchByDocumentId(String docId);
  Future<List<Park>> fetchByDocumentIds(List<String> docIds);
}

class StrapiParkRepository implements ParkRepository {
  StrapiParkRepository({
    required this.baseUrl,
    required this.collection,
    this.staticToken,
  });

  final String baseUrl;             // ex.: http://192.168.15.12:1337
  final String collection;          // ex.: 'parks'
  final String? staticToken;        // se usar token estático

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (staticToken != null) 'Authorization': 'Bearer $staticToken',
      };

  Uri _u(String path, [Map<String, dynamic>? q]) =>
      Uri.parse('$baseUrl/api/$path')
          .replace(queryParameters: q?.map((k, v) => MapEntry(k, '$v')));

  // ---------- Helpers ----------

  List<Park> _parseParksList(String body) {
    final json = jsonDecode(body);
    final List items = (json['data'] ?? []) as List;
    return items
        .whereType<Map<String, dynamic>>()
        .map((e) => Park.fromStrapi(e))
        .toList();
  }

  Park? _parseSingleParkByList(String body) {
    final list = _parseParksList(body);
    return list.isEmpty ? null : list.first;
  }

  // ---------- Existentes ----------

  @override
  Future<Park?> fetchById(int id) async {
    final uri = _u('$collection/$id', {'populate': '*'});
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode != 200) {
      throw Exception(
          'Erro ${r.statusCode} ao buscar parque por id "$id". Body: ${r.body}');
    }
    final json = jsonDecode(r.body);
    final data = json['data'];
    if (data == null) return null;
    return Park.fromStrapi(data);
  }

  @override
  Future<Park?> fetchBySlug(String slugOrId) async {
    if (RegExp(r'^\d+$').hasMatch(slugOrId)) {
      return fetchById(int.parse(slugOrId));
    }

    final uri = _u(collection, {
      'filters[slug][\$eq]': slugOrId,
      'populate': '*',
      'pagination[pageSize]': 1,
    });

    final r = await http.get(uri, headers: _headers());
    if (r.statusCode != 200) {
      throw Exception(
          'Erro ${r.statusCode} ao buscar parque por slug "$slugOrId". Body: ${r.body}');
    }
    return _parseSingleParkByList(r.body);
  }

  // ---------- Novos para favoritos (Strapi v5) ----------

  @override
  Future<Park?> fetchByDocumentId(String docId) async {
    final uri = _u(collection, {
      'filters[documentId][\$eq]': docId,
      // --- CORREÇÃO AQUI ---
      'populate': '*', 
      // --- FIM DA CORREÇÃO ---
      'pagination[pageSize]': 1,
    });

    final r = await http.get(uri, headers: _headers());
    if (r.statusCode != 200) {
      throw Exception(
          'Erro ${r.statusCode} ao buscar por documentId "$docId". Body: ${r.body}');
    }
    return _parseSingleParkByList(r.body);
  }

  @override
  Future<List<Park>> fetchByDocumentIds(List<String> docIds) async {
    if (docIds.isEmpty) return [];

    final uri = _u(collection, {
      'filters[documentId][\$in]': docIds.join(','), 
      // --- CORREÇÃO AQUI ---
      'populate': '*', 
      // --- FIM DA CORREÇÃO ---
      'pagination[pageSize]': '${docIds.length}',
    });

    final r = await http.get(uri, headers: _headers());
    if (r.statusCode != 200) {
      throw Exception(
          'Erro ${r.statusCode} ao buscar por vários documentIds. Body: ${r.body}');
    }
    return _parseParksList(r.body);
  }
}