import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'screens/cadastro_livro_page.dart';
import 'screens/detalhe_livro_page.dart';

void main () {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Minha Biblioteca',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F7FB),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C4DFF), 
          brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false, 
        elevation: 0,
        backgroundColor: Color(0xFFF7F7FB),
        foregroundColor: Color(0xFF1F1F39),
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1F1F39),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8F5FF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF7C4DFF),
            width: 1.5,
          ),
        ),
        labelStyle: const TextStyle(
          color: Color(0xFF6B6B80),
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF9E9EAF),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor:const Color(0xFF7C4DFF),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF7C4DFF),
        foregroundColor: Colors.white,
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F1F39),
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F1F39),
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            color: Color(0xFF2C2C34),
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: Color(0xFF6B6B80),
          ),
        ),
      ),
      home: const ListaLivrosPage(),
    );
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
  List<dynamic> _livrosFiltrados = [];

  Widget _buildCapaLivro(dynamic livro) {
    final imagem = livro['imagem'];
    final lido = livro['lido'] == true;

    Widget capaSemImagem() => Container(
          width: 56,
          height: 82,
          decoration: BoxDecoration(
            color: const Color(0xFFF1EEFF),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.menu_book_rounded,
            size: 28,
            color: Color(0xFF7C4DFF),
          ),
        );

    Widget capaComImagem() => ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CachedNetworkImage(
            imageUrl: imagem.toString(),
            width: 56,
            height: 82,
            fit: BoxFit.cover,
            placeholder: (context, url) => const SizedBox(
              width: 56,
              height: 82,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            errorWidget: (context, url, error) => Container(
              width: 56,
              height: 82,
              color: Colors.grey.shade300,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image),
            ),
          ),
        );

    final filhoCapa = (imagem == null || imagem.toString().isEmpty)
        ? capaSemImagem()
        : capaComImagem();

    if (!lido) return filhoCapa;

    return SizedBox(
      width: 56,
      height: 82,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          filhoCapa,
          Positioned(
            top: -3,
            left: -18,
            child: Transform.rotate(
              angle: -math.pi / 4,
              child: Container(
                width: 72,
                height: 18,
                color: const Color(0xFF2E7D32),
              ),
            ),
          ),
          Positioned(
            top: 5,
            left: 0,
            child: Transform.rotate(
              angle: -math.pi / 4,
              child: const Text(
                'LIDO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
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

  @override
  void initState() {
    super.initState();
    buscarLivros();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> buscarLivros() async {
    final response = await http.get(
      Uri.parse('http://10.0.2.2:8080/livros'),
    );

    if (response.statusCode == 200) {
      setState(() {
        livros = json.decode(response.body);
        _livrosFiltrados = livros;
        carregando = false;
      });
    }
  }

  void _filtrarLivros(String busca) {
    setState(() {
      if (busca.trim().isEmpty) {
        _livrosFiltrados = livros;
        return;
      }
      final termo = busca.trim().toLowerCase();
      _livrosFiltrados = livros.where((livro) {
        final titulo = (livro['titulo'] ?? '').toString().toLowerCase();
        final autor = (livro['autor'] ?? '').toString().toLowerCase();
        return titulo.contains(termo) || autor.contains(termo);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Minha Biblioteca',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              '${livros.length} ${livros.length == 1 ? 'livro cadastrado' : 'livros cadastrados'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        toolbarHeight: 80,
      ),
      body:carregando
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
                              builder: (context) => CadastroLivroPage(),
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
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  TextField(
                    controller: _buscaController,
                    onChanged: _filtrarLivros,
                    decoration: InputDecoration(
                      labelText: 'Buscar livro',
                      hintText: 'Pesquise por título ou autor',
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF7C4DFF)),
                      suffixIcon: _buscaController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, color: Color(0xFF7C4DFF)),
                              onPressed: () {
                                _buscaController.clear();
                                _filtrarLivros('');
                              },
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _livrosFiltrados.isEmpty
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
                                      Icons.search_off_rounded,
                                      size: 44,
                                      color: Color(0xFF7C4DFF),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    _buscaController.text.trim().isEmpty
                                        ? 'Sua biblioteca está vazia.'
                                        : 'Nenhum livro encontrado para "${_buscaController.text}"',
                                    style: Theme.of(context).textTheme.bodyLarge,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _livrosFiltrados.length,
                            itemBuilder: (context, index) {
                              final livro = _livrosFiltrados[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Card(
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    leading: _buildCapaLivro(livro),
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
                                          _buildEstrelas(
                                            livro['avaliacao'] is int ? livro['avaliacao'] : (livro['avaliacao'] is double ? (livro['avaliacao'] as double).toInt() : null),
                                            tamanho: 15,
                                          ),
                                        ],
                                      ),
                                    ),
                                    trailing: Container(
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
                                        buscarLivros();
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
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