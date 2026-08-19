import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/google_books_service.dart';
import 'package:frontend/widgets/estrelas_avaliacao.dart';
import 'package:frontend/utils/formatters.dart';
import 'package:frontend/utils/snackbars.dart';

class CadastroLivroPage extends StatefulWidget {
  const CadastroLivroPage({super.key});

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
  int? _avaliacao;
  DateTime? _dataConclusao;
  Uint8List? _capaBytes;
  String? _tipoCapa;
  final ImagePicker _imagePicker = ImagePicker();

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
          _capaUrl = null;
          _tituloDaCapa = null;
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

    final livro = {
      'titulo': _tituloController.text.trim(),
      'autor': _autorController.text.trim(),
      'editora': _editoraController.text.trim(),
      'genero': _generoController.text.trim(),
      'descricao': _descricaoController.text.trim(),
      'imagem': imagemParaSalvar,
      'lido': _lido,
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
          'Nao foi possivel salvar o livro.',
        );
        mostrarSnackbarErro(context, 'Erro ao salvar o livro: $mensagem');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      mostrarSnackbarErro(context, 'Falha na requisicao. Tente novamente.');
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _autorController.dispose();
    _editoraController.dispose();
    _generoController.dispose();
    _descricaoController.dispose();
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
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () => setState(() => _lido = !_lido),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: _lido ? const Color(0xFFE8FAF0) : const Color(0xFFF8F5FF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _lido ? const Color(0xFF4CAF50) : Colors.transparent,
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _lido ? Icons.check_circle : Icons.menu_book_outlined,
                                color: _lido ? const Color(0xFF2E7D32) : const Color(0xFF7C4DFF),
                                size: 26,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _lido
                                        ? Text(
                                            'Livro lido',
                                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(0xFF2E7D32),
                                                ),
                                          )
                                        : ShaderMask(
                                            shaderCallback: (bounds) => const LinearGradient(
                                              colors: [Color(0xFF7C4DFF), Color(0xFFB28CFF)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ).createShader(bounds),
                                            blendMode: BlendMode.srcIn,
                                            child: Text(
                                              'Ainda não lido',
                                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 17,
                                                    color: Colors.white,
                                                  ),
                                            ),
                                          ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Clique para alternar.',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Switch(
                                value: _lido,
                                onChanged: (valor) => setState(() => _lido = valor),
                                activeThumbColor: const Color(0xFF4CAF50),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_lido) ...[
                        TextFormField(
                          readOnly: true,
                          controller: TextEditingController(text: formatarData(_dataConclusao)),
                          onTap: _selecionarData,
                          decoration: InputDecoration(
                            labelText: 'Data de conclusão da leitura',
                            prefixIcon: const Icon(Icons.calendar_today_rounded, color: Color(0xFF7C4DFF)),
                            suffixIcon: _dataConclusao != null
                                ? IconButton(
                                    icon: const Icon(Icons.close, color: Color(0xFF7C4DFF)),
                                    onPressed: () => setState(() => _dataConclusao = null),
                                    tooltip: 'Limpar data',
                                  )
                                : null,
                            hintText: 'Clique para selecionar',
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
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
