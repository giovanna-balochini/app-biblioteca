import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import '../widgets/capa_livro.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_progresso_leitura.dart';
import '../utils/snackbars.dart';
import '../utils/transitions.dart';
import '../widgets/skeletons.dart';
import 'detalhe_livro_page.dart';

class MinhaLeituraPage extends StatefulWidget {
  const MinhaLeituraPage({super.key});

  @override
  State<MinhaLeituraPage> createState() => _MinhaLeituraPageState();
}

class _MinhaLeituraPageState extends State<MinhaLeituraPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _resumo;
  final Map<String, List<dynamic>> _listas = {
    'QUERO_LER': [],
    'LENDO': [],
    'LIDO': [],
  };
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _carregarTudo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _carregarTudo() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final List<Future<void>> tasks = [
        _carregarResumo(),
        _carregarLista('QUERO_LER'),
        _carregarLista('LENDO'),
        _carregarLista('LIDO'),
      ];
      await Future.wait(tasks);
    } catch (e) {
      _erro = e.toString();
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _carregarResumo() async {
    final r = await AuthService.get('/livros/resumo-estante');
    if (r.statusCode == 200) {
      final data = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      if (mounted) setState(() => _resumo = data);
    }
  }

  Future<void> _carregarLista(String status) async {
    final r = await AuthService.get('/livros/status/$status');
    if (r.statusCode == 200) {
      final data = jsonDecode(utf8.decode(r.bodyBytes)) as List<dynamic>;
      if (mounted) setState(() => _listas[status] = data);
    }
  }

  Future<void> _avancarPagina(Map livro) async {
    final info = InfoProgressoLivro.fromMap(livro);
    final tot = info.totalPaginas;
    if (tot == null || tot <= 0) {
      mostrarSnackbarAviso(context,
          'Informe o total de páginas do livro primeiro (toque no card → Editar)');
      return;
    }
    final prox = ((info.paginaAtual ?? 0) + 1).clamp(0, tot);
    await _atualizarPaginaServidor(livro, prox, tot);
  }

  Future<void> _retrocederPagina(Map livro) async {
    final info = InfoProgressoLivro.fromMap(livro);
    if ((info.paginaAtual ?? 0) <= 0) return;
    final tot = info.totalPaginas ?? 0;
    final prev = ((info.paginaAtual ?? 0) - 1).clamp(0, tot);
    await _atualizarPaginaServidor(livro, prev, tot);
  }

  Future<void> _marcarComoConcluido(Map livro) async {
    final id = livro['id'];
    final statusAntes = livro['statusLeitura'];
    final pagAntes = livro['paginaAtual'];
    setState(() {
      livro['statusLeitura'] = 'LIDO';
      livro['paginaAtual'] = livro['totalPaginas'] ?? livro['paginaAtual'];
      livro['progressoPercentual'] = 100.0;
      livro['lido'] = true;
      _reclassificarLivro(livro, de: statusAntes, para: 'LIDO');
    });
    try {
      final body = jsonEncode(<String, dynamic>{'statusLeitura': 'LIDO'});
      final r = await AuthService.patch('/livros/$id/status', body);
      if (r.statusCode != 200) throw Exception('Erro ${r.statusCode}');
      final data = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      _atualizarDadosLivro(id, data);
      if (mounted) mostrarSnackbarSucesso(context, 'Parabéns! 🎉 Livro marcado como concluído.');
      await _carregarResumo();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        livro['statusLeitura'] = statusAntes;
        livro['paginaAtual'] = pagAntes;
        livro['progressoPercentual'] = InfoProgressoLivro.fromMap(livro).progresso;
        livro['lido'] = statusAntes == 'LIDO';
        _reclassificarLivro(livro, de: 'LIDO', para: statusAntes);
      });
      mostrarSnackbarErro(context, 'Não foi possível marcar como concluído.');
    }
  }

  Future<void> _atualizarPaginaServidor(
      Map livro, int novaPag, int? totalPaginas) async {
    final id = livro['id'];
    final pagAntes = livro['paginaAtual'];
    final statusAntes = livro['statusLeitura'];
    final progressoAntes = livro['progressoPercentual'];
    setState(() {
      livro['paginaAtual'] = novaPag;
      if (totalPaginas != null && totalPaginas > 0) {
        livro['progressoPercentual'] =
            double.parse(((novaPag * 100.0) / totalPaginas).toStringAsFixed(1));
        if (novaPag >= totalPaginas) {
          livro['statusLeitura'] = 'LIDO';
          livro['lido'] = true;
          _reclassificarLivro(livro, de: statusAntes, para: 'LIDO');
        } else if (novaPag > 0 && (statusAntes == null || statusAntes == 'QUERO_LER')) {
          livro['statusLeitura'] = 'LENDO';
          _reclassificarLivro(livro, de: statusAntes ?? 'QUERO_LER', para: 'LENDO');
        }
      }
    });
    try {
      final body = jsonEncode(<String, dynamic>{
        'paginaAtual': novaPag,
        if (totalPaginas != null) 'totalPaginas': totalPaginas,
      });
      final r = await AuthService.patch('/livros/$id/progresso', body);
      if (r.statusCode != 200) throw Exception('Erro ${r.statusCode}');
      final data = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      _atualizarDadosLivro(id, data);
      await _carregarResumo();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        livro['paginaAtual'] = pagAntes;
        livro['statusLeitura'] = statusAntes;
        livro['progressoPercentual'] = progressoAntes;
        livro['lido'] = statusAntes == 'LIDO';
      });
      mostrarSnackbarErro(context, 'Não foi possível atualizar o progresso.');
    }
  }

  void _atualizarDadosLivro(dynamic id, Map<String, dynamic> data) {
    for (final k in _listas.keys) {
      for (int i = 0; i < _listas[k]!.length; i++) {
        if (_listas[k]![i]['id'] == id) {
          _listas[k]![i] = data;
        }
      }
    }
    if (mounted) setState(() {});
  }

  void _reclassificarLivro(Map livro, {String? de, String? para}) {
    if (de == para) return;
    if (de != null) _listas[de]?.removeWhere((l) => l['id'] == livro['id']);
    if (para != null && !(_listas[para]?.any((l) => l['id'] == livro['id']) ?? true)) {
      _listas[para]?.insert(0, livro);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final escuro = tema.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha Leitura'),
        backgroundColor: tema.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF7C4DFF),
          unselectedLabelColor: escuro ? const Color(0xFFB6B6CC) : const Color(0xFF6B6B80),
          indicatorColor: const Color(0xFF7C4DFF),
          tabs: [
            Tab(
              icon: const Icon(Icons.bookmark_border_rounded),
              text: 'Quero ler (${_resumo?['queroLer'] ?? 0})',
              height: 62,
            ),
            Tab(
              icon: const Icon(Icons.menu_book_rounded),
              text: 'Lendo (${_resumo?['lendo'] ?? 0})',
              height: 62,
            ),
            Tab(
              icon: const Icon(Icons.check_circle_outline_rounded),
              text: 'Lidos (${_resumo?['lidos'] ?? 0})',
              height: 62,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_resumo != null) _HeaderResumo(resumo: _resumo!),
          Expanded(
            child: _carregando
                ? const SkeletonListaLivros()
                : _erro != null
                    ? Center(child: Text(_erro!))
                    : RefreshIndicator(
                        onRefresh: _carregarTudo,
                        color: const Color(0xFF7C4DFF),
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _ListaLivros(
                              livros: _listas['QUERO_LER']!,
                              widgetVazio: EmptyState(
                                icone: Icons.bookmark_border_rounded,
                                titulo: "Nenhum livro salvo na lista",
                                descricao: "Adicione livros que deseja ler para nunca mais esquecer o que quer descobrir.",
                                rotuloBotao: "Buscar livros",
                                iconeBotao: Icons.search_rounded,
                                aoClicarBotao: () => DefaultTabController.of(context).animateTo(2),
                              ),
                              onAbrir: (l) => _abrirLivro(l),
                              aoMudarStatus: (l, novo) => _mudarStatus(l, novo),
                              builderBotoes: (_) => const SizedBox.shrink(),
                            ),
                            _ListaLivros(
                              livros: _listas['LENDO']!,
                              widgetVazio: EmptyState(
                                icone: Icons.menu_book_rounded,
                                titulo: "Nenhuma leitura em andamento",
                                descricao: "Comece um livro hoje. Acompanhe seu progresso página por página!",
                                rotuloBotao: "Ver minha biblioteca",
                                iconeBotao: Icons.local_library_rounded,
                                aoClicarBotao: () => Navigator.of(context).pop(),
                              ),
                              onAbrir: _abrirLivro,
                              aoMudarStatus: _mudarStatus,
                              builderBotoes: (l) => _BotoesProgresso(
                                livro: l,
                                onAvancar: () => _avancarPagina(l),
                                onRetroceder: () => _retrocederPagina(l),
                                onConcluir: () => _marcarComoConcluido(l),
                              ),
                            ),
                            _ListaLivros(
                              livros: _listas['LIDO']!,
                              widgetVazio: EmptyState(
                                icone: Icons.check_circle_outline_rounded,
                                titulo: "Nenhum livro concluído ainda",
                                descricao: "Termine de ler seu primeiro livro e registre a conquista aqui!",
                                rotuloBotao: "Ir para livros lendo",
                                iconeBotao: Icons.play_arrow_rounded,
                                aoClicarBotao: () => DefaultTabController.of(context).animateTo(1),
                              ),
                              onAbrir: _abrirLivro,
                              aoMudarStatus: _mudarStatus,
                              builderBotoes: (_) => const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirLivro(Map livro) async {
    final id = livro['id'];
    final titulo = livro['titulo'];
    final autor = livro['autor'];
    final imagem = livro['imagem'];
    final Map<String, dynamic> min = <String, dynamic>{
      'id': id,
      'titulo': titulo,
      'autor': autor,
      'imagem': imagem,
    };
    await navegarComAnimacao(context, DetalheLivroPage(livro: min is Map<String,dynamic> ? min : Map<String,dynamic>.from(min as Map)));
    await _carregarTudo();
  }

  Future<void> _mudarStatus(Map livro, String novoStatus) async {
    final id = livro['id'];
    final statusAntes = livro['statusLeitura'] ?? (livro['lido'] == true ? 'LIDO' : 'QUERO_LER');
    setState(() {
      livro['statusLeitura'] = novoStatus;
      livro['lido'] = novoStatus == 'LIDO';
      if (novoStatus == 'QUERO_LER') {
        livro['paginaAtual'] = 0;
        livro['progressoPercentual'] = 0.0;
      }
      _reclassificarLivro(livro, de: statusAntes, para: novoStatus);
    });
    try {
      final body = jsonEncode(<String, dynamic>{'statusLeitura': novoStatus});
      final r = await AuthService.patch('/livros/$id/status', body);
      if (r.statusCode != 200) throw Exception('Erro ${r.statusCode}');
      final data = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      _atualizarDadosLivro(id, data);
      await _carregarResumo();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        livro['statusLeitura'] = statusAntes;
        livro['lido'] = statusAntes == 'LIDO';
        _reclassificarLivro(livro, de: novoStatus, para: statusAntes);
      });
      mostrarSnackbarErro(context, 'Não foi possível alterar o status.');
    }
  }
}

class _HeaderResumo extends StatelessWidget {
  final Map<String, dynamic> resumo;
  const _HeaderResumo({required this.resumo});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final escuro = tema.brightness == Brightness.dark;
    final total = resumo['total'] ?? 0;
    final lidos = resumo['lidos'] ?? 0;
    final lendo = resumo['lendo'] ?? 0;
    final queroLer = resumo['queroLer'] ?? 0;
    final progressoGeral = (resumo['progressoGeralLendo'] is num
            ? (resumo['progressoGeralLendo'] as num).toDouble()
            : 0.0)
        .clamp(0, 100)
        .toDouble();
    final pagsLidas = resumo['paginasLidasEmAndamento'] ?? 0;
    final pagsTot = resumo['totalPaginasEmAndamento'] ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: escuro ? const Color(0xFF1C1C27) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: escuro ? const Color(0xFF2B2B38) : const Color(0xFFE7E7F1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: escuro ? 0.18 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              BarraProgressoCircular(
                percentual: progressoGeral,
                tamanho: 72,
                espessura: 5.5,
                centro: Text(
                  '${progressoGeral.toStringAsFixed(progressoGeral.truncateToDouble() == progressoGeral ? 0 : 1)}%',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Progresso geral',
                        style: tema.textTheme.titleLarge?.copyWith(fontSize: 17)),
                    const SizedBox(height: 4),
                    Text(
                      lendo > 0 && pagsTot > 0
                          ? 'Você leu $pagsLidas de $pagsTot páginas atualmente'
                          : (lendo > 0
                              ? 'Informe o total de páginas para ver o progresso'
                              : 'Sem livros em andamento'),
                      style: tema.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Estatistica(
                  valor: '$total',
                  rotulo: 'Total',
                  cor: const Color(0xFF7C4DFF)),
              _Estatistica(
                  valor: '$queroLer',
                  rotulo: 'Quero ler',
                  cor: const Color(0xFF9090B0)),
              _Estatistica(
                  valor: '$lendo',
                  rotulo: 'Lendo',
                  cor: const Color(0xFF5E35B1)),
              _Estatistica(
                  valor: '$lidos',
                  rotulo: 'Lidos',
                  cor: const Color(0xFF2E7D32)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Estatistica extends StatelessWidget {
  final String valor;
  final String rotulo;
  final Color cor;
  const _Estatistica(
      {required this.valor, required this.rotulo, required this.cor});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(valor,
              style: tema.textTheme.titleLarge?.copyWith(
                    color: cor,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  )),
          const SizedBox(height: 2),
          Text(rotulo,
              style: tema.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tema.colorScheme.onSurface.withValues(alpha: 0.7),
                  )),
        ],
      ),
    );
  }
}

class _ListaLivros extends StatelessWidget {
  final List<dynamic> livros;
  final Widget widgetVazio;
  final void Function(Map) onAbrir;
  final void Function(Map, String) aoMudarStatus;
  final Widget Function(Map) builderBotoes;
  const _ListaLivros({
    required this.livros,
    required this.widgetVazio,
    required this.onAbrir,
    required this.aoMudarStatus,
    required this.builderBotoes,
  });

  @override
  Widget build(BuildContext context) {
    if (livros.isEmpty) {
      return LayoutBuilder(builder: (ctx, c) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            alignment: Alignment.center,
            child: widgetVazio,
          ),
        );
      });
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
      itemCount: livros.length,
      itemBuilder: (ctx, i) {
        final l = Map<String, dynamic>.from(livros[i] as Map);
        return _CardLivroLeitura(
          livro: l,
          onAbrir: () => onAbrir(l),
          aoMudarStatus: (novo) => aoMudarStatus(l, novo),
          botoesProgresso: builderBotoes(l),
        );
      },
    );
  }
}

class _CardLivroLeitura extends StatelessWidget {
  final Map livro;
  final VoidCallback onAbrir;
  final void Function(String) aoMudarStatus;
  final Widget botoesProgresso;

  const _CardLivroLeitura({
    required this.livro,
    required this.onAbrir,
    required this.aoMudarStatus,
    required this.botoesProgresso,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final escuro = tema.brightness == Brightness.dark;
    final info = InfoProgressoLivro.fromMap(livro);
    final sInfo = infoStatusLeitura(context, info.status);
    final temProgresso = info.totalPaginas != null && info.totalPaginas! > 0
        && info.status?.toUpperCase() == 'LENDO';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: escuro ? const Color(0xFF1C1C27) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: escuro ? const Color(0xFF2B2B38) : const Color(0xFFE7E7F1)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onAbrir,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 58,
                    height: 86,
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CapaLivro(livro: livro, heroTag: heroTagLivro(livro))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                livro['titulo']?.toString() ?? 'Sem título',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: tema.textTheme.titleLarge?.copyWith(fontSize: 16),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (temProgresso)
                              BarraProgressoCircular(
                                percentual: info.progresso,
                                tamanho: 40,
                                espessura: 3.4,
                                corPrimaria: sInfo.cor,
                                centro: Text(
                                  '${info.progresso.toStringAsFixed(info.progresso.truncate() == info.progresso ? 0 : 0)}%',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: sInfo.cor),
                                ),
                              )
                            else
                              ChipStatusLeitura(status: info.status, compacto: true),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          livro['autor']?.toString() ?? 'Autor desconhecido',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tema.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (livro['genero']?.toString().isNotEmpty == true)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C4DFF).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(livro['genero'].toString(),
                                    style: const TextStyle(
                                        color: Color(0xFF7C4DFF),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700)),
                              ),
                            if (info.paginasTexto.isNotEmpty)
                              Text(info.paginasTexto,
                                  style: tema.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF7C4DFF),
                                      )),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (temProgresso) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: (info.progresso / 100).clamp(0, 1),
                    minHeight: 6,
                    backgroundColor: sInfo.cor.withValues(alpha: 0.16),
                    valueColor: AlwaysStoppedAnimation<Color>(sInfo.cor),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              botoesProgresso,
              _BarraAcoesStatus(
                statusAtual: info.status?.toUpperCase(),
                aoMudar: aoMudarStatus,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotoesProgresso extends StatelessWidget {
  final Map livro;
  final VoidCallback onAvancar;
  final VoidCallback onRetroceder;
  final VoidCallback onConcluir;
  const _BotoesProgresso({
    required this.livro,
    required this.onAvancar,
    required this.onRetroceder,
    required this.onConcluir,
  });

  @override
  Widget build(BuildContext context) {
    final info = InfoProgressoLivro.fromMap(livro);
    final finalizado = (info.paginaAtual ?? 0) >= (info.totalPaginas ?? 0)
        && info.totalPaginas != null && info.totalPaginas! > 0;
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Página anterior',
          onPressed: (info.paginaAtual ?? 0) > 0 ? onRetroceder : null,
          icon: const Icon(Icons.remove_rounded),
          style: IconButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF).withValues(alpha: 0.1)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: finalizado ? onConcluir : onAvancar,
            style: ElevatedButton.styleFrom(
              backgroundColor: finalizado ? const Color(0xFF2E7D32) : const Color(0xFF7C4DFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(finalizado ? Icons.check_rounded : Icons.add_rounded),
            label: Text(
              finalizado ? 'Marcar como concluído' : '+1 página',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _BarraAcoesStatus extends StatelessWidget {
  final String? statusAtual;
  final void Function(String) aoMudar;
  const _BarraAcoesStatus({required this.statusAtual, required this.aoMudar});

  @override
  Widget build(BuildContext context) {
    const opcoes = [
      ('QUERO_LER', 'Quero ler', Icons.bookmark_border_rounded),
      ('LENDO', 'Começar a ler', Icons.play_arrow_rounded),
      ('LIDO', 'Marcar lido', Icons.check_circle_outline_rounded),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: opcoes
            .where((o) => o.$1 != statusAtual)
            .map((o) => ActionChip(
                  label: Text(o.$2),
                  avatar: Icon(o.$3, size: 16),
                  onPressed: () => aoMudar(o.$1),
                  visualDensity: VisualDensity.compact,
                ))
            .toList(growable: false),
      ),
    );
  }
}
