import 'dart:convert';

import 'package:http/http.dart' as http;

class FoodProduct {
  final String name;
  final String? brand;
  final double? kcalPer100g;

  const FoodProduct({required this.name, this.brand, this.kcalPer100g});
}

class FoodSearchService {
  static const _baseUrl = 'https://world.openfoodfacts.org/api/v2/search';

  static const _localFoods = <(String, double)>[
    ('Arroz branco cozido', 130),
    ('Frango grelhado', 165),
    ('Peito de peru', 135),
    ('Bife de vaca', 250),
    ('Carne de porco', 242),
    ('Cordeiro', 294),
    ('Bacalhau cozido', 160),
    ('Salmão', 208),
    ('Atum em lata', 184),
    ('Camarão', 99),
    ('Ovo cozido', 155),
    ('Ovo mexido', 149),
    ('Pão branco', 265),
    ('Pão integral', 247),
    ('Batata cozida', 77),
    ('Batata frita', 312),
    ('Massa cozida', 131),
    ('Pizza margherita', 267),
    ('Hambúrguer', 295),
    ('Feijão preto cozido', 132),
    ('Grão-de-bico cozido', 164),
    ('Lentilhas cozidas', 116),
    ('Tofu', 76),
    ('Sopa de legumes', 36),
    ('Brócolos', 34),
    ('Espinafres', 23),
    ('Cenoura', 41),
    ('Tomate', 18),
    ('Alface', 15),
    ('Cebola', 40),
    ('Pimento', 26),
    ('Maçã', 52),
    ('Banana', 89),
    ('Laranja', 47),
    ('Morango', 32),
    ('Uva', 69),
    ('Pêra', 57),
    ('Pêssego', 39),
    ('Melancia', 30),
    ('Abacate', 160),
    ('Manga', 60),
    ('Ananás', 50),
    ('Iogurte natural', 61),
    ('Leite meio-gordo', 50),
    ('Queijo flamengo', 352),
    ('Manteiga', 717),
    ('Azeite', 884),
    ('Amendoim', 567),
    ('Nozes', 654),
    ('Aveia', 389),
    ('Cereais pequeno-almoço', 380),
    ('Chocolate negro', 546),
    ('Arroz doce', 120),
  ];

  Future<List<FoodProduct>> search(String query) async {
    try {
      final results = await _searchApi(query);
      if (results.isNotEmpty) return results;
    } catch (_) {
      // API indisponível — usa a lista local
    }
    return _searchLocal(query);
  }

  Future<List<FoodProduct>> _searchApi(String query) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'search_terms': query,
      'page_size': '20',
      'json': 'true',
      'fields': 'product_name,brands,nutriments',
    });

    final response = await http.get(
      uri,
      headers: {'User-Agent': 'NutriTrack/1.0 (calorie tracker)'},
    );

    if (response.statusCode != 200) {
      throw Exception('Pesquisa falhou (HTTP ${response.statusCode})');
    }

    final data = jsonDecode(response.body);
    final products = data is Map<String, dynamic> ? data['products'] : null;
    if (products is! List) return [];

    return products
        .whereType<Map>()
        .map((p) => Map<String, dynamic>.from(p))
        .where((p) => (p['product_name'] as String? ?? '').trim().isNotEmpty)
        .map((p) {
      final nutriments = p['nutriments'] is Map
          ? Map<String, dynamic>.from(p['nutriments'] as Map)
          : <String, dynamic>{};
      return FoodProduct(
        name: (p['product_name'] as String? ?? '').trim(),
        brand: (p['brands'] as String? ?? '').trim().isNotEmpty
            ? (p['brands'] as String).trim()
            : null,
        kcalPer100g: (nutriments['energy-kcal_100g'] as num?)?.toDouble(),
      );
    }).toList();
  }

  List<FoodProduct> _searchLocal(String query) {
    final q = query.trim().toLowerCase();
    return _localFoods
        .where((entry) => entry.$1.toLowerCase().contains(q))
        .map((entry) => FoodProduct(
              name: entry.$1,
              kcalPer100g: entry.$2,
            ))
        .toList();
  }
}