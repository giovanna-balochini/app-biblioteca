import 'package:flutter/material.dart';
import '../main.dart' show themeService;
import '../services/auth_service.dart';
import '../services/lembrete_leitura_service.dart' show lembreteLeituraService;
import '../screens/login_page.dart';

const List<Map<String, dynamic>> _diasSemanaBusca = const [
  {'dia': 1, 'rotulo': 'D'},
  {'dia': 2, 'rotulo': 'S'},
  {'dia': 3, 'rotulo': 'T'},
  {'dia': 4, 'rotulo': 'Q'},
  {'dia': 5, 'rotulo': 'Q'},
  {'dia': 6, 'rotulo': 'S'},
  {'dia': 7, 'rotulo': 'S'},
];

String _nomeDiaAbreviado(int dia) {
  switch (dia) {
    case 1: return 'Seg';
    case 2: return 'Ter';
    case 3: return 'Qua';
    case 4: return 'Qui';
    case 5: return 'Sex';
    case 6: return 'Sáb';
    case 7: return 'Dom';
    default: return 'Dia $dia';
  }
}

String _resumoDias(List<int> dias) {
  if (dias.length >= 7) return 'todos os dias';
  if (dias.length == 0) return '—';
  final todosSegSex = dias.toSet().containsAll([1,2,3,4,5]);
  if (todosSegSex && dias.length == 5) return 'Seg a Sex';
  final soFds = dias.toSet().containsAll([6,7]);
  if (soFds && dias.length == 2) return 'finais de semana';
  final ordem = dias.toList()..sort();
  return ordem.map(_nomeDiaAbreviado).join(', ');
}

String _resumoHorario(TimeOfDay t) {
  final m = t.minute.toString().padLeft(2, '0');
  return '${t.hour}:$m';
}

Future<void> exibirMenuConfiguracoes(
  BuildContext context, {
  required VoidCallback abrirConfiguracoesLembrete,
}) async {
  final tema = Theme.of(context);
  final escuro = tema.brightness == Brightness.dark;
  final corPrimaria = const Color(0xFF7C4DFF);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: tema.scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42, height: 5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: escuro ? const Color(0xFF3C3C4E) : const Color(0xFFDFDFEA),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Icon(Icons.tune_rounded, size: 22, color: corPrimaria),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Configurações', style: tema.textTheme.titleLarge),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Personalize sua experiência no app',
                  style: tema.textTheme.bodyMedium?.copyWith(
                        color: escuro ? const Color(0xFFB6B6CC) : const Color(0xFF6B6B80),
                      )),
              const SizedBox(height: 20),

              // ====== CARD 1: LEMBRETE DE LEITURA ======
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      abrirConfiguracoesLembrete();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: escuro ? const Color(0xFF1C1C27) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: escuro ? const Color(0xFF2B2B38) : const Color(0xFFE7E7F1)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: corPrimaria.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: ListenableBuilder(
                            listenable: lembreteLeituraService,
                            builder: (_, __) => Icon(
                              lembreteLeituraService.ligado
                                  ? Icons.notifications_active_rounded
                                  : Icons.notifications_none_rounded,
                              color: corPrimaria, size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('⏰ Lembrete de leitura',
                                  style: tema.textTheme.titleLarge?.copyWith(fontSize: 16)),
                              const SizedBox(height: 2),
                              ListenableBuilder(
                                listenable: lembreteLeituraService,
                                builder: (_, __) {
                                  final ligado = lembreteLeituraService.ligado;
                                  final String resumo;
                                  if (!ligado) resumo = 'Desativado';
                                  else resumo = '${_resumoHorario(lembreteLeituraService.horario)} · ${_resumoDias(lembreteLeituraService.dias)}';
                                  return Text(
                                    resumo,
                                    style: tema.textTheme.bodyMedium?.copyWith(
                                          color: ligado ? corPrimaria : const Color(0xFF8A8A9D),
                                          fontWeight: FontWeight.w600,
                                        ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 22,
                          color: escuro ? const Color(0xFF9C9CB5) : const Color(0xFF8A8A9D),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ====== CARD 2: TEMA ESCURO ======
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: escuro ? const Color(0xFF1C1C27) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: escuro ? const Color(0xFF2B2B38) : const Color(0xFFE7E7F1)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: escuro
                            ? const Color(0xFFFFD964).withValues(alpha: 0.14)
                            : const Color(0xFF3B3B50).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: ListenableBuilder(
                        listenable: themeService,
                        builder: (_, __) => Icon(
                          themeService.temaEscuro ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                          color: themeService.temaEscuro
                              ? const Color(0xFFFFD964)
                              : const Color(0xFF3B3B50),
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListenableBuilder(
                            listenable: themeService,
                            builder: (_, __) => Text(
                              themeService.temaEscuro ? '🌙 Tema escuro' : '☀️ Tema claro',
                              style: tema.textTheme.titleLarge?.copyWith(fontSize: 16),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text('Alterne o visual do aplicativo',
                              style: tema.textTheme.bodyMedium?.copyWith(
                                    color: escuro ? const Color(0xFFB6B6CC) : const Color(0xFF6B6B80),
                                  )),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    ListenableBuilder(
                      listenable: themeService,
                      builder: (_, __) {
                        final bool ligado = themeService.temaEscuro;
                        return Switch.adaptive(
                          value: ligado,
                          activeTrackColor: const Color(0xFF3B3B50).withValues(alpha: 0.5),
                          thumbColor: WidgetStatePropertyAll(
                            ligado ? const Color(0xFFFFD964) : null,
                          ),
                          onChanged: (_) async {
                            await themeService.alternarTema();
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // ====== RODAPÉ: SAIR ======
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final NavigatorState nav = Navigator.of(sheetContext);
                    final bool? confirmou = await showDialog<bool>(
                      context: sheetContext,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('Sair da conta?'),
                        content: const Text('Você precisará fazer login novamente para acessar sua biblioteca.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFFE53935)),
                            child: const Text('Sair', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    );
                    if (confirmou != true) return;
                    try { await AuthService.logout(); } catch (_) {}
                    if (nav.mounted) nav.pop();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                        (rota) => false,
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE53935),
                    side: const BorderSide(color: Color(0xFFE53935), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Sair da conta',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
