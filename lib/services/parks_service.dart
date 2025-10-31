import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ParksService {
  final _auth = AuthService.instance;

  Future<List<Map<String, dynamic>>> list() async {
    final t = await _auth.token();
    if (t == null) return [];
    final res = await http.get(
      Uri.parse('$kApiBase/items/parks?limit=20'),
      headers: {'Authorization': 'Bearer $t'},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final items = (data['data'] as List?) ?? [];
      return items.cast<Map<String, dynamic>>();
    }
    return [];
  }
}
