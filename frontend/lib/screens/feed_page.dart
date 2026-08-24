import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/screens/detalhe_livro_page.dart';
import 'package:frontend/screens/perfil_usuario_page.dart';
import 'package:frontend/screens/notificacoes_page.dart';
import 'package:frontend/widgets/estrelas_avaliacao.dart';
import 'package:frontend/widgets/botao_curtida_avaliacao.dart';
import 'package:frontend/utils/formatters.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:typed_data';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _itens = [];
  int _paginaAtual = 0;
  bool _ultimaPagina = false;
  bool _carregando = true;
  bool _carregandoMais = false;
  bool _erro = false;
  String _filtro = 'todos'; // 'todos' ou 'seguindo'
  static const int _tamPagina = 20;
  int _qtdeNotificacoesNaoLidas = 0;
  Timer? _timerAtualizaNotificacoes;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 300 &&
          !_carregandoMais && !_ultimaPagina && !_erro) {
        _carregarMais();
      }
    });
    _carregarTudo();
    _carregarContagemNotificacoes();
    _timerAtualizaNotificacoes = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _carregarContagemNotificacoes();
    });
  }

  @override
  void dispose() {
    _timerAtualizaNotificacoes?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _carregarContagemNotificacoes() async {
    try {
      final r = await AuthService.get('/notificacoes/contagem-nao-lidas');
      if (r.statusCode == 200) {
        final body = jsonDecode(utf8.decode(r.bodyBytes));
        final qtde = body is Map && body['naoLidas'] is int ? body['naoLidas'] as int : 0;
        if (mounted && qtde != _qtdeNotificacoesNaoLidas) {
          setState(() => _qtdeNotificacoesNaoLidas = qtde);
        }
      }
    } catch (e, s) { /* ignora */ }
  }

  Future<void> _carregarTudo() async {
    if (!mounted) return;
    setState(() {
      _carregando = true;
      _erro = false;
    });
    _paginaAtual = 0;
    _ultimaPagina = false;
    await _carregarPagina(0, resetar: true);
    if (mounted) setState(() => _carregando = false);
  }

  Future<void> _carregarMais() async {
    if (_carregando || _carregandoMais || _ultimaPagina || _erro) return;
    setState(() => _carregandoMais = true);
    await _carregarPagina(_paginaAtual + 1);
    if (mounted) setState(() => _carregandoMais = false);
  }

  Future<void> _carregarPagina(int pagina, {bool resetar = false}) async {
    try {
      final filtroParam = _filtro == 'seguindo' ? '&filtro=seguindo' : '';
      final response = await AuthService.get(
        '/feed?page=$pagina&size=$_tamPagina$filtroParam',
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body is Map<String, dynamic>) {
          final itensJson = body['itens'];
          final ultima = body['ultima'] == true;
          if (resetar) _itens.clear();
          if (itensJson is List) {
            _itens.addAll(List<Map<String, dynamic>>.from(
                itensJson.whereType<Map<String, dynamic>>()));
          }
          _paginaAtual = pagina;
          _ultimaPagina = ultima;
          if (mounted) setState(() => _erro = false);
        } else {
          if (mounted) setState(() => _erro = true);
        }
      } else {
        if (mounted) setState(() => _erro = true);
      }
    } catch (_) {
      if (mounted) setState(() => _erro = true);
    }
  }

  Future<void> _abrirLivro(Map<String, dynamic> item) async {
    final livroId = item['livroId'];
    if (livroId == null) return;
    final livro = {
      'id': livroId,
      'titulo': item['livroTitulo'],
      'autor': item['livroAutor'],
      'genero': item['livroGenero'],
      'imagem': item['livroCapa'],
      'lido': true,
    };
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetalheLivroPage(livro: livro)),
    );
  }

  Future<void> _abrirPerfil(Map<String, dynamic> item) async {
    final usuarioId = item['usuarioId'];
    if (usuarioId == null) return;
    final id = usuarioId is int ? usuarioId : int.tryParse(usuarioId.toString());
    if (id == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PerfilUsuarioPage(
          usuarioId: id,
          apelido: item['usuarioNome']?.toString(),
        ),
      ),
    );
  }

  Future<void> _abrirEscolhaFiltro() async {
    final corPrimaria = const Color(0xFF7C4DFF);
    final escolha = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 14),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: BoxDecoration(
            color: Theme.of(ctx).cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE9E6F2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCD6F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Filtrar feed',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF2A2A38),
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Escolha quais avaliações quer ver.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6B6B80),
                    ),
              ),
              const SizedBox(height: 12),
              _opcaoFiltro(
                ctx,
                valor: 'todos',
                atual: _filtro,
                rotulo: 'Todos',
                sub: 'Avaliações recentes de toda a comunidade',
                icone: Icons.public_rounded,
                corPrimaria: corPrimaria,
              ),
              const SizedBox(height: 6),
              _opcaoFiltro(
                ctx,
                valor: 'seguindo',
                atual: _filtro,
                rotulo: 'Só quem sigo',
                sub: 'Apenas avaliações de pessoas que você segue',
                icone: Icons.people_alt_rounded,
                corPrimaria: corPrimaria,
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
    if (escolha != null && escolha != _filtro) {
      if (mounted) {
        setState(() {
          _filtro = escolha;
          _itens.clear();
          _paginaAtual = 0;
          _ultimaPagina = false;
          _erro = false;
        });
        _scrollController.jumpTo(0);
        await _carregarTudo();
      }
    }
  }

  Widget _opcaoFiltro(BuildContext ctx,
      {required String valor,
      required String atual,
      required String rotulo,
      required String sub,
      required IconData icone,
      required Color corPrimaria}) {
    final selecionado = valor == atual;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(ctx).pop(valor),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selecionado
                    ? corPrimaria.withValues(alpha: 0.5)
                    : const Color(0xFFEFEBFA),
                width: selecionado ? 1.4 : 0.8),
            color: selecionado
                ? corPrimaria.withValues(alpha: 0.08)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selecionado
                      ? corPrimaria.withValues(alpha: 0.18)
                      : const Color(0xFFF5F1FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icone,
                    size: 20,
                    color: selecionado ? corPrimaria : const Color(0xFF7C4DFF)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rotulo,
                      style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: selecionado
                                ? corPrimaria
                                : const Color(0xFF2A2A38),
                          ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      sub,
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF6B6B80),
                          ),
                    ),
                  ],
                ),
              ),
              if (selecionado)
                Icon(Icons.check_circle_rounded, color: corPrimaria, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tema = Theme.of(context);
    final corPrimaria = const Color(0xFF7C4DFF);

    return RefreshIndicator(
      color: corPrimaria,
      onRefresh: _carregarTudo,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: false,
            floating: true,
            snap: true,
            backgroundColor: tema.colorScheme.inversePrimary,
            titleSpacing: 0,
            title: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [corPrimaria, const Color(0xFFB28CFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    blendMode: BlendMode.srcIn,
                    child: const Icon(Icons.newspaper_rounded, size: 28),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Feed',
                          style: tema.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Avaliações recentes da comunidade de leitores',
                          style: tema.textTheme.bodySmall?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_on_outlined, color: Colors.white),
                          tooltip: 'Notificações',
                          onPressed: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificacoesPage()));
                            if (mounted) _carregarContagemNotificacoes();
                          },
                        ),
                        if (_qtdeNotificacoesNaoLidas > 0)
                          Positioned(
                            right: 6, top: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                              decoration: const BoxDecoration(color: Color(0xFFFF3B7A), shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: Text(
                                _qtdeNotificacoesNaoLidas > 99 ? '99+' : '$_qtdeNotificacoesNaoLidas',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_carregando)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator(color: Color(0xFF7C4DFF))),
            )
          else if (_erro && _itens.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildErro(tema),
            )
          else if (_itens.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildVazio(tema, corPrimaria),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _ultimaPagina
                            ? '${_itens.length} avaliaç${_itens.length == 1 ? 'ão' : 'ões'}${_filtro == 'seguindo' ? ' · só quem sigo' : ''}'
                            : _filtro == 'seguindo'
                                ? 'Só quem sigo · mais novas primeiro'
                                : 'Mais novas primeiro',
                        style: tema.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF8A8A9D),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      elevation: 0,
                      child: InkWell(
                        onTap: _abrirEscolhaFiltro,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: const Color(0xFFE9E6F2), width: 0.9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _filtro == 'seguindo'
                                    ? Icons.people_alt_rounded
                                    : Icons.public_rounded,
                                size: 15,
                                color: const Color(0xFF7C4DFF),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _filtro == 'seguindo'
                                    ? 'Só quem sigo'
                                    : 'Todos',
                                style: const TextStyle(
                                    color: Color(0xFF7C4DFF),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5),
                              ),
                              const SizedBox(width: 2),
                              const Icon(Icons.expand_more_rounded,
                                  size: 16, color: Color(0xFF7C4DFF)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              sliver: SliverList.separated(
                itemCount: _itens.length + (_ultimaPagina ? 0 : 1),
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  if (index >= _itens.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: _carregandoMais
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Color(0xFF7C4DFF)),
                              )
                            : null,
                      ),
                    );
                  }
                  final item = _itens[index];
                  return _buildCardItem(item, tema, corPrimaria);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErro(ThemeData tema) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 56, color: Color(0xFF8A8A9D)),
            const SizedBox(height: 12),
            Text(
              'Não foi possível carregar o feed.',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _carregarTudo,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Tentar novamente',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVazio(ThemeData tema, Color corPrimaria) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: corPrimaria.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.post_add_rounded, size: 40, color: corPrimaria),
            ),
            const SizedBox(height: 18),
            Text(
              'Nenhuma avaliação publicada ainda.',
              style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Seja o primeiro a publicar uma avaliação em qualquer livro!\n\nPuxe para baixo para atualizar.',
              style: tema.textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B6B80)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardItem(Map<String, dynamic> item, ThemeData tema, Color corPrimaria) {
    final usuarioNome = item['usuarioNome']?.toString() ?? 'Usuário';
    final usuarioFoto = item['usuarioFotoPerfil']?.toString();
    final nota = item['nota'] is int ? item['nota'] as int : 0;
    final comentario = item['comentario']?.toString();
    final livroTitulo = item['livroTitulo']?.toString() ?? 'Livro sem título';
    final livroAutor = item['livroAutor']?.toString() ?? 'Autor desconhecido';
    final livroCapa = item['livroCapa']?.toString();
    final livroGenero = item['livroGenero']?.toString();
    final dataPub = item['dataPublicacao']?.toString();
    final dataFormatada = dataPub != null && dataPub.length >= 10
        ? formatarData(parseDataISO(dataPub.substring(0, 10)))
        : null;
    final isMinha =
        item['usuarioId'] != null && item['usuarioId'] == AuthService.usuarioId;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _abrirLivro(item),
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: tema.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isMinha ? corPrimaria.withValues(alpha: 0.35) : const Color(0xFFE9E6F2),
              width: isMinha ? 1.3 : 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 82,
                  height: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _construirCapa(livroCapa, livroTitulo, tema),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _abrirPerfil(item),
                              borderRadius: BorderRadius.circular(20),
                              child: CircleAvatar(
                                radius: 13,
                                backgroundColor: corPrimaria.withValues(alpha: 0.12),
                                backgroundImage: (usuarioFoto != null &&
                                        usuarioFoto.isNotEmpty &&
                                        usuarioFoto.startsWith('http'))
                                    ? NetworkImage(usuarioFoto)
                                    : null,
                                child: (usuarioFoto == null ||
                                        usuarioFoto.isEmpty ||
                                        !usuarioFoto.startsWith('http'))
                                    ? Text(
                                        usuarioNome.isNotEmpty
                                            ? usuarioNome[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          color: corPrimaria,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _abrirPerfil(item),
                                borderRadius: BorderRadius.circular(6),
                                child: Text(
                                  isMinha ? '$usuarioNome (você)' : usuarioNome,
                                  style: tema.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: corPrimaria,
                                        decoration: TextDecoration.underline,
                                        decorationColor: corPrimaria.withValues(alpha: 0.4),
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          EstrelasAvaliacao(
                            avaliacao: nota == 0 ? null : nota,
                            tamanho: 14,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        livroTitulo,
                        style: tema.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF2A2A38),
                              height: 1.1,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        livroAutor,
                        style: tema.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (livroGenero != null && livroGenero.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: corPrimaria.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            livroGenero,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: corPrimaria,
                            ),
                          ),
                        ),
                      ],
                      if (comentario != null && comentario.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F5FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            comentario,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: tema.textTheme.bodyMedium?.copyWith(height: 1.3),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (dataFormatada != null)
                            Expanded(
                              child: Text(
                                dataFormatada,
                                style: const TextStyle(
                                  color: Color(0xFF8A8A9D),
                                  fontSize: 11.5,
                                ),
                              ),
                            )
                          else
                            const Spacer(),
                          const SizedBox(width: 8),
                          BotaoCurtidaAvaliacao(
                            avaliacao: item,
                            tamanhoIcone: 20,
                            compacto: true,
                          ),
                          const SizedBox(width: 2),
                          TextButton.icon(
                            onPressed: () => _abrirLivro(item),
                            style: TextButton.styleFrom(
                              foregroundColor: corPrimaria,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.open_in_new_rounded, size: 14),
                            label: const Text('Abrir livro',
                                style: TextStyle(
                                    fontSize: 12.5, fontWeight: FontWeight.w700)),
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
  }

  Widget _construirCapa(String? capa, String titulo, ThemeData tema) {
    if (capa != null && capa.isNotEmpty) {
      final c = capa.toString();
      final ehBase64 = c.startsWith('data:image') || c.length > 1000;
      if (ehBase64) {
        try {
          Uint8List bytes;
          final i = c.indexOf(',');
          final b64 = i != -1 ? c.substring(i + 1) : c;
          bytes = base64Decode(b64);
          return Image.memory(bytes, fit: BoxFit.cover,
              errorBuilder: (_, e, s) => _capaPlaceholder(titulo, tema));
        } catch (_) {
          return _capaPlaceholder(titulo, tema);
        }
      }
      return CachedNetworkImage(
        imageUrl: c,
        fit: BoxFit.cover,
        placeholder: (ctx, url) => _capaPlaceholder(titulo, tema),
        errorWidget: (ctx, url, err) => _capaPlaceholder(titulo, tema),
      );
    }
    return _capaPlaceholder(titulo, tema);
  }

  Widget _capaPlaceholder(String titulo, ThemeData tema) {
    final corPrimaria = const Color(0xFF7C4DFF);
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: corPrimaria.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(8),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_rounded, size: 36, color: corPrimaria),
          const SizedBox(height: 6),
          Text(
            titulo,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: tema.textTheme.bodySmall?.copyWith(
                  color: corPrimaria,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
          ),
        ],
      ),
    );
  }
}
