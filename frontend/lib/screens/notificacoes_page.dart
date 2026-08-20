import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/screens/perfil_usuario_page.dart';
import 'package:frontend/screens/detalhe_livro_page.dart';
import 'package:frontend/utils/snackbars.dart';
import 'package:cached_network_image/cached_network_image.dart';

class NotificacoesPage extends StatefulWidget {
  const NotificacoesPage({super.key});

  @override
  State<NotificacoesPage> createState() => _NotificacoesPageState();
}

class _NotificacoesPageState extends State<NotificacoesPage> {
  final List<dynamic> _itens = [];
  bool _carregando = true;
  bool _carregandoMais = false;
  bool _ultimaPagina = false;
  int _paginaAtual = 0;
  static const int _tamanhoPagina = 20;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_aoRolarAteOFim);
    _carregarPagina(resetar: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _aoRolarAteOFim() {
    if (_carregandoMais || _ultimaPagina) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      _carregarPagina(resetar: false);
    }
  }

  Future<void> _carregarPagina({required bool resetar}) async {
    if (_carregandoMais) return;
    final pagina = resetar ? 0 : _paginaAtual;
    if (resetar) {
      if (mounted) setState(() { _carregando = true; });
    } else {
      if (mounted) setState(() { _carregandoMais = true; });
    }
    try {
      final response = await AuthService.get('/notificacoes?page=$pagina&size=$_tamanhoPagina');
      if (response.statusCode == 200) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> itensNovos = body['itens'] is List ? body['itens'] : [];
        if (mounted) {
          setState(() {
            if (resetar) _itens.clear();
            _itens.addAll(itensNovos);
            _carregando = false;
            _carregandoMais = false;
            _paginaAtual = pagina + 1;
            _ultimaPagina = body['ultima'] == true || itensNovos.length < _tamanhoPagina;
          });
        }
      } else if (response.statusCode == 401) {
        if (mounted) mostrarSnackbarErro(context, 'Sessão expirada. Faça login novamente.');
      } else {
        if (mounted && !resetar) setState(() => _carregandoMais = false);
        if (mounted && resetar) setState(() => _carregando = false);
      }
    } catch (e, s) {
      if (mounted && !resetar) setState(() => _carregandoMais = false);
      if (mounted && resetar) setState(() => _carregando = false);
    }
  }

  Future<void> _marcarTodasComoLidas() async {
    try {
      final response = await AuthService.patch('/notificacoes/lidas', null);
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            for (var item in _itens) { if (item is Map) item['lida'] = true; }
          });
          mostrarSnackbarSucesso(context, 'Todas marcadas como lidas ✨');
        }
      }
    } catch (_) {
      if (mounted) mostrarSnackbarErro(context, 'Não foi possível atualizar. Tente novamente.');
    }
  }

  Future<void> _marcarUmaComoLida(int index) async {
    final item = _itens[index];
    if (item is! Map || item['lida'] == true) return;
    setState(() => item['lida'] = true);
    try {
      final id = item['id'];
      final response = await AuthService.patch('/notificacoes/$id/lida', null);
      if (response.statusCode != 200) {
        if (mounted) setState(() => item['lida'] = false);
      }
    } catch (_) {
      if (mounted) setState(() => item['lida'] = false);
    }
  }

  Future<void> _abrirItem(dynamic item) async {
    if (item is! Map) return;
    final int index = _itens.contains(item) ? _itens.indexOf(item) : -1;
    if (index >= 0) await _marcarUmaComoLida(index);
    final tipo = item['tipo'];
    final autorId = item['autorId'];
    final dadoId = item['dadoId'];
    final dadoNome = item['dadoNome'];
    if (!mounted) return;
    if ((tipo == 'SEGUIR') && autorId != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PerfilUsuarioPage(
        usuarioId: autorId,
        apelido: item['autorNome'],
      )));
      return;
    }
    if ((tipo == 'AVALIACAO' || tipo == 'MENSAGEM') && dadoId != null) {
      final livroTemp = <String, dynamic>{
        'id': dadoId,
        'titulo': dadoNome,
      };
      Navigator.push(context, MaterialPageRoute(builder: (_) => DetalheLivroPage(livro: livroTemp)));
      return;
    }
    if (autorId != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PerfilUsuarioPage(
        usuarioId: autorId,
        apelido: item['autorNome'],
      )));
    }
  }

  Color _corPorTipo(String? tipo) {
    switch (tipo) {
      case 'SEGUIR': return const Color(0xFF7C4DFF);
      case 'AVALIACAO': return const Color(0xFFFFB300);
      case 'MENSAGEM': return const Color(0xFF00BFA5);
      default: return const Color(0xFF7C4DFF);
    }
  }

  IconData _iconePorTipo(String? tipo) {
    switch (tipo) {
      case 'SEGUIR': return Icons.person_add_alt_1_rounded;
      case 'AVALIACAO': return Icons.star_rounded;
      case 'MENSAGEM': return Icons.chat_bubble_rounded;
      default: return Icons.notifications_active_rounded;
    }
  }

  String _formatarData(dynamic dataStr) {
    if (dataStr == null) return '';
    try {
      final data = DateTime.parse(dataStr.toString());
      final agora = DateTime.now();
      final diff = agora.difference(data);
      if (diff.inMinutes < 1) return 'agora';
      if (diff.inMinutes < 60) return '${diff.inMinutes} min atrás';
      if (diff.inHours < 24) return '${diff.inHours} h atrás';
      if (diff.inDays < 7) return '${diff.inDays} d atrás';
      return '${data.day.toString().padLeft(2,'0')}/${data.month.toString().padLeft(2,'0')}';
    } catch (e) {
      return '';
    }
  }

  Widget _construirAvatar(dynamic item) {
    final fotoUrl = item['autorFotoUrl'] ?? item['fotoUrl'];
    final String inicial = (item['autorNome'] is String && item['autorNome'].toString().isNotEmpty)
        ? item['autorNome'].toString().substring(0, 1).toUpperCase()
        : '·';
    const double size = 46;
    if (fotoUrl is String && fotoUrl.isNotEmpty) {
      if (fotoUrl.startsWith('http')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: CachedNetworkImage(
            imageUrl: fotoUrl,
            width: size, height: size, fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: size, height: size, alignment: Alignment.center,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFEDE7FF)),
              child: Text(inicial, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF7C4DFF), fontSize: 18)),
            ),
            errorWidget: (_, __, ___) => Container(
              width: size, height: size, alignment: Alignment.center,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFEDE7FF)),
              child: Text(inicial, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF7C4DFF), fontSize: 18)),
            ),
          ),
        );
      }
      if (fotoUrl.contains('base64') || fotoUrl.length > 200) {
        try {
          final bytes = base64Decode(fotoUrl.replaceAll(RegExp(r'^data:image/\w+;base64,'), ''));
          return ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Image.memory(bytes, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true),
          );
        } catch (e, s) { /* ignora */ }
      }
    }
    final corFundo = _corPorTipo(item['tipo']).withValues(alpha: 0.15);
    return Container(
      width: size, height: size, alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: corFundo),
      child: Icon(_iconePorTipo(item['tipo']), color: _corPorTipo(item['tipo']), size: 22),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final corPrimaria = const Color(0xFF7C4DFF);
    final escuro = tema.brightness == Brightness.dark;
    final corBorda = escuro ? const Color(0xFF2C2C38) : const Color(0xFFEDE7F2);
    final corFundoItem = escuro ? const Color(0xFF1C1C26) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          if (_itens.isNotEmpty)
            TextButton.icon(
              onPressed: _marcarTodasComoLidas,
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Marcar lidas'),
              style: TextButton.styleFrom(foregroundColor: corPrimaria),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: corPrimaria,
        onRefresh: () => _carregarPagina(resetar: true),
        child: _carregando && _itens.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _itens.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.28),
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 92, height: 92,
                              decoration: BoxDecoration(color: corPrimaria.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(26)),
                              child: const Icon(Icons.notifications_none_rounded, size: 42, color: Color(0xFF7C4DFF)),
                            ),
                            const SizedBox(height: 18),
                            Text('Sem notificações por enquanto', style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 36),
                              child: Text('Quando alguém seguir você ou avaliar um livro seu, aparecerá aqui.', textAlign: TextAlign.center, style: tema.textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B6B80))),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
                    itemCount: _itens.length + (_carregandoMais ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == _itens.length) {
                        return const Padding(padding: EdgeInsets.all(18), child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))));
                      }
                      final item = _itens[i];
                      final lida = item is Map && item['lida'] == true;
                      final tipo = item is Map ? item['tipo'] : null;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _abrirItem(item),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                              decoration: BoxDecoration(
                                color: lida ? corFundoItem : corFundoItem,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: lida ? corBorda : corPrimaria.withValues(alpha: 0.30), width: lida ? 1 : 1.3),
                                boxShadow: lida ? null : [BoxShadow(color: corPrimaria.withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, 6))],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      _construirAvatar(item),
                                      if (!lida) Positioned(
                                        right: -2, bottom: -2,
                                        child: Container(
                                          width: 14, height: 14,
                                          decoration: BoxDecoration(shape: BoxShape.circle, color: corPrimaria, border: Border.all(color: corFundoItem, width: 2.2)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: RichText(
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                text: TextSpan(
                                                  style: tema.textTheme.bodyMedium?.copyWith(height: 1.35, color: escuro ? const Color(0xFFE6E6F0) : const Color(0xFF2A2A38)),
                                                  children: [
                                                    if (item is Map && item['autorNome'] is String && item['autorNome'].toString().isNotEmpty)
                                                      TextSpan(
                                                        text: '${item['autorNome']} ',
                                                        style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF7C4DFF)),
                                                      ),
                                                    TextSpan(text: (item is Map ? item['conteudo'] : null)?.toString() ?? ''),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                              decoration: BoxDecoration(
                                                color: _corPorTipo(tipo).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(_iconePorTipo(tipo), size: 13, color: _corPorTipo(tipo)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(Icons.schedule_rounded, size: 13, color: const Color(0xFF6B6B80).withValues(alpha: 0.9)),
                                            const SizedBox(width: 4),
                                            Text(_formatarData(item is Map ? item['dataCriacao'] : null),
                                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B6B80), fontWeight: FontWeight.w500),
                                            ),
                                            const Spacer(),
                                            if (item is Map && item['dadoNome'] is String && item['dadoNome'].toString().isNotEmpty)
                                              Flexible(
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                  decoration: BoxDecoration(
                                                    color: escuro ? const Color(0xFF26263A) : const Color(0xFFF5F2FF),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    item['dadoNome'].toString(),
                                                    overflow: TextOverflow.ellipsis, maxLines: 1,
                                                    style: TextStyle(fontSize: 11, color: corPrimaria, fontWeight: FontWeight.w700),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
