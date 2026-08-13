import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:frontend/services/google_books_service.dart';

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

  bool _editando = false;
  bool _salvando = false;
  late bool _lido;
  late int? _avaliacao;
  late DateTime? _dataConclusao;
  bool _jaAvisouLimiteDesc = false;
  Uint8List? _capaBytes;
  String? _capaUrlLocal; // fallback local da URL quando em edição
  String? _tipoCapa; // 'url' ou 'bytes'
  final ImagePicker _imagePicker = ImagePicker();

  void _mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }

  String _formatarData(DateTime? data) {
    if (data == null) return '';
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString();
    return '$dia/$mes/$ano';
  }

  String _formatarDataISO(DateTime? data) {
    if (data == null) return '';
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString();
    return '$ano-$mes-$dia';
  }

  DateTime? _parseDataISO(String? dataStr) {
    if (dataStr == null || dataStr.trim().isEmpty) return null;
    try {
      final partes = dataStr.trim().split('-');
      if (partes.length != 3) return null;
      return DateTime(int.parse(partes[0]), int.parse(partes[1]), int.parse(partes[2]));
    } catch (_) {
      return null;
    }
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

  Widget _buildEstrelas(int? avaliacao, {double tamanho = 16, bool clicavel = false, ValueChanged<int>? aoClicar}) {
    final qtd = avaliacao ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final estrelaNumero = index + 1;
        final preenchida = estrelaNumero <= qtd;
        final icone = Icon(
          preenchida ? Icons.star_rounded : Icons.star_border_rounded,
          size: tamanho,
          color: const Color(0xFFFFB300),
        );
        if (!clicavel) {
          return Padding(
            padding: EdgeInsets.only(right: index == 4 ? 0 : 2),
            child: icone,
          );
        }
        return GestureDetector(
          onTap: () => aoClicar?.call(estrelaNumero == qtd ? 0 : estrelaNumero),
          child: Padding(
            padding: EdgeInsets.only(right: index == 4 ? 0 : 4),
            child: icone,
          ),
        );
      }),
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
      _mostrarMensagem('Nao foi possivel selecionar a imagem.');
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
      _mostrarMensagem('Nao foi possivel tirar a foto.');
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

    if (resultado == true) {
      _mostrarMensagem('Capa encontrada!');
    } else if (resultado == false) {
      _mostrarMensagem('Nenhuma capa foi encontrada para esse título.');
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
    _lido = widget.livro['lido'] == true;
    final aval = widget.livro['avaliacao'];
    _avaliacao = aval is int ? aval : (aval is double ? aval.toInt() : null);
    _dataConclusao = _parseDataISO(widget.livro['dataConclusao']?.toString());
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
  }

  void _cancelarEdicao() {
    _tituloController.text = widget.livro['titulo']?.toString() ?? '';
    _autorController.text = widget.livro['autor']?.toString() ?? '';
    _editoraController.text = widget.livro['editora']?.toString() ?? '';
    _generoController.text = widget.livro['genero']?.toString() ?? '';
    _descricaoController.text = widget.livro['descricao']?.toString() ?? '';
    _lido = widget.livro['lido'] == true;
    final aval = widget.livro['avaliacao'];
    _avaliacao = aval is int ? aval : (aval is double ? aval.toInt() : null);
    _dataConclusao = _parseDataISO(widget.livro['dataConclusao']?.toString());
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

    // Define o valor de imagem a ser salvo:
    // - Se o usuario mudou para base64 (camera/galeria): envia o base64
    // - Se o usuario mudou para URL (busca): envia a URL
    // - Se o usuario removeu a capa (tipoCapa == null e original nao era nulo): envia null
    // - Se o usuario NAO mexeu na capa (_tipoCapa == null E original era nulo OU _tipoCapa nao mudou em relacao ao original): envia o original (backward compat)
    String? imagemParaSalvar;
    if (_tipoCapa == 'bytes' && _capaBytes != null) {
      imagemParaSalvar = base64Encode(_capaBytes!);
    } else if (_tipoCapa == 'url') {
      imagemParaSalvar = _capaUrlLocal;
    } else if (_tipoCapa == null) {
      imagemParaSalvar = null; // usuario removeu
    } else {
      imagemParaSalvar = widget.livro['imagem']?.toString();
    }

    final livroAtualizado = {
      'titulo': _tituloController.text.trim(),
      'autor': _autorController.text.trim(),
      'editora': _editoraController.text.trim(),
      'genero': _generoController.text.trim(),
      'descricao': _descricaoController.text.trim(),
      'imagem': imagemParaSalvar,
      'lido': _lido,
      'avaliacao': _avaliacao,
      'dataConclusao': _lido && _dataConclusao != null ? _formatarDataISO(_dataConclusao) : null,
    };

    try {
      final response = await http.put(
        Uri.parse('http://10.0.2.2:8080/livros/${widget.livro['id']}'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: json.encode(livroAtualizado),
      );

      if (!mounted) return;
      setState(() => _salvando = false);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() => _editando = false);
        _mostrarMensagem('Livro atualizado com sucesso.');
        Navigator.pop(context, true);
      } else {
        final mensagem = _mensagemErro(
          response,
          'Nao foi possivel atualizar o livro.',
        );
        _mostrarMensagem('Erro ao atualizar o livro: $mensagem');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      _mostrarMensagem('Falha na requisicao. Tente novamente.');
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
              child: const Text('Deletar', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
 
      if (confirmar != true) return;

      await http.delete(
        Uri.parse('http://10.0.2.2:8080/livros/${widget.livro['id']}'),
      );

      if (mounted) Navigator.pop(context, true);
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

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_editando ? 'Editar Livro' : 'Detalhes'),
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
          padding: const EdgeInsets.all(16),
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
                    // --- CAPA do livro ---
                    if (!_editando) ...[
                      // MODO LEITURA: usa o original do banco
                      if (widget.livro['imagem'] != null &&
                          widget.livro['imagem'].toString().isNotEmpty)
                        () {
                          final imagemStr = widget.livro['imagem'].toString();
                          final ehBase64 = imagemStr.startsWith('data:image') || imagemStr.length > 1000;
                          Widget capaOk;
                          if (ehBase64) {
                            try {
                              Uint8List bytes;
                              if (imagemStr.startsWith('data:image')) {
                                final commaIdx = imagemStr.indexOf(',');
                                final b64 = commaIdx != -1 ? imagemStr.substring(commaIdx + 1) : imagemStr;
                                bytes = base64Decode(b64);
                              } else {
                                bytes = base64Decode(imagemStr);
                              }
                              capaOk = ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.memory(
                                  bytes,
                                  height: 220,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 220,
                                    width: 150,
                                    color: const Color(0xFFF1EEFF),
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.broken_image, size: 40),
                                  ),
                                ),
                              );
                            } catch (_) {
                              capaOk = Container(
                                height: 220,
                                width: 150,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1EEFF),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.menu_book_rounded, size: 52, color: Color(0xFF7C4DFF)),
                                    SizedBox(height: 12),
                                    Text(
                                      'Sem capa',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF5F5F7A)),
                                    ),
                                  ],
                                ),
                              );
                            }
                          } else {
                            capaOk = ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: CachedNetworkImage(
                                imageUrl: imagemStr,
                                height: 220,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const SizedBox(
                                  height: 220,
                                  child: Center(child: CircularProgressIndicator()),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  height: 220,
                                  width: 150,
                                  color: Colors.grey.shade300,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.broken_image, size: 40),
                                ),
                              ),
                            );
                          }
                          return capaOk;
                        }()
                      else
                        Container(
                          height: 220,
                          width: 150,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1EEFF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
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
                    ] else ...[
                      // MODO EDIÇÃO: usa os valores locais (capaBytes, capaUrlLocal)
                      if (_tipoCapa == 'bytes' && _capaBytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(
                            _capaBytes!,
                            height: 220,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 220,
                              width: 150,
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
                            height: 220,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const SizedBox(
                              height: 220,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (context, url, error) => Container(
                              height: 220,
                              width: 150,
                              color: Colors.grey.shade300,
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image, size: 40),
                            ),
                          ),
                        )
                      else
                        Container(
                          height: 220,
                          width: 150,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1EEFF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
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
                      const SizedBox(height: 20),
                      const Text(
                        'Capa do livro',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF2A2A38)),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Edite a capa: tire uma foto, selecione da galeria ou busque pelo título.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
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
                    // --- FIM DA CAPA ---

                      const SizedBox(height: 16),
                      Text(
                        widget.livro['titulo'] ?? 'Livro sem título',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.livro['autor'] ?? 'Autor desconhecido',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      _buildEstrelas(
                        _editando ? _avaliacao : (widget.livro['avaliacao'] is int ? widget.livro['avaliacao'] : (widget.livro['avaliacao'] is double ? (widget.livro['avaliacao'] as double).toInt() : null)),
                        tamanho: 28,
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
                      Text(
                        _editando ? 'Editar livro' : 'Informações do livro',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _editando
                            ? 'Altere os dados abaixo e clique em Salvar para confirmar.'
                            : 'Veja os dados cadastrados para este livro.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      if (!_editando) ...[
                        _InfoTile(
                          label: 'Título',
                          value: widget.livro['titulo']?.toString(),
                        ),
                        _InfoTile(
                          label: 'Autor',
                          value: widget.livro['autor']?.toString(),
                        ),
                        _InfoTile(
                          label: 'Editora',
                          value: widget.livro['editora']?.toString(),
                        ),
                        _InfoTile(
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
                        Container(
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
                                    Text(
                                      _lido ? 'Livro lido' : 'Ainda não lido',
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: _lido ? const Color(0xFF2E7D32) : const Color(0xFF2A2A38),
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Altere em "Editar informações".',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_lido && _dataConclusao != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8FAF0),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF4CAF50),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.event_available_rounded,
                                  color: Color(0xFF2E7D32),
                                  size: 26,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Concluído em',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF2E7D32),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _formatarData(_dataConclusao),
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
                              _mostrarMensagem('Limite de caracteres atingido.');
                            }
                            if (valor.length < 495) {
                              _jaAvisouLimiteDesc = false;
                            }
                          },
                        ),
                        const SizedBox(height: 16),
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
                                      Text(
                                        _lido ? 'Livro lido' : 'Ainda não lido',
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: _lido ? const Color(0xFF2E7D32) : const Color(0xFF2A2A38),
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
                                  activeColor: const Color(0xFF4CAF50),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_lido) ...[
                          TextFormField(
                            readOnly: true,
                            controller: TextEditingController(text: _formatarData(_dataConclusao)),
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
                                child: _buildEstrelas(
                                  _avaliacao,
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
      );
    }
  }

class _InfoTile extends StatelessWidget {
  final String label;
  final String? value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final valorValido = value != null && value!.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
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
              valorValido ? value! : 'Não informado',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFF2A2A38)),
            ),
          ),
        ],
      ),
    );
  }
}
