import 'package:flutter/material.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/screens/lista_livros_page.dart';
import 'package:frontend/screens/cadastro_page.dart';
import 'package:frontend/utils/snackbars.dart';

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
    final corPrimaria = const Color(0xFF7C4DFF);
    String? novaUrl = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final paddingBottom = MediaQuery.of(ctx).viewInsets.bottom;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: paddingBottom),
            child: Container(
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 14),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: BoxDecoration(
                color: Theme.of(ctx).cardColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE9E6F2)),
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
                          color: const Color(0xFFDCD6F0),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Endereço do backend',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF2A2A38),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Se estiver no celular físico na mesma WiFi, use o IP da sua rede.',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF6B6B80),
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
                    const SizedBox(height: 6),
                    Text(
                      'Sugestão (WiFi atual detectada): http://192.168.15.124:8080',
                      style: TextStyle(
                        fontSize: 11,
                        color: corPrimaria,
                        fontWeight: FontWeight.w700,
                      ),
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
                              backgroundColor: corPrimaria,
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

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final corPrimaria = const Color(0xFF7C4DFF);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: corPrimaria.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.menu_book_rounded, size: 44, color: corPrimaria),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Minha Biblioteca',
                    style: tema.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: corPrimaria,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Entre para acessar seus livros',
                    style: tema.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_ocultarSenha ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _ocultarSenha = !_ocultarSenha),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Informe sua senha';
                      if (value.length < 6) return 'Senha inválida';
                      return null;
                    },
                    enabled: !_carregando,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _carregando ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: corPrimaria,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _carregando
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text('Entrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Não tem conta? ', style: tema.textTheme.bodyMedium),
                      GestureDetector(
                        onTap: _carregando
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const CadastroPage()),
                                );
                              },
                        child: Text(
                          'Cadastre-se',
                          style: tema.textTheme.bodyMedium?.copyWith(
                            color: corPrimaria,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0EDFF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDDD6FF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.wifi_find_rounded,
                                size: 14, color: const Color(0xFF5A3EE8)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Backend (${AuthService.tipoUrlAtual}): ${AuthService.baseUrlAtual}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF5A3EE8),
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.1),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 34,
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _carregando ? null : _abrirConfigUrl,
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                        color: const Color(0xFF5A3EE8)
                                            .withValues(alpha: 0.5),
                                        width: 1),
                                    foregroundColor: const Color(0xFF5A3EE8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(Icons.tune_rounded, size: 15),
                                  label: const Text(
                                    'Alterar URL',
                                    style: TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _carregando
                                      ? null
                                      : () async {
                                          await AuthService.resetarBaseUrl();
                                          if (mounted) setState(() {});
                                          mostrarSnackbarSucesso(context,
                                              'URL resetada. Tente entrar novamente.');
                                        },
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                        color: const Color(0xFF8A8A9D)
                                            .withValues(alpha: 0.45),
                                        width: 1),
                                    foregroundColor: const Color(0xFF6B6B80),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon:
                                      const Icon(Icons.restart_alt_rounded, size: 15),
                                  label: const Text(
                                    'Reset',
                                    style: TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
