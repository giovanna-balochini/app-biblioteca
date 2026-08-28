import 'package:flutter/material.dart';
import 'package:frontend/utils/app_theme.dart';

class EmptyState extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String? descricao;
  final String? rotuloBotao;
  final IconData? iconeBotao;
  final VoidCallback? aoClicarBotao;
  final double tamanhoIcone;

  const EmptyState({
    super.key,
    required this.icone,
    required this.titulo,
    this.descricao,
    this.rotuloBotao,
    this.iconeBotao,
    this.aoClicarBotao,
    this.tamanhoIcone = 120,
  });

  @override
  Widget build(BuildContext context) {
    final cores = context.coresApp;
    final esquemaTema = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: tamanhoIcone,
              height: tamanhoIcone,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cores.roxoPrimario.withValues(alpha: 0.18),
                    cores.roxoPrimario.withValues(alpha: 0.06),
                  ],
                ),
              ),
              child: Icon(
                icone,
                size: tamanhoIcone * 0.56,
                color: cores.roxoPrimario,
                shadows: [
                  BoxShadow(
                    color: cores.roxoPrimario.withValues(alpha: 0.22),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: cores.textoForte,
                  ),
            ),
            if (descricao != null && descricao!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                descricao!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.4,
                      color: cores.textoMedio,
                    ),
              ),
            ],
            if (rotuloBotao != null && rotuloBotao!.isNotEmpty && aoClicarBotao != null) ...[
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: aoClicarBotao,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    backgroundColor: cores.roxoPrimario,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  icon: Icon(iconeBotao ?? Icons.add_rounded, size: 20),
                  label: Text(
                    rotuloBotao!,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
