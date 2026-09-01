import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/google_books_service.dart';
import 'package:frontend/widgets/estrelas_avaliacao.dart';
import 'package:frontend/widgets/status_progresso_leitura.dart';
import 'package:frontend/utils/app_theme.dart';
import 'package:frontend/utils/formatters.dart';
import 'package:frontend/utils/snackbars.dart';

class CadastroLivroPage extends StatefulWidget {
  final Map<String, dynamic>? livroInicial;
  const CadastroLivroPage({super.key, this.livroInicial});

  @override
  State<CadastroLivroPage> createState() => _CadastroLivroPageState();
}

class _CadastroLivroPageState extends State<CadastroLivroPage> {
  final _formKey = GlobalKey<FormState>();

  final _tituloController = TextEditingController();
  final _autorController = TextEditingController();
  final _editoraController = TextEditingController();
  final _generoController = TextEditingController();
  final _descricaoController = TextEditingController();

  bool _salvando = false;
  String? _capaUrl;
  String? _tituloDaCapa;
  bool _jaAvisouLimiteDesc = false;
  bool _lido = false;
  String _statusLeitura = 'QUERO_LER';
  final _totalPaginasController = TextEditingController();
  final _paginaAtualController = TextEditingController();
  DateTime? _dataInicio;
  int? _avaliacao;
  DateTime? _dataConclusao;
  Uint8List? _capaBytes;
  String? _tipoCapa;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final inicial = widget.livroInicial;
    if (inicial != null) {
      _tituloController.text = inicial['titulo']?.toString() ?? '';
      _autorController.text = inicial['autor']?.toString() ?? '';
      _editoraController.text = inicial['editora']?.toString() ?? '';
      _generoController.text = inicial['genero']?.toString() ?? '';
      _descricaoController.text = inicial['descricao']?.toString() ?? '';
      final img = inicial['imagem'];
      if (img != null && img.toString().isNotEmpty) {
        _capaUrl = img.toString();
        _tipoCapa = 'url';
        _tituloDaCapa = inicial['titulo']?.toString();
      }
      final totalPags = inicial['totalPaginas'];
      if (totalPags != null) {
        _totalPaginasController.text = totalPags.toString();
      }
      final pagAtual = inicial['paginaAtual'];
      if (pagAtual != null) {
        _paginaAtualController.text = pagAtual.toString();
      }
      final st = inicial['statusLeitura']?.toString().toUpperCase();
      if (st != null && (st == 'QUERO_LER' || st == 'LENDO' || st == 'LIDO')) {
        _statusLeitura = st;
        _lido = st == 'LIDO';
      } else {
        final lidoCampo = inicial['lido'];
        if (lidoCampo is bool && lidoCampo) {
          _statusLeitura = 'LIDO';
          _lido = true;
        }
      }
      final aval = inicial['avaliacao'];
      if (aval != null) {
        int? nota;
        if (aval is int) {
          nota = aval;
        } else if (aval is double) {
          nota = aval.toInt();
        } else if (aval is num) {
          nota = aval.toInt();
        } else {
          nota = int.tryParse(aval.toString());
        }
        if (nota != null && nota >= 1 && nota <= 5) {
          _avaliacao = nota;
        }
      }
      final dIni = inicial['dataInicioLeitura']?.toString();
      if (dIni != null && dIni.trim().isNotEmpty) {
        final di = DateTime.tryParse(dIni.replaceAll('/', '-'));
        if (di != null) {
          _dataInicio = di;
        } else {
          final partes = dIni.split('/');
          if (partes.length == 3) {
            _dataInicio = DateTime(int.parse(partes[2]), int.parse(partes[1]), int.parse(partes[0]));
          }
        }
      }
      final dFim = inicial['dataFimLeitura']?.toString() ?? inicial['dataConclusao']?.toString();
      if (dFim != null && dFim.trim().isNotEmpty) {
        final df = DateTime.tryParse(dFim.replaceAll('/', '-'));
        if (df != null) {
          _dataConclusao = df;
        } else {
          final partes = dFim.split('/');
          if (partes.length == 3) {
            _dataConclusao = DateTime(int.parse(partes[2]), int.parse(partes[1]), int.parse(partes[0]));
          }
        }
      }
    }
  }

  bool _formularioFoiAlterado() {
    return _tituloController.text.trim().isNotEmpty ||
        _autorController.text.trim().isNotEmpty ||
        _editoraController.text.trim().isNotEmpty ||
        _generoController.text.trim().isNotEmpty ||
        _descricaoController.text.trim().isNotEmpty ||
        _lido == true ||
        _avaliacao != null ||
        _dataConclusao != null ||
        _tipoCapa != null;
  }

  Future<bool> _confirmarSaidaSemSalvar() async {
    if (!_formularioFoiAlterado()) return true;
    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Descartar alterações?'),
        content: const Text('Você preencheu dados no cadastro. Tem certeza de que quer sair sem salvar?'),
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
          _capaUrl = null;
          _tituloDaCapa = null;
          _tipoCapa = 'bytes';
        });
      }
    } catch (e) {
      if (!mounted) return;
      mostrarSnackbarErro(context, 'Não foi possível selecionar a imagem.');
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
          _capaUrl = null;
          _tituloDaCapa = null;
          _tipoCapa = 'bytes';
        });
      }
    } catch (e) {
      if (!mounted) return;
      mostrarSnackbarErro(context, 'Não foi possível tirar a foto.');
    }
  }

  void _removerCapa() {
    setState(() {
      _capaUrl = null;
      _capaBytes = null;
      _tituloDaCapa = null;
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
                          _capaUrl = capa;
                          _capaBytes = null;
                          _tituloDaCapa = capa != null ? buscaController.text.trim() : null;
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
                                  _capaUrl = capa;
                                  _capaBytes = null;
                                  _tituloDaCapa = capa != null ? buscaController.text.trim() : null;
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

  Future<void> _salvarLivro() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    String? imagemParaSalvar;
    if (_tipoCapa == 'bytes' && _capaBytes != null) {
      imagemParaSalvar = base64Encode(_capaBytes!);
    } else if (_tipoCapa == 'url' && _capaUrl != null) {
      imagemParaSalvar = _capaUrl;
    }

    final avaliacaoParaEnviar = _avaliacao;
    final dataParaEnviar = _lido && _dataConclusao != null
        ? formatarDataISO(_dataConclusao)
        : null;
    final totalPaginas = int.tryParse(_totalPaginasController.text.trim());
    final paginaAtual = int.tryParse(_paginaAtualController.text.trim());

    final livro = {
      'titulo': _tituloController.text.trim(),
      'autor': _autorController.text.trim(),
      'editora': _editoraController.text.trim(),
      'genero': _generoController.text.trim(),
      'descricao': _descricaoController.text.trim(),
      'imagem': imagemParaSalvar,
      'lido': _lido,
      'statusLeitura': _statusLeitura,
      if (avaliacaoParaEnviar != null) 'avaliacao': avaliacaoParaEnviar,
      if (avaliacaoParaEnviar != null) 'comentarioAvaliacao': null,
      if (dataParaEnviar != null) 'dataAvaliacao': dataParaEnviar,
      if (totalPaginas != null) 'totalPaginas': totalPaginas,
      if (paginaAtual != null) 'paginaAtual': paginaAtual,
      if (_dataInicio != null) 'dataInicioLeitura': formatarDataISO(_dataInicio),
      if (_dataConclusao != null && _statusLeitura.toUpperCase() == 'LIDO')
        'dataFimLeitura': formatarDataISO(_dataConclusao),
    };

    try {
      final response = await AuthService.post('/livros', livro);

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        dynamic livroCriado;
        try {
          livroCriado = jsonDecode(utf8.decode(response.bodyBytes));
        } catch (_) {
          livroCriado = null;
        }

        final livroId = livroCriado is Map<String, dynamic> ? livroCriado['id'] : null;
        if (livroId != null && (avaliacaoParaEnviar != null || dataParaEnviar != null)) {
          try {
            await AuthService.post('/livros/$livroId/avaliacoes', {
              'nota': avaliacaoParaEnviar ?? 5,
              'comentario': null,
              'dataConclusao': dataParaEnviar,
            });
          } catch (_) {}
        }

        setState(() => _salvando = false);
        mostrarSnackbarSucesso(context, 'Livro cadastrado com sucesso!');
        Navigator.pop(context, true);
      } else {
        setState(() => _salvando = false);
        final mensagem = _mensagemErro(
          response,
          'Nao foi possível salvar o livro.',
        );
        mostrarSnackbarErro(context, 'Erro ao salvar o livro: $mensagem');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      mostrarSnackbarErro(context, 'Falha na requisção. Tente novamente.');
    }
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

  Widget _buildTituloSecao(String texto) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFF7C4DFF), Color(0xFFB28CFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Text(
        texto,
        style: const TextStyle(
          fontFamily: 'Diphylleia',
          fontSize: 24,
          letterSpacing: 0.1,
        ),
      ),
    );
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

  Widget _botaoStatusNovo({
    required String status,
    required IconData icone,
    required String rotulo,
    required ({Color fundo, Color fundoClaro, Color texto, Color iconeCor}) cores,
  }) {
    final selecionado = _statusLeitura == status;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _statusLeitura = status;
            _lido = status == 'LIDO';
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: selecionado
                ? LinearGradient(
                    colors: [cores.fundo, cores.fundoClaro],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: selecionado ? null : Theme.of(context).cardColor.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selecionado
                  ? cores.fundo.withValues(alpha: 0.32)
                  : context.coresApp.separador,
              width: selecionado ? 0.8 : 0.7,
            ),
            boxShadow: selecionado
                ? [
                    BoxShadow(
                      color: cores.fundo.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                      spreadRadius: -2,
                    ),
                    BoxShadow(
                      color: cores.fundo.withValues(alpha: 0.18),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                      spreadRadius: -2,
                    ),
                  ],
          ),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 32, height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selecionado ? Colors.white.withValues(alpha: 0.18) : cores.fundo.withValues(alpha: 0.09),
                ),
                child: Icon(
                  icone,
                  size: 17,
                  color: selecionado ? Colors.white : cores.fundo,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                rotulo,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      letterSpacing: 0.1,
                      color: selecionado ? Colors.white : context.coresApp.textoForte,
                    ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final podeSair = await _confirmarSaidaSemSalvar();
        if (podeSair && mounted) Navigator.of(context).pop(false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFFB28CFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: const Text(
                  'Cadastrar Livro',
                  style: TextStyle(
                    fontFamily: 'Diphylleia',
                    fontSize: 27,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Adicione um novo título à sua biblioteca',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6B6B80),
                    ),
              ),
            ],
          ),
          toolbarHeight: 92,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      if (_tipoCapa == 'bytes' && _capaBytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(
                            _capaBytes!,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        )
                      else if (_tipoCapa == 'url' && _capaUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl: _capaUrl!,
                            height: 200,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const SizedBox(
                              height: 200,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (context, url, error) => Container(
                              height: 200,
                              color: Colors.grey.shade300,
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image, size: 40),
                            ),
                          ),
                        )
                      else
                        Container(
                          height: 200,
                          width: 140,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1EEFF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.menu_book_rounded,
                                size: 52,
                                color: Color(0xFF7C4DFF),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Sem capa',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF5F5F7A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_tipoCapa != null) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _removerCapa,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Remover capa'),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _buildTituloSecao('Capa do livro'),
                      const SizedBox(height: 6),
                      Text(
                        'Escolha a capa: tire uma foto, selecione da galeria ou busque pelo título.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _tirarFotoComCamera,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              icon: const Icon(Icons.photo_camera_rounded, size: 16),
                              label: const Text('Câmera'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _selecionarDaGaleria,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              icon: const Icon(Icons.photo_library_rounded, size: 16),
                              label: const Text('Galeria'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _abrirDialogBuscarCapa,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              icon: const Icon(Icons.search_rounded, size: 16),
                              label: const Text('Buscar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTituloSecao('Informações do livro'),
                      const SizedBox(height: 6),
                      Text(
                        'Preencha os campos abaixo para cadastrar um novo livro.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _tituloController,
                        decoration: const InputDecoration(
                          labelText: 'Título *',
                          hintText: 'Digite o nome do livro',
                        ),
                        validator: (v) =>
                            v!.isEmpty ? 'Informe o título' : null,
                        onChanged: (value) {
                          final tituloAtual = value.trim();
                          if ((_capaUrl != null || _capaBytes != null) &&
                              tituloAtual != _tituloDaCapa) {
                            setState(() {
                              _capaUrl = null;
                              _capaBytes = null;
                              _tipoCapa = null;
                              _tituloDaCapa = null;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _autorController,
                        decoration: const InputDecoration(labelText: 'Autor *'),
                        validator: (v) => v!.isEmpty ? 'Informe o autor' : null,
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
                      const SizedBox(height: 20),
                      _buildTituloSecao('Descrição do livro'),
                      const SizedBox(height: 8),
                      Text(
                        'Adicione um resumo, observação ou detalhes importantes sobre o livro.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descricaoController,
                        maxLength: 500,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: 'Descrição'),
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
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                        decoration: BoxDecoration(
                          color: context.coresApp.roxoFundoChip.withValues(alpha:
                            Theme.of(context).brightness == Brightness.dark ? 0.30 : 0.65),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: context.coresApp.roxoPrimario.withValues(alpha: 0.18),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: context.coresApp.roxoPrimario.withValues(alpha: 0.07),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [context.coresApp.roxoPrimario, context.coresApp.roxoClaro],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: context.coresApp.roxoPrimario.withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.auto_graph_rounded, color: Colors.white, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Progresso da leitura',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w900,
                                              color: context.coresApp.textoForte,
                                              letterSpacing: -0.2,
                                            ),
                                      ),
                                      Text(
                                        'Registre sua jornada com este livro',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: context.coresApp.textoMedio,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                ChipStatusLeitura(status: _statusLeitura),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                _botaoStatusNovo(
                                  status: 'QUERO_LER',
                                  icone: Icons.bookmark_border_rounded,
                                  rotulo: 'Quero ler',
                                  cores: (
                                    fundo: const Color(0xFF6B7280),
                                    fundoClaro: const Color(0xFF9CA3AF),
                                    texto: Colors.white,
                                    iconeCor: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _botaoStatusNovo(
                                  status: 'LENDO',
                                  icone: Icons.menu_book_rounded,
                                  rotulo: 'Lendo',
                                  cores: (
                                    fundo: context.coresApp.roxoPrimario,
                                    fundoClaro: context.coresApp.roxoClaro,
                                    texto: Colors.white,
                                    iconeCor: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _botaoStatusNovo(
                                  status: 'LIDO',
                                  icone: Icons.verified_rounded,
                                  rotulo: 'Lido',
                                  cores: (
                                    fundo: context.coresApp.verdeLido,
                                    fundoClaro: const Color(0xFF66BB6A),
                                    texto: Colors.white,
                                    iconeCor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            if (_statusLeitura == 'QUERO_LER') ...[
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: context.coresApp.separador, width: 0.8),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 46, height: 46,
                                      decoration: BoxDecoration(
                                        color: context.coresApp.roxoPrimario.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(Icons.auto_stories_rounded, color: context.coresApp.roxoPrimario, size: 24),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        'Comece a ler para ativar o controle de progresso, páginas e datas. Volte aqui quando abrir a primeira página! 📚',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: context.coresApp.textoMedio,
                                              height: 1.4,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: context.coresApp.separador, width: 0.8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                      spreadRadius: -2,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Builder(
                                      builder: (_) {
                                        final tot = int.tryParse(_totalPaginasController.text.trim());
                                        final at = int.tryParse(_paginaAtualController.text.trim()) ?? 0;
                                        final temTotal = tot != null && tot > 0;
                                        double? pct;
                                        if (temTotal) {
                                          pct = ((at.clamp(0, tot!) * 100) / tot).clamp(0, 100);
                                        } else if (_statusLeitura == 'LIDO') {
                                          pct = 100;
                                        }
                                        final corBarra = _statusLeitura == 'LIDO'
                                            ? context.coresApp.verdeLido
                                            : context.coresApp.roxoPrimario;
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  temTotal && _statusLeitura == 'LENDO'
                                                      ? 'Página ${at.clamp(0, tot!)} de $tot'
                                                      : _statusLeitura == 'LIDO'
                                                          ? (temTotal ? '$tot páginas — concluído' : 'Leitura concluída')
                                                          : 'Acompanhe seu progresso',
                                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                        color: context.coresApp.textoForte,
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                ),
                                                const Spacer(),
                                                if (pct != null)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: corBarra.withValues(alpha: 0.12),
                                                      borderRadius: BorderRadius.circular(999),
                                                    ),
                                                    child: Text(
                                                      '${pct.round()}%',
                                                      style: TextStyle(
                                                        color: corBarra,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w900,
                                                        letterSpacing: 0.2,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Stack(
                                              children: [
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(999),
                                                  child: LinearProgressIndicator(
                                                    value: (pct ?? 0) / 100,
                                                    minHeight: 14,
                                                    backgroundColor: corBarra.withValues(alpha: 0.12),
                                                    valueColor: AlwaysStoppedAnimation<Color>(corBarra),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    if (_statusLeitura == 'LIDO') ...[
                                      _CampoNumerico(
                                        controller: _totalPaginasController,
                                        onChanged: (v) => setState(() {}),
                                        icone: Icons.book_rounded,
                                        label: 'Total de páginas',
                                        hint: '280',
                                        iconeCor: context.coresApp.roxoPrimario,
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        height: 60,
                                        width: double.infinity,
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        decoration: BoxDecoration(
                                          color: context.coresApp.verdeLido.withValues(alpha: 0.10),
                                          borderRadius: BorderRadius.circular(18),
                                          border: Border.all(
                                            color: context.coresApp.verdeLido.withValues(alpha: 0.30),
                                            width: 1,
                                          ),
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.celebration_rounded, color: context.coresApp.verdeLido, size: 20),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Leitura finalizada com sucesso',
                                                maxLines: 1,
                                                style: TextStyle(
                                                  color: context.coresApp.verdeLido,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 14,
                                                  letterSpacing: 0.1,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _CampoNumerico(
                                              controller: _totalPaginasController,
                                              onChanged: (v) => setState(() {}),
                                              icone: Icons.book_rounded,
                                              label: 'Total páginas',
                                              hint: '280',
                                              iconeCor: context.coresApp.roxoPrimario,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _CampoNumerico(
                                              controller: _paginaAtualController,
                                              onChanged: (v) => setState(() {}),
                                              icone: Icons.label_important_rounded,
                                              label: 'Pág. atual',
                                              hint: '47',
                                              iconeCor: context.coresApp.roxoPrimario,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 18),
                                    _LinhaDoTempoDatas(
                                      status: _statusLeitura,
                                      dataInicio: _dataInicio,
                                      dataConclusao: _dataConclusao,
                                      aoSelecionarInicio: _selecionarDataInicio,
                                      aoLimparInicio: () => setState(() => _dataInicio = null),
                                      aoSelecionarConclusao: _selecionarData,
                                      aoLimparConclusao: () => setState(() => _dataConclusao = null),
                                      tema: Theme.of(context),
                                      cores: context.coresApp,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F5FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ShaderMask(
                                  shaderCallback: (bounds) => const LinearGradient(
                                    colors: [Color(0xFF7C4DFF), Color(0xFFB28CFF)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ).createShader(bounds),
                                  blendMode: BlendMode.srcIn,
                                  child: const Icon(Icons.star_rate_rounded, color: Colors.white, size: 28),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ShaderMask(
                                    shaderCallback: (bounds) => const LinearGradient(
                                      colors: [Color(0xFF7C4DFF), Color(0xFFB28CFF)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ).createShader(bounds),
                                    blendMode: BlendMode.srcIn,
                                    child: Text(
                                      'Sua avaliação',
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 18,
                                            color: Colors.white,
                                          ),
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
                                tamanho: 32,
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
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _salvando ? null : _salvarLivro,
                          child: _salvando
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Salvar livro'),
                        ),
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
}

class _CampoNumerico extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final IconData icone;
  final String label;
  final String hint;
  final Color iconeCor;
  const _CampoNumerico({
    required this.controller,
    required this.onChanged,
    required this.icone,
    required this.label,
    required this.hint,
    required this.iconeCor,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.extension<AppCores>() ?? AppCores.claro;
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: cores.roxoFundoChip.withValues(alpha: tema.brightness == Brightness.dark ? 0.25 : 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cores.separador, width: 0.6),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: TextInputType.number,
        style: tema.textTheme.titleSmall?.copyWith(
              color: cores.textoForte,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.only(left: 4, right: 6, top: 4, bottom: 4),
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 10, right: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: iconeCor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icone, color: iconeCor, size: 16),
                ),
              ],
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 40),
          labelText: label,
          labelStyle: tema.textTheme.labelLarge?.copyWith(
                color: cores.textoMedio,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                height: 1,
              ),
          floatingLabelAlignment: FloatingLabelAlignment.start,
          floatingLabelStyle: TextStyle(
                color: iconeCor,
                fontWeight: FontWeight.w800,
                fontSize: 10,
                height: 0.6,
              ),
          alignLabelWithHint: true,
          hintText: hint,
          hintStyle: tema.textTheme.labelLarge?.copyWith(
                color: cores.textoFraco,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
        ),
      ),
    );
  }
}

class _LinhaDoTempoDatas extends StatelessWidget {
  final String status;
  final DateTime? dataInicio;
  final DateTime? dataConclusao;
  final VoidCallback aoSelecionarInicio;
  final VoidCallback aoLimparInicio;
  final VoidCallback aoSelecionarConclusao;
  final VoidCallback aoLimparConclusao;
  final ThemeData tema;
  final AppCores cores;

  const _LinhaDoTempoDatas({
    required this.status,
    required this.dataInicio,
    required this.dataConclusao,
    required this.aoSelecionarInicio,
    required this.aoLimparInicio,
    required this.aoSelecionarConclusao,
    required this.aoLimparConclusao,
    required this.tema,
    required this.cores,
  });

  @override
  Widget build(BuildContext context) {
    final showConclusao = status == 'LIDO';
    return Column(
      children: [
        _ItemLinhaTempo(
          bolinhaCor: cores.roxoPrimario,
          bolinhaIcone: Icons.play_arrow_rounded,
          label: 'Data de início',
          data: dataInicio,
          onSelecionar: aoSelecionarInicio,
          onLimpar: aoLimparInicio,
          tema: tema,
          cores: cores,
          hint: 'Quando você começou a ler?',
        ),
        if (showConclusao) ...[
          Padding(
            padding: const EdgeInsets.only(left: 17),
            child: SizedBox(
              height: 14,
              child: LayoutBuilder(
                builder: (_, c) {
                  return Row(
                    children: List.generate(10, (i) =>
                        Expanded(
                          child: Container(
                            color: (i.isEven) ? cores.roxoPrimario.withValues(alpha: 0.35) : Colors.transparent,
                          ),
                        ),
                    ),
                  );
                },
              ),
            ),
          ),
          _ItemLinhaTempo(
            bolinhaCor: cores.verdeLido,
            bolinhaIcone: Icons.flag_rounded,
            label: 'Data de conclusão',
            data: dataConclusao,
            onSelecionar: aoSelecionarConclusao,
            onLimpar: aoLimparConclusao,
            tema: tema,
            cores: cores,
            hint: 'Quando finalizou a leitura?',
          ),
        ],
      ],
    );
  }
}

class _ItemLinhaTempo extends StatelessWidget {
  final Color bolinhaCor;
  final IconData bolinhaIcone;
  final String label;
  final DateTime? data;
  final VoidCallback onSelecionar;
  final VoidCallback onLimpar;
  final ThemeData tema;
  final AppCores cores;
  final String hint;

  const _ItemLinhaTempo({
    required this.bolinhaCor,
    required this.bolinhaIcone,
    required this.label,
    required this.data,
    required this.onSelecionar,
    required this.onLimpar,
    required this.tema,
    required this.cores,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bolinhaCor,
                boxShadow: [
                  BoxShadow(
                    color: bolinhaCor.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(bolinhaIcone, color: Colors.white, size: 17),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: onSelecionar,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: data != null ? bolinhaCor.withValues(alpha: 0.38) : cores.separador,
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: tema.textTheme.bodySmall?.copyWith(
                                color: cores.textoMedio,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                letterSpacing: 0.2,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          data != null ? formatarData(data) : hint,
                          style: tema.textTheme.bodyMedium?.copyWith(
                                color: data != null ? cores.textoForte : cores.textoFraco,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (data != null)
                    GestureDetector(
                      onTap: () => onLimpar(),
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: cores.textoFraco.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close_rounded, size: 15, color: cores.textoMedio),
                      ),
                    )
                  else
                    Icon(Icons.chevron_right_rounded, color: cores.textoFraco, size: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
