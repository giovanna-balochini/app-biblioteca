import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;

class CapaLivro extends StatelessWidget {
  final dynamic livro;

  const CapaLivro({super.key, required this.livro});

  @override
  Widget build(BuildContext context) {
    final imagem = livro['imagem'];
    final lido = livro['lido'] == true;

    Widget capaSemImagem() => Container(
          width: 56,
          height: 82,
          decoration: BoxDecoration(
            color: const Color(0xFFF1EEFF),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.menu_book_rounded,
            size: 28,
            color: Color(0xFF7C4DFF),
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
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              bytes,
              width: 56,
              height: 82,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => capaSemImagem(),
            ),
          );
        } catch (_) {
          return capaSemImagem();
        }
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: imagemStr,
          width: 56,
          height: 82,
          fit: BoxFit.cover,
          placeholder: (context, url) => const SizedBox(
            width: 56,
            height: 82,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          errorWidget: (context, url, error) => capaSemImagem(),
        ),
      );
    }

    final filhoCapa = (imagem == null || imagem.toString().isEmpty)
        ? capaSemImagem()
        : capaComImagem();

    if (!lido) return filhoCapa;

    return SizedBox(
      width: 56,
      height: 82,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          filhoCapa,
          Positioned(
            top: -3,
            left: -18,
            child: Transform.rotate(
              angle: -math.pi / 4,
              child: Container(
                width: 72,
                height: 18,
                color: const Color(0xFF2E7D32),
              ),
            ),
          ),
          Positioned(
            top: 5,
            left: 0,
            child: Transform.rotate(
              angle: -math.pi / 4,
              child: const Text(
                'LIDO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
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
}
