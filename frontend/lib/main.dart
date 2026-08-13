import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:typed_data';
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
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
  String _filtroStatus = 'todos'; // 'todos' | 'lidos' | 'nao_lidos'

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

    Widget capaComImagem() {
      final imagemStr = imagem.toString();
      final ehBase64 = imagemStr.startsWith('data:image') || imagemStr.length > 1000;
      if (ehBase64) {
        try {
          Uint8List bytes;
          if (imagemStr.startsWith('data:image')) {
            final commaIdx = imagemStr.indexOf(',');
            final base64Str = commaIdx != -1 ? imagemStr.substring(commaIdx + 1) : imagemStr;
            bytes = base64Decode(base64Str);
          } else {
            bytes = base64Decode(imagemStr);
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              bytes,
              width: 56,
              height: 82,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => capaSemImagem(),
            ),
          );
        } catch (_) {
          return capaSemImagem();
        }
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: imagemStr,
          width: 56,
          height: 82,
          fit: BoxFit.cover,
          placeholder: (context, url) => const SizedBox(
            width: 56,
            height: 82,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          errorWidget: (context, url, error) => capaSemImagem(),
        ),
      );
    }

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

  String _formatarDataCurta(String? dataStr) {
    if (dataStr == null || dataStr.trim().isEmpty) return '';
    try {
      final partes = dataStr.trim().split('-');
      if (partes.length != 3) return '';
      final dia = partes[2].padLeft(2, '0');
      final mes = partes[1].padLeft(2, '0');
      return '$dia/$mes';
    } catch (_) {
      return '';
    }
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
        carregando = false;
      });
      _aplicarFiltros();
    }
  }

  void _aplicarFiltros() {
    _filtrarLivros(_buscaController.text);
  }

  void _filtrarLivros(String busca) {
    setState(() {
      final termo = busca.trim().toLowerCase();

      // Passo 1: filtro por TEXTO (busca)
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

      // Passo 2: filtro por STATUS (lidos / não lidos)
      if (_filtroStatus == 'lidos') {
        resultado = resultado.where((livro) => livro['lido'] == true);
      } else if (_filtroStatus == 'nao_lidos') {
        resultado = resultado.where((livro) => livro['lido'] != true);
      }

      _livrosFiltrados = resultado.toList();
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
            color: Colors.black.withOpacity(0.05),
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

    // Busca com texto (preenchido) - combina com status
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        _buildCardEstatisticas(),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _buscaController,
                          onChanged: _filtrarLivros,
                          decoration: InputDecoration(
                            labelText: 'Buscar livro',
                            hintText: 'Pesquise por título, autor, editora ou gênero',
                            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF7C4DFF)),
                            suffixIcon: _buscaController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close, color: Color(0xFF7C4DFF)),
                                    onPressed: () {
                                      _buscaController.clear();
                                      _aplicarFiltros();
                                    },
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ChoiceChip(
                                label: const Text('Todos'),
                                selected: _filtroStatus == 'todos',
                                onSelected: (_) {
                                  setState(() => _filtroStatus = 'todos');
                                  _aplicarFiltros();
                                },
                                selectedColor: const Color(0xFF7C4DFF),
                                backgroundColor: Colors.white,
                                labelStyle: TextStyle(
                                  color: _filtroStatus == 'todos' ? Colors.white : const Color(0xFF5F5F7A),
                                  fontWeight: FontWeight.w600,
                                ),
                                side: const BorderSide(color: Color(0xFFE0DBF2)),
                                avatar: Icon(
                                  Icons.library_books_rounded,
                                  size: 18,
                                  color: _filtroStatus == 'todos' ? Colors.white : const Color(0xFF7C4DFF),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('Lidos'),
                                selected: _filtroStatus == 'lidos',
                                onSelected: (_) {
                                  setState(() => _filtroStatus = 'lidos');
                                  _aplicarFiltros();
                                },
                                selectedColor: const Color(0xFF2E7D32),
                                backgroundColor: Colors.white,
                                labelStyle: TextStyle(
                                  color: _filtroStatus == 'lidos' ? Colors.white : const Color(0xFF5F5F7A),
                                  fontWeight: FontWeight.w600,
                                ),
                                side: const BorderSide(color: Color(0xFFD7EBDB)),
                                avatar: Icon(
                                  Icons.check_circle_rounded,
                                  size: 18,
                                  color: _filtroStatus == 'lidos' ? Colors.white : const Color(0xFF2E7D32),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('Não lidos'),
                                selected: _filtroStatus == 'nao_lidos',
                                onSelected: (_) {
                                  setState(() => _filtroStatus = 'nao_lidos');
                                  _aplicarFiltros();
                                },
                                selectedColor: const Color(0xFF7C4DFF),
                                backgroundColor: Colors.white,
                                labelStyle: TextStyle(
                                  color: _filtroStatus == 'nao_lidos' ? Colors.white : const Color(0xFF5F5F7A),
                                  fontWeight: FontWeight.w600,
                                ),
                                side: const BorderSide(color: Color(0xFFE0DBF2)),
                                avatar: Icon(
                                  Icons.menu_book_outlined,
                                  size: 18,
                                  color: _filtroStatus == 'nao_lidos' ? Colors.white : const Color(0xFF7C4DFF),
                                ),
                              ),
                            ],
                          ),
                        ),
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
                                    setState(() => _filtroStatus = 'todos');
                                    _aplicarFiltros();
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

                                      if (livro['lido'] == true) ...[
                                        if (_formatarDataCurta(livro['dataConclusao']?.toString()).isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.event_available_rounded, size: 12, color: Color(0xFF2E7D32)),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Concluído em ${_formatarDataCurta(livro['dataConclusao']?.toString())}',
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
                        childCount: _livrosFiltrados.length,
                      ),
                    ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 24),
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