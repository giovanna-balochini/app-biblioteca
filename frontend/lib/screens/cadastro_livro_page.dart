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
  bool _jaAvisouLimiteDesc = false;
  bool _lido = false;
  int? _avaliacao;
  DateTime? _dataConclusao;

  void _mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
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
      'lido': _lido,
      'avaliacao': _avaliacao,
      'dataConclusao': _lido && _dataConclusao != null ? _formatarDataISO(_dataConclusao) : null,
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
                      maxLength: 500,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Descrição'),
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