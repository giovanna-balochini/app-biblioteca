import 'package:flutter/material.dart';
import 'screens/lista_livros_page.dart';
import 'screens/minha_leitura_page.dart';
import 'screens/busca_page.dart';
import 'screens/feed_page.dart';

class HomeWrapper extends StatefulWidget {
  const HomeWrapper({super.key});

  @override
  State<HomeWrapper> createState() => _HomeWrapperState();
}

class _HomeWrapperState extends State<HomeWrapper> {
  int _abaAtual = 0;
  final PageStorageBucket _bucket = PageStorageBucket();
  final List<Widget> _abas = const [
    ListaLivrosPage(),
    MinhaLeituraPage(),
    BuscaPage(),
    FeedPage(),
  ];

  final List<_AbaNav> _navItems = const [
    _AbaNav(
      iconeAtivo: Icons.local_library_rounded,
      iconeInativo: Icons.local_library_outlined,
      rotulo: 'Biblioteca',
    ),
    _AbaNav(
      iconeAtivo: Icons.menu_book_rounded,
      iconeInativo: Icons.menu_book_outlined,
      rotulo: 'Minha leitura',
    ),
    _AbaNav(
      iconeAtivo: Icons.search_rounded,
      iconeInativo: Icons.search_outlined,
      rotulo: 'Buscar',
    ),
    _AbaNav(
      iconeAtivo: Icons.newspaper_rounded,
      iconeInativo: Icons.newspaper_outlined,
      rotulo: 'Feed',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final corPrimaria = const Color(0xFF7C4DFF);

    return Scaffold(
      body: IndexedStack(
        index: _abaAtual,
        children: [
          PageStorage(bucket: _bucket, key: const ValueKey('biblioteca'), child: _abas[0]),
          PageStorage(bucket: _bucket, key: const ValueKey('minha-leitura'), child: _abas[1]),
          PageStorage(bucket: _bucket, key: const ValueKey('busca'), child: _abas[2]),
          PageStorage(bucket: _bucket, key: const ValueKey('feed'), child: _abas[3]),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: tema.cardColor,
          indicatorColor: corPrimaria.withValues(alpha: 0.14),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selecionado = states.contains(WidgetState.selected);
            return TextStyle(
              fontWeight: selecionado ? FontWeight.w800 : FontWeight.w600,
              fontSize: 12,
              color: selecionado ? corPrimaria : const Color(0xFF6B6B80),
              letterSpacing: 0.1,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selecionado = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selecionado ? corPrimaria : const Color(0xFF8A8A9D),
              size: 24,
            );
          }),
        ),
        child: NavigationBar(
          height: 70,
          elevation: 8,
          selectedIndex: _abaAtual,
          animationDuration: const Duration(milliseconds: 450),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) {
            if (mounted) setState(() => _abaAtual = i);
          },
          destinations: List.generate(_navItems.length, (i) {
            final item = _navItems[i];
            return NavigationDestination(
              icon: Icon(item.iconeInativo),
              selectedIcon: Icon(item.iconeAtivo),
              label: item.rotulo,
            );
          }),
        ),
      ),
    );
  }
}

class _AbaNav {
  final IconData iconeAtivo;
  final IconData iconeInativo;
  final String rotulo;

  const _AbaNav({
    required this.iconeAtivo,
    required this.iconeInativo,
    required this.rotulo,
  });
}
