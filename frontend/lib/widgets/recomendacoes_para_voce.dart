import 'package:flutter/material.dart';
import 'package:frontend/services/recomendacoes_service.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/widgets/capa_livro.dart';
import 'package:frontend/widgets/skeletons.dart';
import 'package:frontend/widgets/estrelas_avaliacao.dart';
import 'package:frontend/screens/cadastro_livro_page.dart';
import 'package:frontend/utils/transitions.dart';
import 'package:frontend/utils/app_theme.dart';

class RecomendacoesParaVoce extends StatefulWidget {
  final int limite;
  const RecomendacoesParaVoce({super.key, this.limite = 8});

  @override
  State<RecomendacoesParaVoce> createState() => _RecomendacoesParaVoceState();
}

class _RecomendacoesParaVoceState extends State<RecomendacoesParaVoce> {
  bool _carregando = true;
  List<Map<String, dynamic>> _itens = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    if (!AuthService.estaLogado) {
      if (mounted) setState(() { _itens = []; _carregando = false; });
      return;
    }
    final lista = await RecomendacoesService.buscarParaMim(limite: widget.limite);
    if (mounted) setState(() { _itens = lista; _carregando = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.estaLogado) return const SizedBox.shrink();
    final tema = Theme.of(context);
    final cores = context.coresApp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cores.roxoPrimario.withValues(alpha: 0.14),
                ),
                child: Icon(Icons.auto_awesome_rounded, color: cores.roxoPrimario, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recomendados para você',
                      style: tema.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: cores.textoForte,
                            letterSpacing: -0.2,
                          ),
                    ),
                    Text(
                      _carregando
                          ? 'Calculando seus gostos...'
                          : _itens.isEmpty
                              ? 'Ainda sem sugestões personalizadas'
                              : 'Baseados em seus livros lidos e favoritos',
                      style: tema.textTheme.bodySmall?.copyWith(
                            color: cores.textoMedio,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
              if (!_carregando)
                IconButton(
                  splashRadius: 18,
                  visualDensity: VisualDensity.compact,
                  onPressed: _carregar,
                  icon: Icon(Icons.refresh_rounded, color: cores.textoMedio, size: 20),
                ),
            ],
          ),
        ),
        if (_carregando)
          SizedBox(
            height: 278,
            child: _SkeletonRecomendacoes(),
          )
        else if (_itens.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: cores.roxoFundoChip.withValues(alpha: 0.6),
                border: Border.all(color: cores.separador, width: 0.6),
              ),
              child: Row(
                children: [
                  Icon(Icons.psychology_alt_rounded, color: cores.roxoPrimario, size: 32),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Termine mais livros e avalie-os com 4★ ou mais para começarmos a sugerir novas leituras.',
                      style: tema.textTheme.bodyMedium?.copyWith(
                            color: cores.textoMedio,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 278,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _itens.length,
              separatorBuilder: (_, i) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _CardRecomendacao(item: _itens[i], aoAtualizar: _carregar),
            ),
          ),
      ],
    );
  }
}

class _CardRecomendacao extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback aoAtualizar;
  const _CardRecomendacao({required this.item, required this.aoAtualizar});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = context.coresApp;
    final match = item['matchPercentual'] is int ? item['matchPercentual'] as int : 50;
    final autor = item['autor']?.toString() ?? '';
    final genero = item['genero']?.toString() ?? '';
    final notaMedia = item['notaMedia'] is num ? (item['notaMedia'] as num).toDouble() : null;

    return GestureDetector(
      onTap: () => _abrirDetalhe(context),
      child: Container(
        width: 170,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: cores.separador, width: 0.6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 6),
              spreadRadius: -2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 180,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: CapaLivro(
                      livro: item,
                      heroTag: heroTagLivro({'recomendacao_': item['livroId'] ?? item.hashCode}),
                      largura: double.infinity,
                      altura: 170,
                      borderRadius: 14,
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cores.roxoPrimario,
                        borderRadius: BorderRadius.circular(99),
                        boxShadow: [
                          BoxShadow(
                            color: cores.roxoPrimario.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt_rounded, size: 11, color: Colors.white.withValues(alpha: 0.95)),
                          const SizedBox(width: 3),
                          Text(
                            '$match%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['titulo']?.toString() ?? 'Sem título',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tema.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cores.textoForte,
                          height: 1.2,
                        ),
                  ),
                  const SizedBox(height: 4),
                  if (autor.isNotEmpty)
                    Text(
                      autor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodySmall?.copyWith(
                            color: cores.textoMedio,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (genero.isNotEmpty)
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: cores.roxoFundoChip,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              genero,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: cores.roxoPrimario,
                              ),
                            ),
                          ),
                        ),
                      const Spacer(),
                      if (notaMedia != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            EstrelasAvaliacao(
                              avaliacao: notaMedia.round(),
                              tamanho: 12,
                              clicavel: false,
                            ),
                          ],
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

  Future<void> _abrirDetalhe(BuildContext ctx) async {
    final cores = ctx.coresApp;
    final tema = Theme.of(ctx);
    final match = item['matchPercentual'] is int ? item['matchPercentual'] as int : 50;
    final motivos = item['motivos'] is List
        ? List<String>.from((item['motivos'] as List).whereType<String>())
        : <String>[];
    final notaMedia = item['notaMedia'] is num ? (item['notaMedia'] as num).toDouble() : null;
    final qtde = item['quantidadeAvaliacoes'];

    final resultado = await showModalBottomSheet<bool>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (ctxInterno) {
        final alturaMax = MediaQuery.of(ctxInterno).size.height;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
            child: Container(
              constraints: BoxConstraints(maxHeight: alturaMax * 0.84),
              decoration: BoxDecoration(
                color: tema.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: cores.separador, width: 0.6),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44, height: 4,
                          decoration: BoxDecoration(
                            color: cores.separador,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CapaLivro(
                            livro: item,
                            heroTag: null,
                            largura: 110,
                            altura: 165,
                            borderRadius: 16,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [cores.roxoPrimario, cores.roxoClaro],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.auto_awesome_rounded, size: 13, color: Colors.white),
                                      const SizedBox(width: 5),
                                      Text(
                                        '$match% de compatibilidade',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  item['titulo']?.toString() ?? 'Sem título',
                                  style: tema.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: cores.textoForte,
                                        height: 1.1,
                                        letterSpacing: -0.3,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                if (item['autor']?.toString().isNotEmpty == true)
                                  Text(
                                    item['autor'].toString(),
                                    style: tema.textTheme.bodyMedium?.copyWith(
                                          color: cores.textoMedio,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                if (item['editora']?.toString().isNotEmpty == true)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text(
                                      'Editora ' + item['editora'].toString(),
                                      style: tema.textTheme.bodySmall?.copyWith(
                                            color: cores.textoFraco,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ),
                                const SizedBox(height: 10),
                                if (notaMedia != null && qtde is int && qtde > 0)
                                  Row(
                                    children: [
                                      EstrelasAvaliacao(
                                        avaliacao: notaMedia.round(),
                                        tamanho: 16,
                                        clicavel: false,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        notaMedia.toStringAsFixed(1) + ' ★',
                                        style: tema.textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: cores.textoForte,
                                            ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '($qtde ${qtde == 1 ? 'avaliação' : 'avaliações'})',
                                        style: tema.textTheme.bodySmall?.copyWith(
                                              color: cores.textoMedio,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (motivos.isNotEmpty) ...[
                        Text(
                          'Por que recomendamos?',
                          style: tema.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: cores.textoForte,
                              ),
                        ),
                        const SizedBox(height: 8),
                        for (final motivo in motivos)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Icon(Icons.check_circle_rounded, size: 15, color: cores.verdeLido),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    motivo,
                                    style: tema.textTheme.bodyMedium?.copyWith(
                                          color: cores.textoMedio,
                                          height: 1.4,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                      if (item['descricao']?.toString().isNotEmpty == true) ...[
                        Text(
                          'Sinopse',
                          style: tema.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: cores.textoForte,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item['descricao'].toString(),
                          style: tema.textTheme.bodyMedium?.copyWith(
                                color: cores.textoMedio,
                                height: 1.55,
                              ),
                          maxLines: 8,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 18),
                      ],
                      SafeArea(
                        top: false,
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final r = await navegarComAnimacao<bool>(
                                ctx,
                                CadastroLivroPage(livroInicial: Map<String, dynamic>.from(item)),
                              );
                              if (ctxInterno.mounted) Navigator.pop(ctxInterno, r == true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cores.roxoPrimario,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            ),
                            icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                            label: const Text(
                              'Adicionar à minha biblioteca',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (resultado == true) {
      aoAtualizar();
    }
  }
}

class _SkeletonRecomendacoes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
      scrollDirection: Axis.horizontal,
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (_, __) {
        return ShimmerBase(
          child: Container(
            width: 170,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: BlocoSkeleton(largura: 150, altura: 160, raio: 14),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      BlocoSkeleton(altura: 14, raio: 7),
                      SizedBox(height: 6),
                      BlocoSkeleton(largura: 90, altura: 12, raio: 6),
                      SizedBox(height: 8),
                      BlocoSkeleton(largura: 64, altura: 18, raio: 99),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
