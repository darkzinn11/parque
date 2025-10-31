import 'dart:convert';
import 'package:http/http.dart' as http;
import './models/park.dart'; // Certifique-se que o Park.fromStrapi existe neste arquivo

abstract class ParkRepository {
  Future<Park?> fetchBySlug(String id);
}

class StrapiParkRepository implements ParkRepository {
  final String baseUrl;
  final String collection;
  final String? staticToken;

  StrapiParkRepository({
    required this.baseUrl,
    required this.collection,
    this.staticToken,
  });

  @override
  Future<Park?> fetchBySlug(String id) async {
    // Definimos os campos de busca que o Strapi aceita
    final List<String> slugFields = ['id_parque']; // Campo customizado

    final qp = <String, String>{
      'populate': '*', // Popula todas as relações (como imagens)
      
      // Filtro OU: tenta [id_parque] = "id"
      'filters[\$or][0][${slugFields[0]}][\$eq]': id, 
    };
    
    // Adiciona o ID primário (numérico) como uma segunda opção de filtro
    // O campo 'id' é sempre filtrável no Strapi.
    if (int.tryParse(id) != null) {
      qp['filters[\$or][1][id][\$eq]'] = id;
    }

    // Monta a URI correta (ex: /api/parks?populate=*)
    final uri = Uri.parse('$baseUrl/api/$collection').replace(queryParameters: qp);

    final headers = <String, String>{
      'Accept': 'application/json',
      if (staticToken != null) 'Authorization': 'Bearer $staticToken',
    };

    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final body = json.decode(response.body);

      // A busca por filtro retorna uma LISTA (data: [ ... ])
      if (body['data'] is List && (body['data'] as List).isNotEmpty) {
        
        // Pega o primeiro item da lista
        final itemData = (body['data'] as List).first;
        
        // Passa o objeto direto (sem .attributes) para o seu construtor
        // Assumindo que seu Park.fromStrapi sabe lidar com isso (como no home_screen)
        return Park.fromStrapi(itemData); 
      }
      
      return null; // Não encontrado (lista vazia)
    } else if (response.statusCode == 404) {
      return null;
    } else {
      // Joga o erro para a tela de detalhe (como na sua foto)
      throw Exception('Erro ${response.statusCode} ao buscar parque "$id". Body: ${response.body}');
    }
  }
}