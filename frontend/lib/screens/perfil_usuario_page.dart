import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/screens/detalhe_livro_page.dart';
import 'package:frontend/screens/seguindo_seguidores_page.dart';
import 'package:frontend/widgets/estrelas_avaliacao.dart';
import 'package:frontend/utils/formatters.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:typed_data';

class PerfilUsuarioPage extends StatefulWidget {
  final int usuarioId;
  final String? apelido;

  const PerfilUsuarioPage({super.key, required this.usuarioId, this.apelido});

  @override
  State<PerfilUsuarioPage> createState() => _PerfilUsuarioPageState();
}

class _PerfilUsuarioPageState extends State<PerfilUsuarioPage> {
  final ScrollController _scrollController = ScrollController();
  Map<String, dynamic>? _perfil;
  bool _carregandoPerfil = true;
  bool _erroPerfil = false;

  final List<Map<String, dynamic>> _avaliacoes = [];
  int _paginaAtual = 0;
  bool _ultimaPagina = false;
  bool _carregandoAvaliacoes = true;
  bool _carregandoMaisAvaliacoes = false;
  bool _erroAvaliacoes = false;
  bool _alterandoSeguir = false;
  static const int _tamPagina = 20;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 300 &&
          !_carregandoMaisAvaliacoes && !_ultimaPagina && !_erroAvaliacoes) {
        _carregarMaisAvaliacoes();
      }
    });
    _carregarPerfil();
    _carregarAvaliacoes();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _carregarPerfil() async {
    if (!mounted) return;
    setState(() {
      _carregandoPerfil = true;
      _erroPerfil = false;
    });
    try {
      final r = await AuthService.get('/usuarios/${widget.usuarioId}');
      if (r.statusCode == 200) {
        final body = jsonDecode(utf8.decode(r.bodyBytes));
        if (body is Map<String, dynamic>) {
          if (mounted) setState(() {
            _perfil = body;
            _carregandoPerfil = false;
          });
          return;
        }
      }
      if (mounted) setState(() {
        _erroPerfil = true;
        _carregandoPerfil = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _erroPerfil = true;
        _carregandoPerfil = false;
      });
    }
  }

  Future<void> _carregarAvaliacoes({bool resetar = true}) async {
    if (resetar) {
      if (mounted) setState(() {
        _carregandoAvaliacoes = true;
        _erroAvaliacoes = false;
      });
      _paginaAtual = 0;
      _ultimaPagina = false;
    }
    try {
      final pagina = resetar ? 0 : _paginaAtual + 1;
      final r = await AuthService.get(
        '/usuarios/${widget.usuarioId}/avaliacoes?page=$pagina&size=$_tamPagina',
      );
      if (r.statusCode == 200) {
        final body = jsonDecode(utf8.decode(r.bodyBytes));
        if (body is Map<String, dynamic>) {
          final itens = body['itens'];
          final ultima = body['ultima'] == true;
          if (resetar) _avaliacoes.clear();
          if (itens is List) {
            _avaliacoes.addAll(List<Map<String, dynamic>>.from(
                itens.whereType<Map<String, dynamic>>()));
          }
          _paginaAtual = pagina;
          _ultimaPagina = ultima;
          if (mounted) setState(() {
            _erroAvaliacoes = false;
            if (resetar) _carregandoAvaliacoes = false;
          });
          return;
        }
      }
      if (mounted) setState(() {
        _erroAvaliacoes = true;
        if (resetar) _carregandoAvaliacoes = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _erroAvaliacoes = true;
        if (resetar) _carregandoAvaliacoes = false;
      });
    }
  }

  Future<void> _carregarMaisAvaliacoes() async {
    if (_carregandoAvaliacoes || _carregandoMaisAvaliacoes || _ultimaPagina || _erroAvaliacoes) return;
    setState(() => _carregandoMaisAvaliacoes = true);
    await _carregarAvaliacoes(resetar: false);
    if (mounted) setState(() => _carregandoMaisAvaliacoes = false);
  }

  String _formatarNumero(num valor) {
    if (valor >= 1000000) {
      return '${(valor / 1000000).toStringAsFixed(1)}M';
    }
    if (valor >= 1000) {
      return '${(valor / 1000).toStringAsFixed(1)}k';
    }
    return valor.toString();
  }

  Future<void> _toggleSeguir() async {
    if (_perfil == null || _alterandoSeguir) return;
    final estouSeguindo = _perfil!['estouSeguindo'] == true;
    if (!mounted) return;
    setState(() => _alterandoSeguir = true);
    try {
      final response = estouSeguindo
          ? await AuthService.delete('/usuarios/${widget.usuarioId}/seguir')
          : await AuthService.post('/usuarios/${widget.usuarioId}/seguir', null);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted && _perfil != null) {
          setState(() {
            _perfil!['estouSeguindo'] = !estouSeguindo;
            if (body is Map<String, dynamic>) {
              final novoTotal = body['totalSeguidores'];
              if (novoTotal is int) _perfil!['totalSeguidores'] = novoTotal;
            }
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(estouSeguindo
                    ? 'Erro ao deixar de seguir.'
                    : 'Erro ao seguir.'),
                backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Verifique sua conexão.'),
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _alterandoSeguir = false);
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

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final corPrimaria = const Color(0xFF7C4DFF);
    final souEu = _perfil?['souEu'] == true;
    final nome = _perfil?['nome']?.toString() ?? widget.apelido ?? 'Usuário';

    return Scaffold(
      backgroundColor: tema.colorScheme.inversePrimary.withValues(alpha: 0.10),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: corPrimaria,
        title: Text(
          souEu ? 'Meu perfil' : 'Perfil',
          style: tema.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: corPrimaria,
              ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        color: corPrimaria,
        onRefresh: () async {
          await Future.wait([_carregarPerfil(), _carregarAvaliacoes()]);
        },
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            _buildHeaderPerfil(tema, corPrimaria, souEu, nome),
            const SizedBox(height: 20),
            _buildSecaoAvaliacoes(tema, corPrimaria),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderPerfil(ThemeData tema, Color corPrimaria, bool souEu, String nome) {
    final foto = _perfil?['fotoPerfil']?.toString();
    final bio = _perfil?['bio']?.toString();
    final dataCriacao = _perfil?['dataCriacao']?.toString();
    final totalLivros = _perfil?['totalLivros'] as int? ?? 0;
    final totalAvaliacoes = _perfil?['totalAvaliacoes'] as int? ?? 0;
    final media = _perfil?['mediaAvaliacoes'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tema.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE9E6F2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _carregandoPerfil
              ? const SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(color: Color(0xFF7C4DFF)),
                )
              : _erroPerfil
                  ? _buildErroMinicard(tema, corPrimaria)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: corPrimaria.withValues(alpha: 0.30),
                              width: 3.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: corPrimaria.withValues(alpha: 0.22),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: corPrimaria.withValues(alpha: 0.10),
                            backgroundImage: (foto != null &&
                                    foto.isNotEmpty &&
                                    foto.startsWith('http'))
                                ? NetworkImage(foto)
                                : null,
                            child: (foto == null ||
                                    foto.isEmpty ||
                                    !foto.startsWith('http'))
                                ? Text(
                                    nome.isNotEmpty ? nome[0].toUpperCase() : '?',
                                    style: TextStyle(
                                      color: corPrimaria,
                                      fontSize: 36,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          nome,
                          style: tema.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF2A2A38),
                              ),
                        ),
                        if (souEu) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: corPrimaria.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('é você',
                                style: TextStyle(
                                    color: corPrimaria,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12)),
                          ),
                        ],
                        if (bio != null && bio.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            bio.trim(),
                            textAlign: TextAlign.center,
                            style: tema.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF5C5C70),
                                  height: 1.4,
                                ),
                          ),
                        ],
                        if (dataCriacao != null && dataCriacao.length >= 10) ...[
                          const SizedBox(height: 10),
                          Text(
                            '📅 Entrou em ${formatarData(parseDataISO(dataCriacao.substring(0, 10)))}',
                            style: const TextStyle(
                              color: Color(0xFF8A8A9D),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            _buildContador(
                              tema,
                              corPrimaria,
                              _formatarNumero(totalLivros),
                              'Livros',
                              Icons.menu_book_rounded,
                              onTap: null,
                            ),
                            _buildDivisorVertical(),
                            _buildContador(
                              tema,
                              corPrimaria,
                              _formatarNumero(totalAvaliacoes),
                              'Avaliações',
                              Icons.star_rate_rounded,
                              onTap: null,
                            ),
                            _buildDivisorVertical(),
                            _buildContador(
                              tema,
                              corPrimaria,
                              _formatarNumero((_perfil?['totalSeguidores'] ?? 0) as num),
                              'Seguidores',
                              Icons.people_alt_rounded,
                              onTap: () => _abrirListaRelacionamentos('seguidores'),
                            ),
                            _buildDivisorVertical(),
                            _buildContador(
                              tema,
                              corPrimaria,
                              _formatarNumero((_perfil?['totalSeguindo'] ?? 0) as num),
                              'Seguindo',
                              Icons.person_add_alt_rounded,
                              onTap: () => _abrirListaRelacionamentos('seguindo'),
                            ),
                            _buildDivisorVertical(),
                            _buildContador(
                              tema,
                              corPrimaria,
                              (media is num)
                                  ? (media as num).toStringAsFixed(1)
                                  : '-',
                              'Média',
                              Icons.insights_rounded,
                              onTap: null,
                            ),
                          ],
                        ),
                        if (!souEu) ...[
                          const SizedBox(height: 16),
                          _buildBotaoSeguir(tema, corPrimaria),
                        ],
                      ],
                    ),
        ],
      ),
    );
  }

  Widget _buildErroMinicard(ThemeData tema, Color corPrimaria) {
    return Column(
      children: [
        const SizedBox(height: 30),
        Icon(Icons.cloud_off_rounded, size: 42, color: corPrimaria.withValues(alpha: 0.6)),
        const SizedBox(height: 6),
        Text('Não carregou', style: tema.textTheme.bodyMedium),
        TextButton.icon(
          onPressed: _carregarPerfil,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Tentar novamente'),
        ),
      ],
    );
  }

  Widget _buildContador(ThemeData tema, Color corPrimaria, String valor, String rotulo, IconData icone, {VoidCallback? onTap}) {
    final child = Expanded(
      child: Column(
        children: [
          Icon(icone, size: 19, color: corPrimaria),
          const SizedBox(height: 3),
          Text(
            valor,
            style: tema.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF2A2A38),
                  letterSpacing: -0.2,
                  fontSize: 16,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            rotulo,
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFF8A8A9D),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Column(
            children: [
              Icon(icone, size: 19, color: corPrimaria),
              const SizedBox(height: 3),
              Text(
                valor,
                style: tema.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF2A2A38),
                      letterSpacing: -0.2,
                      fontSize: 16,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                rotulo,
                style: TextStyle(
                  fontSize: 10.5,
                  color: corPrimaria,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _abrirListaRelacionamentos(String tipo) async {
    final perfilNome = _perfil?['nome']?.toString();
    final id = widget.usuarioId;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SeguindoSeguidoresPage(
          usuarioId: id,
          apelido: perfilNome,
          abaInicial: tipo,
        ),
      ),
    );
    // Ao voltar, atualiza contadores caso tenha seguido/desseguido alguém
    _carregarPerfil();
  }

  Widget _buildBotaoSeguir(ThemeData tema, Color corPrimaria) {
    final estouSeguindo = _perfil?['estouSeguindo'] == true;
    final segueVoce = _perfil?['segueVoce'] == true;
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: _alterandoSeguir
          ? const Center(
              child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Color(0xFF7C4DFF))),
            )
          : estouSeguindo
              ? OutlinedButton.icon(
                  onPressed: _toggleSeguir,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: corPrimaria, width: 1.4),
                    foregroundColor: corPrimaria,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Seguindo',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14)),
                      if (segueVoce) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: corPrimaria.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Segue você',
                              style: TextStyle(
                                  color: corPrimaria,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ],
                  ),
                )
              : FilledButton.icon(
                  onPressed: _toggleSeguir,
                  style: FilledButton.styleFrom(
                    backgroundColor: corPrimaria,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: Text('Seguir',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, letterSpacing: 0.2)),
                ),
    );
  }

  Widget _buildDivisorVertical() {
    return Container(
      height: 44,
      width: 1,
      color: const Color(0xFFE9E6F2),
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildSecaoAvaliacoes(ThemeData tema, Color corPrimaria) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tema.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE9E6F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
            child: Row(
              children: [
                Icon(Icons.rate_review_rounded, size: 20, color: corPrimaria),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Avaliações publicadas',
                    style: tema.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF2A2A38),
                        ),
                  ),
                ),
                if (_perfil?['totalAvaliacoes'] != null)
                  Text(
                    '${_perfil!['totalAvaliacoes']}',
                    style: TextStyle(
                      color: corPrimaria,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 10),
          _buildListaAvaliacoes(tema, corPrimaria),
        ],
      ),
    );
  }

  Widget _buildListaAvaliacoes(ThemeData tema, Color corPrimaria) {
    if (_carregandoAvaliacoes) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: Color(0xFF7C4DFF))),
      );
    }
    if (_erroAvaliacoes) {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: Color(0xFF8A8A9D)),
            const SizedBox(height: 8),
            const Text('Não foi possível carregar as avaliações.'),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _carregarAvaliacoes,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }
    if (_avaliacoes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(Icons.post_add_rounded, size: 42, color: corPrimaria.withValues(alpha: 0.6)),
            const SizedBox(height: 8),
            Text(
              '${_perfil?['nome']?.toString() ?? 'Este usuário'} ainda não publicou avaliações.',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B6B80)),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_avaliacoes.length + (_ultimaPagina ? 0 : 1), (index) {
        if (index >= _avaliacoes.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: _carregandoMaisAvaliacoes
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF7C4DFF)))
                  : null,
            ),
          );
        }
        final item = _avaliacoes[index];
        if (index > 0) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(height: 1, color: Color(0xFFF0EDFA)),
              const SizedBox(height: 12),
              _buildCardAvaliacao(item, tema, corPrimaria),
              const SizedBox(height: 12),
            ],
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildCardAvaliacao(item, tema, corPrimaria),
        );
      }),
    );
  }

  Widget _buildCardAvaliacao(Map<String, dynamic> item, ThemeData tema, Color corPrimaria) {
    final livroTitulo = item['livroTitulo']?.toString() ?? 'Livro sem título';
    final livroAutor = item['livroAutor']?.toString() ?? 'Autor desconhecido';
    final livroCapa = item['livroCapa']?.toString();
    final livroGenero = item['livroGenero']?.toString();
    final nota = item['nota'] is int ? item['nota'] as int : 0;
    final comentario = item['comentario']?.toString();
    final dataPub = item['dataCriacao']?.toString();
    final dataFormatada = dataPub != null && dataPub.length >= 10
        ? formatarData(parseDataISO(dataPub.substring(0, 10)))
        : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _abrirLivro(item),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F5FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE9E6F2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 62,
                height: 92,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _construirMiniCapa(livroCapa, livroTitulo, tema),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      livroTitulo,
                      style: tema.textTheme.titleSmall?.copyWith(
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        EstrelasAvaliacao(
                          avaliacao: nota == 0 ? null : nota,
                          tamanho: 13,
                        ),
                        const SizedBox(width: 6),
                        if (dataFormatada != null)
                          Expanded(
                            child: Text(
                              dataFormatada,
                              style: const TextStyle(color: Color(0xFF8A8A9D), fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                    if (livroGenero != null && livroGenero.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: corPrimaria.withValues(alpha: 0.22)),
                        ),
                        child: Text(
                          livroGenero,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: corPrimaria,
                          ),
                        ),
                      ),
                    ],
                    if (comentario != null && comentario.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE9E6F2)),
                        ),
                        child: Text(
                          comentario,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: tema.textTheme.bodySmall?.copyWith(height: 1.35),
                        ),
                      ),
                    ],
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _abrirLivro(item),
                        style: TextButton.styleFrom(
                          foregroundColor: corPrimaria,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 13),
                        label: const Text('Abrir livro',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirMiniCapa(String? capa, String titulo, ThemeData tema) {
    final corPrimaria = const Color(0xFF7C4DFF);
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
              errorBuilder: (_, e, s) => _placeholderMiniCapa(titulo, tema, corPrimaria));
        } catch (_) {
          return _placeholderMiniCapa(titulo, tema, corPrimaria);
        }
      }
      return CachedNetworkImage(
        imageUrl: c,
        fit: BoxFit.cover,
        placeholder: (ctx, url) => _placeholderMiniCapa(titulo, tema, corPrimaria),
        errorWidget: (ctx, url, err) => _placeholderMiniCapa(titulo, tema, corPrimaria),
      );
    }
    return _placeholderMiniCapa(titulo, tema, corPrimaria);
  }

  Widget _placeholderMiniCapa(String titulo, ThemeData tema, Color corPrimaria) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: corPrimaria.withValues(alpha: 0.12),
      padding: const EdgeInsets.all(5),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_rounded, size: 22, color: corPrimaria),
          const SizedBox(height: 2),
          Text(
            titulo,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: tema.textTheme.bodySmall?.copyWith(
                  color: corPrimaria,
                  fontWeight: FontWeight.w800,
                  fontSize: 9,
                  height: 1.1,
                ),
          ),
        ],
      ),
    );
  }
}
