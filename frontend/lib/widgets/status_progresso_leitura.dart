import 'package:flutter/material.dart';

class BarraProgressoCircular extends StatelessWidget {
  final double percentual;
  final double tamanho;
  final double espessura;
  final Color? corPrimaria;
  final Color? corFundo;
  final Widget? centro;

  const BarraProgressoCircular({
    super.key,
    required this.percentual,
    this.tamanho = 54,
    this.espessura = 4.2,
    this.corPrimaria,
    this.corFundo,
    this.centro,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final escuro = tema.brightness == Brightness.dark;
    final double p = (percentual < 0 ? 0 : (percentual > 100 ? 100 : percentual)) / 100;
    final corP = corPrimaria ?? const Color(0xFF7C4DFF);
    final corF = corFundo ?? (escuro ? const Color(0xFF2A2A37) : const Color(0xFFE7E7F1));

    return SizedBox(
      width: tamanho,
      height: tamanho,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: 1,
            strokeWidth: espessura,
            backgroundColor: corF,
            valueColor: AlwaysStoppedAnimation<Color>(corF),
          ),
          CircularProgressIndicator(
            value: p,
            strokeWidth: espessura,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(corP),
            strokeCap: StrokeCap.round,
          ),
          if (centro != null) Center(child: centro!),
        ],
      ),
    );
  }
}

const Color _corQueroLer = Color(0xFF9090B0);
const Color _corLendo = Color(0xFF7C4DFF);
const Color _corLido = Color(0xFF2E7D32);

({Color cor, String rotulo, IconData icone}) infoStatusLeitura(String? status) {
  switch (status?.toUpperCase()) {
    case 'LENDO':
      return (cor: _corLendo, rotulo: 'Lendo', icone: Icons.menu_book_rounded);
    case 'LIDO':
      return (cor: _corLido, rotulo: 'Lido', icone: Icons.check_circle_rounded);
    case 'QUERO_LER':
    default:
      return (cor: _corQueroLer, rotulo: 'Quero ler', icone: Icons.bookmark_border_rounded);
  }
}

class ChipStatusLeitura extends StatelessWidget {
  final String? status;
  final bool compacto;
  const ChipStatusLeitura({super.key, required this.status, this.compacto = false});

  @override
  Widget build(BuildContext context) {
    final info = infoStatusLeitura(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compacto ? 8 : 10,
        vertical: compacto ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: info.cor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: info.cor.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(info.icone, size: compacto ? 13 : 15, color: info.cor),
          SizedBox(width: compacto ? 4 : 6),
          Text(
            info.rotulo,
            style: TextStyle(
              color: info.cor,
              fontSize: compacto ? 11 : 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class InfoProgressoLivro {
  final String? status;
  final int? paginaAtual;
  final int? totalPaginas;
  final double progresso;

  InfoProgressoLivro.fromMap(Map m)
      : status = m['statusLeitura']?.toString() ?? (m['lido'] == true ? 'LIDO' : 'QUERO_LER'),
        paginaAtual = m['paginaAtual'] is num ? (m['paginaAtual'] as num).toInt() : null,
        totalPaginas = m['totalPaginas'] is num ? (m['totalPaginas'] as num).toInt() : null,
        progresso = (m['progressoPercentual'] is num
                ? (m['progressoPercentual'] as num).toDouble()
                : _calcularPercentual(m))
            .clamp(0, 100)
            .toDouble();

  static double _calcularPercentual(Map m) {
    final tot = m['totalPaginas'] is num ? (m['totalPaginas'] as num).toInt() : 0;
    final at = m['paginaAtual'] is num ? (m['paginaAtual'] as num).toInt() : 0;
    if (tot <= 0) return 0;
    final p = (at * 100) / tot;
    return (p * 10).round() / 10;
  }

  String get paginasTexto {
    final tot = totalPaginas;
    final at = paginaAtual;
    if (tot == null || tot <= 0) {
      if (at != null && at > 0) return 'página $at';
      return '';
    }
    return '$at / $tot páginas';
  }
}
