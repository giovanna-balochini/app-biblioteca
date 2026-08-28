import 'package:flutter/material.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/lembrete_leitura_service.dart';
import 'package:frontend/screens/lista_livros_page.dart';
import 'package:frontend/screens/cadastro_page.dart';
import 'package:frontend/utils/snackbars.dart';
import 'package:frontend/utils/app_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _carregando = false;
  bool _ocultarSenha = true;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _carregando = true);
    final resultado = await AuthService.login(
      email: _emailController.text.trim(),
      senha: _senhaController.text,
    );
    if (!mounted) return;
    setState(() => _carregando = false);
    if (resultado['sucesso'] == true) {
      try { await lembreteLeituraService.sincronizarDoServidor(); } catch (_) {}
      if (!mounted) return;
      mostrarSnackbarSucesso(context, 'Bem-vindo(a), ${AuthService.usuarioNome ?? 'Leitor'}!');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ListaLivrosPage()),
      );
    } else {
      setState(() {});
      mostrarSnackbarErro(context, resultado['mensagem'] ?? 'Falha no login');
    }
  }

  Future<void> _abrirConfigUrl() async {
    final inicial = AuthService.baseUrlAtual;
    final controlador = TextEditingController(text: inicial);
    final formKey = GlobalKey<FormState>();
    String? novaUrl = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final paddingBottom = MediaQuery.of(ctx).viewInsets.bottom;
        final cores = ctx.coresApp;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: paddingBottom),
            child: Container(
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 14),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: BoxDecoration(
                color: Theme.of(ctx).cardColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: cores.separador),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: cores.separador,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Endereço do backend',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: cores.textoForte,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Se estiver no celular físico na mesma WiFi, use o IP da sua rede.',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: cores.textoMedio,
                          ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controlador,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: 'URL (ex: http://192.168.15.124:8080)',
                        prefixIcon: const Icon(Icons.link_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        helperText: 'Deixe em branco para voltar ao modo automático',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final uri = Uri.tryParse(
                            v.trim().startsWith('http')
                                ? v.trim()
                                : 'http://' + v.trim());
                        if (uri == null || uri.host.isEmpty) {
                          return 'Endereço inválido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              if (!formKey.currentState!.validate()) return;
                              Navigator.of(ctx).pop(controlador.text.trim());
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: cores.roxoPrimario,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Salvar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    if (novaUrl == null) return;
    if (novaUrl.isEmpty) {
      await AuthService.setBaseUrlManual(null);
      await AuthService.resetarBaseUrl();
      if (mounted) {
        setState(() {});
        mostrarSnackbarSucesso(context, 'Voltou para o modo automático.');
      }
    } else {
      await AuthService.setBaseUrlManual(novaUrl);
      if (mounted) {
        setState(() {});
        mostrarSnackbarSucesso(
            context, 'URL salva: ${AuthService.baseUrlAtual}');
      }
    }
  }

  Future<void> _abrirMenuDevOculto() async {
    await showDialog(
      context: context,
      builder: (ctx) {
        final cores = ctx.coresApp;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Configurações de desenvolvedor'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.wifi_find_rounded, size: 14, color: cores.roxoPrimario),
                    const SizedBox(width: 6),
                    Text(
                      'Backend (${AuthService.tipoUrlAtual})',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: cores.roxoPrimario),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  AuthService.baseUrlAtual,
                  style: TextStyle(fontSize: 13, fontFamily: 'monospace', color: cores.textoForte),
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () async {
                await AuthService.resetarBaseUrl();
                await AuthService.setBaseUrlManual(null);
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                if (mounted) {
                  setState(() {});
                  mostrarSnackbarSucesso(context, 'URL resetada. Modo automático.');
                }
              },
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                foregroundColor: cores.textoMedio,
              ),
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: const Text('Reset'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _abrirConfigUrl();
              },
              style: FilledButton.styleFrom(
                backgroundColor: cores.roxoPrimario,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.tune_rounded, size: 16),
              label: const Text('Alterar URL'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = context.coresApp;
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final alturaTela = MediaQuery.of(context).size.height;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -alturaTela * 0.28,
              right: -alturaTela * 0.18,
              child: Container(
                width: alturaTela * 0.72,
                height: alturaTela * 0.72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      cores.roxoPrimario.withValues(alpha: escuro ? 0.30 : 0.16),
                      cores.roxoPrimario.withValues(alpha: 0.0),
                    ],
                    stops: const [0.3, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -alturaTela * 0.12,
              left: -alturaTela * 0.22,
              child: Container(
                width: alturaTela * 0.52,
                height: alturaTela * 0.52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      cores.verdeLido.withValues(alpha: escuro ? 0.20 : 0.10),
                      cores.verdeLido.withValues(alpha: 0.0),
                    ],
                    stops: const [0.25, 1.0],
                  ),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onLongPress: _abrirMenuDevOculto,
                      child: Column(
                        children: [
                          Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cores.roxoPrimario.withValues(alpha: 0.12),
                              boxShadow: [
                                BoxShadow(
                                  color: cores.roxoPrimario.withValues(alpha: 0.22),
                                  blurRadius: 42,
                                  offset: const Offset(0, 16),
                                  spreadRadius: -2,
                                ),
                                BoxShadow(
                                  color: cores.roxoPrimario.withValues(alpha: 0.10),
                                  blurRadius: 2,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(80),
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Image.asset(
                                  'assets/images/logo_minha_biblioteca.png',
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Minha Biblioteca',
                            style: tema.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: cores.textoForte,
                              height: 1.1,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Organize, acompanhe e compartilhe suas leituras',
                            textAlign: TextAlign.center,
                            style: tema.textTheme.bodyMedium?.copyWith(
                              color: cores.textoMedio,
                              fontWeight: FontWeight.w500,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),
                    Container(
                      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: escuro ? 0.22 : 0.06),
                            blurRadius: 40,
                            offset: const Offset(0, 14),
                            spreadRadius: -6,
                          ),
                        ],
                        border: escuro
                            ? Border.all(color: cores.separador, width: 0.6)
                            : null,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Entrar na conta',
                              style: tema.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: cores.textoForte,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Informe seus dados para continuar.',
                              style: tema.textTheme.bodySmall?.copyWith(
                                color: cores.textoMedio,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 22),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              textInputAction: TextInputAction.next,
                              style: TextStyle(color: cores.textoForte),
                              decoration: InputDecoration(
                                labelText: 'E-mail',
                                hintText: 'voce@email.com',
                                filled: true,
                                fillColor: escuro ? cores.superficieCardClara : cores.roxoFundoChip.withValues(alpha: 0.45),
                                prefixIcon: Icon(Icons.alternate_email_rounded, color: cores.roxoPrimario),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: cores.roxoPrimario, width: 1.5),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: cores.separador, width: 0.8),
                                ),
                                floatingLabelBehavior: FloatingLabelBehavior.auto,
                                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) return 'Informe seu e-mail';
                                final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                                if (!regex.hasMatch(value.trim())) return 'E-mail inválido';
                                return null;
                              },
                              enabled: !_carregando,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _senhaController,
                              obscureText: _ocultarSenha,
                              textInputAction: TextInputAction.send,
                              style: TextStyle(color: cores.textoForte),
                              decoration: InputDecoration(
                                labelText: 'Senha',
                                hintText: 'Sua senha de acesso',
                                filled: true,
                                fillColor: escuro ? cores.superficieCardClara : cores.roxoFundoChip.withValues(alpha: 0.45),
                                prefixIcon: Icon(Icons.lock_outline_rounded, color: cores.roxoPrimario),
                                suffixIcon: IconButton(
                                  splashRadius: 18,
                                  color: cores.textoMedio,
                                  icon: Icon(
                                    _ocultarSenha ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () => setState(() => _ocultarSenha = !_ocultarSenha),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: cores.roxoPrimario, width: 1.5),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: cores.separador, width: 0.8),
                                ),
                                floatingLabelBehavior: FloatingLabelBehavior.auto,
                                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Informe sua senha';
                                if (value.length < 6) return 'Senha inválida';
                                return null;
                              },
                              enabled: !_carregando,
                              onFieldSubmitted: (_) => _submit(),
                            ),
                            const SizedBox(height: 26),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _carregando ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: cores.roxoPrimario,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shadowColor: cores.roxoPrimario.withValues(alpha: 0.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                ),
                                child: _carregando
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.6),
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.login_rounded, size: 20),
                                          SizedBox(width: 10),
                                          Text('Entrar',
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.2)),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Não tem conta? ',
                                    style: tema.textTheme.bodyMedium?.copyWith(color: cores.textoMedio)),
                                GestureDetector(
                                  onTap: _carregando
                                      ? null
                                      : () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(builder: (_) => const CadastroPage()),
                                          );
                                        },
                                  child: Text(
                                    'Crie uma agora',
                                    style: tema.textTheme.bodyMedium?.copyWith(
                                      color: cores.roxoPrimario,
                                      fontWeight: FontWeight.w800,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      '© ${DateTime.now().year} · Minha Biblioteca',
                      style: TextStyle(
                        fontSize: 12,
                        color: cores.textoFraco,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
