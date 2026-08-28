import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/google_books_service.dart';
import 'package:frontend/widgets/estrelas_avaliacao.dart';
import 'package:frontend/widgets/info_tile.dart';
import 'package:frontend/widgets/botao_curtida_avaliacao.dart';
import 'package:frontend/widgets/status_progresso_leitura.dart';
import 'package:frontend/widgets/capa_livro.dart';
import 'package:frontend/utils/formatters.dart';
import 'package:frontend/utils/snackbars.dart';
import 'package:frontend/utils/transitions.dart';
import 'package:frontend/screens/perfil_usuario_page.dart';

class DetalheLivroPage extends StatefulWidget {
  final Map<String, dynamic> livro;

  const DetalheLivroPage({super.key, required this.livro});

  @override
  State<DetalheLivroPage> createState() => _DetalheLivroPageState();
}

class _DetalheLivroPageState extends State<DetalheLivroPage> {
  late TextEditingController _tituloController;
  late TextEditingController _autorController;
  late TextEditingController _editoraController;
  late TextEditingController _generoController;
  late TextEditingController _descricaoController;
  late TextEditingController _totalPaginasController;
  late TextEditingController _paginaAtualController;

  bool _editando = false;
  bool _salvando = false;
  late bool _lido;
  late String _statusLeitura;
  late int? _avaliacao;
  late DateTime? _dataConclusao;
  late DateTime? _dataInicio;
  bool _jaAvisouLimiteDesc = false;
  Uint8List? _capaBytes;
  String? _capaUrlLocal;
  String? _tipoCapa;
  final ImagePicker _imagePicker = ImagePicker();

  double? _mediaAvaliacoes;
  int _totalAvaliacoes = 0;
  List<Map<String, dynamic>> _listaAvaliacoes = [];
  bool _carregandoAvaliacoes = false;

  bool _capaFoiAlterada() {
    final original = widget.livro['imagem']?.toString();
    final originalVazia = original == null || original.isEmpty;
    final temCapaLocal = _capaBytes != null;
    final temUrlLocal = _tipoCapa == 'url' && _capaUrlLocal != null;

    if (_tipoCapa == null && originalVazia) return false;
    if (_tipoCapa == null && !originalVazia) return true;
    if (temCapaLocal) return true;
    if (temUrlLocal) return _capaUrlLocal != original;
    return false;
  }

  int? _avaliacaoOriginal() {
    final aval = widget.livro['avaliacao'];
    return aval is int ? aval : (aval is double ? aval.toInt() : null);
  }

  bool _formularioFoiAlterado() {
    final titulo = _tituloController.text.trim();
    final autor = _autorController.text.trim();
    final editora = _editoraController.text.trim();
    final genero = _generoController.text.trim();
    final descricao = _descricaoController.text.trim();

    final tOriginal = widget.livro['titulo']?.toString() ?? '';
    final aOriginal = widget.livro['autor']?.toString() ?? '';
    final eOriginal = widget.livro['editora']?.toString() ?? '';
    final gOriginal = widget.livro['genero']?.toString() ?? '';
    final dOriginal = widget.livro['descricao']?.toString() ?? '';
    final lidoOriginal = widget.livro['lido'] == true;
    final avalOriginal = _avaliacaoOriginal();
    final dataOriginal = parseDataISO(widget.livro['dataConclusao']?.toString());

    return titulo != tOriginal ||
        autor != aOriginal ||
        editora != eOriginal ||
        genero != gOriginal ||
        descricao != dOriginal ||
        _lido != lidoOriginal ||
        _avaliacao != avalOriginal ||
        _dataConclusao != dataOriginal ||
        _capaFoiAlterada();
  }

  Future<bool> _confirmarSaidaSemSalvar() async {
    if (!_editando) return true;
    if (!_formularioFoiAlterado()) return true;
    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Descartar alterações?'),
        content: const Text('Você fez edições nos dados deste livro. Tem certeza de que quer sair sem salvar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuar editando'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFB3261E)),
            child: const Text('Sair sem salvar'),
          ),
        ],
      ),
    );
    return resultado == true;
  }

  Future<void> _selecionarData() async {
    final hoje = DateTime.now();
    final data = await showDatePicker(
      context: context,
      initialDate: _dataConclusao ?? hoje,
      firstDate: DateTime(1900),
      lastDate: hoje,
      locale: const Locale('pt', 'BR'),
      confirmText: 'Confirmar',
      cancelText: 'Cancelar',
      fieldLabelText: 'Data de conclusão',
      fieldHintText: 'dd/mm/aaaa',
      helpText: 'Selecione a data de conclusão',
    );
    if (data != null) {
      setState(() => _dataConclusao = data);
    }
  }

  Future<void> _selecionarDataInicio() async {
    final hoje = DateTime.now();
    final data = await showDatePicker(
      context: context,
      initialDate: _dataInicio ?? hoje,
      firstDate: DateTime(1900),
      lastDate: hoje,
      locale: const Locale('pt', 'BR'),
      confirmText: 'Confirmar',
      cancelText: 'Cancelar',
      fieldLabelText: 'Data de início',
      fieldHintText: 'dd/mm/aaaa',
      helpText: 'Quando você começou a ler?',
    );
    if (data != null) {
      setState(() => _dataInicio = data);
    }
  }

  Widget _botaoStatus(String status, IconData icone, String rotulo) {
    final info = infoStatusLeitura(context, status);
    final selecionado = _statusLeitura == status;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() {
              _statusLeitura = status;
              if (status == 'LIDO') {
                _lido = true;
              } else {
                _lido = false;
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: selecionado
                  ? info.cor
                  : (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF111118)
                      : Colors.white),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selecionado ? info.cor : (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2A2A38)
                    : const Color(0xFFDDD5F2)),
                width: 1.2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icone,
                  color: selecionado ? Colors.white : info.cor,
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  rotulo,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: selecionado ? FontWeight.w800 : FontWeight.w600,
                        color: selecionado ? Colors.white : info.cor,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _mensagemErro(http.Response response, String fallback) {
    if (response.body.isEmpty) return fallback;

    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic>) {
        final message = body['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {}

    return fallback;
  }

  Future<void> _carregarAvaliacoesComunidade() async {
    if (!mounted) return;
    setState(() => _carregandoAvaliacoes = true);
    try {
      final response = await AuthService.get('/livros/${widget.livro['id']}/avaliacoes');
      if (response.statusCode == 200) {
        dynamic body;
        try {
          body = jsonDecode(utf8.decode(response.bodyBytes));
        } catch (e) {}
        if (body is Map<String, dynamic>) {
          final media = body['media'];
          final total = body['total'];
          final lista = body['avaliacoes'];
          if (!mounted) return;
          setState(() {
            if (media is num) _mediaAvaliacoes = media.toDouble();
            if (total is int) _totalAvaliacoes = total;
            if (lista is List) {
              _listaAvaliacoes = List<Map<String, dynamic>>.from(
                lista.whereType<Map<String, dynamic>>(),
              );
            }
            _carregandoAvaliacoes = false;
          });
        } else {
          if (mounted) setState(() => _carregandoAvaliacoes = false);
        }
      } else {
        if (mounted) setState(() => _carregandoAvaliacoes = false);
      }
    } catch (_) {
      if (mounted) setState(() => _carregandoAvaliacoes = false);
    }
  }

  Future<void> _abrirPerfilAutor(Map<String, dynamic> av) async {
    final usuarioId = av['usuarioId'];
    if (usuarioId == null) return;
    final id = usuarioId is int ? usuarioId : int.tryParse(usuarioId.toString());
    if (id == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PerfilUsuarioPage(
          usuarioId: id,
          apelido: av['usuarioNome']?.toString(),
        ),
      ),
    );
  }

  Future<void> _abrirMinhaAvaliacao() async {
    final minhaAvaliacao = _listaAvaliacoes.firstWhere(
      (a) => a['usuarioId'] == AuthService.usuarioId,
      orElse: () => <String, dynamic>{},
    );

    int notaSelecionada =
        minhaAvaliacao['nota'] is int ? minhaAvaliacao['nota'] as int : (_avaliacao ?? 0);
    DateTime? dataSelecionada = parseDataISO(minhaAvaliacao['dataConclusao']?.toString()) ?? _dataConclusao;
    TextEditingController comentarioController =
        TextEditingController(text: minhaAvaliacao['comentario']?.toString() ?? '');
    bool salvandoAvaliacao = false;

    final resultado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctxBottom) {
        return StatefulBuilder(
          builder: (ctx, setBottomState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctxBottom).viewInsets.bottom + 16,
                left: 12,
                right: 12,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(ctxBottom).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C4DFF).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.rate_review_rounded, color: Color(0xFF7C4DFF), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Minha avaliação',
                              style: Theme.of(ctxBottom).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: salvandoAvaliacao ? null : () => Navigator.of(ctxBottom).pop(false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F5FF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Nota',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                                const Spacer(),
                                EstrelasAvaliacao(
                                  avaliacao: notaSelecionada == 0 ? null : notaSelecionada,
                                  tamanho: 28,
                                  clicavel: true,
                                  aoClicar: (v) => setBottomState(
                                      () => notaSelecionada = v == 0 ? 0 : v),
                                ),
                              ],
                            ),
                            if (notaSelecionada > 0) ...[
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.only(left: 2),
                                child: Text(
                                  notaSelecionada == 1
                                      ? '1 estrela. Não gostei muito. 😕'
                                      : notaSelecionada == 2
                                          ? '2 estrelas. Deixa a desejar. 🫤'
                                          : notaSelecionada == 3
                                              ? '3 estrelas. Leitura mediana. 🙂'
                                              : notaSelecionada == 4
                                                  ? '4 estrelas! Muito bom! 🥰'
                                                  : '5 estrelas! Livro incrível! 😍',
                                  style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 13),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: comentarioController,
                        minLines: 3,
                        maxLines: 6,
                        maxLength: 500,
                        decoration: InputDecoration(
                          labelText: 'Comentário (opcional)',
                          hintText: 'O que você achou deste livro?',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          prefixIcon: const Icon(Icons.comment_outlined),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        readOnly: true,
                        controller: TextEditingController(
                          text: dataSelecionada != null ? formatarData(dataSelecionada) : '',
                        ),
                        onTap: () async {
                          final hoje = DateTime.now();
                          final data = await showDatePicker(
                            context: ctxBottom,
                            initialDate: dataSelecionada ?? hoje,
                            firstDate: DateTime(1900),
                            lastDate: hoje,
                            locale: const Locale('pt', 'BR'),
                            confirmText: 'Confirmar',
                            cancelText: 'Cancelar',
                            helpText: 'Data de conclusão',
                          );
                          if (data != null) {
                            setBottomState(() => dataSelecionada = data);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Data de conclusão (opcional)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          prefixIcon: const Icon(Icons.calendar_today_rounded, color: Color(0xFF7C4DFF)),
                          suffixIcon: dataSelecionada != null
                              ? IconButton(
                                  icon: const Icon(Icons.close, color: Color(0xFF7C4DFF)),
                                  onPressed: () => setBottomState(() => dataSelecionada = null),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: salvandoAvaliacao
                              ? null
                              : () async {
                                  if (notaSelecionada == 0) {
                                    mostrarSnackbarAviso(ctxBottom, 'Selecione uma nota de 1 a 5.');
                                    return;
                                  }
                                  setBottomState(() => salvandoAvaliacao = true);
                                  try {
                                    final response = await AuthService.post(
                                      '/livros/${widget.livro['id']}/avaliacoes',
                                      {
                                        'nota': notaSelecionada,
                                        'comentario': comentarioController.text.trim().isEmpty
                                            ? null
                                            : comentarioController.text.trim(),
                                        'dataConclusao': dataSelecionada != null
                                            ? formatarDataISO(dataSelecionada)
                                            : null,
                                      },
                                    );
                                    if (!ctxBottom.mounted) return;
                                    setBottomState(() => salvandoAvaliacao = false);
                                    if (response.statusCode >= 200 && response.statusCode < 300) {
                                      mostrarSnackbarSucesso(ctxBottom, 'Avaliação publicada!');
                                      Navigator.of(ctxBottom).pop(true);
                                    } else {
                                      mostrarSnackbarErro(ctxBottom, 'Não foi possível publicar. Tente novamente.');
                                    }
                                  } catch (_) {
                                    if (!ctxBottom.mounted) return;
                                    setBottomState(() => salvandoAvaliacao = false);
                                    mostrarSnackbarErro(ctxBottom, 'Falha na conexão.');
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C4DFF),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: salvandoAvaliacao
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : const Text('Publicar avaliação',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (resultado == true) {
      _avaliacao = notaSelecionada == 0 ? null : notaSelecionada;
      _dataConclusao = dataSelecionada;
      _carregarAvaliacoesComunidade();
    }
  }

  Future<void> _selecionarDaGaleria() async {
    try {
      final XFile? imagem = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (imagem != null) {
        final bytes = await imagem.readAsBytes();
        if (!mounted) return;
        setState(() {
          _capaBytes = bytes;
          _capaUrlLocal = null;
          _tipoCapa = 'bytes';
        });
      }
    } catch (e) {
      if (!mounted) return;
      mostrarSnackbarErro(context, 'Nao foi possivel selecionar a imagem.');
    }
  }

  Future<void> _tirarFotoComCamera() async {
    try {
      final XFile? imagem = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (imagem != null) {
        final bytes = await imagem.readAsBytes();
        if (!mounted) return;
        setState(() {
          _capaBytes = bytes;
          _capaUrlLocal = null;
          _tipoCapa = 'bytes';
        });
      }
    } catch (e) {
      if (!mounted) return;
      mostrarSnackbarErro(context, 'Nao foi possivel tirar a foto.');
    }
  }

  void _removerCapa() {
    setState(() {
      _capaUrlLocal = null;
      _capaBytes = null;
      _tipoCapa = null;
    });
  }

  Future<void> _abrirDialogBuscarCapa() async {
    final buscaController = TextEditingController(text: _tituloController.text.trim());
    final formKey = GlobalKey<FormState>();
    bool buscandoInterno = false;

    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctxDialog) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Buscar capa do livro'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Digite o título para procurar a capa do livro.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: buscaController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Título do livro',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Digite um título para buscar';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => buscandoInterno = true);
                        final capa = await GoogleBooksService.buscarCapa(buscaController.text);
                        if (!mounted) return;
                        setDialogState(() => buscandoInterno = false);
                        setState(() {
                          _capaUrlLocal = capa;
                          _capaBytes = null;
                          _tipoCapa = capa != null ? 'url' : null;
                        });
                        Navigator.of(ctxDialog).pop(capa != null);
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: buscandoInterno
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setDialogState(() => buscandoInterno = true);
                                final capa = await GoogleBooksService.buscarCapa(buscaController.text);
                                if (!mounted) return;
                                setDialogState(() => buscandoInterno = false);
                                setState(() {
                                  _capaUrlLocal = capa;
                                  _capaBytes = null;
                                  _tipoCapa = capa != null ? 'url' : null;
                                });
                                Navigator.of(ctxDialog).pop(capa != null);
                              },
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: buscandoInterno
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.search_rounded, size: 18),
                        label: Text(buscandoInterno ? 'Buscando...' : 'Buscar', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: buscandoInterno ? null : () => Navigator.of(ctxDialog).pop(false),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Cancelar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;
    if (resultado == true) {
      mostrarSnackbarSucesso(context, 'Capa encontrada!');
    } else if (resultado == false) {
      mostrarSnackbarAviso(context, 'Nenhuma capa foi encontrada para esse título.');
    }
  }

  @override
  void initState() {
    super.initState();
    _tituloController = TextEditingController(text: widget.livro['titulo']?.toString() ?? '');
    _autorController = TextEditingController(text: widget.livro['autor']?.toString() ?? '');
    _editoraController = TextEditingController(text: widget.livro['editora']?.toString() ?? '');
    _generoController = TextEditingController(text: widget.livro['genero']?.toString() ?? '');
    _descricaoController = TextEditingController(text: widget.livro['descricao']?.toString() ?? '');
    final tot = widget.livro['totalPaginas'];
    final pag = widget.livro['paginaAtual'];
    _totalPaginasController = TextEditingController(
        text: (tot is int || tot is double) ? tot.toString() : (tot is String ? tot : ''));
    _paginaAtualController = TextEditingController(
        text: (pag is int || pag is double) ? pag.toString() : (pag is String ? pag : ''));
    _lido = widget.livro['lido'] == true;
    final st = widget.livro['statusLeitura']?.toString().toUpperCase();
    _statusLeitura = st == 'QUERO_LER' || st == 'LENDO' || st == 'LIDO'
        ? st ?? (_lido ? 'LIDO' : 'QUERO_LER')
        : (_lido ? 'LIDO' : 'QUERO_LER');
    _avaliacao = _avaliacaoOriginal();
    _dataConclusao = parseDataISO(widget.livro['dataConclusao']?.toString())
        ?? parseDataISO(widget.livro['dataFimLeitura']?.toString());
    _dataInicio = parseDataISO(widget.livro['dataInicioLeitura']?.toString());
    final imgOriginal = widget.livro['imagem']?.toString();
    if (imgOriginal != null && imgOriginal.isNotEmpty) {
      final ehBase64 = imgOriginal.startsWith('data:image') || imgOriginal.length > 1000;
      _tipoCapa = ehBase64 ? 'bytes' : 'url';
      if (ehBase64) {
        try {
          if (imgOriginal.startsWith('data:image')) {
            final commaIdx = imgOriginal.indexOf(',');
            _capaBytes = base64Decode(commaIdx != -1 ? imgOriginal.substring(commaIdx + 1) : imgOriginal);
          } else {
            _capaBytes = base64Decode(imgOriginal);
          }
        } catch (_) {
          _capaBytes = null;
          _tipoCapa = null;
        }
      } else {
        _capaUrlLocal = imgOriginal;
      }
    }
    _carregarAvaliacoesComunidade();
  }

  void _cancelarEdicao() {
    _tituloController.text = widget.livro['titulo']?.toString() ?? '';
    _autorController.text = widget.livro['autor']?.toString() ?? '';
    _editoraController.text = widget.livro['editora']?.toString() ?? '';
    _generoController.text = widget.livro['genero']?.toString() ?? '';
    _descricaoController.text = widget.livro['descricao']?.toString() ?? '';
    final tot = widget.livro['totalPaginas'];
    final pag = widget.livro['paginaAtual'];
    _totalPaginasController.text = (tot is int || tot is double) ? tot.toString() : (tot is String ? tot : '');
    _paginaAtualController.text = (pag is int || pag is double) ? pag.toString() : (pag is String ? pag : '');
    _lido = widget.livro['lido'] == true;
    final st = widget.livro['statusLeitura']?.toString().toUpperCase();
    _statusLeitura = st == 'QUERO_LER' || st == 'LENDO' || st == 'LIDO'
        ? st ?? (_lido ? 'LIDO' : 'QUERO_LER')
        : (_lido ? 'LIDO' : 'QUERO_LER');
    _avaliacao = _avaliacaoOriginal();
    _dataConclusao = parseDataISO(widget.livro['dataConclusao']?.toString())
        ?? parseDataISO(widget.livro['dataFimLeitura']?.toString());
    _dataInicio = parseDataISO(widget.livro['dataInicioLeitura']?.toString());
    final imgOriginal = widget.livro['imagem']?.toString();
    _capaBytes = null;
    _capaUrlLocal = null;
    _tipoCapa = null;
    if (imgOriginal != null && imgOriginal.isNotEmpty) {
      final ehBase64 = imgOriginal.startsWith('data:image') || imgOriginal.length > 1000;
      _tipoCapa = ehBase64 ? 'bytes' : 'url';
      if (ehBase64) {
        try {
          if (imgOriginal.startsWith('data:image')) {
            final commaIdx = imgOriginal.indexOf(',');
            _capaBytes = base64Decode(commaIdx != -1 ? imgOriginal.substring(commaIdx + 1) : imgOriginal);
          } else {
            _capaBytes = base64Decode(imgOriginal);
          }
        } catch (_) {
          _capaBytes = null;
          _tipoCapa = null;
        }
      } else {
        _capaUrlLocal = imgOriginal;
      }
    }
    setState(() => _editando = false);
  }

  Future<void> _salvarEdicao() async {
    setState(() => _salvando = true);

    String? imagemParaSalvar;
    if (_tipoCapa == 'bytes' && _capaBytes != null) {
      imagemParaSalvar = base64Encode(_capaBytes!);
    } else if (_tipoCapa == 'url') {
      imagemParaSalvar = _capaUrlLocal;
    } else if (_tipoCapa == null) {
      imagemParaSalvar = null;
    } else {
      imagemParaSalvar = widget.livro['imagem']?.toString();
    }

    final avaliacaoParaEnviar = _avaliacao;
    final dataParaEnviar = _lido && _dataConclusao != null
        ? formatarDataISO(_dataConclusao)
        : null;
    final totalPaginas = int.tryParse(_totalPaginasController.text.trim());
    final paginaAtual = int.tryParse(_paginaAtualController.text.trim());

    final livroAtualizado = {
      'titulo': _tituloController.text.trim(),
      'autor': _autorController.text.trim(),
      'editora': _editoraController.text.trim(),
      'genero': _generoController.text.trim(),
      'descricao': _descricaoController.text.trim(),
      'imagem': imagemParaSalvar,
      'lido': _lido,
      'statusLeitura': _statusLeitura,
      if (totalPaginas != null) 'totalPaginas': totalPaginas,
      if (paginaAtual != null) 'paginaAtual': paginaAtual,
      if (_dataInicio != null) 'dataInicioLeitura': formatarDataISO(_dataInicio),
      if (_dataConclusao != null && _statusLeitura.toUpperCase() == 'LIDO')
        'dataFimLeitura': formatarDataISO(_dataConclusao),
    };

    try {
      final response = await AuthService.put(
        '/livros/${widget.livro['id']}',
        livroAtualizado,
      );

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (avaliacaoParaEnviar != null || dataParaEnviar != null) {
          try {
            await AuthService.post('/livros/${widget.livro['id']}/avaliacoes', {
              'nota': avaliacaoParaEnviar ?? 5,
              'comentario': null,
              'dataConclusao': dataParaEnviar,
            });
          } catch (_) {}
        }
        setState(() => _salvando = false);
        setState(() => _editando = false);
        _carregarAvaliacoesComunidade();
        mostrarSnackbarSucesso(context, 'Livro atualizado com sucesso.');
        Navigator.pop(context, true);
      } else {
        setState(() => _salvando = false);
        final mensagem = _mensagemErro(
          response,
          'Nao foi possivel atualizar o livro.',
        );
        mostrarSnackbarErro(context, 'Erro ao atualizar o livro: $mensagem');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      mostrarSnackbarErro(context, 'Falha na requisicao. Tente novamente.');
    }
  }

  Future<void> _deletarLivro() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deletar Livro'),
        content: const Text('Tem certeza de deseja remover este livro?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Deletar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final livroDeletado = Map<String, dynamic>.from(widget.livro);
    final livroId = widget.livro['id'];

    bool desfez = false;
    bool deletouNoBackend = false;

    void executarDelecaoReal() async {
      if (deletouNoBackend || desfez) return;
      deletouNoBackend = true;
      try {
        await AuthService.delete('/livros/$livroId');
      } catch (_) {}
    }

    Navigator.of(context).pop({
      'deletado': true,
      'livro': livroDeletado,
      'adiado': true,
    });

    final timerDelecao = Timer(const Duration(seconds: 4), () {
      executarDelecaoReal();
    });

    Future.delayed(Duration.zero, () {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger
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
                    '"${(livroDeletado['titulo'] ?? 'Livro').toString().length > 32 ? '${(livroDeletado['titulo'] ?? 'Livro').toString().substring(0, 32)}...' : livroDeletado['titulo'] ?? 'Livro'}" foi movido para a lixeira',
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
                desfez = true;
                timerDelecao.cancel();
              },
            ),
          ),
        );
    });
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _autorController.dispose();
    _editoraController.dispose();
    _generoController.dispose();
    _descricaoController.dispose();
    _totalPaginasController.dispose();
    _paginaAtualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tamanhoTela = MediaQuery.of(context).size;
    final menorLado = tamanhoTela.shortestSide;
    final telaPequena = menorLado < 360;

    final alturaCapa = (tamanhoTela.height * 0.28).clamp(140.0, 220.0);
    final larguraCapa = (alturaCapa * 0.68).clamp(100.0, 150.0);
    final paddingSecao = telaPequena ? const EdgeInsets.all(14) : const EdgeInsets.all(20);
    final espacamentoSecao = SizedBox(height: telaPequena ? 16 : 24);
    final espacamentoInterno = SizedBox(height: telaPequena ? 10 : 16);
    final fonteTituloAppBar = telaPequena ? 24.0 : 30.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final podeSair = await _confirmarSaidaSemSalvar();
        if (podeSair && mounted) {
          if (_editando) {
            Navigator.of(context).pop(false);
          } else {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF7C4DFF), Color(0xFFB28CFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: Text(
                _editando ? 'Editar Livro' : 'Detalhes',
                style: TextStyle(
                  fontFamily: 'Diphylleia',
                  fontSize: fonteTituloAppBar,
                  letterSpacing: 0.2,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            if (!_editando)
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => setState(() => _editando = true),
              ),
            if (!_editando)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: _deletarLivro,
              ),
          ],
        ),
        body: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: telaPequena ? 12 : 16,
            vertical: telaPequena ? 10 : 16,
          ),
          child: ListView(
            children: [
              Container(
                width: double.infinity,
                padding: paddingSecao,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    if (!_editando) ...[
                      CapaLivro(
                        livro: widget.livro,
                        heroTag: heroTagLivro(widget.livro),
                        largura: larguraCapa,
                        altura: alturaCapa,
                        borderRadius: 16,
                      ),
                      espacamentoInterno,
                      Text(
                        widget.livro['titulo'] ?? 'Sem Título',
                        style: TextStyle(
                          fontFamily: 'Diphylleia',
                          fontSize: telaPequena ? 24 : 30,
                          fontWeight: FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: telaPequena ? 6 : 10),
                      Text(
                        widget.livro['autor'] ?? 'Autor Desconhecido',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: telaPequena ? 8 : 14),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (widget.livro['editora']?.toString().isNotEmpty == true)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.business_center_rounded, size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.livro['editora']!.toString(),
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          if (widget.livro['genero']?.toString().isNotEmpty == true)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3EEFF),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.category_rounded, size: 15, color: Color(0xFF7C4DFF)),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.livro['genero']!.toString(),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF7C4DFF)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ] else ...[
                      if (_tipoCapa == 'bytes' && _capaBytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(
                            _capaBytes!,
                            height: alturaCapa,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              height: alturaCapa,
                              width: larguraCapa,
                              color: const Color(0xFFF1EEFF),
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image, size: 40),
                            ),
                          ),
                        )
                      else if (_tipoCapa == 'url' && _capaUrlLocal != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl: _capaUrlLocal!,
                            height: alturaCapa,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => SizedBox(
                              height: alturaCapa,
                              child: const Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (context, url, error) => Container(
                              height: alturaCapa,
                              width: larguraCapa,
                              color: Colors.grey.shade300,
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image, size: 40),
                            ),
                          ),
                        )
                      else
                        Container(
                          height: alturaCapa,
                          width: larguraCapa,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1EEFF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.menu_book_rounded,
                                size: telaPequena ? 42 : 52,
                                color: Color(0xFF7C4DFF),
                              ),
                              SizedBox(height: telaPequena ? 8 : 12),
                              Text(
                                'Sem capa',
                                style: TextStyle(
                                  fontSize: telaPequena ? 14 : 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF5F5F7A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      espacamentoInterno,
                      Text(
                        'Capa do livro',
                        style: TextStyle(fontSize: telaPequena ? 16 : 18, fontWeight: FontWeight.w700, color: Color(0xFF2A2A38)),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: telaPequena ? 6 : 8),
                      const Text(
                        'Edite a capa: tire uma foto, selecione da galeria ou busque pelo título.',
                        textAlign: TextAlign.center,
                      ),
                      espacamentoInterno,
                      if (telaPequena)
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton.icon(
                                onPressed: _tirarFotoComCamera,
                                icon: const Icon(Icons.camera_alt_rounded, size: 16, color: Color(0xFF7C4DFF)),
                                label: const Text('Câmera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF7C4DFF))),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton.icon(
                                onPressed: _selecionarDaGaleria,
                                icon: const Icon(Icons.image_outlined, size: 16, color: Color(0xFF7C4DFF)),
                                label: const Text('Galeria', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF7C4DFF))),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton.icon(
                                onPressed: _abrirDialogBuscarCapa,
                                icon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF7C4DFF)),
                                label: const Text('Buscar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF7C4DFF))),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _tirarFotoComCamera,
                                icon: const Icon(Icons.camera_alt_rounded, size: 16, color: Color(0xFF7C4DFF)),
                                label: const Text('Câmera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF7C4DFF))),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _selecionarDaGaleria,
                                icon: const Icon(Icons.image_outlined, size: 16, color: Color(0xFF7C4DFF)),
                                label: const Text('Galeria', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF7C4DFF))),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _abrirDialogBuscarCapa,
                                icon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF7C4DFF)),
                                label: const Text('Buscar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF7C4DFF))),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (_tipoCapa != null) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _removerCapa,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFB3261E),
                              side: const BorderSide(color: Color(0xFFB3261E)),
                            ),
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: const Text('Remover capa'),
                          ),
                        ),
                      ],
                    ],
                    espacamentoInterno,
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        widget.livro['titulo'] ?? 'Livro sem título',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(height: telaPequena ? 4 : 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        widget.livro['autor'] ?? 'Autor desconhecido',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(height: telaPequena ? 10 : 12),
                    EstrelasAvaliacao(
                      avaliacao: _editando ? _avaliacao : (widget.livro['avaliacao'] is int ? widget.livro['avaliacao'] : (widget.livro['avaliacao'] is double ? (widget.livro['avaliacao'] as double).toInt() : null)),
                      tamanho: telaPequena ? 24 : 28,
                    ),
                  ],
                ),
              ),
              espacamentoSecao,
              Container(
                width: double.infinity,
                padding: paddingSecao,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _editando ? 'Editar livro' : 'Informações do livro',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: telaPequena ? 4 : 6),
                    Text(
                      _editando
                          ? 'Altere os dados abaixo e clique em Salvar para confirmar.'
                          : 'Veja os dados cadastrados para este livro.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    espacamentoInterno,
                    if (!_editando) ...[
                      InfoTile(
                        label: 'Título',
                        value: widget.livro['titulo']?.toString(),
                      ),
                      InfoTile(
                        label: 'Autor',
                        value: widget.livro['autor']?.toString(),
                      ),
                      InfoTile(
                        label: 'Editora',
                        value: widget.livro['editora']?.toString(),
                      ),
                      InfoTile(
                        label: 'Gênero',
                        value: widget.livro['genero']?.toString(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Descrição',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F5FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          (widget.livro['descricao']?.toString().trim().isNotEmpty == true)
                              ? widget.livro['descricao'].toString()
                              : 'Não informado',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: const Color(0xFF2A2A38),
                                height: 1.35,
                              ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Builder(
                        builder: (_) {
                          final info = InfoProgressoLivro.fromMap(widget.livro);
                          final info2 = infoStatusLeitura(context, _statusLeitura);
                          final temPaginas = info.totalPaginas != null;
                          final dtInicio = parseDataISO(widget.livro['dataInicioLeitura']?.toString());
                          final dtFim = parseDataISO(widget.livro['dataConclusao']?.toString())
                              ?? parseDataISO(widget.livro['dataFimLeitura']?.toString());
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                            decoration: BoxDecoration(
                              color: info2.cor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: info2.cor.withValues(alpha: 0.5),
                                width: 1.1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(info2.icone, color: info2.cor, size: 26),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        info2.rotulo,
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: info2.cor,
                                            ),
                                      ),
                                    ),
                                    ChipStatusLeitura(status: _statusLeitura, compacto: true),
                                  ],
                                ),
                                if (temPaginas) ...[
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: BarraProgressoCircular(
                                          percentual: info.progresso,
                                          tamanho: 56,
                                          espessura: 5.5,
                                          corFundo: info2.cor.withValues(alpha: 0.2),
                                          corPrimaria: info2.cor,
                                          centro: Text(
                                            '${info.progresso.toInt()}%',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: info2.cor,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Página ${info.paginaAtual ?? 0} / ${info.totalPaginas}',
                                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            const SizedBox(height: 3),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(999),
                                              child: LinearProgressIndicator(
                                                value: (info.progresso / 100).clamp(0.0, 1.0),
                                                minHeight: 6,
                                                backgroundColor: info2.cor.withValues(alpha: 0.15),
                                                valueColor: AlwaysStoppedAnimation<Color>(info2.cor),
                                              ),
                                            ),
                                            if (dtInicio != null || dtFim != null) ...[
                                              const SizedBox(height: 10),
                                              Wrap(
                                                spacing: 14,
                                                runSpacing: 6,
                                                children: [
                                                  if (dtInicio != null)
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.calendar_month_rounded,
                                                            size: 16, color: Color(0xFF7C4DFF)),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          'Início: ${formatarData(dtInicio)}',
                                                          style: Theme.of(context).textTheme.bodySmall,
                                                        ),
                                                      ],
                                                    ),
                                                  if (dtFim != null)
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.celebration_rounded,
                                                            size: 16, color: Color(0xFF2E7D32)),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          'Fim: ${formatarData(dtFim)}',
                                                          style: Theme.of(context).textTheme.bodySmall,
                                                        ),
                                                      ],
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (!temPaginas && (dtInicio != null || dtFim != null)) ...[
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 14,
                                    runSpacing: 6,
                                    children: [
                                      if (dtInicio != null)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.calendar_month_rounded,
                                                size: 16, color: Color(0xFF7C4DFF)),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Início: ${formatarData(dtInicio)}',
                                              style: Theme.of(context).textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      if (dtFim != null)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.celebration_rounded,
                                                size: 16, color: Color(0xFF2E7D32)),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Fim: ${formatarData(dtFim)}',
                                              style: Theme.of(context).textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Altere em "Editar informações".',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F5FF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE0D7FF), width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.people_alt_rounded, color: Color(0xFF7C4DFF), size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Avaliações da comunidade',
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFF2A2A38),
                                            ),
                                      ),
                                      const SizedBox(height: 1),
                                      _carregandoAvaliacoes
                                          ? const Text('Carregando...',
                                              style: TextStyle(color: Color(0xFF8A8A9D), fontSize: 13))
                                          : Text(
                                              '$_totalAvaliacoes avaliaç${_totalAvaliacoes == 1 ? 'ão' : 'ões'}${_mediaAvaliacoes != null ? ' · média ⭐${_mediaAvaliacoes!.toStringAsFixed(1)}' : ''}',
                                              style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 13),
                                            ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                SizedBox(
                                  height: 42,
                                  child: OutlinedButton.icon(
                                    onPressed: _carregandoAvaliacoes ? null : _abrirMinhaAvaliacao,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF7C4DFF),
                                      side: const BorderSide(color: Color(0xFF7C4DFF), width: 1.2),
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    icon: const Icon(Icons.rate_review_outlined, size: 16),
                                    label: const Text(
                                      'Minha',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (_carregandoAvaliacoes)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C4DFF)),
                                  ),
                                ),
                              )
                            else if (_listaAvaliacoes.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Icon(Icons.chat_bubble_outline_rounded,
                                        size: 18, color: const Color(0xFF7C4DFF).withValues(alpha: 0.6)),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Ainda ninguém avaliou esse livro publicamente. Seja o primeiro!',
                                        style: TextStyle(color: Color(0xFF6B6B80), fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ..._listaAvaliacoes.map((av) {
                                final nome = av['usuarioNome']?.toString() ?? 'Usuário anônimo';
                                final foto = av['usuarioFotoPerfil']?.toString();
                                final nota = av['nota'] is int ? av['nota'] as int : 0;
                                final comentario = av['comentario']?.toString();
                                final dataCriacao = av['dataCriacao']?.toString();
                                final dataFormatada = dataCriacao != null && dataCriacao.length >= 10
                                    ? formatarData(parseDataISO(dataCriacao.substring(0, 10)))
                                    : null;
                                final isMinha = av['usuarioId'] != null && av['usuarioId'] == AuthService.usuarioId;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isMinha
                                            ? const Color(0xFF7C4DFF).withValues(alpha: 0.4)
                                            : const Color(0xFFE9E6F2),
                                        width: isMinha ? 1.2 : 0.6,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () => _abrirPerfilAutor(av),
                                                borderRadius: BorderRadius.circular(24),
                                                child: CircleAvatar(
                                                  radius: 16,
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
                                                            fontSize: 14,
                                                          ),
                                                        )
                                                      : null,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Material(
                                                          color: Colors.transparent,
                                                          child: InkWell(
                                                            onTap: () => _abrirPerfilAutor(av),
                                                            borderRadius: BorderRadius.circular(6),
                                                            child: Text(
                                                              isMinha ? '$nome (você)' : nome,
                                                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                                    fontWeight: FontWeight.w700,
                                                                    color: const Color(0xFF7C4DFF),
                                                                    decoration: TextDecoration.underline,
                                                                    decorationColor: const Color(0xFF7C4DFF).withValues(alpha: 0.4),
                                                                  ),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      EstrelasAvaliacao(
                                                        avaliacao: nota == 0 ? null : nota,
                                                        tamanho: 14,
                                                      ),
                                                    ],
                                                  ),
                                                  if (dataFormatada != null) ...[
                                                    const SizedBox(height: 1),
                                                    Text(
                                                      dataFormatada,
                                                      style: const TextStyle(
                                                        color: Color(0xFF8A8A9D),
                                                        fontSize: 11.5,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (comentario != null && comentario.trim().isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Padding(
                                            padding: const EdgeInsets.only(left: 42),
                                            child: Text(
                                              comentario,
                                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                    color: const Color(0xFF3B3B4B),
                                                    height: 1.35,
                                                  ),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: BotaoCurtidaAvaliacao(
                                            avaliacao: av,
                                            tamanhoIcone: 19,
                                            compacto: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => setState(() => _editando = true),
                          icon: const Icon(Icons.edit, size: 20),
                          label: const Text('Editar informações'),
                        ),
                      ),
                    ],
                    if (_editando) ...[
                      TextFormField(
                        controller: _tituloController,
                        decoration: const InputDecoration(labelText: 'Título'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _autorController,
                        decoration: const InputDecoration(labelText: 'Autor'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _editoraController,
                        decoration: const InputDecoration(labelText: 'Editora'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _generoController,
                        decoration: const InputDecoration(labelText: 'Gênero'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descricaoController,
                        maxLength: 500,
                        decoration: const InputDecoration(labelText: 'Descrição'),
                        maxLines: 3,
                        onChanged: (valor) {
                          if (valor.length >= 500 && !_jaAvisouLimiteDesc) {
                            _jaAvisouLimiteDesc = true;
                            mostrarSnackbarAviso(context, 'Limite de caracteres atingido.');
                          }
                          if (valor.length < 495) {
                            _jaAvisouLimiteDesc = false;
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF1C1C27)
                              : const Color(0xFFF3F0FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF2B2B38)
                                : const Color(0xFFE0D6FF),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.bar_chart_rounded,
                                    color: Color(0xFF7C4DFF), size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Progresso da leitura',
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                  ),
                                ),
                                ChipStatusLeitura(status: _statusLeitura),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _botaoStatus('QUERO_LER', Icons.bookmark_border_rounded, 'Quero ler'),
                                const SizedBox(width: 8),
                                _botaoStatus('LENDO', Icons.menu_book_rounded, 'Lendo'),
                                const SizedBox(width: 8),
                                _botaoStatus('LIDO', Icons.check_circle_rounded, 'Lido'),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _totalPaginasController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Total de páginas',
                                      prefixIcon: Icon(Icons.menu_book_rounded, color: Color(0xFF7C4DFF)),
                                      hintText: 'Ex: 280',
                                    ),
                                    onChanged: (v) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _paginaAtualController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Página atual',
                                      prefixIcon: Icon(Icons.label_important_rounded, color: Color(0xFF7C4DFF)),
                                      hintText: 'Ex: 47',
                                    ),
                                    onChanged: (v) => setState(() {}),
                                  ),
                                ),
                              ],
                            ),
                            if (_statusLeitura == 'LENDO' || _statusLeitura == 'LIDO') ...[
                              const SizedBox(height: 12),
                              TextFormField(
                                readOnly: true,
                                controller: TextEditingController(text: formatarData(_dataInicio)),
                                onTap: _selecionarDataInicio,
                                decoration: InputDecoration(
                                  labelText: 'Data de início',
                                  prefixIcon: const Icon(Icons.event_available_rounded,
                                      color: Color(0xFF7C4DFF)),
                                  suffixIcon: _dataInicio != null
                                      ? IconButton(
                                          icon: const Icon(Icons.close, color: Color(0xFF7C4DFF)),
                                          onPressed: () => setState(() => _dataInicio = null),
                                          tooltip: 'Limpar data',
                                        )
                                      : null,
                                  hintText: 'Quando você começou?',
                                ),
                              ),
                              if (_statusLeitura == 'LIDO')
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: TextFormField(
                                    readOnly: true,
                                    controller: TextEditingController(text: formatarData(_dataConclusao)),
                                    onTap: _selecionarData,
                                    decoration: InputDecoration(
                                      labelText: 'Data de conclusão',
                                      prefixIcon: const Icon(Icons.celebration_rounded,
                                          color: Color(0xFF2E7D32)),
                                      suffixIcon: _dataConclusao != null
                                          ? IconButton(
                                              icon: const Icon(Icons.close, color: Color(0xFF7C4DFF)),
                                              onPressed: () => setState(() => _dataConclusao = null),
                                              tooltip: 'Limpar data',
                                            )
                                          : null,
                                      hintText: 'Quando terminou de ler?',
                                    ),
                                  ),
                                ),
                            ],
                            if (_statusLeitura == 'LENDO' &&
                                int.tryParse(_totalPaginasController.text) != null &&
                                int.tryParse(_totalPaginasController.text)! > 0) ...[
                              const SizedBox(height: 14),
                              Builder(
                                builder: (_) {
                                  final tot = int.tryParse(_totalPaginasController.text)!;
                                  final at = int.tryParse(_paginaAtualController.text) ?? 0;
                                  final p = ((at.clamp(0, tot) * 100) / tot).clamp(0, 100);
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: LinearProgressIndicator(
                                      value: p / 100,
                                      minHeight: 6,
                                      backgroundColor: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C4DFF)),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      espacamentoInterno,
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: telaPequena ? 12 : 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F5FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.star_rate_rounded, color: Color(0xFF7C4DFF)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Sua avaliação',
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF2A2A38),
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: EstrelasAvaliacao(
                                avaliacao: _avaliacao,
                                tamanho: telaPequena ? 28 : 32,
                                clicavel: true,
                                aoClicar: (valor) => setState(() => _avaliacao = valor == 0 ? null : valor),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: Text(
                                _avaliacao == null || _avaliacao == 0
                                    ? 'Toque em uma estrela para avaliar (1 a 5).'
                                    : _avaliacao == 1
                                        ? '1 estrela. Não gostei muito. 😕'
                                        : _avaliacao == 2
                                            ? '2 estrelas. Deixa a desejar. 🫤'
                                            : _avaliacao == 3
                                                ? '3 estrelas. Leitura mediana. 🙂'
                                                : _avaliacao == 4
                                                    ? '4 estrelas! Muito bom! 🥰'
                                                    : '5 estrelas! Livro incrível! 😍',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF6B6B80),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      espacamentoSecao,
                      if (telaPequena)
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton(
                                onPressed: _salvando ? null : _cancelarEdicao,
                                child: const Text('Cancelar'),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _salvando ? null : _salvarEdicao,
                                child: _salvando
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Salvar alterações'),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _salvando ? null : _cancelarEdicao,
                                child: const Text('Cancelar'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: _salvando ? null : _salvarEdicao,
                                child: _salvando
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Salvar alterações'),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
