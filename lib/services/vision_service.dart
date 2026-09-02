import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../models/vision_result.dart';

class VisionService {
  final SupabaseClient _client;

  VisionService(this._client);

  Future<VisionAnalysis> analyzeMeal(String imageUrl) async {
    final response = await _client.functions.invoke(
      AppConfig.analyzeMealFunction,
      body: {'imageUrl': imageUrl},
    );

    if (response.status < 200 || response.status >= 300 || response.data == null) {
      throw Exception('A análise da imagem falhou (HTTP ${response.status}).');
    }

    final data = jsonDecode(jsonEncode(response.data));
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Resposta da IA em formato inesperado.');
    }

    return VisionAnalysis.fromJson(data);
  }
}