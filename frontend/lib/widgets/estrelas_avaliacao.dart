import 'package:flutter/material.dart';

class EstrelasAvaliacao extends StatelessWidget {
  final int? avaliacao;
  final double tamanho;
  final bool clicavel;
  final ValueChanged<int>? aoClicar;

  const EstrelasAvaliacao({
    super.key,
    required this.avaliacao,
    this.tamanho = 16,
    this.clicavel = false,
    this.aoClicar,
  });

  @override
  Widget build(BuildContext context) {
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
}
