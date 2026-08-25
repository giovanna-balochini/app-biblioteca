import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:frontend/main.dart' show themeService;
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/lembrete_leitura_service.dart' show lembreteLeituraService;
import 'package:frontend/screens/cadastro_livro_page.dart';
import 'package:frontend/screens/detalhe_livro_page.dart';
import 'package:frontend/screens/login_page.dart';
import 'package:frontend/screens/notificacoes_page.dart';
import 'package:frontend/widgets/estrelas_avaliacao.dart';
import 'package:frontend/widgets/capa_livro.dart';
import 'package:frontend/widgets/menu_configuracoes_bottomsheet.dart';
import 'package:frontend/widgets/status_progresso_leitura.dart';
import 'package:frontend/utils/formatters.dart';
import 'package:frontend/utils/snackbars.dart';

enum OpcaoOrdenacao {
  tituloAZ,
  autorAZ,
  dataConclusaoMaisRecente,
  dataCadastroMaisRecente,
}

extension OpcaoOrdenacaoExtension on OpcaoOrdenacao {
  String get rotulo {
    switch (this) {
      case OpcaoOrdenacao.tituloAZ:
        return 'Título (A → Z)';
      case OpcaoOrdenacao.autorAZ:
        return 'Autor (A → Z)';
      case OpcaoOrdenacao.dataConclusaoMaisRecente:
        return 'Concluídos (mais recentes)';
      case OpcaoOrdenacao.dataCadastroMaisRecente:
        return 'Cadastrados (mais recentes)';
    }
  }

  IconData get icone {
    switch (this) {
      case OpcaoOrdenacao.tituloAZ:
        return Icons.sort_by_alpha_rounded;
      case OpcaoOrdenacao.autorAZ:
        return Icons.person_search_rounded;
      case OpcaoOrdenacao.dataConclusaoMaisRecente:
        return Icons.event_available_rounded;
      case OpcaoOrdenacao.dataCadastroMaisRecente:
        return Icons.access_time_rounded;
    }
  }
}

class ListaLivrosPage extends StatefulWidget {
  const ListaLivrosPage({super.key});

  @override
  State<ListaLivrosPage> createState() => _ListaLivrosPageState();
}

class _ListaLivrosPageState extends State<ListaLivrosPage> {
  List<dynamic> livros = [];
  bool carregando = true;
  final _buscaController = TextEditingController();
  final _scrollController = ScrollController();
  List<dynamic> _livrosFiltrados = [];
  List<dynamic> _livrosPaginados = [];
  String _filtroStatus = 'todos';
  OpcaoOrdenacao _ordenacaoAtual = OpcaoOrdenacao.dataCadastroMaisRecente;
  Timer? _debounceBusca;
  bool _carregandoMais = false;
  bool _temMaisParaCarregar = false;
  static const int _tamanhoPagina = 10;
  int _qtdeNotificacoesNaoLidas = 0;
  Timer? _timerAtualizaNotificacoes;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_aoRolarAteOFinal);
    buscarLivros();
    _carregarContagemNotificacoes();
    _timerAtualizaNotificacoes = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _carregarContagemNotificacoes();
    });
  }

  @override
  void dispose() {
    _buscaController.dispose();
    _debounceBusca?.cancel();
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
        } else if (mounted && _qtdeNotificacoesNaoLidas == 0 && qtde != 0) {
          setState(() => _qtdeNotificacoesNaoLidas = qtde);
        }
      }
    } catch (e, s) { /* ignora silenciosamente */ }
  }

  Future<void> buscarLivros() async {
    final response = await AuthService.get('/livros');

    if (response.statusCode == 200) {
      setState(() {
        livros = json.decode(response.body);
        carregando = false;
      });
      _aplicarFiltros(resetarPagina: true);
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    }
  }

  void _aplicarFiltros({bool resetarPagina = true}) {
    _filtrarLivros(_buscaController.text, resetarPagina: resetarPagina);
  }

  Future<void> _atualizarLivros() async {
    await buscarLivros();
    if (!mounted) return;
    mostrarSnackbarSucesso(context, 'Biblioteca atualizada!');
  }

  void _aoDigitarBusca(String valor) {
    if (_debounceBusca?.isActive ?? false) _debounceBusca!.cancel();
    _debounceBusca = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _aplicarFiltros(resetarPagina: true);
    });
  }

  void _aoRolarAteOFinal() {
    if (_carregandoMais || !_temMaisParaCarregar) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _carregarProximaPagina();
    }
  }

  void _carregarProximaPagina() {
    if (_carregandoMais || !_temMaisParaCarregar) return;
    setState(() => _carregandoMais = true);

    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      _atualizarPagina(incrementar: true);
      setState(() => _carregandoMais = false);
    });
  }

  void _atualizarPagina({bool incrementar = false}) {
    final totalDisponivel = _livrosFiltrados.length;
    int proximoFim = _livrosPaginados.length + (incrementar ? _tamanhoPagina : _tamanhoPagina);
    proximoFim = proximoFim.clamp(0, totalDisponivel);
    setState(() {
      _livrosPaginados = _livrosFiltrados.sublist(0, proximoFim);
      _temMaisParaCarregar = _livrosPaginados.length < totalDisponivel;
    });
  }

  Future<void> _abrirOpcoesOrdenacao() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFF7F7FB),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0DBF2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ordenar por',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF5F5F7A)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final opcao in OpcaoOrdenacao.values) ...[
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.pop(context);
                        if (_ordenacaoAtual != opcao) {
                          setState(() => _ordenacaoAtual = opcao);
                          _aplicarFiltros(resetarPagina: true);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: _ordenacaoAtual == opcao
                              ? const Color(0xFFF1EEFF)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _ordenacaoAtual == opcao
                                ? const Color(0xFF7C4DFF)
                                : Colors.transparent,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _ordenacaoAtual == opcao
                                    ? const Color(0xFF7C4DFF)
                                    : const Color(0xFFF1EEFF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                opcao.icone,
                                color: _ordenacaoAtual == opcao
                                    ? Colors.white
                                    : const Color(0xFF7C4DFF),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                opcao.rotulo,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      fontWeight: _ordenacaoAtual == opcao
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: _ordenacaoAtual == opcao
                                          ? const Color(0xFF7C4DFF)
                                          : const Color(0xFF2A2A38),
                                    ),
                              ),
                            ),
                            if (_ordenacaoAtual == opcao)
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF7C4DFF)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  static const List<Map<String, dynamic>> _diasSemana = [
    {'rotulo': 'D', 'dia': DateTime.sunday},
    {'rotulo': 'S', 'dia': DateTime.monday},
    {'rotulo': 'T', 'dia': DateTime.tuesday},
    {'rotulo': 'Q', 'dia': DateTime.wednesday},
    {'rotulo': 'Q', 'dia': DateTime.thursday},
    {'rotulo': 'S', 'dia': DateTime.friday},
    {'rotulo': 'S', 'dia': DateTime.saturday},
  ];

  String _nomeDiaCompleto(int dia) {
    return switch (dia) {
      DateTime.monday => 'Seg',
      DateTime.tuesday => 'Ter',
      DateTime.wednesday => 'Qua',
      DateTime.thursday => 'Qui',
      DateTime.friday => 'Sex',
      DateTime.saturday => 'Sáb',
      _ => 'Dom',
    };
  }

  String _proximoLembreteTexto(TimeOfDay horario, List<int> dias) {
    if (dias.isEmpty) return 'Nenhum dia selecionado';
    final agora = DateTime.now();
    int? proxDia;
    for (int i = 0; i < 7; i++) {
      final diaCandidato = agora.weekday + i;
      final diaNormalizado = ((diaCandidato - 1) % 7) + 1;
      final dataCandidata = DateTime(agora.year, agora.month, agora.day + i, horario.hour, horario.minute);
      final cairAgora = i == 0 ? dataCandidata.isAfter(agora) : true;
      if (dias.contains(diaNormalizado) && cairAgora) {
        proxDia = diaNormalizado;
        break;
      }
    }
    proxDia ??= dias.first;
    final minuto = horario.minute.toString().padLeft(2, '0');
    return 'Próximo lembrete: ${_nomeDiaCompleto(proxDia)} às ${horario.hour}:$minuto';
  }

  Future<void> _abrirConfiguracoesLembrete(BuildContext context) async {
    final tema = Theme.of(context);
    final escuro = tema.brightness == Brightness.dark;
    final corPrimaria = const Color(0xFF7C4DFF);
    final corCard = escuro ? const Color(0xFF1C1C27) : Colors.white;
    final corBorda = escuro ? const Color(0xFF2B2B38) : const Color(0xFFE7E7F1);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tema.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return ListenableBuilder(
              listenable: lembreteLeituraService,
              builder: (context, _) {
                final ligado = lembreteLeituraService.ligado;
                final horario = lembreteLeituraService.horario;
                final dias = List<int>.from(lembreteLeituraService.dias);

                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 5,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: escuro
                                  ? const Color(0xFF3C3C4E)
                                  : const Color(0xFFDFDFEA),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Icon(
                              ligado
                                  ? Icons.notifications_active_rounded
                                  : Icons.notifications_none_rounded,
                              size: 22,
                              color: corPrimaria,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Lembrete de leitura',
                                style: tema.textTheme.titleLarge,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Configure quando quer ser lembrado de ler',
                          style: tema.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: corCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: corBorda),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Lembretes ativos',
                                        style: tema.textTheme.titleLarge
                                            ?.copyWith(fontSize: 16)),
                                    const SizedBox(height: 2),
                                    Text(
                                      ligado
                                          ? 'Você receberá notificações nos dias selecionados'
                                          : 'Os lembretes estão desativados',
                                      style: tema.textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Switch.adaptive(
                                value: ligado,
                                activeTrackColor:
                                    corPrimaria.withValues(alpha: 0.35),
                                thumbColor: WidgetStatePropertyAll(ligado ? corPrimaria : null),
                                onChanged: (v) async {
                                  await lembreteLeituraService.atualizar(
                                      ligado: v);
                                  if (v &&
                                      context.mounted) {
                                    mostrarSnackbarInfo(context,
                                        'Lembretes ativados! Você receberá notificações.');
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            final novo = await showTimePicker(
                              context: context,
                              initialTime: horario,
                              builder: (ctx, child) {
                                return Theme(
                                  data: tema.copyWith(
                                    colorScheme: tema.colorScheme.copyWith(
                                      primary: corPrimaria,
                                    ),
                                  ),
                                  child: child ?? const SizedBox.shrink(),
                                );
                              },
                            );
                            if (novo != null && context.mounted) {
                              await lembreteLeituraService.atualizar(
                                  horario: novo);
                              mostrarSnackbarInfo(context,
                                  'Horário atualizado para ${novo.hour}:${novo.minute.toString().padLeft(2, '0')}');
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: corCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: corBorda),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: corPrimaria.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(Icons.schedule_rounded,
                                      color: corPrimaria, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Horário do lembrete',
                                          style: tema.textTheme.titleLarge
                                              ?.copyWith(fontSize: 16)),
                                      const SizedBox(height: 2),
                                      Text(
                                        horario.format(context),
                                        style: tema.textTheme.bodyMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(Icons.chevron_right_rounded,
                                    size: 22,
                                    color: escuro
                                        ? const Color(0xFF9C9CB5)
                                        : const Color(0xFF8A8A9D)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                          decoration: BoxDecoration(
                            color: corCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: corBorda),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Repetir nos dias',
                                  style: tema.textTheme.titleLarge
                                      ?.copyWith(fontSize: 16)),
                              const SizedBox(height: 12),
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                spacing: 6,
                                children:
                                    _diasSemana.map((mapa) {
                                  final int dia = mapa['dia'];
                                  final bool selecionado = dias.contains(dia);
                                  return GestureDetector(
                                    onTap: () async {
                                      final novaLista =
                                          List<int>.from(dias);
                                      if (selecionado) {
                                        if (novaLista.length > 1) {
                                          novaLista.remove(dia);
                                        } else {
                                          mostrarSnackbarAviso(context,
                                              'Selecione pelo menos um dia!');
                                          return;
                                        }
                                      } else {
                                        novaLista.add(dia);
                                      }
                                      novaLista.sort();
                                      await lembreteLeituraService.atualizar(
                                          dias: novaLista);
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                          milliseconds: 200),
                                      curve: Curves.easeOut,
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: selecionado
                                            ? corPrimaria
                                            : (escuro
                                                ? const Color(0xFF2A2A37)
                                                : const Color(0xFFF3F3FB)),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        border: Border.all(
                                          color: selecionado
                                              ? corPrimaria
                                              : corBorda,
                                          width: 1.2,
                                        ),
                                        boxShadow: selecionado
                                            ? [
                                                BoxShadow(
                                                  color: corPrimaria
                                                      .withValues(alpha: 0.25),
                                                  blurRadius: 8,
                                                  offset:
                                                      const Offset(0, 3),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        mapa['rotulo'],
                                        style: tema.textTheme.bodyLarge
                                            ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: selecionado
                                              ? Colors.white
                                              : (escuro
                                                  ? const Color(0xFFC7C7D9)
                                                  : const Color(0xFF5A5A6A)),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 9),
                                decoration: BoxDecoration(
                                  color: corPrimaria.withValues(alpha: escuro ? 0.16 : 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      ligado
                                          ? Icons.info_outline_rounded
                                          : Icons.info_rounded,
                                      size: 16,
                                      color: corPrimaria,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        ligado
                                            ? _proximoLembreteTexto(horario, dias)
                                            : 'Ative os lembretes para começar',
                                        style: tema.textTheme.bodyMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: corPrimaria,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: MediaQuery.viewInsetsOf(context).bottom + 16),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _filtrarLivros(String busca, {bool resetarPagina = true}) {
    final termo = busca.trim().toLowerCase();

    Iterable<dynamic> resultado = livros;
    if (termo.isNotEmpty) {
      resultado = resultado.where((livro) {
        final titulo = (livro['titulo'] ?? '').toString().toLowerCase();
        final autor = (livro['autor'] ?? '').toString().toLowerCase();
        final editora = (livro['editora'] ?? '').toString().toLowerCase();
        final genero = (livro['genero'] ?? '').toString().toLowerCase();
        return titulo.contains(termo) ||
            autor.contains(termo) ||
            editora.contains(termo) ||
            genero.contains(termo);
      });
    }

    if (_filtroStatus == 'lidos') {
      resultado = resultado.where((livro) => livro['lido'] == true);
    } else if (_filtroStatus == 'nao_lidos') {
      resultado = resultado.where((livro) => livro['lido'] != true);
    }

    final listaOrdenada = resultado.toList();
    switch (_ordenacaoAtual) {
      case OpcaoOrdenacao.tituloAZ:
        listaOrdenada.sort((a, b) {
          final ta = (a['titulo'] ?? '').toString().toLowerCase();
          final tb = (b['titulo'] ?? '').toString().toLowerCase();
          return ta.compareTo(tb);
        });
        break;
      case OpcaoOrdenacao.autorAZ:
        listaOrdenada.sort((a, b) {
          final aa = (a['autor'] ?? '').toString().toLowerCase();
          final ab = (b['autor'] ?? '').toString().toLowerCase();
          return aa.compareTo(ab);
        });
        break;
      case OpcaoOrdenacao.dataConclusaoMaisRecente:
        listaOrdenada.sort((a, b) {
          final da = a['dataConclusao']?.toString();
          final db = b['dataConclusao']?.toString();
          if ((da == null || da.isEmpty) && (db == null || db.isEmpty)) return 0;
          if (da == null || da.isEmpty) return 1;
          if (db == null || db.isEmpty) return -1;
          return db.compareTo(da);
        });
        break;
      case OpcaoOrdenacao.dataCadastroMaisRecente:
        listaOrdenada.sort((a, b) {
          final ida = a['id'];
          final idb = b['id'];
          if (ida is int && idb is int) return idb.compareTo(ida);
          if (ida == null) return 1;
          if (idb == null) return -1;
          return idb.toString().compareTo(ida.toString());
        });
        break;
    }

    setState(() {
      _livrosFiltrados = listaOrdenada;
      if (resetarPagina) {
        final total = listaOrdenada.length;
        final fim = total.clamp(0, _tamanhoPagina);
        _livrosPaginados = listaOrdenada.sublist(0, fim);
        _temMaisParaCarregar = _livrosPaginados.length < total;
        if (_scrollController.hasClients && _scrollController.offset > 0) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        }
      }
    });
  }

  Widget _buildCardEstatisticas() {
    final total = livros.length;
    final totalLidos = livros.where((l) => l['lido'] == true).length;
    final porcentagem = total == 0 ? 0.0 : (totalLidos / total).clamp(0.0, 1.0);
    final porcentagemTexto = total == 0 ? '0%' : '${(porcentagem * 100).toStringAsFixed(0)}%';
    final completo = porcentagem >= 1.0 && total > 0;
    final corConcluido = completo ? const Color(0xFF2E7D32) : const Color(0xFF7C4DFF);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.insights_rounded, size: 18, color: Color(0xFF7C4DFF)),
              SizedBox(width: 6),
              Text(
                'Sua leitura em números',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF2A2A38)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F5FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.library_books_rounded, size: 18, color: Color(0xFF7C4DFF)),
                      const SizedBox(height: 4),
                      Text(
                        '$total',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF2A2A38)),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        total == 1 ? 'livro cadastrado' : 'livros cadastrados',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: Color(0xFF6B6B80)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8FAF0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF2E7D32)),
                      const SizedBox(height: 4),
                      Text(
                        '$totalLidos',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF2A2A38)),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        totalLidos == 1 ? 'livro lido' : 'livros lidos',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: Color(0xFF6B6B80)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progresso de leitura',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2A2A38),
                    ),
              ),
              Text(
                '$porcentagemTexto concluída',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: corConcluido,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: porcentagem,
              minHeight: 6,
              backgroundColor: const Color(0xFFEDE7FF),
              valueColor: AlwaysStoppedAnimation<Color>(
                completo ? const Color(0xFF2E7D32) : const Color(0xFF7C4DFF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipFiltro({
    required String rotulo,
    required String statusValor,
    required IconData icone,
    required Color corSelecionado,
    required Color corIconeNaoSelecionado,
    required Color corBordaNaoSelecionado,
  }) {
    final selecionado = _filtroStatus == statusValor;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        scale: selecionado ? 1.03 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              if (selecionado)
                BoxShadow(
                  color: corSelecionado.withValues(alpha: 0.25),
                  blurRadius: 10,
                  spreadRadius: 0.5,
                  offset: const Offset(0, 3),
                ),
            ],
          ),
          child: ChoiceChip(
            label: Text(rotulo),
            selected: selecionado,
            onSelected: (_) {
              setState(() => _filtroStatus = statusValor);
              _aplicarFiltros(resetarPagina: true);
            },
            selectedColor: corSelecionado,
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            labelStyle: TextStyle(
              color: selecionado ? Colors.white : const Color(0xFF5F5F7A),
              fontWeight: FontWeight.w700,
            ),
            side: BorderSide(
              color: selecionado ? corSelecionado : corBordaNaoSelecionado,
              width: 1.2,
            ),
            avatar: Icon(
              icone,
              size: 18,
              color: selecionado ? Colors.white : corIconeNaoSelecionado,
            ),
          ),
        ),
      ),
    );
  }

  bool _temFiltroAplicado() {
    return _buscaController.text.trim().isNotEmpty || _filtroStatus != 'todos';
  }

  String _mensagemEstadoVazio() {
    final buscaVazia = _buscaController.text.trim().isEmpty;

    if (buscaVazia && _filtroStatus == 'todos') {
      return 'Sua biblioteca está vazia.';
    }
    if (buscaVazia && _filtroStatus == 'lidos') {
      return 'Você ainda não marcou nenhum livro como lido.';
    }
    if (buscaVazia && _filtroStatus == 'nao_lidos') {
      return 'Parabéns! Você já leu todos os seus livros 📚🎉';
    }

    final termo = _buscaController.text.trim();
    if (_filtroStatus == 'lidos') {
      return 'Nenhum livro LIDO encontrado para "$termo".';
    }
    if (_filtroStatus == 'nao_lidos') {
      return 'Nenhum livro NÃO LIDO encontrado para "$termo".';
    }
    return 'Nenhum livro encontrado para "$termo".';
  }

  String _subtituloEstadoVazio() {
    final buscaVazia = _buscaController.text.trim().isEmpty;

    if (buscaVazia && _filtroStatus == 'lidos') {
      return 'Comece marcando alguns livros como lidos e eles aparecerão aqui.';
    }
    if (buscaVazia && _filtroStatus == 'nao_lidos') {
      return 'Você não tem livros pendentes para ler.';
    }

    return 'Tente buscar por título, autor, editora ou gênero.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/logo_minha_biblioteca.png',
                  height: 36,
                  width: 36,
                  fit: BoxFit.contain,
                  errorBuilder: (context, err, stack) => Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1EEFF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.menu_book_rounded, color: Color(0xFF7C4DFF)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF7C4DFF), Color(0xFFB28CFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    blendMode: BlendMode.srcIn,
                    child: const Text(
                      'Minha Biblioteca',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontFamily: 'Diphylleia',
                        fontSize: 27,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${livros.length} ${livros.length == 1 ? 'livro cadastrado' : 'livros cadastrados'}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6B6B80),
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
        toolbarHeight: 92,
        actions: [
          SizedBox(
            height: 48,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: ListenableBuilder(
                    listenable: lembreteLeituraService,
                    builder: (ctx, _) => Icon(
                      lembreteLeituraService.ligado
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_none_rounded,
                      color: lembreteLeituraService.ligado
                          ? const Color(0xFF7C4DFF)
                          : null,
                    ),
                  ),
                  tooltip: 'Notificações',
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificacoesPage()));
                    if (mounted) _carregarContagemNotificacoes();
                  },
                ),
                if (_qtdeNotificacoesNaoLidas > 0)
                  Positioned(
                    right: 4, top: 4,
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
          IconButton(
            tooltip: 'Configurações',
            onPressed: () {
              exibirMenuConfiguracoes(
                context,
                abrirConfiguracoesLembrete: () => _abrirConfiguracoesLembrete(context),
              );
            },
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : livros.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: const Color(0xFFEDE7FF),
                          ),
                          child: const Icon(
                            Icons.menu_book_rounded,
                            size: 44,
                            color: Color(0xFF7C4DFF),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Sua biblioteca está vazia.',
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: 220,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final resultado = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CadastroLivroPage(),
                                ),
                              );
                              if (resultado == true) {
                                buscarLivros();
                              }
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Adicionar livro'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFF7C4DFF),
                  backgroundColor: Colors.white,
                  onRefresh: _atualizarLivros,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            _buildCardEstatisticas(),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _buscaController,
                                    onChanged: _aoDigitarBusca,
                                    decoration: InputDecoration(
                                      labelText: 'Buscar livro',
                                      hintText: 'Pesquise por título, autor, editora ou gênero',
                                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF7C4DFF)),
                                      suffixIcon: _buscaController.text.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.close, color: Color(0xFF7C4DFF)),
                                              onPressed: () {
                                                _buscaController.clear();
                                                _debounceBusca?.cancel();
                                                _aplicarFiltros(resetarPagina: true);
                                              },
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  height: 48,
                                  child: Tooltip(
                                    message: 'Ordenar por: ${_ordenacaoAtual.rotulo}',
                                    child: OutlinedButton.icon(
                                      onPressed: _abrirOpcoesOrdenacao,
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        side: const BorderSide(color: Color(0xFFDCD5F5)),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      icon: const Icon(Icons.sort_rounded, size: 20, color: Color(0xFF7C4DFF)),
                                      label: Text(
                                        'Ordenar',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF7C4DFF)),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildChipFiltro(
                                    rotulo: 'Todos',
                                    statusValor: 'todos',
                                    icone: Icons.library_books_rounded,
                                    corSelecionado: const Color(0xFF7C4DFF),
                                    corIconeNaoSelecionado: const Color(0xFF7C4DFF),
                                    corBordaNaoSelecionado: const Color(0xFFE0DBF2),
                                  ),
                                  _buildChipFiltro(
                                    rotulo: 'Lidos',
                                    statusValor: 'lidos',
                                    icone: Icons.check_circle_rounded,
                                    corSelecionado: const Color(0xFF2E7D32),
                                    corIconeNaoSelecionado: const Color(0xFF2E7D32),
                                    corBordaNaoSelecionado: const Color(0xFFD7EBDB),
                                  ),
                                  _buildChipFiltro(
                                    rotulo: 'Não lidos',
                                    statusValor: 'nao_lidos',
                                    icone: Icons.menu_book_outlined,
                                    corSelecionado: const Color(0xFF7C4DFF),
                                    corIconeNaoSelecionado: const Color(0xFF7C4DFF),
                                    corBordaNaoSelecionado: const Color(0xFFE0DBF2),
                                  ),
                                ],
                              ),
                            ),
                            if (_livrosFiltrados.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    'Exibindo ${_livrosPaginados.length} de ${_livrosFiltrados.length} ${_livrosFiltrados.length == 1 ? 'livro' : 'livros'}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: const Color(0xFF6B6B80),
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                  const Spacer(),
                                  if (_temMaisParaCarregar)
                                    Text(
                                      'Role para ver mais',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: const Color(0xFF7C4DFF),
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 14),
                          ],
                        ),
                      ),
                      if (_livrosFiltrados.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 96,
                                    height: 96,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                      color: const Color(0xFFEDE7FF),
                                    ),
                                    child: const Icon(
                                      Icons.search_off_rounded,
                                      size: 44,
                                      color: Color(0xFF7C4DFF),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    _mensagemEstadoVazio(),
                                    style: Theme.of(context).textTheme.bodyLarge,
                                    textAlign: TextAlign.center,
                                  ),
                                  if (_temFiltroAplicado()) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      _subtituloEstadoVazio(),
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: const Color(0xFF6B6B80),
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 20),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        _buscaController.clear();
                                        _debounceBusca?.cancel();
                                        setState(() => _filtroStatus = 'todos');
                                        _aplicarFiltros(resetarPagina: true);
                                      },
                                      icon: const Icon(Icons.refresh_rounded, size: 18),
                                      label: const Text('Limpar filtros'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              if (index == _livrosPaginados.length) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Color(0xFF7C4DFF),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Carregando mais livros...',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                color: const Color(0xFF5F5F7A),
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              final livro = _livrosPaginados[index];
                              final progressoInfo = InfoProgressoLivro.fromMap(livro);
                              final statusTxt = livro['statusLeitura']?.toString().toUpperCase();
                              final statusDisplay = statusTxt == 'QUERO_LER' || statusTxt == 'LENDO' || statusTxt == 'LIDO'
                                  ? statusTxt
                                  : (livro['lido'] == true ? 'LIDO' : 'QUERO_LER');
                              final ehLendo = statusDisplay == 'LENDO' && progressoInfo.totalPaginas != null;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Card(
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    leading: CapaLivro(livro: livro),
                                    title: Text(
                                      livro['titulo'] ?? '',
                                      style: Theme.of(context).textTheme.titleLarge,
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            livro['autor'] ?? 'Autor Desconhecido',
                                            style: Theme.of(context).textTheme.bodyMedium,
                                          ),
                                          const SizedBox(height: 6),
                                          EstrelasAvaliacao(
                                            avaliacao: livro['avaliacao'] is int ? livro['avaliacao'] : (livro['avaliacao'] is double ? (livro['avaliacao'] as double).toInt() : null),
                                            tamanho: 15,
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 6,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              ChipStatusLeitura(status: statusDisplay, compacto: true),
                                              if (ehLendo)
                                                Text(
                                                  '${progressoInfo.paginaAtual ?? 0}/${progressoInfo.totalPaginas} · ${progressoInfo.progresso.toInt()}%',
                                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                        fontWeight: FontWeight.w700,
                                                        color: const Color(0xFF6B3AFF),
                                                      ),
                                                ),
                                            ],
                                          ),
                                          if (ehLendo) ...[
                                            const SizedBox(height: 8),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(999),
                                              child: LinearProgressIndicator(
                                                value: (progressoInfo.progresso / 100).clamp(0.0, 1.0),
                                                minHeight: 4,
                                                backgroundColor: const Color(0xFF7C4DFF).withValues(alpha: 0.16),
                                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C4DFF)),
                                              ),
                                            ),
                                          ],
                                          if (livro['lido'] == true) ...[
                                            if (formatarDataCurta(livro['dataConclusao']?.toString() ?? livro['dataFimLeitura']?.toString()).isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.event_available_rounded, size: 12, color: Color(0xFF2E7D32)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Concluído em ${formatarDataCurta(livro['dataConclusao']?.toString() ?? livro['dataFimLeitura']?.toString())}',
                                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                          color: const Color(0xFF2E7D32),
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ],
                                      ),
                                    ),
                                    trailing: ehLendo
                                        ? SizedBox(
                                            width: 44,
                                            height: 44,
                                            child: BarraProgressoCircular(
                                              percentual: progressoInfo.progresso,
                                              tamanho: 44,
                                              espessura: 4.2,
                                              corFundo: const Color(0xFF7C4DFF).withValues(alpha: 0.2),
                                              corPrimaria: const Color(0xFF7C4DFF),
                                              centro: Text(
                                                '${progressoInfo.progresso.toInt()}%',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF5A33E0),
                                                ),
                                              ),
                                            ),
                                          )
                                        : Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                              color: const Color(0xFFF1EEFF),
                                            ),
                                            child: const Icon(Icons.chevron_right_rounded, color: Color(0xFF7C4DFF)),
                                          ),
                                    onTap: () async {
                                      final resultado = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => DetalheLivroPage(livro: livro),
                                        ),
                                      );
                                      if (resultado == true) {
                                        _buscaController.clear();
                                        _debounceBusca?.cancel();
                                        buscarLivros();
                                      } else if (resultado is Map &&
                                          resultado['deletado'] == true &&
                                          resultado['adiado'] == true &&
                                          resultado['livro'] is Map) {
                                        final livroDeletado = resultado['livro'] as Map;
                                        final livroId = livroDeletado['id'];

                                        final idxTodos = livros.indexWhere((l) =>
                                            (l['id'] != null ? l['id'].toString() : '') ==
                                            (livroId != null ? livroId.toString() : ''));
                                        final snapshotTodos = List<dynamic>.from(livros);

                                        if (idxTodos != -1) {
                                          setState(() {
                                            livros.removeAt(idxTodos);
                                            final idxFiltradosAtual = _livrosFiltrados.indexWhere((l) =>
                                                (l['id'] != null ? l['id'].toString() : '') ==
                                                (livroId != null ? livroId.toString() : ''));
                                            if (idxFiltradosAtual != -1) _livrosFiltrados.removeAt(idxFiltradosAtual);
                                            final qtdExibir = _livrosPaginados.length.clamp(0, _livrosFiltrados.length);
                                            _livrosPaginados = qtdExibir == 0
                                                ? List<dynamic>.from(_livrosFiltrados)
                                                : List<dynamic>.from(_livrosFiltrados.sublist(0, qtdExibir));
                                            _temMaisParaCarregar = _livrosPaginados.length < _livrosFiltrados.length;
                                          });
                                        }

                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                          ..removeCurrentSnackBar()
                                          ..showSnackBar(
                                            SnackBar(
                                              behavior: SnackBarBehavior.floating,
                                              duration: const Duration(seconds: 4),
                                              margin: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              backgroundColor: const Color(0xFF2B2B33),
                                              content: Row(
                                                children: [
                                                  const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFFFB3B3)),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(
                                                      '"${(livroDeletado['titulo'] ?? 'Livro').toString().length > 32 ? '${(livroDeletado['titulo'] ?? 'Livro').toString().substring(0, 32)}...' : livroDeletado['titulo'] ?? 'Livro'}" removido da biblioteca',
                                                      style: const TextStyle(color: Colors.white, fontSize: 14),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              action: SnackBarAction(
                                                label: 'DESFAZER',
                                                textColor: const Color(0xFFB28CFF),
                                                onPressed: () {
                                                  if (idxTodos != -1 && mounted) {
                                                    setState(() {
                                                      livros = snapshotTodos;
                                                    });
                                                    _filtrarLivros(
                                                      _buscaController.text,
                                                      resetarPagina: true,
                                                    );
                                                  }
                                                },
                                              ),
                                            ),
                                          );
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                            childCount: _livrosPaginados.length + (_carregandoMais || _temMaisParaCarregar ? 1 : 0),
                          ),
                        ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 24),
                      ),
                    ],
                  ),
                ),
              ),
      floatingActionButton: livros.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final resultado = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CadastroLivroPage(),
                  ),
                );
                if (resultado == true) {
                  buscarLivros();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Adicionar livro'),
            ),
    );
  }
}
