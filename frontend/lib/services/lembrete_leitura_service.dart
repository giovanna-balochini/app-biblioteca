import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/services/notificacao_service.dart';

class LembreteLeituraService with ChangeNotifier {
  bool _ligado = false;
  TimeOfDay _horario = const TimeOfDay(hour: 20, minute: 0);
  List<int> _dias = const [DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday, DateTime.friday, DateTime.saturday, DateTime.sunday];

  bool get ligado => _ligado;
  TimeOfDay get horario => _horario;
  List<int> get dias => _dias;

  static const String _keyLigado = 'lembrete_ligado';
  static const String _keyHora = 'lembrete_hora';
  static const String _keyMinuto = 'lembrete_minuto';
  static const String _keyDias = 'lembrete_dias_json';

  static const String tituloPadrao = 'Hora de ler 📚';
  static const String mensagemPadrao =
      'Que tal 15 páginas do seu livro atual hoje?';

  Future<void> carregarPreferencias() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _ligado = prefs.getBool(_keyLigado) ?? false;
      final hora = prefs.getInt(_keyHora) ?? 20;
      final minuto = prefs.getInt(_keyMinuto) ?? 0;
      _horario = TimeOfDay(hour: hora, minute: minuto);
      final diasStr = prefs.getString(_keyDias);
      if (diasStr != null && diasStr.isNotEmpty) {
        try {
          final lista = diasStr.split(',').map(int.parse).toList();
          if (lista.isNotEmpty) {
            _dias = List<int>.unmodifiable(lista);
          }
        } catch (_) {}
      }
      if (_ligado && _dias.isNotEmpty) {
        try {
          await _aplicarAgendamento();
        } catch (_) {}
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _salvarPreferencias() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyLigado, _ligado);
      await prefs.setInt(_keyHora, _horario.hour);
      await prefs.setInt(_keyMinuto, _horario.minute);
      await prefs.setString(_keyDias, _dias.join(','));
    } catch (_) {}
  }

  Future<void> atualizar({
    bool? ligado,
    TimeOfDay? horario,
    List<int>? dias,
  }) async {
    final mudouAlgo = (ligado != null && ligado != _ligado) ||
        (horario != null &&
            (horario.hour != _horario.hour ||
                horario.minute != _horario.minute)) ||
        (dias != null && !(dias.length == _dias.length && dias.toSet().containsAll(_dias)));

    if (!mudouAlgo) return;

    if (ligado != null) _ligado = ligado;
    if (horario != null) _horario = horario;
    if (dias != null && dias.isNotEmpty) {
      _dias = List<int>.unmodifiable(dias);
    }

    await _aplicarAgendamento();
    await _salvarPreferencias();
    notifyListeners();
  }

  Future<void> alternarLigado() async {
    await atualizar(ligado: !_ligado);
  }

  Future<void> _aplicarAgendamento() async {
    try {
      await NotificacaoService.pedirPermissao();
      await NotificacaoService.cancelarTodosLembretes();
      if (_ligado && _dias.isNotEmpty) {
        await NotificacaoService.agendarLembreteSemanal(
          diasSemana: _dias,
          horario: _horario,
          titulo: tituloPadrao,
          mensagem: mensagemPadrao,
        );
      }
    } catch (_) {}
  }
}

final LembreteLeituraService lembreteLeituraService =
    LembreteLeituraService();
