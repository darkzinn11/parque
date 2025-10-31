// lib/screens/favorites_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../services/favorites_service.dart';
import '../widgets/favorite_button.dart';
// Removido: import '../data/park_repository.dart'; - Não usamos mais
// Removido: import '../services/auth_service.dart'; - Não estava sendo usado aqui

// --- Constantes de UI (do seu arquivo original) ---
const kGreen = Color(0xFF669340);
const kDark = Color(0xFF32384A);
const kMuted = Color(0xFFB6BEC9);

// --- Constantes do Strapi (copiadas do home_screen.dart) ---
const String kStrapiBaseUrl = 'http://192.168.15.17:1337';
const String kParksCollection = 'parks';
const String? kStrapiStaticToken = null;

// Campos do Strapi para Parques
const _CollectionFields kParksFields = _CollectionFields(
  title: ['title', 'name', 'nome'],
  image: ['image', 'hero_image', 'capa', 'banner', 'foto', 'imagem'],
  status: ['status', 'situacao'],
  slug: ['slug', 'id_parque', 'id'],
);
// --- Fim das Constantes do Strapi ---

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final favs = FavoritesService.instance;

  // Removido: final ParkRepository _repo = DirectusParkRepository(...)

  bool _loading = true;
  bool _busy = false; // Trava contra cargas concorrentes
  List<_FavParkItem> _items = []; // Usando um modelo local

  @override
  void initState() {
    super.initState();
    _bootstrap();
    favs.addListener(_refreshFromFavs);
  }

  @override
  void dispose() {
    favs.removeListener(_refreshFromFavs);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await FavoritesService.instance.init();
    await _load();
  }

  Future<void> _refreshFromFavs() async => _load();

  /// Função principal de carregamento
  Future<void> _load() async {
    if (_busy) return; // já tem uma rodando
    _busy = true;
    if (mounted) setState(() => _loading = true);

    try {
      final ids = favs.parkIds
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();

      if (ids.isEmpty) {
        if (mounted) setState(() { _items = []; });
        return;
      }

      // Busca paralela, com timeout e captura de erro por item
      final futures = ids.map((id) async {
        try {
          // AQUI ESTÁ A MUDANÇA: Usando a nova função de busca do Strapi
          final p = await _fetchParkById(id).timeout(const Duration(seconds: 8));
          return p;
        } catch (_) {
          return null;
        }
      }).toList();

      final results = await Future.wait(futures);
      final cleaned = results.whereType<_FavParkItem>().toList(); // Usando nosso modelo local

      if (mounted) setState(() { _items = cleaned; });
    } finally {
      _busy = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Nova função de busca de parque por ID/Slug (baseada no home_screen)
  Future<_FavParkItem?> _fetchParkById(String parkId) async {
    // Filtramos por QUALQUER um dos campos de slug/id definidos em kParksFields
    final qp = <String, String>{
      'populate': '*',
      'filters[\$or][0][${kParksFields.slug[0]}][\$eq]': parkId, // ex: slug
      'filters[\$or][1][${kParksFields.slug[1]}][\$eq]': parkId, // ex: id_parque
      'filters[\$or][2][${kParksFields.slug[2]}][\$eq]': parkId, // ex: id
    };
    
    // Adiciona filtro para ID numérico, caso seja
    if (int.tryParse(parkId) != null) {
      qp['filters[\$or][3][id][\$eq]'] = parkId;
    }

    final uri = Uri.parse('$kStrapiBaseUrl/api/$kParksCollection').replace(queryParameters: qp);

    final headers = <String, String>{
      'Accept': 'application/json',
      if (kStrapiStaticToken != null) 'Authorization': 'Bearer $kStrapiStaticToken',
    };

    try {
      final res = await http.get(uri, headers: headers);
      if (res.statusCode != 200) return null; // Falha silenciosa

      final body = json.decode(res.body);

      // Como filtramos, esperamos uma lista 'data': [ { ... } ]
      if (body['data'] is List && (body['data'] as List).isNotEmpty) {
        final itemData = (body['data'] as List).first as Map<String, dynamic>;

        // --- Lógica de parse (copiada do home_screen.dart) ---
        final id = '${itemData['id']}';
        // Seus dados não usam 'attributes', então usamos o objeto 'itemData' diretamente.
        final map = itemData;

        final title = _firstNonEmpty(map, kParksFields.title) ?? 'Sem título';
        final slug = _firstNonEmpty(map, kParksFields.slug) ?? id; // O ID/Slug real do item
        final imageVal = _resolveImageValue(map, kParksFields.image);
        final imageUrl = _toImageUrl(imageVal);

        return _FavParkItem(
          id: slug, // Usamos o slug como ID para o FavoriteButton
          name: title,
          heroImage: imageUrl ?? '',
        );
      }
      return null; // Não encontrado
    } catch (e) {
      // print('Erro ao buscar parque $parkId: $e');
      return null;
    }
  }

  // --- Funções Helper (copiadas do home_screen.dart) ---

  static dynamic _resolveImageValue(Map<String, dynamic> map, List<String> candidates) {
    for (final key in candidates) {
      if (map.containsKey(key) && map[key] != null) {
        final val = map[key];
        // Acessa a URL da imagem diretamente
        if (val is Map && val.containsKey('url')) {
          return val['url'];
        }
        return val;
      }
    }
    return null;
  }

  static String? _toImageUrl(dynamic value) {
    if (value == null) return null;
    final v = value.toString().trim();
    if (v.isEmpty) return null;
    if (v.startsWith('http://') || v.startsWith('https://')) return v;
    if (v.startsWith('/')) return '$kStrapiBaseUrl$v';
    // Assumindo que assets são servidos da base (ajuste se for /uploads ou /assets)
    return '$kStrapiBaseUrl$v'; 
  }

  static String? _firstNonEmpty(Map<String, dynamic> map, List<String> candidates) {
    for (final key in candidates) {
      final v = map[key];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }
  // --- Fim das Funções Helper ---


  @override
  Widget build(BuildContext context) {
    // O seu código de UI original não precisa de NENHUMA alteração,
    // pois o modelo _FavParkItem tem os mesmos campos que Park (id, name, heroImage).
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabeçalho (Figma)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Favoritos',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: kGreen,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Seus parques e atividades salvos em um só lugar.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B6B6B),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  Expanded(
                    child: _items.isEmpty
                        ? const Center(
                            child: Text(
                              'Você ainda não favoritou nada',
                              style: TextStyle(fontSize: 14, color: kMuted),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: GridView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                                childAspectRatio: 1.05,
                              ),
                              itemCount: _items.length,
                              itemBuilder: (context, i) => _FavCard(park: _items[i]),
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _FavCard extends StatelessWidget {
  const _FavCard({required this.park});
  // Usando nosso modelo local _FavParkItem, que tem os mesmos campos
  final _FavParkItem park;

  @override
  Widget build(BuildContext context) {
    // O 'image' aqui é o 'heroImage' do nosso modelo
    final image = park.heroImage; 
    return InkWell(
      // O 'park.id' aqui é o 'slug' que pegamos do Strapi
      onTap: () => context.push('/tabs/home/park/${park.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
                    child: SizedBox.expand(
                      child: image.isNotEmpty
                          ? Image.network(
                              image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFEFEFEF)),
                            )
                          : const ColoredBox(color: Color(0xFFEFEFEF)),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    // Passa o ID (slug) para o FavoriteButton
                    child: FavoriteButton(parkId: park.id, size: 30), 
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Text(
                park.name, // O 'name' do nosso modelo
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Modelo de Dados Local ---
// Um modelo simples para guardar os dados do parque para a UI
// Baseado no seu 'Park' original, mas renomeado para evitar conflito
class _FavParkItem {
  final String id; // Será o 'slug' ou 'id_parque'
  final String name;
  final String heroImage;
  const _FavParkItem({
    required this.id,
    required this.name,
    required this.heroImage,
  });
}

// --- Definição do Helper (copiado do home_screen.dart) ---
class _CollectionFields {
  final List<String> title;
  final List<String> image;
  final List<String> status;
  final List<String> slug;
  const _CollectionFields({
    required this.title,
    required this.image,
    required this.status,
    required this.slug,
  });
}