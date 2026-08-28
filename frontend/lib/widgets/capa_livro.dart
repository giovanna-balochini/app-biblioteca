import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:frontend/utils/app_theme.dart';

class CapaLivro extends StatelessWidget {
  final dynamic livro;
  final String? heroTag;
  final double? largura;
  final double? altura;
  final double? borderRadius;
  final bool mostrarFitaLido;

  const CapaLivro({
    super.key,
    required this.livro,
    this.heroTag,
    this.largura,
    this.altura,
    this.borderRadius,
    this.mostrarFitaLido = true,
  });

  @override
  Widget build(BuildContext context) {
    final w = largura ?? 56.0;
    final h = altura ?? 82.0;
    final raio = borderRadius ?? 10.0;
    final imagem = livro['imagem'];
    final lido = livro['lido'] == true;
    final usarFita = mostrarFitaLido && lido;
    final cores = context.coresApp;
    final roxoIcone = cores.roxoPrimario;
    final fundoSemCapa = cores.roxoFundoChip;
    final corFita = cores.verdeLido;

    Widget capaSemImagem() => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: fundoSemCapa,
            borderRadius: BorderRadius.circular(raio),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.menu_book_rounded,
            size: w <= 60 ? 28 : (w * 0.48).clamp(26, 90),
            color: roxoIcone,
          ),
        );

    Widget capaComImagem() {
      final imagemStr = imagem.toString();
      final ehBase64 = imagemStr.startsWith('data:image') || imagemStr.length > 1000;
      if (ehBase64) {
        try {
          Uint8List bytes;
          if (imagemStr.startsWith('data:image')) {
            final commaIdx = imagemStr.indexOf(',');
            final base64Str = commaIdx != -1 ? imagemStr.substring(commaIdx + 1) : imagemStr;
            bytes = base64Decode(base64Str);
          } else {
            bytes = base64Decode(imagemStr);
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(raio),
            child: Image.memory(
              bytes,
              width: w,
              height: h,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => capaSemImagem(),
            ),
          );
        } catch (_) {
          return capaSemImagem();
        }
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(raio),
        child: CachedNetworkImage(
          imageUrl: imagemStr,
          width: w,
          height: h,
          fit: BoxFit.cover,
          placeholder: (context, url) => SizedBox(
            width: w,
            height: h,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          errorWidget: (context, url, error) => capaSemImagem(),
        ),
      );
    }

    final filhoCapa = (imagem == null || imagem.toString().isEmpty)
        ? capaSemImagem()
        : capaComImagem();

    Widget camadaFita(Widget child) {
      if (!usarFita) return child;
      final tamanhoFita = (w * 1.28).clamp(60.0, 240.0);
      final tamTexto = (w * 0.17).clamp(9.0, 16.0);
      return SizedBox(
        width: w,
        height: h,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            child,
            Positioned(
              top: -(tamanhoFita * 0.04),
              left: -(tamanhoFita * 0.25),
              child: Transform.rotate(
                angle: -math.pi / 4,
                child: Container(
                  width: tamanhoFita,
                  height: (h * 0.21).clamp(15.0, 40.0),
                  color: corFita,
                ),
              ),
            ),
            Positioned(
              top: (h * 0.05).clamp(3, 14),
              left: 0,
              child: Transform.rotate(
                angle: -math.pi / 4,
                child: Text(
                  'LIDO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: tamTexto,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final filho = camadaFita(filhoCapa);

    if (heroTag != null && heroTag!.isNotEmpty) {
      return Hero(
        tag: heroTag!,
        transitionOnUserGestures: true,
        flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
          final Widget toHero = toHeroContext.widget;
          return RotationTransition(
            turns: Tween<double>(begin: flightDirection == HeroFlightDirection.pop ? -0.02 : 0.02, end: 0)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: FadeTransition(
              opacity: animation.drive(Tween<double>(begin: 0.7, end: 1.0)),
              child: toHero,
            ),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: filho,
        ),
      );
    }

    return filho;
  }
}
