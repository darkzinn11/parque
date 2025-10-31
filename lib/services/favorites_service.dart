// lib/services/favorites_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

// Mesma base do AuthService
const String kDirectusBaseUrl = 'http://192.168.15.17:1337/api';


class FavoritesService extends ChangeNotifier {
  // ---------- SINGLETON ----------
  static final FavoritesService instance = FavoritesService._();
  FavoritesService._();

  /// ids de parques favoritados
  final Set<String> _parkIds = {};

  /// mapeia parkId -> id do registro em `favoritos` (para deletar rápido)
  final Map<String, String> _favIdByPark = {};

  Set<String> get parkIds => _parkIds;

  bool isFavorite(String parkId) => _parkIds.contains(parkId);

  // ---------- Carga inicial (após login / app start com token) ----------
  Future<void> init() async {
    // Se não estiver logado, deixa vazio e não quebra
    final token = await AuthService.instance.token();
    final me = await AuthService.instance.me();

    _parkIds.clear();
    _favIdByPark.clear();

    if (token == null || me == null) {
      notifyListeners();
      return;
    }

    await _loadFromServer(token, me['id'].toString());
  }

  Future<void> _loadFromServer(String token, String userId) async {
    final filter = jsonEncode({
      'user': {'_eq': userId},
    });

    final uri = Uri.parse('$kApiBase/items/favoritos').replace(queryParameters: {
      'filter': filter,
      'fields': 'id,park',
      'limit': '500',
    });

    final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});

    if (res.statusCode == 200) {
      final list = (jsonDecode(res.body)['data'] as List?) ?? [];
      for (final row in list) {
        final favId = row['id']?.toString();
        final parkId = row['park']?.toString();
        if (favId != null && parkId != null) {
          _parkIds.add(parkId);
          _favIdByPark[parkId] = favId;
        }
      }
    }
    notifyListeners();
  }

  // ---------- Ações ----------
  Future<bool> toggleFavorite(String parkId) async {
    if (isFavorite(parkId)) {
      return remove(parkId);
    } else {
      return add(parkId);
    }
  }

  Future<bool> add(String parkId) async {
    final token = await AuthService.instance.token();
    if (token == null) return false;

    // POST sem `user` (preset no Directus preenche)
    final res = await http.post(
      Uri.parse('$kApiBase/items/favoritos'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'park': parkId,
      }),
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      final data = (jsonDecode(res.body)['data']) as Map<String, dynamic>;
      final favId = data['id']?.toString();
      if (favId != null) {
        _parkIds.add(parkId);
        _favIdByPark[parkId] = favId;
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  Future<bool> remove(String parkId) async {
    final token = await AuthService.instance.token();
    if (token == null) return false;

    // temos o id do favorito?
    String? favId = _favIdByPark[parkId];

    // fallback: busca pelo par (user, park) caso o map não tenha
    if (favId == null) {
      final me = await AuthService.instance.me();
      if (me == null) return false;

      final filter = jsonEncode({
        'user': {'_eq': me['id']},
        'park': {'_eq': parkId},
      });

      final uri = Uri.parse('$kApiBase/items/favoritos').replace(queryParameters: {
        'filter': filter,
        'fields': 'id',
        'limit': '1',
      });

      final findRes = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      if (findRes.statusCode == 200) {
        final list = (jsonDecode(findRes.body)['data'] as List?) ?? [];
        if (list.isNotEmpty) {
          favId = list.first['id']?.toString();
        }
      }
      if (favId == null) return false;
    }

    final del = await http.delete(
      Uri.parse('$kApiBase/items/favoritos/$favId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (del.statusCode == 200 || del.statusCode == 204) {
      _parkIds.remove(parkId);
      _favIdByPark.remove(parkId);
      notifyListeners();
      return true;
    }
    return false;
  }
}
