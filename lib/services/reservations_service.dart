// lib/services/reservations_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class MyReservation {
  final String id;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String status;
  final String spaceTitle;
  final String? parkName;

  MyReservation({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.spaceTitle,
    required this.parkName,
  });

  factory MyReservation.fromJson(Map<String, dynamic> j) {
    String spaceTitle = '';
    String? parkName;

    final space = j['space'];
    if (space is Map) {
      spaceTitle = (space['title'] ?? '').toString();

      final park = space['park'];
      if (park is Map) {
        parkName = (park['name'] ?? '').toString();
      } else if (park is String) {
        parkName = null; // só id; sem nome
      }
    }

    return MyReservation(
      id: j['id'].toString(),
      date: DateTime.parse(j['date'] as String),
      startTime: (j['start_time'] ?? '').toString(),
      endTime: (j['end_time'] ?? '').toString(),
      status: (j['status'] ?? 'pending').toString(),
      spaceTitle: spaceTitle,
      parkName: parkName,
    );
  }
}

class ReservationsService {
  final _auth = AuthService.instance;

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  int _toMin(String hhmm) {
    final p = hhmm.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  String _fmtMin(int m) {
    final h = (m ~/ 60).toString().padLeft(2, '0');
    final mm = (m % 60).toString().padLeft(2, '0');
    return '$h:$mm';
  }

  /// horários ocupados (HH:mm) para um espaço numa data
  Future<Set<String>> reservedSlots({required String spaceId, required DateTime date}) async {
    final t = await _auth.token();
    if (t == null) return {};
    final filter = jsonEncode({
      'space': {'_eq': spaceId},
      'date': {'_eq': date.toIso8601String().substring(0, 10)},
    });
    final uri = Uri.parse('$kApiBase/items/reservas').replace(queryParameters: {
      'filter': filter,
      'fields': 'start_time,end_time',
      'limit': '200',
    });
    final res = await http.get(uri, headers: {'Authorization': 'Bearer $t'});
    if (res.statusCode != 200) return {};
    final data = (jsonDecode(res.body)['data'] as List?) ?? [];
    final taken = <String>{};
    for (final r in data) {
      final s = (r['start_time'] ?? '').toString();
      final e = (r['end_time'] ?? '').toString();
      if (s.isEmpty || e.isEmpty) continue;
      for (int m = _toMin(s); m < _toMin(e); m += 60) {
        taken.add(_fmtMin(m));
      }
    }
    return taken;
  }

  Future<bool> create({
    required String spaceId,
    required DateTime date,
    required TimeOfDay start,
    required TimeOfDay end,
    String? note,
  }) async {
    final t = await _auth.token();
    final me = await _auth.me();
    if (t == null || me == null) return false;

    final body = {
      'user': me['id'],
      'space': spaceId,
      'date': date.toIso8601String().substring(0, 10),
      'start_time': _fmt(start),
      'end_time': _fmt(end),
      'status': 'pending',
      if (note != null && note.isNotEmpty) 'note': note,
    };

    final res = await http.post(
      Uri.parse('$kApiBase/items/reservas'),
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    return res.statusCode == 200 || res.statusCode == 201;
  }

  Future<List<MyReservation>> myReservations() async {
    final t = await _auth.token();
    final me = await _auth.me();
    if (t == null || me == null) return [];
    final filter = jsonEncode({'user': {'_eq': me['id']}});
    final uri = Uri.parse('$kApiBase/items/reservas').replace(queryParameters: {
      'filter': filter,
      'fields': 'id,date,start_time,end_time,status,space.title,space.park.name',
      'sort': '-date,-start_time',
    });
    final res = await http.get(uri, headers: {'Authorization': 'Bearer $t'});
    if (res.statusCode != 200) return [];
    final data = (jsonDecode(res.body)['data'] as List?) ?? [];
    return data.map((e) => MyReservation.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// cancelar = atualizar status para 'cancelled'
  Future<bool> cancel(String reservationId) async {
    final t = await _auth.token();
    if (t == null) return false;
    final res = await http.patch(
      Uri.parse('$kApiBase/items/reservas/$reservationId'),
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'status': 'cancelled'}),
    );
    return res.statusCode == 200;
  }
}
