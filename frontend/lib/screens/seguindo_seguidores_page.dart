import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/screens/perfil_usuario_page.dart';
import 'package:frontend/widgets/empty_state.dart';
import '../widgets/skeletons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:typed_data';

class SeguindoSeguidoresPage extends StatefulWidget {
  final int usuarioId;
  final String? apelido;
  final String abaInicial;

  const SeguindoSeguidoresPage({
    super.key,
    required this.usuarioId,
    this.apelido,
    this.abaInicial = 'seguidores',
  });

  @override
  State<SeguindoSeguidoresPage> createState() => _SeguindoSeguidoresPageState();
}

class _SeguindoSeguidoresPageState extends State<SeguindoSeguidoresPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.abaInicial == 'seguindo' ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    const corPrimaria = Color(0xFF7C4DFF);
    final nomeExibicao = widget.apelido?.trim().isNotEmpty == true
        ? widget.apelido!
        : 'Usuário';
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FB),
      appBar: AppBar(
        backgroundColor: tema.colorScheme.inversePrimary,
        title: Text(
          nomeExibicao,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
            fontSize: 18,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: corPrimaria,
          unselectedLabelColor: const Color(0xFF6B6B80),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13.5,
            letterSpacing: 0.2,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
          indicatorSize: TabBarIndicatorSize.label,
          indicatorColor: corPrimaria,
          indicatorWeight: 2.5,
          dividerColor: const Color(0xFFE9E6F2),
          tabs: const [
            Tab(text: 'Seguidores'),
            Tab(text: 'Seguindo'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ListaRelacionamento(
            usuarioId: widget.usuarioId,
            tipo: 'seguidores',
          ),
          _ListaRelacionamento(
            usuarioId: widget.usuarioId,
            tipo: 'seguindo',
          ),
        ],
      ),
    );
  }
}

class _ListaRelacionamento extends StatefulWidget {
  final int usuarioId;
  final String tipo;

  const _ListaRelacionamento({
    required this.usuarioId,
    required this.tipo,
  });

  @override
  State<_ListaRelacionamento> createState() => _ListaRelacionamentoState();
}

class _ListaRelacionamentoState extends State<_ListaRelacionamento>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _itens = [];
  int _paginaAtual = 0;
  bool _ultimaPagina = false;
  bool _carregando = true;
  bool _carregandoMais = false;
  bool _erro = false;
  final Set<int> _idsAlterando = <int>{};
  static const int _tamPagina = 20;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 300 &&
          !_carregandoMais &&
          !_ultimaPagina &&
          !_erro) {
        _carregarMais();
      }
    });
    _carregarTudo();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _formatarNumero(num valor) {
    if (valor >= 1000000) return '${(valor / 1e6).toStringAsFixed(1)}M';
    if (valor >= 1000) return '${(valor / 1e3).toStringAsFixed(1)}k';
    return valor.toString();
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
    if (_carregandoMais || _ultimaPagina || _erro) return;
    if (!mounted) return;
    setState(() => _carregandoMais = true);
    await _carregarPagina(_paginaAtual + 1);
    if (mounted) setState(() => _carregandoMais = false);
  }

  Future<void> _carregarPagina(int pagina, {bool resetar = false}) async {
    try {
      final endpoint = widget.tipo == 'seguindo' ? 'seguindo' : 'seguidores';
      final response = await AuthService.get(
        '/usuarios/${widget.usuarioId}/$endpoint?page=$pagina&size=$_tamPagina',
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

  Future<void> _toggleSeguir(Map<String, dynamic> usuario) async {
    final userId = usuario['id'] as int?;
    if (userId == null) return;
    if (_idsAlterando.contains(userId)) return;
    final estouSeguindo = usuario['estouSeguindo'] == true;
    if (!mounted) return;
    setState(() => _idsAlterando.add(userId));
    try {
      final response = estouSeguindo
          ? await AuthService.delete('/usuarios/$userId/seguir')
          : await AuthService.post('/usuarios/$userId/seguir', null);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          final idx = _itens.indexWhere((u) => u['id'] == userId);
          if (idx != -1) {
            setState(() {
              _itens[idx]['estouSeguindo'] = !estouSeguindo;
              final ts = _itens[idx]['totalSeguidores'];
              if (ts is int) {
                _itens[idx]['totalSeguidores'] = estouSeguindo ? ts - 1 : ts + 1;
              }
            });
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não foi possível alterar. Tente novamente.'),
              backgroundColor: Color(0xFFE53935),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verifique sua conexão com a internet.'),
            backgroundColor: Color(0xFFE53935),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _idsAlterando.remove(userId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tema = Theme.of(context);
    const corPrimaria = Color(0xFF7C4DFF);

    if (_carregando) {
      return Scaffold(
        appBar: AppBar(title: const Text('')),
        body: SafeArea(
          child: ShimmerBase(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (_) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      const BlocoSkeleton(largura: 46, altura: 46, raio: 99),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const BlocoSkeleton(largura: 160, altura: 14, raio: 7),
                        const SizedBox(height: 6),
                        const BlocoSkeleton(largura: 90, altura: 12, raio: 6),
                      ])),
                      const BlocoSkeleton(largura: 80, altura: 32, raio: 99),
                    ],
                  ),
                )),
              ),
            ),
          ),
        ),
      );
    }

    if (_erro) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 44, color: Color(0xFF8A8A9D)),
            const SizedBox(height: 10),
            Text(
              'Não carregou',
              style: tema.textTheme.bodyMedium
                  ?.copyWith(color: const Color(0xFF6B6B80)),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: _carregarTudo,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (_itens.isEmpty) {
      return RefreshIndicator(
        color: corPrimaria,
        onRefresh: _carregarTudo,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: widget.tipo == 'seguindo'
                  ? const EmptyState(
                      icone: Icons.person_add_rounded,
                      titulo: "Ainda não segue ninguém",
                      descricao: "Siga autores e leitores para acompanhar suas avaliações e recomendações.",
                    )
                  : const EmptyState(
                      icone: Icons.people_outline_rounded,
                      titulo: "Sem seguidores ainda",
                      descricao: "Continue avaliando e compartilhando suas leituras para atrair seguidores!",
                    ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: corPrimaria,
      onRefresh: _carregarTudo,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
            sliver: SliverList.separated(
              itemCount: _itens.length + (_ultimaPagina ? 0 : 1),
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (_, index) {
                if (index >= _itens.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: _carregandoMais
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: corPrimaria,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  );
                }
                final item = _itens[index];
                return _linhaUsuario(item, tema, corPrimaria);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _linhaUsuario(
      Map<String, dynamic> usuario, ThemeData tema, Color corPrimaria) {
    final userId = usuario['id'] as int?;
    final nome = usuario['nome']?.toString() ?? 'Usuário';
    final bio = usuario['bio']?.toString();
    final foto = usuario['fotoPerfil']?.toString();
    final estouSeguindo = usuario['estouSeguindo'] == true;
    final segueVoce = usuario['segueVoce'] == true;
    final souEu = usuario['souEu'] == true;
    final totalSeguidores = usuario['totalSeguidores'] as int? ?? 0;
    final totalSeguindo = usuario['totalSeguindo'] as int? ?? 0;
    final alterando = userId != null && _idsAlterando.contains(userId);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFEBFA), width: 0.8),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _abrirPerfil(usuario),
              borderRadius: BorderRadius.circular(999),
              child: _avatar(foto, nome, 44),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _abrirPerfil(usuario),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              nome,
                              overflow: TextOverflow.ellipsis,
                              style: tema.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF2A2A38),
                                  ),
                            ),
                          ),
                          if (segueVoce && !souEu) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: corPrimaria.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Segue você',
                                style: TextStyle(
                                  color: corPrimaria,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (bio != null && bio.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          bio,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B6B80),
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${_formatarNumero(totalSeguidores)} seg.',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF8A8A9D),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_formatarNumero(totalSeguindo)} seguindo',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF8A8A9D),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!souEu) ...[
            const SizedBox(width: 8),
            SizedBox(
              height: 34,
              child: alterando
                  ? Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: corPrimaria,
                        ),
                      ),
                    )
                  : estouSeguindo
                      ? OutlinedButton(
                          onPressed: () => _toggleSeguir(usuario),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 0),
                            side: BorderSide(
                                color: corPrimaria.withValues(alpha: 0.8),
                                width: 1.2),
                            foregroundColor: corPrimaria,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Seguindo',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                        )
                      : FilledButton(
                          onPressed: () => _toggleSeguir(usuario),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 0),
                            backgroundColor: corPrimaria,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Seguir',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                        ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _avatar(String? foto, String nome, double tamanho) {
    Widget placeholder = Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB39DDB), Color(0xFF7C4DFF)],
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        nome.isNotEmpty ? nome[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: tamanho * 0.42,
          letterSpacing: 0.2,
        ),
      ),
    );

    if (foto == null || foto.trim().isEmpty) return placeholder;

    Uint8List? bytes;
    try {
      if (foto.startsWith('data:')) {
        final base64Str = foto.contains(',') ? foto.split(',')[1] : '';
        if (base64Str.isNotEmpty) bytes = base64Decode(base64Str);
      }
    } catch (_) {
      bytes = null;
    }

    if (bytes != null) {
      return Container(
        width: tamanho,
        height: tamanho,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          image: DecorationImage(
            image: MemoryImage(bytes),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    if (foto.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: CachedNetworkImage(
          imageUrl: foto,
          width: tamanho,
          height: tamanho,
          fit: BoxFit.cover,
          placeholder: (_, __) => placeholder,
          errorWidget: (_, __, ___) => placeholder,
        ),
      );
    }

    return placeholder;
  }

  Future<void> _abrirPerfil(Map<String, dynamic> usuario) async {
    final userId = usuario['id'];
    if (userId == null) return;
    final id = userId is int ? userId : int.tryParse(userId.toString());
    if (id == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PerfilUsuarioPage(
          usuarioId: id,
          apelido: usuario['nome']?.toString(),
        ),
      ),
    );
    _carregarTudo();
  }
}
