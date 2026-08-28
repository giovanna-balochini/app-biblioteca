import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

String heroTagLivro(dynamic livro) {
  if (livro == null) return 'livro-sem-id';
  final id = livro['id'];
  if (id != null) return 'livro-capa-$id';
  final titulo = livro['titulo']?.toString().hashCode ?? 0;
  final autor = livro['autor']?.toString().hashCode ?? 0;
  return 'livro-capa-hash-${titulo.abs()}-${autor.abs()}';
}

class RotasAnimadas {
  static PageRouteBuilder<T> fadeSlide<T>(Widget pagina, {Duration duracao = const Duration(milliseconds: 320)}) {
    return PageRouteBuilder<T>(
      transitionDuration: duracao,
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, anim, secundaria) => pagina,
      transitionsBuilder: (context, anim, secundaria, child) {
        final t = CurvedAnimation(parent: anim, curve: Curves.easeOutQuart, reverseCurve: Curves.easeInQuint);
        final slideTween = Tween<Offset>(begin: const Offset(0.0, 0.08), end: Offset.zero).animate(t);
        final fadeTween = Tween<double>(begin: 0.0, end: 1.0).animate(t);
        return FadeTransition(
          opacity: fadeTween,
          child: SlideTransition(position: slideTween, child: child),
        );
      },
    );
  }

  static PageRouteBuilder<T> fadeSimples<T>(Widget pagina, {Duration duracao = const Duration(milliseconds: 240)}) {
    return PageRouteBuilder<T>(
      transitionDuration: duracao,
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim, secundaria) => pagina,
      transitionsBuilder: (context, anim, secundaria, child) {
        final t = CurvedAnimation(parent: anim, curve: Curves.easeOut, reverseCurve: Curves.easeIn);
        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(t),
          child: child,
        );
      },
    );
  }
}

Future<T?> navegarComAnimacao<T extends Object?>(BuildContext context, Widget pagina, {bool fadeApenas = false}) {
  return Navigator.of(context).push<T>(
    fadeApenas ? RotasAnimadas.fadeSimples<T>(pagina) : RotasAnimadas.fadeSlide<T>(pagina),
  );
}

TickerProvider vsyncProviderVsync(BuildContext context) {
  return Navigator.of(context).overlay!;
}
