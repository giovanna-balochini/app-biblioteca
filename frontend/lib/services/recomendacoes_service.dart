import 'dart:convert';
import 'package:frontend/services/auth_service.dart';

class RecomendacoesService {
  static Future<List<Map<String, dynamic>>> buscarParaMim({int limite = 12}) async {
    try {
      final url = '/recomendacoes/para-mim?limite=${limite < 1 ? 5 : (limite > 30 ? 20 : limite)}';
      final r = await AuthService.get(url);
      if (r.statusCode < 200 || r.statusCode >= 300) return [];
      final body = jsonDecode(utf8.decode(r.bodyBytes));
      if (body is Map<String, dynamic> && body['itens'] is List) {
        final list = body['itens'] as List;
        return List<Map<String, dynamic>>.from(
          list.whereType<Map<String, dynamic>>(),
        );
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
