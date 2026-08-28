import 'package:flutter/material.dart';

@immutable
class AppCores extends ThemeExtension<AppCores> {
  final Color roxoPrimario;
  final Color roxoClaro;
  final Color roxoFundoChip;
  final Color verdeLido;
  final Color verdeLidoFundo;
  final Color cinzaStatus;
  final Color lendoRoxo;
  final Color lendoFundo;
  final Color textoForte;
  final Color textoMedio;
  final Color textoFraco;
  final Color superficieCardClara;
  final Color separador;
  final Color skeletonBase;
  final Color skeletonHigh;

  const AppCores({
    required this.roxoPrimario,
    required this.roxoClaro,
    required this.roxoFundoChip,
    required this.verdeLido,
    required this.verdeLidoFundo,
    required this.cinzaStatus,
    required this.lendoRoxo,
    required this.lendoFundo,
    required this.textoForte,
    required this.textoMedio,
    required this.textoFraco,
    required this.superficieCardClara,
    required this.separador,
    required this.skeletonBase,
    required this.skeletonHigh,
  });

  static AppCores get claro => const AppCores(
        roxoPrimario: Color(0xFF7C4DFF),
        roxoClaro: Color(0xFFB28CFF),
        roxoFundoChip: Color(0xFFF3EEFF),
        verdeLido: Color(0xFF2E7D32),
        verdeLidoFundo: Color(0xFFE8FAF0),
        cinzaStatus: Color(0xFF6C6C80),
        lendoRoxo: Color(0xFF6B3AFF),
        lendoFundo: Color(0xFFEAE2FF),
        textoForte: Color(0xFF1F1F39),
        textoMedio: Color(0xFF4F4F66),
        textoFraco: Color(0xFF8E8EA3),
        superficieCardClara: Color(0xFFFFFFFF),
        separador: Color(0xFFE8E6F0),
        skeletonBase: Color(0xFFE7E5EF),
        skeletonHigh: Color(0xFFF5F4FA),
      );

  static AppCores get escuro => const AppCores(
        roxoPrimario: Color(0xFFB28CFF),
        roxoClaro: Color(0xFFD4B8FF),
        roxoFundoChip: Color(0xFF2A2340),
        verdeLido: Color(0xFF6FDA83),
        verdeLidoFundo: Color(0xFF1A3320),
        cinzaStatus: Color(0xFFB8B8D0),
        lendoRoxo: Color(0xFFC7AEFF),
        lendoFundo: Color(0xFF261D3F),
        textoForte: Color(0xFFF3EEFF),
        textoMedio: Color(0xFFC5C0D8),
        textoFraco: Color(0xFF8E8EA3),
        superficieCardClara: Color(0xFF1C1C27),
        separador: Color(0xFF33333F),
        skeletonBase: Color(0xFF2B2B37),
        skeletonHigh: Color(0xFF3C3C4A),
      );

  @override
  ThemeExtension<AppCores> copyWith({
    Color? roxoPrimario,
    Color? roxoClaro,
    Color? roxoFundoChip,
    Color? verdeLido,
    Color? verdeLidoFundo,
    Color? cinzaStatus,
    Color? lendoRoxo,
    Color? lendoFundo,
    Color? textoForte,
    Color? textoMedio,
    Color? textoFraco,
    Color? superficieCardClara,
    Color? separador,
    Color? skeletonBase,
    Color? skeletonHigh,
  }) {
    return AppCores(
      roxoPrimario: roxoPrimario ?? this.roxoPrimario,
      roxoClaro: roxoClaro ?? this.roxoClaro,
      roxoFundoChip: roxoFundoChip ?? this.roxoFundoChip,
      verdeLido: verdeLido ?? this.verdeLido,
      verdeLidoFundo: verdeLidoFundo ?? this.verdeLidoFundo,
      cinzaStatus: cinzaStatus ?? this.cinzaStatus,
      lendoRoxo: lendoRoxo ?? this.lendoRoxo,
      lendoFundo: lendoFundo ?? this.lendoFundo,
      textoForte: textoForte ?? this.textoForte,
      textoMedio: textoMedio ?? this.textoMedio,
      textoFraco: textoFraco ?? this.textoFraco,
      superficieCardClara: superficieCardClara ?? this.superficieCardClara,
      separador: separador ?? this.separador,
      skeletonBase: skeletonBase ?? this.skeletonBase,
      skeletonHigh: skeletonHigh ?? this.skeletonHigh,
    );
  }

  @override
  ThemeExtension<AppCores> lerp(ThemeExtension<AppCores>? other, double t) {
    if (other is! AppCores) return this;
    return AppCores(
      roxoPrimario: Color.lerp(roxoPrimario, other.roxoPrimario, t)!,
      roxoClaro: Color.lerp(roxoClaro, other.roxoClaro, t)!,
      roxoFundoChip: Color.lerp(roxoFundoChip, other.roxoFundoChip, t)!,
      verdeLido: Color.lerp(verdeLido, other.verdeLido, t)!,
      verdeLidoFundo: Color.lerp(verdeLidoFundo, other.verdeLidoFundo, t)!,
      cinzaStatus: Color.lerp(cinzaStatus, other.cinzaStatus, t)!,
      lendoRoxo: Color.lerp(lendoRoxo, other.lendoRoxo, t)!,
      lendoFundo: Color.lerp(lendoFundo, other.lendoFundo, t)!,
      textoForte: Color.lerp(textoForte, other.textoForte, t)!,
      textoMedio: Color.lerp(textoMedio, other.textoMedio, t)!,
      textoFraco: Color.lerp(textoFraco, other.textoFraco, t)!,
      superficieCardClara: Color.lerp(superficieCardClara, other.superficieCardClara, t)!,
      separador: Color.lerp(separador, other.separador, t)!,
      skeletonBase: Color.lerp(skeletonBase, other.skeletonBase, t)!,
      skeletonHigh: Color.lerp(skeletonHigh, other.skeletonHigh, t)!,
    );
  }
}

extension PegarAppCores on BuildContext {
  AppCores get coresApp {
    final ext = Theme.of(this).extension<AppCores>();
    return ext ??
        (Theme.of(this).brightness == Brightness.dark ? AppCores.escuro : AppCores.claro);
  }

  Color get roxoPrimario => coresApp.roxoPrimario;
  Color get verdeLido => coresApp.verdeLido;
  Color get textoForte => coresApp.textoForte;
}

class Espacamentos {
  static const p4 = SizedBox(width: 4, height: 4);
  static const p6 = SizedBox(width: 6, height: 6);
  static const p8 = SizedBox(width: 8, height: 8);
  static const p10 = SizedBox(width: 10, height: 10);
  static const p12 = SizedBox(width: 12, height: 12);
  static const p14 = SizedBox(width: 14, height: 14);
  static const p16 = SizedBox(width: 16, height: 16);
  static const p20 = SizedBox(width: 20, height: 20);
  static const p24 = SizedBox(width: 24, height: 24);
  static const p32 = SizedBox(width: 32, height: 32);

  static const h4 = SizedBox(height: 4);
  static const h6 = SizedBox(height: 6);
  static const h8 = SizedBox(height: 8);
  static const h10 = SizedBox(height: 10);
  static const h12 = SizedBox(height: 12);
  static const h14 = SizedBox(height: 14);
  static const h16 = SizedBox(height: 16);
  static const h20 = SizedBox(height: 20);
  static const h24 = SizedBox(height: 24);
  static const h32 = SizedBox(height: 32);

  static const w4 = SizedBox(width: 4);
  static const w6 = SizedBox(width: 6);
  static const w8 = SizedBox(width: 8);
  static const w10 = SizedBox(width: 10);
  static const w12 = SizedBox(width: 12);
  static const w14 = SizedBox(width: 14);
  static const w16 = SizedBox(width: 16);
  static const w20 = SizedBox(width: 20);
  static const w24 = SizedBox(width: 24);
}

class Raios {
  static const r8 = BorderRadius.all(Radius.circular(8));
  static const r10 = BorderRadius.all(Radius.circular(10));
  static const r12 = BorderRadius.all(Radius.circular(12));
  static const r14 = BorderRadius.all(Radius.circular(14));
  static const r16 = BorderRadius.all(Radius.circular(16));
  static const r20 = BorderRadius.all(Radius.circular(20));
  static const r24 = BorderRadius.all(Radius.circular(24));
  static const r28 = BorderRadius.all(Radius.circular(28));
  static const rPill = BorderRadius.all(Radius.circular(999));
}
