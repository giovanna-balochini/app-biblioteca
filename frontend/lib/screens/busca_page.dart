import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../widgets/empty_state.dart';
import '../utils/snackbars.dart';
import '../utils/transitions.dart';
import 'perfil_usuario_page.dart';
import 'detalhe_livro_page.dart';

class BuscaPage extends StatefulWidget {
  const BuscaPage({super.key});

  @override
  State<BuscaPage> createState() => _BuscaPageState();
}

class _BuscaPageState extends State<BuscaPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  DateTime? _ultimaBuscaEm;
  bool _primeiraVez = true;

  // Aba 0: Pessoas
  final List<Map<String, dynamic>> _pessoas = [];
  int _paginaPessoas = 0;
  bool _carregandoPessoas = false;
  bool _ultimaPaginaPessoas = false;
  final ScrollController _scrollPessoas = ScrollController();

  // Aba 1: Livros
  final List<Map<String, dynamic>> _livros = [];
  int _paginaLivros = 0;
  bool _carregandoLivros = false;
  bool _ultimaPaginaLivros = false;
  final ScrollController _scrollLivros = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_aoMudarAba);
    _searchController.addListener(_aoDigitar);
    _scrollPessoas.addListener(_aoRolarPessoas);
    _scrollLivros.addListener(_aoRolarLivros);
    WidgetsBinding.instance.addPostFrameCallback((_) => _buscarPessoas(resetar: true));
  }

  @override
  void dispose() {
    _tabController.removeListener(_aoMudarAba);
    _tabController.dispose();
    _searchController.removeListener(_aoDigitar);
    _searchController.dispose();
    _scrollPessoas.removeListener(_aoRolarPessoas);
    _scrollPessoas.dispose();
    _scrollLivros.removeListener(_aoRolarLivros);
    _scrollLivros.dispose();
    super.dispose();
  }

  void _aoMudarAba() {
    if (_tabController.indexIsChanging) return;
    if (_primeiraVez && _tabController.index == 1 && _livros.isEmpty) {
      _primeiraVez = false;
      _buscarLivros(resetar: true);
    }
  }

  void _aoDigitar() {
    final agora = DateTime.now();
    final ultima = _ultimaBuscaEm;
    if (ultima != null && agora.difference(ultima).inMilliseconds < 450) return;
    Future.delayed(const Duration(milliseconds: 480), () {
      final t = _searchController.text.trim();
      if (t != _query) {
        _query = t;
        _resetarTudo();
      }
    });
    _ultimaBuscaEm = agora;
  }

  void _resetarTudo() {
    setState(() {
      _pessoas.clear();
      _livros.clear();
      _paginaPessoas = 0;
      _paginaLivros = 0;
      _ultimaPaginaPessoas = false;
      _ultimaPaginaLivros = false;
    });
    _buscarPessoas(resetar: true);
    if (_tabController.index == 1 || !_primeiraVez) {
      _buscarLivros(resetar: true);
    }
  }

  void _aoRolarPessoas() {
    if (_scrollPessoas.position.pixels + 300 >= _scrollPessoas.position.maxScrollExtent &&
        !_carregandoPessoas &&
        !_ultimaPaginaPessoas) {
      _buscarPessoas();
    }
  }

  void _aoRolarLivros() {
    if (_scrollLivros.position.pixels + 300 >= _scrollLivros.position.maxScrollExtent &&
        !_carregandoLivros &&
        !_ultimaPaginaLivros) {
      _buscarLivros();
    }
  }

  Future<void> _buscarPessoas({bool resetar = false}) async {
    if (!mounted) return;
    if (resetar) _paginaPessoas = 0;
    setState(() => _carregandoPessoas = true);
    try {
      final res = await AuthService.get(
          '/usuarios/buscar?q=${Uri.encodeComponent(_query)}&page=$_paginaPessoas&size=20');
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final List itens = (data['itens'] as List?) ?? [];
        final ultima = data['ultima'] == true;
        setState(() {
          if (resetar) _pessoas.clear();
          for (final i in itens) {
            _pessoas.add(Map<String, dynamic>.from(i as Map));
          }
          _ultimaPaginaPessoas = ultima;
          if (!ultima) _paginaPessoas++;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _carregandoPessoas = false);
  }

  Future<void> _buscarLivros({bool resetar = false}) async {
    if (!mounted) return;
    if (resetar) _paginaLivros = 0;
    setState(() => _carregandoLivros = true);
    try {
      final res = await AuthService.get(
          '/livros/buscar?q=${Uri.encodeComponent(_query)}&page=$_paginaLivros&size=20');
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final List itens = (data['itens'] as List?) ?? [];
        final ultima = data['ultima'] == true;
        setState(() {
          if (resetar) _livros.clear();
          for (final i in itens) {
            _livros.add(Map<String, dynamic>.from(i as Map));
          }
          _ultimaPaginaLivros = ultima;
          if (!ultima) _paginaLivros++;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _carregandoLivros = false);
  }

  @override
  Widget build(BuildContext context) {
    final corPrimaria = const Color(0xFF7C4DFF);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Buscar'),
          titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: corPrimaria,
                letterSpacing: 0.2,
              ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(108),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Procurar pessoas, livros, autores...',
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF7C4DFF)),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              tooltip: 'Limpar',
                              icon: const Icon(Icons.close_rounded, color: Color(0xFF8A8A9D)),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _query = '';
                                  _resetarTudo();
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF8F5FF),
                      contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: corPrimaria.withValues(alpha: 0.3), width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: const Color(0xFFE0D7FF).withValues(alpha: 0.8), width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: corPrimaria, width: 1.3),
                      ),
                    ),
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  labelColor: corPrimaria,
                  unselectedLabelColor: const Color(0xFF6B6B80),
                  indicatorColor: corPrimaria,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: const Color(0xFFE9E6F2),
                  tabs: const [
                    Tab(text: '👥 Pessoas'),
                    Tab(text: '📚 Livros'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildAbaPessoas(),
            _buildAbaLivros(),
          ],
        ),
      ),
    );
  }

  Widget _buildAbaPessoas() {
    if (_pessoas.isEmpty && !_carregandoPessoas) {
      if (_query.isEmpty) {
        return const EmptyState(
          icone: Icons.search_rounded,
          titulo: "Digite para buscar livros, autores ou pessoas",
          descricao: "Comece digitando algo na barra de busca acima.",
        );
      }
      return const EmptyState(
        icone: Icons.search_off_rounded,
        titulo: "Nada encontrado por aqui",
        descricao: "Tente palavras diferentes ou navegue pelo feed para descobrir novos livros.",
      );
    }
    return RefreshIndicator(
      color: const Color(0xFF7C4DFF),
      onRefresh: () => _buscarPessoas(resetar: true),
      child: ListView.builder(
        controller: _scrollPessoas,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: _pessoas.length + 1,
        itemBuilder: (ctx, i) {
          if (i == _pessoas.length) {
            return _carregandoPessoas ? _loading() : (_ultimaPaginaPessoas ? _fim() : const SizedBox(height: 40));
          }
          return _CardPessoa(
            key: ValueKey('p-${_pessoas[i]['id']}'),
            pessoa: _pessoas[i],
            aoAbrirPerfil: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PerfilUsuarioPage(usuarioId: _pessoas[i]['id'] as int),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAbaLivros() {
    if (_livros.isEmpty && !_carregandoLivros) {
      if (_query.isEmpty) {
        return const EmptyState(
          icone: Icons.search_rounded,
          titulo: "Digite para buscar livros, autores ou pessoas",
          descricao: "Comece digitando algo na barra de busca acima.",
        );
      }
      return const EmptyState(
        icone: Icons.search_off_rounded,
        titulo: "Nada encontrado por aqui",
        descricao: "Tente palavras diferentes ou navegue pelo feed para descobrir novos livros.",
      );
    }
    return RefreshIndicator(
      color: const Color(0xFF7C4DFF),
      onRefresh: () => _buscarLivros(resetar: true),
      child: ListView.builder(
        controller: _scrollLivros,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: _livros.length + 1,
        itemBuilder: (ctx, i) {
          if (i == _livros.length) {
            return _carregandoLivros ? _loading() : (_ultimaPaginaLivros ? _fim() : const SizedBox(height: 40));
          }
          return _CardLivro(
            key: ValueKey('l-${_livros[i]['id']}'),
            livro: _livros[i],
            aoAbrir: () {
              final livroParam = <String, dynamic>{
                'id': _livros[i]['id'],
                'titulo': _livros[i]['titulo'],
                'autor': _livros[i]['autor'],
                'imagem': _livros[i]['imagem'],
              };
              navegarComAnimacao(
                context,
                DetalheLivroPage(
                  livro: livroParam is Map<String, dynamic> ? livroParam : Map<String, dynamic>.from(livroParam as Map),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _loading() => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF7C4DFF)))),
      );

  Widget _fim() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text('✨ fim dos resultados', style: TextStyle(color: Color(0xFF8A8A9D), fontSize: 12))),
      );

  Widget _vazio({required IconData icone, required String titulo, required String subtitulo}) {
    return LayoutBuilder(
      builder: (ctx, c) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: c.maxHeight,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icone, size: 58, color: const Color(0xFF7C4DFF).withValues(alpha: 0.7)),
                  const SizedBox(height: 16),
                  Text(titulo, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF2A2A38))),
                  const SizedBox(height: 6),
                  Text(subtitulo, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 13, height: 1.4)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardPessoa extends StatefulWidget {
  final Map<String, dynamic> pessoa;
  final VoidCallback aoAbrirPerfil;
  const _CardPessoa({super.key, required this.pessoa, required this.aoAbrirPerfil});

  @override
  State<_CardPessoa> createState() => _CardPessoaState();
}

class _CardPessoaState extends State<_CardPessoa> {
  bool _carregando = false;

  Future<void> _toggleSeguir() async {
    if (_carregando || (widget.pessoa['souEu'] == true)) return;
    final antes = widget.pessoa['estouSeguindo'] == true;
    final totalAntes = (widget.pessoa['totalSeguidores'] as num?)?.toInt() ?? 0;

    setState(() {
      _carregando = true;
      widget.pessoa['estouSeguindo'] = !antes;
      widget.pessoa['totalSeguidores'] = antes ? (totalAntes - 1).clamp(0, 1 << 30) : totalAntes + 1;
    });

    http.Response? res;
    try {
      res = antes
          ? await AuthService.delete('/usuarios/${widget.pessoa['id']}/seguir')
          : await AuthService.post('/usuarios/${widget.pessoa['id']}/seguir', null);
    } catch (_) {}

    final ok = res != null && (res.statusCode == 200 || res.statusCode == 201);
    if (!ok && mounted) {
      setState(() {
        widget.pessoa['estouSeguindo'] = antes;
        widget.pessoa['totalSeguidores'] = totalAntes;
      });
      mostrarSnackbarErro(context, 'Não foi possível ${antes ? 'desseguir' : 'seguir'} essa pessoa agora.');
    } else if (ok && mounted && !antes) {
      mostrarSnackbarSucesso(context, 'Agora você segue ${widget.pessoa['nome'] ?? 'essa pessoa'}');
    }
    if (mounted) setState(() => _carregando = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pessoa;
    final nome = p['nome']?.toString() ?? 'Usuário';
    final foto = p['fotoPerfil']?.toString();
    final totalLivros = (p['totalLivros'] as num?)?.toInt() ?? 0;
    final totalAvaliacoes = (p['totalAvaliacoes'] as num?)?.toInt() ?? 0;
    final media = p['mediaAvaliacoes'];
    final totalSeguidores = (p['totalSeguidores'] as num?)?.toInt() ?? 0;
    final estouSeguindo = p['estouSeguindo'] == true;
    final segueVoce = p['segueVoce'] == true;
    final souEu = p['souEu'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE9E6F2), width: 0.8),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.aoAbrirPerfil,
                borderRadius: BorderRadius.circular(26),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFF7C4DFF).withValues(alpha: 0.12),
                  backgroundImage: (foto != null && foto.isNotEmpty && foto.startsWith('http'))
                      ? NetworkImage(foto)
                      : null,
                  child: (foto == null || foto.isEmpty || !foto.startsWith('http'))
                      ? Text(
                          nome.isNotEmpty ? nome[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Color(0xFF7C4DFF),
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.aoAbrirPerfil,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                souEu ? '$nome (você)' : nome,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF2A2A38),
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (segueVoce && !souEu) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C4DFF).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'segue você',
                                  style: TextStyle(color: Color(0xFF7C4DFF), fontWeight: FontWeight.w700, fontSize: 10.5),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 10,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text('$totalLivros livro${totalLivros == 1 ? '' : 's'}', style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 12)),
                            Text('$totalAvaliacoes aval${totalAvaliacoes == 1 ? '.' : '.'}', style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 12)),
                            if (media != null) Text('⭐ ${media.toString()}', style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 12)),
                            Text('$totalSeguidores seguidor${totalSeguidores == 1 ? '' : 'es'}', style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 36,
              child: souEu
                  ? const SizedBox.shrink()
                  : OutlinedButton.icon(
                      onPressed: _carregando ? null : _toggleSeguir,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        foregroundColor: estouSeguindo ? const Color(0xFF6B6B80) : const Color(0xFF7C4DFF),
                        side: BorderSide(
                          color: estouSeguindo ? const Color(0xFFD9D5E5) : const Color(0xFF7C4DFF),
                          width: 1.2,
                        ),
                        backgroundColor: estouSeguindo ? Colors.transparent : const Color(0xFF7C4DFF).withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _carregando
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF7C4DFF)))
                          : Icon(estouSeguindo ? Icons.person_remove_outlined : Icons.person_add_alt_rounded, size: 15),
                      label: Text(
                        estouSeguindo ? 'Seguindo' : 'Seguir',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardLivro extends StatefulWidget {
  final Map<String, dynamic> livro;
  final VoidCallback aoAbrir;
  const _CardLivro({super.key, required this.livro, required this.aoAbrir});

  @override
  State<_CardLivro> createState() => _CardLivroState();
}

class _CardLivroState extends State<_CardLivro> {
  bool _carregando = false;

  Future<void> _adicionarNaMinhaBiblioteca() async {
    if (_carregando || (widget.livro['estaNaMinhaBiblioteca'] == true)) return;
    setState(() => _carregando = true);
    http.Response? res;
    try {
      res = await AuthService.post('/livros/${widget.livro['id']}/copiar-para-minha-biblioteca', null);
    } catch (_) {}
    if (!mounted) return;
    final ok = res != null && (res.statusCode == 200 || res.statusCode == 201);
    if (ok) {
      try {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data['ok'] == true) {
          setState(() => widget.livro['estaNaMinhaBiblioteca'] = true);
          mostrarSnackbarSucesso(context, 'Livro adicionado à sua biblioteca!');
        } else {
          final motivo = data['motivo']?.toString();
          if (motivo == 'ESSE_EH_SEU' || motivo == 'JA_TEM_NA_BIBLIOTECA') {
            setState(() => widget.livro['estaNaMinhaBiblioteca'] = true);
          }
          mostrarSnackbarAviso(context, data['mensagem']?.toString() ?? 'Livro já adicionado.');
        }
      } catch (_) {}
    } else {
      mostrarSnackbarErro(context, 'Não foi possível adicionar agora.');
    }
    if (mounted) setState(() => _carregando = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.livro;
    final titulo = l['titulo']?.toString() ?? 'Livro sem título';
    final autor = l['autor']?.toString() ?? 'Autor desconhecido';
    final genero = l['genero']?.toString();
    final totalAv = (l['totalAvaliacoesPublicas'] as num?)?.toInt() ?? 0;
    final media = l['mediaAvaliacoes'];
    final jaTenho = l['estaNaMinhaBiblioteca'] == true;
    final donoNome = l['donoNome']?.toString();
    final donoFoto = l['donoFotoPerfil']?.toString();
    final donoId = l['donoId'];
    final imagem = l['imagem']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE9E6F2), width: 0.8),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.aoAbrir,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 52,
                  height: 76,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F5FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE0D7FF), width: 0.8),
                    image: (imagem != null && imagem.isNotEmpty && imagem.startsWith('http'))
                        ? DecorationImage(fit: BoxFit.cover, image: NetworkImage(imagem))
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: (imagem == null || imagem.isEmpty || !imagem.startsWith('http'))
                      ? const Icon(Icons.menu_book_rounded, color: Color(0xFF7C4DFF), size: 26)
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.aoAbrir,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF2A2A38),
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              autor,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                            if (genero != null && genero.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7C4DFF).withValues(alpha: 0.09),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      genero,
                                      style: const TextStyle(color: Color(0xFF7C4DFF), fontWeight: FontWeight.w700, fontSize: 11),
                                    ),
                                  ),
                                  if (totalAv > 0) ...[
                                    const SizedBox(width: 4),
                                    Text('$totalAv aval${totalAv == 1 ? '.' : '.'}', style: const TextStyle(color: Color(0xFF8A8A9D), fontSize: 11.5)),
                                  ],
                                  if (media != null) Text('⭐ ${media.toString()}', style: const TextStyle(color: Color(0xFF8A8A9D), fontSize: 11.5)),
                                ],
                              ),
                            ],
                            if (donoNome != null && donoNome.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    if (donoId != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => PerfilUsuarioPage(usuarioId: donoId as int)),
                                      );
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 10,
                                        backgroundColor: const Color(0xFF7C4DFF).withValues(alpha: 0.12),
                                        backgroundImage: (donoFoto != null && donoFoto.isNotEmpty && donoFoto.startsWith('http'))
                                            ? NetworkImage(donoFoto)
                                            : null,
                                        child: (donoFoto == null || donoFoto.isEmpty || !donoFoto.startsWith('http'))
                                            ? Text(
                                                donoNome.isNotEmpty ? donoNome[0].toUpperCase() : '?',
                                                style: const TextStyle(color: Color(0xFF7C4DFF), fontWeight: FontWeight.w800, fontSize: 10),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          donoNome,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Color(0xFF7C4DFF), fontWeight: FontWeight.w700, fontSize: 12, decoration: TextDecoration.underline),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: widget.aoAbrir,
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFF6B6B80), padding: const EdgeInsets.symmetric(horizontal: 8)),
                        icon: const Icon(Icons.open_in_new_outlined, size: 15),
                        label: const Text('Abrir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 2),
                      jaTenho
                          ? Container(
                              height: 34,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: const Color(0xFFE8FAF0),
                                border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.5), width: 1),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF2E7D32)),
                                  SizedBox(width: 5),
                                  Text(
                                    'Na sua biblioteca',
                                    style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w700, fontSize: 12),
                                  ),
                                ],
                              ),
                            )
                          : SizedBox(
                              height: 34,
                              child: OutlinedButton.icon(
                                onPressed: _carregando ? null : _adicionarNaMinhaBiblioteca,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF7C4DFF),
                                  side: const BorderSide(color: Color(0xFF7C4DFF), width: 1.2),
                                  backgroundColor: const Color(0xFF7C4DFF).withValues(alpha: 0.08),
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: _carregando
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF7C4DFF)))
                                    : const Icon(Icons.add_rounded, size: 15),
                                label: const Text('Adicionar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
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
    );
  }
}
