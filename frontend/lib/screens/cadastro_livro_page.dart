import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'package:frontend/services/google_books_service.dart';

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
  bool _buscandoCapa = false;
  String? _capaUrl;
  String? _tituloDaCapa;

  void _mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
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

  Future<void> _buscarCapa() async {
    if (_tituloController.text.trim().isEmpty) return;

    setState(() => _buscandoCapa = true);

    final capa = await GoogleBooksService.buscarCapa(_tituloController.text);

    setState(() {
      _capaUrl = capa;
      _tituloDaCapa = capa != null ? _tituloController.text.trim() : null;
      _buscandoCapa = false;
    });

    if (!mounted) return;

    if (capa == null) {
      _mostrarMensagem('Nenhuma capa foi encontrada para esse titulo.');
    }
  }

  Future<void> _salvarLivro() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    final livro = {
      'titulo': _tituloController.text.trim(),
      'autor': _autorController.text.trim(),
      'editora': _editoraController.text.trim(),
      'genero': _generoController.text.trim(),
      'descricao': _descricaoController.text.trim(),
      'imagem': _capaUrl,
      'lido': false,
      'avaliacao': null,
    };

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8080/livros'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode(livro),
      );

      if (!mounted) return;
      setState(() => _salvando = false);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        Navigator.pop(context, true);
      } else {
        final mensagem = _mensagemErro(
          response,
          'Nao foi possivel salvar o livro.',
        );
        _mostrarMensagem('Erro ao salvar o livro: $mensagem');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      _mostrarMensagem('Falha na requisicao. Tente novamente.');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              'Cadastrar Livro',
              style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                'Adicione um novo título à sua biblioteca',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ),
        toolbarHeight: 88,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              //Preview da capa
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    if (_buscandoCapa)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: CircularProgressIndicator(),
                      )
                    else if (_capaUrl != null)
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
                                color: Color(0xFF5F5F7A)
                              )
                            )
                          ]
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Capa do livro',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pesquise pelo título para encontrar a capa do seu livro.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              //Campo título com botão de buscar capa
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
                      'Informações do livro',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Preencha os campos abaixo para cadastrar um novo livro.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _tituloController,
                            decoration: const InputDecoration(
                              labelText: 'Título *',
                              hintText: 'Digite o nome do livro',
                            ),
                            validator: (v) =>
                                v!.isEmpty ? 'Informe o título' : null,
                            onChanged: (value) {
                              final tituloAtual = value.trim();
                              if (_capaUrl != null &&
                                  tituloAtual != _tituloDaCapa) {
                                setState(() {
                                  _capaUrl = null;
                                  _tituloDaCapa = null;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          height: 56,
                          width: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1EEFF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.search_rounded, color: Color(0xFF7C4DFF)),
                            tooltip: 'Buscar capa',
                            onPressed: _buscarCapa,
                          ),
                        ),
                      ],
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
                    Text(
                      'Descrição do livro',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Adicione um resumo, observação ou detalhes importantes sobre o livro.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descricaoController,
                      decoration: const InputDecoration(labelText: 'Descrição'),
                      maxLines: 4,
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
    )
  );
 }
}