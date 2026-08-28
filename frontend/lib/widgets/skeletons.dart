import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:frontend/utils/app_theme.dart';

class ShimmerBase extends StatefulWidget {
  final Widget child;
  final Duration periodo;

  const ShimmerBase({
    super.key,
    required this.child,
    this.periodo = const Duration(milliseconds: 1400),
  });

  @override
  State<ShimmerBase> createState() => _ShimmerBaseState();
}

class _ShimmerBaseState extends State<ShimmerBase> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.periodo)..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cores = context.coresApp;
    final base = cores.skeletonBase;
    final highlight = cores.skeletonHigh;
    return AnimatedBuilder(
      animation: _c,
      builder: (c, w) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [base, base, highlight, base, base],
              stops: const <double>[0.0, 0.35, 0.5, 0.65, 1.0],
              transform: _SlidingGradientTransform(slides: _c.value, largura: bounds.width, altura: bounds.height),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slides;
  final double largura;
  final double altura;
  const _SlidingGradientTransform({
    required this.slides,
    required this.largura,
    required this.altura,
  });

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final dx = -largura + slides * largura * 2.4;
    return Matrix4.translationValues(dx, 0.0, 0.0);
  }
}

class BlocoSkeleton extends StatelessWidget {
  final double? largura;
  final double altura;
  final double raio;
  const BlocoSkeleton({super.key, this.largura, required this.altura, this.raio = 10});

  @override
  Widget build(BuildContext context) {
    final cores = context.coresApp;
    return Container(
      width: largura,
      height: altura,
      decoration: BoxDecoration(
        color: cores.skeletonBase,
        borderRadius: BorderRadius.circular(raio),
      ),
    );
  }
}

class SkeletonCardLivro extends StatelessWidget {
  const SkeletonCardLivro({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerBase(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Card(
          elevation: 0,
          color: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BlocoSkeleton(largura: 56, altura: 82, raio: 10),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      BlocoSkeleton(largura: MediaQuery.of(context).size.width * 0.55, altura: 16, raio: 8),
                      const SizedBox(height: 8),
                      BlocoSkeleton(largura: MediaQuery.of(context).size.width * 0.38, altura: 13, raio: 6),
                      const SizedBox(height: 12),
                      BlocoSkeleton(largura: MediaQuery.of(context).size.width * 0.45, altura: 13, raio: 6),
                      const SizedBox(height: 10),
                      Row(
                        children: const [
                          BlocoSkeleton(largura: 62, altura: 22, raio: 99),
                          SizedBox(width: 8),
                          BlocoSkeleton(largura: 70, altura: 22, raio: 99),
                          Spacer(),
                          BlocoSkeleton(largura: 32, altura: 32, raio: 12),
                        ],
                      ),
                    ],
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

class SkeletonListaLivros extends StatelessWidget {
  final int qtd;
  const SkeletonListaLivros({super.key, this.qtd = 5});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: List<SkeletonCardLivro>.generate(qtd, (_) => const SkeletonCardLivro()),
        ),
      ),
    );
  }
}

class SkeletonCardAvaliacao extends StatelessWidget {
  const SkeletonCardAvaliacao({super.key});

  @override
  Widget build(BuildContext context) {
    final larg = MediaQuery.of(context).size.width;
    return ShimmerBase(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const BlocoSkeleton(largura: 44, altura: 44, raio: 99),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BlocoSkeleton(largura: larg * 0.35, altura: 15, raio: 8),
                          const SizedBox(height: 6),
                          BlocoSkeleton(largura: larg * 0.22, altura: 12, raio: 6),
                        ],
                      ),
                    ),
                    const BlocoSkeleton(largura: 88, altura: 22, raio: 99),
                  ],
                ),
                const SizedBox(height: 16),
                BlocoSkeleton(altura: 14, raio: 7),
                const SizedBox(height: 8),
                BlocoSkeleton(altura: 14, raio: 7),
                const SizedBox(height: 8),
                BlocoSkeleton(largura: larg * 0.6, altura: 14, raio: 7),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const BlocoSkeleton(largura: 60, altura: 22, raio: 10),
                    const Spacer(),
                    const BlocoSkeleton(largura: 38, altura: 34, raio: 12),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SkeletonListaAvaliacoes extends StatelessWidget {
  final int qtd;
  const SkeletonListaAvaliacoes({super.key, this.qtd = 3});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: List<SkeletonCardAvaliacao>.generate(qtd, (_) => const SkeletonCardAvaliacao()),
        ),
      ),
    );
  }
}

class SkeletonCardFeed extends StatelessWidget {
  const SkeletonCardFeed({super.key});

  @override
  Widget build(BuildContext context) {
    final larg = MediaQuery.of(context).size.width;
    return ShimmerBase(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const BlocoSkeleton(largura: 44, altura: 44, raio: 99),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BlocoSkeleton(largura: larg * 0.38, altura: 15, raio: 8),
                          const SizedBox(height: 6),
                          BlocoSkeleton(largura: larg * 0.24, altura: 12, raio: 6),
                        ],
                      ),
                    ),
                    const BlocoSkeleton(largura: 32, altura: 32, raio: 10),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BlocoSkeleton(largura: 64, altura: 96, raio: 12),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BlocoSkeleton(largura: larg * 0.5, altura: 15, raio: 7),
                          const SizedBox(height: 6),
                          BlocoSkeleton(largura: larg * 0.3, altura: 12, raio: 6),
                          const SizedBox(height: 10),
                          BlocoSkeleton(largura: 82, altura: 22, raio: 99),
                          const SizedBox(height: 8),
                          BlocoSkeleton(largura: larg * 0.42, altura: 12, raio: 6),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: const [
                    BlocoSkeleton(largura: 38, altura: 28, raio: 14),
                    SizedBox(width: 10),
                    BlocoSkeleton(largura: 70, altura: 22, raio: 99),
                    Spacer(),
                    BlocoSkeleton(largura: 74, altura: 22, raio: 99),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SkeletonListaFeed extends StatelessWidget {
  final int qtd;
  const SkeletonListaFeed({super.key, this.qtd = 3});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: List<SkeletonCardFeed>.generate(qtd, (_) => const SkeletonCardFeed()),
        ),
      ),
    );
  }
}
