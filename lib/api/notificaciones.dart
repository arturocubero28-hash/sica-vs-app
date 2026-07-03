import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'client.dart';

/// Maneja las notificaciones push (Firebase Cloud Messaging) de SICA-VS.
///
/// Flujo:
/// 1. Al iniciar sesión, se obtiene el token FCM del dispositivo y se envía
///    al backend para asociarlo al usuario.
/// 2. El backend dispara notificaciones en 3 eventos: cuota por vencer/vencida,
///    comprobante aprobado/rechazado, y entrada/salida de visita.
/// 3. Esta clase las recibe y las muestra, tanto en primer plano como en
///    segundo plano.
class NotificacionesService {
  static final _fcm = FirebaseMessaging.instance;
  static final _local = FlutterLocalNotificationsPlugin();

  static const _canal = AndroidNotificationChannel(
    'sicavs_canal',
    'Notificaciones SICA-VS',
    description: 'Avisos de cuotas, pagos y visitas',
    importance: Importance.high,
  );

  /// Inicializa el sistema de notificaciones. Se llama una vez al arrancar.
  static Future<void> inicializar() async {
    // Permisos (Android 13+ los pide explícitamente)
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // Configurar notificaciones locales (para mostrar cuando la app está abierta)
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _local.initialize(initSettings);

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_canal);

    // Cuando llega una notificación con la app en PRIMER PLANO
    FirebaseMessaging.onMessage.listen(_mostrarLocal);
  }

  /// Registra el token de este dispositivo en el backend (tras login).
  static Future<void> registrarToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await ApiClient.post('/dispositivos/registrar', {'fcm_token': token});
      }
      // Si el token se renueva, actualizarlo también
      _fcm.onTokenRefresh.listen((nuevo) async {
        try {
          await ApiClient.post('/dispositivos/registrar', {'fcm_token': nuevo});
        } catch (_) {}
      });
    } catch (_) {
      // Silencioso: si falla el registro, la app sigue funcionando sin push
    }
  }

  /// Borra el token del backend (al cerrar sesión).
  static Future<void> desregistrar() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await ApiClient.post('/dispositivos/desregistrar', {'fcm_token': token});
      }
    } catch (_) {}
  }

  static void _mostrarLocal(RemoteMessage msg) {
    final notif = msg.notification;
    if (notif == null) return;
    _local.show(
      notif.hashCode,
      notif.title,
      notif.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _canal.id, _canal.name,
          channelDescription: _canal.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFFF48723),
        ),
      ),
    );
  }
}

/// Handler para notificaciones recibidas en SEGUNDO PLANO (app cerrada).
/// Debe ser una función top-level (no dentro de una clase).
@pragma('vm:entry-point')
Future<void> notificacionSegundoPlano(RemoteMessage message) async {
  // No hace falta hacer nada: Android muestra la notificación automáticamente
  // cuando el mensaje trae un bloque 'notification'.
}
