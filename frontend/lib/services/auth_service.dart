import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  /// Lista de bases URL para tentar em ORDEM até uma funcionar.
  /// Sempre que uma URL responder, ela é salva e vira a "oficial" da próxima sessão.
  ///   1) URL salva manualmente (setBaseUrlManual / LoginPage custom)
  ///   2) 10.0.2.2        -> emulador Android → localhost do PC
  ///   3) 127.0.0.1       -> localhost (web, iOS, desktop, dispositivo físico via proxy/reverse)
  ///   4) 192.168.x.x     -> IPs privados LAN (celular físico na mesma WiFi do PC)
  ///   5) localhost       -> fallback textual
  static const List<String> _baseUrls = [
    'http://10.0.2.2:8080',
    'http://127.0.0.1:8080',
    'http://192.168.15.124:8080',
    'http://192.168.0.124:8080',
    'http://192.168.1.124:8080',
    'http://172.17.224.1:8080',
    'http://localhost:8080',
  ];

  static String? _baseUrlResolvida;
  static String? _baseUrlManual;
  static const String _keyBaseUrl = 'auth_base_url';
  static const String _keyBaseUrlManual = 'auth_base_url_manual';

  static const String _keyToken = 'auth_token';
  static const String _keyUsuarioId = 'auth_usuario_id';
  static const String _keyUsuarioNome = 'auth_usuario_nome';
  static const String _keyUsuarioEmail = 'auth_usuario_email';

  static String? _token;
  static int? _usuarioId;
  static String? _usuarioNome;
  static String? _usuarioEmail;
  static bool _inicializado = false;

  static Future<void> inicializar() async {
    if (_inicializado) return;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_keyToken);
    _usuarioId = prefs.getInt(_keyUsuarioId);
    _usuarioNome = prefs.getString(_keyUsuarioNome);
    _usuarioEmail = prefs.getString(_keyUsuarioEmail);
    _baseUrlResolvida = prefs.getString(_keyBaseUrl);
    _baseUrlManual = prefs.getString(_keyBaseUrlManual);
    _inicializado = true;
  }

  static String _baseUrl() =>
      _baseUrlManual ?? _baseUrlResolvida ?? _baseUrls.first;

  static Future<void> setBaseUrlManual(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url.trim().isEmpty) {
      _baseUrlManual = null;
      await prefs.remove(_keyBaseUrlManual);
    } else {
      final normalizada = _normalizarUrl(url);
      _baseUrlManual = normalizada;
      await prefs.setString(_keyBaseUrlManual, normalizada);
    }
  }

  static String _normalizarUrl(String url) {
    String u = url.trim();
    if (u.isEmpty) return u;
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'http://$u';
    }
    // Se for só IP/host sem porta, adiciona :8080 padrão
    final uri = Uri.tryParse(u);
    if (uri != null && uri.host.isNotEmpty && uri.hasPort == false) {
      u = u.replaceFirst(RegExp(r'/*$'), '') + ':8080';
    }
    return u;
  }

  static Future<void> resetarBaseUrl() async {
    _baseUrlResolvida = null;
    _baseUrlManual = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyBaseUrl);
    await prefs.remove(_keyBaseUrlManual);
  }

  static String get tipoUrlAtual =>
      _baseUrlManual != null
          ? 'manual'
          : (_baseUrlResolvida != null ? 'automático' : 'padrão');

  static Future<String?> _resolverBaseUrl() async {
    if (_baseUrlManual != null) return _baseUrlManual;
    if (_baseUrlResolvida != null) return _baseUrlResolvida;
    for (final url in _baseUrls) {
      try {
        final uri = Uri.parse('$url/auth/login');
        final req = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json; charset=UTF-8'},
              body: jsonEncode(
                  {'email': '_ping_', 'senha': '_ping_'}),
            )
            .timeout(const Duration(milliseconds: 1600));
        if (req.statusCode >= 200 && req.statusCode < 599) {
          _baseUrlResolvida = url;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_keyBaseUrl, url);
          if (kDebugMode) debugPrint('[AuthService] Base URL = $url');
          return url;
        }
      } catch (_) {}
    }
    return null;
  }

  static Future<void> _persistirBaseUrl(String url) async {
    if (url == _baseUrlResolvida) return;
    _baseUrlResolvida = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseUrl, url);
  }

  static bool get estaLogado => _token != null && _token!.isNotEmpty;
  static String? get token => _token;
  static int? get usuarioId => _usuarioId;
  static String? get usuarioNome => _usuarioNome;
  static String? get usuarioEmail => _usuarioEmail;
  static String get baseUrlAtual => _baseUrl();

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=UTF-8',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  static Future<Map<String, dynamic>> login({
    required String email,
    required String senha,
  }) async {
    return _executarAutenticacao(
      '/auth/login',
      {'email': email, 'senha': senha},
      'Erro ao fazer login',
    );
  }

  static Future<Map<String, dynamic>> registrar({
    required String nome,
    required String email,
    required String senha,
  }) async {
    return _executarAutenticacao(
      '/auth/registrar',
      {'nome': nome, 'email': email, 'senha': senha},
      'Erro ao cadastrar',
    );
  }

  static Future<Map<String, dynamic>> _executarAutenticacao(
    String path,
    Map<String, dynamic> body,
    String mensagemGenerica,
  ) async {
    if (!_inicializado) await inicializar();

    // Monta lista de URLs para tentar: a última que funcionou primeiro, depois as outras
    final urls = <String>{};
    if (_baseUrlResolvida != null) urls.add(_baseUrlResolvida!);
    urls.addAll(_baseUrls);

    Exception? ultimoErro;
    for (final url in urls) {
      try {
        final response = await http
            .post(
              Uri.parse('$url$path'),
              headers: {'Content-Type': 'application/json; charset=UTF-8'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 6));
        if (response.statusCode == 200 ||
            response.statusCode == 401 ||
            response.statusCode == 409 ||
            response.statusCode == 400) {
          // Resposta válida do backend => marcar como URL preferida
          await _persistirBaseUrl(url);
          final decoded = _decodeBody(response);
          if (response.statusCode == 200 &&
              decoded is Map<String, dynamic> &&
              decoded['token'] != null) {
            await _persistirResposta(decoded);
            return {'sucesso': true};
          }
          return {
            'sucesso': false,
            'mensagem': decoded is String
                ? decoded
                : (decoded is Map
                    ? decoded['message'] ??
                        decoded['erro'] ??
                        decoded['mensagem'] ??
                        mensagemGenerica
                    : mensagemGenerica),
          };
        }
      } on Exception catch (e) {
        ultimoErro = e;
      }
    }
    final msgErro = ultimoErro != null
        ? 'Backend inacessível (${ultimoErro.runtimeType}). '
            'Verifique se o Spring está rodando em http://localhost:8080. '
            'No celular físico, use o IP da sua rede LAN.'
        : mensagemGenerica;
    return {'sucesso': false, 'mensagem': msgErro};
  }

  static Future<void> logout() async {
    _token = null;
    _usuarioId = null;
    _usuarioNome = null;
    _usuarioEmail = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUsuarioId);
    await prefs.remove(_keyUsuarioNome);
    await prefs.remove(_keyUsuarioEmail);
  }

  static Future<void> _persistirResposta(Map<String, dynamic> body) async {
    _token = body['token'] as String?;
    _usuarioId = body['usuarioId'] as int?;
    _usuarioNome = body['nome'] as String?;
    _usuarioEmail = body['email'] as String?;
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) await prefs.setString(_keyToken, _token!);
    if (_usuarioId != null) await prefs.setInt(_keyUsuarioId, _usuarioId!);
    if (_usuarioNome != null) await prefs.setString(_keyUsuarioNome, _usuarioNome!);
    if (_usuarioEmail != null) await prefs.setString(_keyUsuarioEmail, _usuarioEmail!);
  }

  static dynamic _decodeBody(http.Response response) {
    try {
      if (response.body.isEmpty) return null;
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      return response.body;
    }
  }

  static Future<http.Response> get(String path) async {
    return _tratarResposta(() async {
      final urls = <String>{};
      if (_baseUrlResolvida != null) urls.add(_baseUrlResolvida!);
      urls.addAll(_baseUrls);
      Object? ultimoErro;
      for (final url in urls) {
        try {
          final res = await http
              .get(Uri.parse('$url$path'), headers: _headers)
              .timeout(const Duration(seconds: 7));
          if (res.statusCode >= 200 && res.statusCode < 599) {
            await _persistirBaseUrl(url);
            return res;
          }
        } catch (e) {
          ultimoErro = e;
        }
      }
      return http.Response(
          '{"erro":"Backend inacessível em: ${urls.join(", ")}. $ultimoErro"}', 500);
    });
  }

  static Future<http.Response> post(String path, Object? body) async {
    return _tratarResposta(() async {
      final urls = <String>{};
      if (_baseUrlResolvida != null) urls.add(_baseUrlResolvida!);
      urls.addAll(_baseUrls);
      Object? ultimoErro;
      for (final url in urls) {
        try {
          final res = await http
              .post(
                Uri.parse('$url$path'),
                headers: _headers,
                body: body == null ? null : jsonEncode(body),
              )
              .timeout(const Duration(seconds: 7));
          if (res.statusCode >= 200 && res.statusCode < 599) {
            await _persistirBaseUrl(url);
            return res;
          }
        } catch (e) {
          ultimoErro = e;
        }
      }
      return http.Response(
          '{"erro":"Backend inacessível em: ${urls.join(", ")}. $ultimoErro"}', 500);
    });
  }

  static Future<http.Response> put(String path, Object? body) async {
    return _tratarResposta(() async {
      final urls = <String>{};
      if (_baseUrlResolvida != null) urls.add(_baseUrlResolvida!);
      urls.addAll(_baseUrls);
      Object? ultimoErro;
      for (final url in urls) {
        try {
          final res = await http
              .put(
                Uri.parse('$url$path'),
                headers: _headers,
                body: body == null ? null : jsonEncode(body),
              )
              .timeout(const Duration(seconds: 7));
          if (res.statusCode >= 200 && res.statusCode < 599) {
            await _persistirBaseUrl(url);
            return res;
          }
        } catch (e) {
          ultimoErro = e;
        }
      }
      return http.Response(
          '{"erro":"Backend inacessível em: ${urls.join(", ")}. $ultimoErro"}', 500);
    });
  }

  static Future<http.Response> delete(String path) async {
    return _tratarResposta(() async {
      final urls = <String>{};
      if (_baseUrlResolvida != null) urls.add(_baseUrlResolvida!);
      urls.addAll(_baseUrls);
      Object? ultimoErro;
      for (final url in urls) {
        try {
          final res = await http
              .delete(Uri.parse('$url$path'), headers: _headers)
              .timeout(const Duration(seconds: 7));
          if (res.statusCode >= 200 && res.statusCode < 599) {
            await _persistirBaseUrl(url);
            return res;
          }
        } catch (e) {
          ultimoErro = e;
        }
      }
      return http.Response(
          '{"erro":"Backend inacessível em: ${urls.join(", ")}. $ultimoErro"}', 500);
    });
  }

  static Future<http.Response> _tratarResposta(Future<http.Response> Function() chamada) async {
    if (!_inicializado) await inicializar();
    try {
      return await chamada();
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthService] Erro na requisição: $e');
      return http.Response('{"error":"$e"}', 500);
    }
  }
}
