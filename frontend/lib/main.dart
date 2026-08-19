import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'services/theme_service.dart';
import 'services/notificacao_service.dart';
import 'services/lembrete_leitura_service.dart';
import 'services/auth_service.dart';
import 'screens/login_page.dart';
import 'home_wrapper.dart';

ThemeService _themeService = ThemeService();

ThemeService get themeService => _themeService;

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await NotificacaoService.inicializar();
  await AuthService.inicializar();
  await _themeService.carregarPreferencia();
  await lembreteLeituraService.carregarPreferencias();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeService,
      builder: (context, child) {
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
          themeMode: themeService.modoTema,
          theme: ThemeService.buildTemaClaro(),
          darkTheme: ThemeService.buildTemaEscuro(),
          home: child,
        );
      },
      child: AuthService.estaLogado ? const HomeWrapper() : const LoginPage(),
    );
  }
}
