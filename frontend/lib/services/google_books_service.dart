import 'package:http/http.dart' as http;
import 'dart:convert';

class GoogleBooksService {
  static Future<String?> buscarCapa(String titulo) async {
    final tituloLimpo = titulo.trim();
    if (tituloLimpo.isEmpty) return null;

    try {
      final query = Uri.encodeComponent(tituloLimpo);
      final url = 'https://openlibrary.org/search.json?title=$query&limit=5';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final docs = data['docs'] as List?;

        if (docs != null && docs.isNotEmpty) {
          // Tenta achar o primeiro resultado com capa
          for (final doc in docs) {
            final coverId = doc['cover_i'];
            if (coverId != null) {
              return 'https://covers.openlibrary.org/b/id/$coverId-L.jpg';
            }
          }
        }
      }
    } catch (_) {}

    return null;
  }
}
