import 'package:flutter/material.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/screens/lista_livros_page.dart';
import 'package:frontend/utils/snackbars.dart';

class CadastroPage extends StatefulWidget {
  const CadastroPage({super.key});

  @override
  State<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _carregando = false;
  bool _ocultarSenha = true;
  bool _ocultarConfirmacao = true;

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _carregando = true);
    final resultado = await AuthService.registrar(
      nome: _nomeController.text.trim(),
      email: _emailController.text.trim(),
      senha: _senhaController.text,
    );
    if (!mounted) return;
    setState(() => _carregando = false);
    if (resultado['sucesso'] == true) {
      mostrarSnackbarSucesso(context, 'Conta criada com sucesso! Bem-vindo(a)!');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ListaLivrosPage()),
        (_) => false,
      );
    } else {
      mostrarSnackbarErro(context, resultado['mensagem'] ?? 'Falha no cadastro');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final corPrimaria = const Color(0xFF7C4DFF);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar conta'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Crie sua conta',
                    style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: corPrimaria)),
                const SizedBox(height: 6),
                Text('Preencha os campos abaixo para começar.', style: tema.textTheme.bodyMedium),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nomeController,
                  decoration: InputDecoration(
                    labelText: 'Nome',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Informe seu nome';
                    if (value.trim().length < 2) return 'Nome muito curto';
                    return null;
                  },
                  enabled: !_carregando,
                ),
                const SizedBox(height: 14),
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
                    labelText: 'Senha (mín. 6 caracteres)',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_ocultarSenha ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _ocultarSenha = !_ocultarSenha),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Informe uma senha';
                    if (value.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                  enabled: !_carregando,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirmarSenhaController,
                  obscureText: _ocultarConfirmacao,
                  decoration: InputDecoration(
                    labelText: 'Confirmar senha',
                    prefixIcon: const Icon(Icons.lock_reset_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_ocultarConfirmacao ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _ocultarConfirmacao = !_ocultarConfirmacao),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Confirme a senha';
                    if (value != _senhaController.text) return 'As senhas não coincidem';
                    return null;
                  },
                  enabled: !_carregando,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
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
                        : const Text('Criar conta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
