import 'dart:convert';

import 'package:http/http.dart' as http;

class FoodProduct {
  final String name;
  final String? brand;
  final double? kcalPer100g;
  final double referenceGrams;

  const FoodProduct({
    required this.name,
    this.brand,
    this.kcalPer100g,
    this.referenceGrams = 100,
  });
}

class FoodSearchService {
  static const _baseUrl = 'https://world.openfoodfacts.org/api/v2/search';

  /// Base local com marcas e supermercados portugueses.
  /// Formato: (nome, kcal/100g, gramas de porção de referência — opcional, default 100)
  static const _localFoods = <(String, double, double?)>[
    // Lacticínios
    ('Leite Meio Gordo Mimosa', 50, 200),
    ('Leite Magro Mimosa', 34, 200),
    ('Leite Gordo Mimosa', 63, 200),
    ('Leite sem Lactose Mimosa', 50, 200),
    ('Iogurte natural', 61, 125),
    ('Iogurte grego', 97, 150),
    ('Iogurte grego 0%', 59, 150),
    ('Iogurte líquido Continente', 68, 200),
    ('Iogurte natural Pingo Doce', 58, 125),
    ('Iogurte de aromas Pingo Doce', 85, 125),
    ('Queijo flamengo', 352, 30),
    ('Queijo flamengo Pingo Doce', 350, 30),
    ('Queijo cottage', 98, 100),
    ('Queijo fresco', 72, 100),
    ('Queijo em fatias', 250, 20),
    ('Manteiga', 717, 10),
    ('Margarina', 555, 10),
    ('Creme vegetal Continente', 540, 10),
    ('Nata', 340, 20),
    ('Leite condensado', 321, 20),
    ('Requeijão', 120, 50),

    // Carnes e aves
    ('Peito de frango', 165, 120),
    ('Frango assado', 210, 120),
    ('Frango do Pingo Doce assado', 210, 120),
    ('Bife de vaca', 250, 150),
    ('Carne picada', 250, 120),
    ('Carne de porco', 242, 120),
    ('Entrecosto', 320, 120),
    ('Chouriço', 455, 20),
    ('Presunto cozido', 145, 30),
    ('Fiambre de peru', 100, 30),
    ('Salame', 470, 20),
    ('Salsicha', 300, 50),
    ('Bacon', 541, 15),
    ('Cordeiro', 294, 120),
    ('Peru assado', 160, 120),
    ('Almôndegas', 260, 80),
    ('Hambúrguer de carne', 295, 90),

    // Peixes e marisco
    ('Bacalhau cozido', 160, 120),
    ('Bacalhau à Brás', 185, 250),
    ('Salmão', 208, 120),
    ('Atum em lata', 184, 80),
    ('Sardinhas em lata', 208, 80),
    ('Camarão', 99, 100),
    ('Dourada', 96, 150),
    ('Pescada', 82, 150),
    ('Robalo', 97, 150),
    ('Polvo cozido', 82, 100),
    ('Lulas', 88, 100),

    // Ovos
    ('Ovo cozido', 155, 50),
    ('Ovo mexido', 149, 60),
    ('Omelete de queijo', 220, 100),

    // Padaria e cereais
    ('Pão branco', 265, 30),
    ('Pão integral', 247, 30),
    ('Pão de centeio', 236, 30),
    ('Pão de forma Continente', 255, 30),
    ('Pão de forma Pingo Doce', 255, 30),
    ('Croissant', 406, 60),
    ('Croissant de chocolate', 420, 60),
    ('Bolachas Maria', 433, 20),
    ('Bolachas Digestive', 480, 20),
    ('Cereais Corn Flakes', 378, 40),
    ('Cereais All-Bran', 260, 40),
    ('Aveia', 389, 40),
    ('Torradas', 380, 15),
    ('Pizza margherita', 267, 300),
    ('Pizza congelada', 250, 350),
    ('Massa cozida', 131, 180),
    ('Arroz branco cozido', 130, 150),
    ('Arroz integral cozido', 111, 150),
    ('Cuscuz', 112, 150),
    ('Quinoa cozida', 120, 150),
    ('Batata cozida', 77, 120),
    ('Batata frita', 312, 120),
    ('Puré de batata', 106, 200),

    // Leguminosas
    ('Feijão preto cozido', 132, 130),
    ('Feijão encarnado cozido', 127, 130),
    ('Grão-de-bico cozido', 164, 130),
    ('Lentilhas cozidas', 116, 130),
    ('Tremoços', 116, 50),
    ('Ervilhas', 81, 80),

    // Frutas e legumes
    ('Maçã', 52, 150),
    ('Banana', 89, 120),
    ('Laranja', 47, 130),
    ('Morangos', 32, 100),
    ('Uva', 69, 100),
    ('Pêra', 57, 160),
    ('Pêssego', 39, 150),
    ('Melancia', 30, 200),
    ('Abacate', 160, 100),
    ('Manga', 60, 150),
    ('Ananás', 50, 150),
    ('Kiwi', 61, 75),
    ('Cerejas', 63, 100),
    ('Cenoura', 41, 80),
    ('Tomate', 18, 120),
    ('Alface', 15, 50),
    ('Cebola', 40, 80),
    ('Pimento', 26, 80),
    ('Brócolos', 34, 100),
    ('Espinafres', 23, 80),
    ('Courgette', 17, 100),
    ('Beringela', 25, 100),
    ('Sopa de legumes', 36, 250),

    // Snacks e doces
    ('Batata frita de pacote', 536, 30),
    ('Amendoins', 567, 30),
    ('Nozes', 654, 30),
    ('Amêndoas', 579, 30),
    ('Pistácios', 560, 30),
    ('Chocolate negro 70%', 546, 20),
    ('Chocolate de leite', 535, 20),
    ('Nutella', 544, 15),
    ('Bolacha Oreo', 477, 20),
    ('Gomas', 340, 20),
    ('Donuts', 452, 60),
    ('Gelado de nata', 200, 100),

    // Bebidas
    ('Coca-Cola', 42, 330),
    ('Coca-Cola Zero', 0, 330),
    ('Sumo de laranja', 45, 200),
    ('Sumo de maçã', 46, 200),
    ('Água com gás', 0, 330),
    ('Cerveja', 43, 330),
    ('Vinho tinto', 85, 150),
    ('Café (sem açúcar)', 2, 50),
    ('Ice Tea', 31, 330),
    ('Bebida energética', 45, 250),

    // Molhos e condimentos
    ('Azeite', 884, 10),
    ('Maionese', 680, 15),
    ('Ketchup', 112, 15),
    ('Mostarda', 66, 10),
    ('Molho de soja', 53, 10),
    ('Molho pesto', 490, 20),
    ('Vinagre balsâmico', 88, 10),

    // Enlatados e congelados
    ('Milho em lata', 86, 80),
    ('Ervilhas em lata', 80, 80),
    ('Feijoada enlatada', 136, 250),
    ('Nuggets de frango', 250, 100),
    ('Croquetes', 290, 40),
    ('Rissóis', 300, 60),
    ('Pastéis de bacalhau', 330, 60),
    ('Batatas pré-fritas congeladas', 150, 150),

    // Diversos e alternativas
    ('Tofu', 76, 100),
    ('Seitan', 145, 100),
    ('Hambúrguer de soja', 220, 90),
    ('Proteína whey', 400, 30),
    ('Barra de proteína', 350, 50),
    ('Frutos secos mistos', 590, 30),
    ('Mel', 304, 20),
    ('Compota', 250, 20),
    ('Pasta de amendoim', 588, 20),
    ('Leite de amêndoa', 24, 200),
    ('Bebida vegetal de aveia', 50, 200),
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

  List<FoodProduct> searchLocal(String query) => _searchLocal(query);

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
              referenceGrams: entry.$3 ?? 100,
            ))
        .toList();
  }
}