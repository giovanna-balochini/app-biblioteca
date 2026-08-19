import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificacaoService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _inicializado = false;
  static const String _idCanal = 'lembretes_leitura';
  static const String _nomeCanal = 'Lembretes de Leitura';
  static const String _descricaoCanal =
      'Notificações diárias para lembrar você de ler';
  static Future<void> inicializar() async {
    if (_inicializado) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.local);

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _idCanal,
            _nomeCanal,
            description: _descricaoCanal,
            importance: Importance.max,
            enableVibration: true,
            playSound: true,
            showBadge: true,
          ),
        );

    _inicializado = true;
  }

  static Future<bool> pedirPermissao() async {
    if (!_inicializado) await inicializar();

    bool concedida = false;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final result = await android.requestNotificationsPermission();
      concedida = result ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final result = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      concedida = concedida || (result ?? false);
    }

    return concedida;
  }

  static Future<bool> podeAgendarAlarmesExatos() async {
    if (!_inicializado) await inicializar();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.canScheduleExactNotifications() ?? false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static int _idNotificacaoDia(int diaSemana) {
    return 100 + diaSemana;
  }

  static tz.TZDateTime _proximaDataHora(int diaSemana, int hora, int minuto) {
    final agora = tz.TZDateTime.now(tz.local);
    var agendada = tz.TZDateTime(
      tz.local,
      agora.year,
      agora.month,
      agora.day,
      hora,
      minuto,
    );

    int diferenca = diaSemana - agendada.weekday;
    if (diferenca < 0 || (diferenca == 0 && agendada.isBefore(agora))) {
      diferenca += 7;
    }
    agendada = agendada.add(Duration(days: diferenca));
    return agendada;
  }

  static const NotificationDetails _detalhesPadrao = NotificationDetails(
    android: AndroidNotificationDetails(
      _idCanal,
      _nomeCanal,
      channelDescription: _descricaoCanal,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF7C4DFF),
      enableVibration: true,
      playSound: true,
      channelShowBadge: true,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  static Future<void> agendarLembreteSemanal({
    required List<int> diasSemana,
    required TimeOfDay horario,
    required String titulo,
    required String mensagem,
  }) async {
    if (!_inicializado) await inicializar();
    final temExact = await podeAgendarAlarmesExatos();
    final modo = temExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    for (final dia in diasSemana) {
      final id = _idNotificacaoDia(dia);
      await _plugin.zonedSchedule(
        id,
        titulo,
        mensagem,
        _proximaDataHora(dia, horario.hour, horario.minute),
        _detalhesPadrao,
        androidScheduleMode: modo,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  static Future<void> cancelarTodosLembretes() async {
    if (!_inicializado) await inicializar();
    await _plugin.cancelAll();
  }

  static Future<void> cancelarLembretesDosDias(List<int> diasSemana) async {
    if (!_inicializado) await inicializar();
    for (final dia in diasSemana) {
      await _plugin.cancel(_idNotificacaoDia(dia));
    }
  }
}
