import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:frontend/services/auth_service.dart';

class BotaoCurtidaAvaliacao extends StatefulWidget {
  final Map<String, dynamic> avaliacao;
  final VoidCallback? onToggle;
  final double tamanhoIcone;
  final bool compacto;

  const BotaoCurtidaAvaliacao({
    super.key,
    required this.avaliacao,
    this.onToggle,
    this.tamanhoIcone = 20,
    this.compacto = false,
  });

  @override
  State<BotaoCurtidaAvaliacao> createState() => _BotaoCurtidaAvaliacaoState();
}

class _BotaoCurtidaAvaliacaoState extends State<BotaoCurtidaAvaliacao>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: _curti ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  bool get _curti => widget.avaliacao['curtiEu'] == true;
  int get _total {
    final v = widget.avaliacao['totalCurtidas'];
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Future<void> _toggle() async {
    if (_carregando) return;
    final idAvaliacao = widget.avaliacao['id'];
    if (idAvaliacao == null) return;
    final estouCurtiAntes = _curti;

    setState(() => _carregando = true);

    // Anima imediatamente (otimista)
    if (estouCurtiAntes) {
      _anim.reverse();
      setState(() {
        widget.avaliacao['curtiEu'] = false;
        widget.avaliacao['totalCurtidas'] = (_total - 1).clamp(0, 999999999);
      });
    } else {
      _anim.forward();
      setState(() {
        widget.avaliacao['curtiEu'] = true;
        widget.avaliacao['totalCurtidas'] = _total + 1;
      });
    }

    try {
      final resp = estouCurtiAntes
          ? await AuthService.delete('/avaliacoes/$idAvaliacao/curtir')
          : await AuthService.post('/avaliacoes/$idAvaliacao/curtir', null);
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final body = jsonDecode(utf8.decode(resp.bodyBytes));
        if (body is Map && body['totalCurtidas'] != null) {
          widget.avaliacao['totalCurtidas'] = (body['totalCurtidas'] as num).toInt();
        }
        widget.onToggle?.call();
      } else {
        // rollback
        setState(() {
          if (estouCurtiAntes) {
            widget.avaliacao['curtiEu'] = true;
            widget.avaliacao['totalCurtidas'] = _total + 1;
            _anim.forward();
          } else {
            widget.avaliacao['curtiEu'] = false;
            widget.avaliacao['totalCurtidas'] = (_total - 1).clamp(0, 999999999);
            _anim.reverse();
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Não foi possível registrar sua curtida. Tente novamente.'),
            backgroundColor: Color(0xFFE03E3E),
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (_) {
      setState(() {
        if (estouCurtiAntes) {
          widget.avaliacao['curtiEu'] = true;
          widget.avaliacao['totalCurtidas'] = _total + 1;
          _anim.forward();
        } else {
          widget.avaliacao['curtiEu'] = false;
          widget.avaliacao['totalCurtidas'] = (_total - 1).clamp(0, 999999999);
          _anim.reverse();
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Sem conexão. Verifique sua internet e tente novamente.'),
          backgroundColor: Color(0xFFE03E3E),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  String _formatar(int valor) {
    if (valor >= 1000000) return '${(valor / 1e6).toStringAsFixed(1)}M';
    if (valor >= 1000) return '${(valor / 1e3).toStringAsFixed(1)}k';
    return valor.toString();
  }

  @override
  Widget build(BuildContext context) {
    final corCurtiu = const Color(0xFFFF2E7C);
    final corPadrao = const Color(0xFF6B6B80);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: _carregando ? null : _toggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 140),
                child: _carregando
                    ? SizedBox(
                        width: widget.tamanhoIcone,
                        height: widget.tamanhoIcone,
                        child: const CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFFF2E7C)),
                      )
                    : ScaleTransition(
                        scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                          CurvedAnimation(parent: _anim, curve: Curves.elasticOut),
                        ),
                        child: Icon(
                          _curti ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          key: ValueKey(_curti),
                          color: _curti ? corCurtiu : corPadrao,
                          size: widget.tamanhoIcone,
                        ),
                      ),
              ),
              if (_total > 0) ...[
                SizedBox(width: widget.compacto ? 3 : 6),
                Text(
                  _formatar(_total),
                  style: TextStyle(
                    fontSize: widget.compacto ? 12 : 13,
                    fontWeight: FontWeight.w700,
                    color: _curti ? corCurtiu : corPadrao,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
