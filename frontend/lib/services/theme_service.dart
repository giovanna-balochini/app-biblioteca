import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService with ChangeNotifier {
  static const String _chaveTema = 'tema_escuro_ativo';
  static const Color sementeRoxa = Color(0xFF7C4DFF);

  bool _temaEscuro = false;
  bool get temaEscuro => _temaEscuro;

  ThemeMode get modoTema => _temaEscuro ? ThemeMode.dark : ThemeMode.light;

  Future<void> carregarPreferencia() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _temaEscuro = prefs.getBool(_chaveTema) ?? false;
      notifyListeners();
    } catch (_) {
      _temaEscuro = false;
      notifyListeners();
    }
  }

  Future<void> alternarTema() async {
    _temaEscuro = !_temaEscuro;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_chaveTema, _temaEscuro);
    } catch (_) {}
  }

  static ThemeData buildTemaClaro() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF7F7FB),
      colorScheme: ColorScheme.fromSeed(
        seedColor: sementeRoxa,
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
          backgroundColor: const Color(0xFF7C4DFF),
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
    );
  }

  static ThemeData buildTemaEscuro() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF11111A),
      colorScheme: ColorScheme.fromSeed(
        seedColor: sementeRoxa,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Color(0xFF11111A),
        foregroundColor: Color(0xFFF1EEFF),
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Color(0xFFF1EEFF),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF1C1C27),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF26263A),
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
            color: Color(0xFFB28CFF),
            width: 1.5,
          ),
        ),
        labelStyle: const TextStyle(
          color: Color(0xFFAEAEC5),
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF787890),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFF7C4DFF),
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
          color: Color(0xFFF1EEFF),
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFFF1EEFF),
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: Color(0xFFE5E5F0),
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Color(0xFFAEAEC5),
        ),
      ),
    );
  }
}
