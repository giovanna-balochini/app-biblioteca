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
  late bool _lido;
  late int? _avaliacao;
  bool _jaAvisouLimiteDesc = false;

  void _mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
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
    setState(() => _editando = false);
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
      'lido': _lido,
      'avaliacao': _avaliacao,
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
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F5FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.menu_book_outlined, color: Color(0xFF7C4DFF)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Livro lido',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF2A2A38),
                                      ),
                                ),
                              ),
                              Switch(
                                value: _lido,
                                onChanged: (valor) => setState(() => _lido = valor),
                                activeColor: const Color(0xFF4CAF50),
                              ),
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
                                      : _avaliacao == 5
                                          ? '5 estrelas! Livro incrível 😍'
                                          : 'Você deu $_avaliacao estrela${_avaliacao == 1 ? '' : 's'}. Toque de novo para limpar.',
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
