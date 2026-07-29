import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
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

  Widget? _buildCapaLivro(dynamic livro) {
    final imagem = livro['imagem'];
    if (imagem == null || imagem.toString().isEmpty) {
      return null;
    }

    return ClipRRect(
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
  }

  @override
  void initState() {
    super.initState();
    buscarLivros();
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
    }
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
              '${livros.length} livros cadastrados',
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
              child: ListView.builder(
                itemCount: livros.length,
                itemBuilder: (context, index) {
                  final livro = livros[index];
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
                          child: Text(livro['autor'] ?? 'Autor Desconhecido',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                        trailing: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: const Color(0xFFF1EEFF),
                          ),
                          child: const Icon(Icons.chevron_right_rounded, color: Color(0xFF7C4DFF),
                        ),
                      ),
                        onTap: () async {
                          final resultado = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DetalheLivroPage(livro: livro),
                            ),
                          );
                          if (resultado == true) {
                          buscarLivros();                          
                        }
                      },
                    ),
                   ),
                  );
                },
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