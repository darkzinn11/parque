import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class SpaceItem {
  final String id;
  final String title;
  final String type;        // categoria
  final String? imageId;    // file id
  final String? parkName;

  SpaceItem({
    required this.id,
    required this.title,
    required this.type,
    required this.imageId,
    required this.parkName,
  });

  String? get coverUrl => imageId == null ? null : '$kApiBase/assets/$imageId';

  factory SpaceItem.fromJson(Map<String, dynamic> j) {
    final img = j['image'];
    String? imageId;
    if (img is Map && img['id'] != null) {
      imageId = img['id'].toString();
    } else if (img is String) {
      imageId = img;
    }
    return SpaceItem(
      id: j['id'].toString(),
      title: j['title']?.toString() ?? '',
      type: j['type']?.toString() ?? '',
      imageId: imageId,
      parkName: (j['park'] is Map) ? j['park']['name']?.toString() : null,
    );
  }
}

class SpacesService {
  final _auth = AuthService.instance;

  Future<List<SpaceItem>> list({String? category}) async {
    final t = await _auth.token();
    if (t == null) return [];

    final filter = <String, dynamic>{
      'visible': {'_eq': true},
      if (category != null && category.isNotEmpty && category != 'Todos')
        'type': {'_eq': category},
    };

    final uri = Uri.parse('$kApiBase/items/map_points').replace(queryParameters: {
      'filter': jsonEncode(filter),
      'fields': 'id,title,type,image.id,park.name',
      'sort': 'title',
      'limit': '100',
    });

    final res = await http.get(uri, headers: {'Authorization': 'Bearer $t'});
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body);
    final List items = (data['data'] as List?) ?? [];
    return items.map((e) => SpaceItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SpaceItem?> getById(String id) async {
    final t = await _auth.token();
    if (t == null) return null;

    final uri = Uri.parse('$kApiBase/items/map_points/$id').replace(queryParameters: {
      'fields': 'id,title,type,image.id,park.name',
    });
    final res = await http.get(uri, headers: {'Authorization': 'Bearer $t'});
    if (res.statusCode != 200) return null;
    return SpaceItem.fromJson((jsonDecode(res.body)['data']) as Map<String, dynamic>);
  }
}
