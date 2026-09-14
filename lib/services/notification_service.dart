import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int inactivityNotificationId = 1001;
  static const int dailyCloseNotificationId = 1002;
  static const int testNotificationId = 1099;

  static const String _activityChannelId = 'motocaja_activity_reminders';
  static const String _dailyCloseChannelId = 'motocaja_daily_close';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Payloads pendientes de navegación. MainShell escucha este notifier para
  /// llevar al usuario a Resumen o Registrar servicio cuando toca un aviso.
  final ValueNotifier<String?> navigationPayload = ValueNotifier<String?>(null);

  bool _initialized = false;
  String? _pendingPayload;

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('America/Lima'));
    }

    const androidSettings = AndroidInitializationSettings('ic_stat_motocaja');
    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Si Android abrió MotoCaja desde una notificación cuando la app estaba
    // cerrada, guardamos el payload hasta que MainShell esté listo.
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _pendingPayload = launchDetails?.notificationResponse?.payload;
    }

    _initialized = true;
  }

  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    _pendingPayload = payload;
    navigationPayload.value = payload;
  }

  String? consumePendingPayload() {
    final payload = _pendingPayload;
    _pendingPayload = null;
    if (navigationPayload.value == payload) {
      navigationPayload.value = null;
    }
    return payload;
  }

  Future<bool> requestPermission() async {
    await initialize();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android == null) return true;

    final alreadyEnabled = await android.areNotificationsEnabled();
    if (alreadyEnabled == true) return true;

    final granted = await android.requestNotificationsPermission();
    return granted ?? false;
  }

  Future<bool> areNotificationsEnabled() async {
    await initialize();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android == null) return true;
    return await android.areNotificationsEnabled() ?? false;
  }

  Future<void> showTestNotification() async {
    await initialize();

    await _plugin.show(
      id: testNotificationId,
      title: 'MotoCaja está listo 🏍️',
      body: 'Las notificaciones están activadas correctamente.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _activityChannelId,
          'Recordatorios de actividad',
          channelDescription:
              'Avisos para recordar el registro de servicios e ingresos.',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_motocaja',
        ),
      ),
      payload: 'test',
    );
  }

  Future<void> scheduleInactivityReminder({
    required DateTime lastMovementAt,
    required int intervalMinutes,
    int workStartHour = 7,
    int workStartMinute = 0,
    int workEndHour = 20,
    int workEndMinute = 30,
  }) async {
    await initialize();
    await cancelInactivityReminder();

    final localLastMovement = tz.TZDateTime.from(lastMovementAt, tz.local);
    final scheduledAt = localLastMovement.add(Duration(minutes: intervalMinutes));
    final now = tz.TZDateTime.now(tz.local);

    if (!scheduledAt.isAfter(now)) return;

    final workStart = tz.TZDateTime(
      tz.local,
      scheduledAt.year,
      scheduledAt.month,
      scheduledAt.day,
      workStartHour,
      workStartMinute,
    );
    final workEnd = tz.TZDateTime(
      tz.local,
      scheduledAt.year,
      scheduledAt.month,
      scheduledAt.day,
      workEndHour,
      workEndMinute,
    );

    if (scheduledAt.isBefore(workStart) || scheduledAt.isAfter(workEnd)) {
      return;
    }

    await _plugin.zonedSchedule(
      id: inactivityNotificationId,
      title: '¿Sigues trabajando?',
      body:
          'Han pasado $intervalMinutes minutos desde tu último movimiento. '
          '¿Se te pasó registrar algún servicio?',
      scheduledDate: scheduledAt,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _activityChannelId,
          'Recordatorios de actividad',
          channelDescription:
              'Avisos para recordar el registro de servicios e ingresos.',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_motocaja',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'register_service',
    );
  }

  Future<void> scheduleDailyClose({
    required DateTime activityDate,
    required int hour,
    required int minute,
    required int services,
    required double income,
    required double expenses,
  }) async {
    await initialize();
    await cancelDailyClose();

    final localActivity = tz.TZDateTime.from(activityDate, tz.local);
    final scheduledAt = tz.TZDateTime(
      tz.local,
      localActivity.year,
      localActivity.month,
      localActivity.day,
      hour,
      minute,
    );

    final now = tz.TZDateTime.now(tz.local);
    if (!scheduledAt.isAfter(now)) return;

    final profit = income - expenses;

    await _plugin.zonedSchedule(
      id: dailyCloseNotificationId,
      title: 'Cierre del día',
      body:
          '$services servicios · Ganancia S/ ${profit.toStringAsFixed(2)}. '
          'Revisa tu resumen antes de terminar.',
      scheduledDate: scheduledAt,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _dailyCloseChannelId,
          'Cierre diario',
          channelDescription:
              'Resumen y recordatorio para cerrar la jornada en MotoCaja.',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_motocaja',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'daily_summary',
    );
  }

  Future<void> cancelInactivityReminder() async {
    await initialize();
    await _plugin.cancel(id: inactivityNotificationId);
  }

  Future<void> cancelDailyClose() async {
    await initialize();
    await _plugin.cancel(id: dailyCloseNotificationId);
  }

  Future<void> cancelAllMotoCajaReminders() async {
    await cancelInactivityReminder();
    await cancelDailyClose();
  }
}
