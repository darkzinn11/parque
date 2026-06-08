import 'dart:convert';
import '../core/api/api_client.dart';
import '../core/api/api_config.dart';

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

  String? get coverUrl => imageId == null ? null : '${ApiConfig.baseUrl}/assets/$imageId';

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
  final _api = ApiClient();

  Future<List<SpaceItem>> list({String? category}) async {
    try {
      final res = await _api.get('/map-points');

      if (res.statusCode == 200) {
        final List items = jsonDecode(res.body) as List? ?? [];
        var result = items.map((e) => SpaceItem.fromJson(e as Map<String, dynamic>)).toList();
        if (category != null && category.isNotEmpty && category != 'Todos') {
          result = result.where((s) => s.type == category).toList();
        }
        return result;
      }
    } catch (e) {
      // Tratar erro
    }
    return [];
  }

  Future<SpaceItem?> getById(String id) async {
    try {
      final res = await _api.get('/map-points/$id');

      if (res.statusCode == 200) {
        return SpaceItem.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (e) {
      // Tratar erro
    }
    return null;
  }
}
