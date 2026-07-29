import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';

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

  void _mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
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

  @override
  void initState() {
    super.initState();
    _tituloController = TextEditingController(text: widget.livro['titulo']);
    _autorController = TextEditingController(text: widget.livro['autor']);
    _editoraController = TextEditingController(text: widget.livro['editora']);
    _generoController = TextEditingController(text: widget.livro['genero']);
    _descricaoController = TextEditingController(text: widget.livro['descricao']);
  }

  Future<void> _salvarEdicao() async {
    setState(() => _salvando = true);

    final livroAtualizado = {
      'titulo': _tituloController.text.trim(),
      'autor': _autorController.text.trim(),
      'editora': _editoraController.text.trim(),
      'genero': _generoController.text.trim(),
      'descricao': _descricaoController.text.trim(),
      'imagem': widget.livro['imagem'],
      'lido': widget.livro['lido'],
      'avaliacao': widget.livro['avaliacao'],
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
                    if (widget.livro['imagem'] != null && 
                        widget.livro['imagem'].toString().isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: widget.livro['imagem'].toString(),
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
                        'Informações do livro',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Veja os dados cadastrados para este livro.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: _tituloController,
                        enabled: _editando,
                        decoration: const InputDecoration(labelText: 'Título'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _autorController,
                        enabled: _editando,
                        decoration: const InputDecoration(labelText: 'Autor'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _editoraController,
                        enabled: _editando,
                        decoration: const InputDecoration(labelText: 'Editora'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _generoController,
                        enabled: _editando,
                        decoration: const InputDecoration(labelText: 'Gênero'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descricaoController,
                        enabled: _editando,
                        decoration: const InputDecoration(labelText: 'Descrição'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),
                      if (_editando)
                      ElevatedButton(
                        onPressed: _salvando ? null : _salvarEdicao,
                        child: _salvando
                        ? const CircularProgressIndicator()
                        : const Text('Salvar alterações'),
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
