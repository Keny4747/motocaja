import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import '../models/movement.dart';
import 'backup_service.dart';
import 'notification_service.dart';

class AppState extends ChangeNotifier {
  // Se mantiene temporalmente para migrar instalaciones anteriores.
  static const _legacyMovementsKey = 'movements';
  static const _nameKey = 'profile_name';
  static const _vehicleKey = 'vehicle';
  static const _defaultPaymentKey = 'default_payment';
  static const _remindIncomeKey = 'remind_income';
  static const _remindCloseKey = 'remind_close';
  static const _reminderIntervalKey = 'reminder_interval_minutes';
  static const _closeHourKey = 'close_hour';
  static const _closeMinuteKey = 'close_minute';
  static const _processedYapeEventIdsKey = 'processed_yape_event_ids';
  static const _frequentRatesKey = 'frequent_rates';
  static const _onboardingCompletedKey = 'onboarding_completed';

  final List<Movement> _movements = [];
  String name = 'Motociclista';
  String vehicle = 'Mi moto';
  String defaultPayment = 'Efectivo';
  final List<double> _frequentRates = [5, 7, 8, 10];
  bool remindIncome = false;
  bool remindClose = false;
  int reminderIntervalMinutes = 90;
  int closeHour = 21;
  int closeMinute = 0;
  bool loaded = false;
  bool onboardingCompleted = false;
  String? loadError;

  List<Movement> get movements => List.unmodifiable(_movements);
  List<double> get frequentRates => List.unmodifiable(_frequentRates);

  void _sortMovementsDescending() {
    _movements.sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> load() async {
    try {
      debugPrint('AppState.load(): iniciando...');

      final prefs = await SharedPreferences.getInstance();

      debugPrint('AppState.load(): SharedPreferences OK');

      final savedOnboarding = prefs.getBool(_onboardingCompletedKey);
      onboardingCompleted = savedOnboarding ?? false;

      name = prefs.getString(_nameKey) ?? name;
      vehicle = prefs.getString(_vehicleKey) ?? vehicle;
      defaultPayment = prefs.getString(_defaultPaymentKey) ?? defaultPayment;
      final savedRates = prefs.getStringList(_frequentRatesKey);
      if (savedRates != null) {
        final parsedRates = savedRates
            .map((value) => double.tryParse(value))
            .whereType<double>()
            .where((value) => value > 0)
            .toSet()
            .toList()
          ..sort();
        if (parsedRates.isNotEmpty) {
          _frequentRates
            ..clear()
            ..addAll(parsedRates.take(6));
        }
      }
      remindIncome = prefs.getBool(_remindIncomeKey) ?? false;
      remindClose = prefs.getBool(_remindCloseKey) ?? false;
      reminderIntervalMinutes = prefs.getInt(_reminderIntervalKey) ?? 90;
      // La opción de 1 minuto existía solo para validar el piloto.
      if (reminderIntervalMinutes == 1) {
        reminderIntervalMinutes = 90;
        await prefs.setInt(_reminderIntervalKey, reminderIntervalMinutes);
      }
      closeHour = prefs.getInt(_closeHourKey) ?? 21;
      closeMinute = prefs.getInt(_closeMinuteKey) ?? 0;

      debugPrint('AppState.load(): intentando abrir SQLite...');

      final databaseMovements = await AppDatabase.instance.getAllMovements();

      debugPrint(
        'AppState.load(): SQLite OK. '
        'Movimientos encontrados: ${databaseMovements.length}',
      );

      _movements
        ..clear()
        ..addAll(databaseMovements);
      _sortMovementsDescending();

      final legacyJson =
          prefs.getStringList(_legacyMovementsKey) ?? const <String>[];

      if (databaseMovements.isEmpty && legacyJson.isNotEmpty) {
        debugPrint(
          'AppState.load(): migrando '
          '${legacyJson.length} movimientos antiguos...',
        );

        final legacyMovements = legacyJson.map(Movement.fromJson).toList();

        await AppDatabase.instance.insertMovements(legacyMovements);

        _movements
          ..clear()
          ..addAll(legacyMovements);
        _sortMovementsDescending();

        await prefs.remove(_legacyMovementsKey);

        debugPrint('AppState.load(): migración completada');
      }

      if (savedOnboarding == null) {
        final hasExistingInstallationData =
            _movements.isNotEmpty ||
            prefs.containsKey(_nameKey) ||
            prefs.containsKey(_vehicleKey) ||
            prefs.containsKey(_frequentRatesKey) ||
            prefs.containsKey(_defaultPaymentKey) ||
            prefs.containsKey(_remindIncomeKey) ||
            prefs.containsKey(_remindCloseKey) ||
            prefs.containsKey(_reminderIntervalKey) ||
            prefs.containsKey(_closeHourKey) ||
            prefs.containsKey(_closeMinuteKey);

        if (hasExistingInstallationData) {
          onboardingCompleted = true;
          await prefs.setBool(_onboardingCompletedKey, true);
        }
      }

      try {
        await _refreshScheduledRemindersOnLoad();
      } catch (error, stackTrace) {
        debugPrint('Aviso: no se pudieron restaurar recordatorios: $error');
        debugPrintStack(stackTrace: stackTrace);
      }

      debugPrint('AppState.load(): completado correctamente');
    } catch (error, stackTrace) {
      loadError = error.toString();

      debugPrint('ERROR AppState.load(): $error');

      debugPrintStack(stackTrace: stackTrace);
    } finally {
      loaded = true;
      notifyListeners();
    }
  }

  Future<void> addIncome(double amount, String paymentMethod) async {
    final movement = Movement(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: MovementType.income,
      amount: amount,
      category: 'Servicio',
      paymentMethod: paymentMethod,
      date: DateTime.now(),
    );

    await AppDatabase.instance.insertMovement(movement);
    _movements.add(movement);
    _sortMovementsDescending();
    try {
      await _afterNewMovement(movement);
    } catch (error) {
      debugPrint('Aviso: no se pudo programar el recordatorio: $error');
    }
    notifyListeners();
  }


  Future<bool> addDetectedYapeIncome({
    required double amount,
    required String eventId,
    required DateTime detectedAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final processed =
        prefs.getStringList(_processedYapeEventIdsKey) ?? <String>[];

    if (processed.contains(eventId)) {
      return false;
    }

    final movement = Movement(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: MovementType.income,
      amount: amount,
      category: 'Servicio',
      paymentMethod: 'Yape',
      date: detectedAt,
    );

    await AppDatabase.instance.insertMovement(movement);
    _movements.add(movement);
    _sortMovementsDescending();

    processed.add(eventId);
    if (processed.length > 100) {
      processed.removeRange(0, processed.length - 100);
    }
    await prefs.setStringList(_processedYapeEventIdsKey, processed);

    try {
      await _afterNewMovement(movement);
    } catch (error) {
      debugPrint('Aviso: no se pudo programar el recordatorio: $error');
    }

    notifyListeners();
    return true;
  }

  Future<void> addExpense(
    double amount,
    String category,
    String paymentMethod,
  ) async {
    final movement = Movement(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: MovementType.expense,
      amount: amount,
      category: category,
      paymentMethod: paymentMethod,
      date: DateTime.now(),
    );

    await AppDatabase.instance.insertMovement(movement);
    _movements.add(movement);
    _sortMovementsDescending();
    try {
      await _afterNewMovement(movement);
    } catch (error) {
      debugPrint('Aviso: no se pudo programar el recordatorio: $error');
    }
    notifyListeners();
  }

  Future<void> updateMovement(Movement movement) async {
    await AppDatabase.instance.updateMovement(movement);

    final index = _movements.indexWhere((item) => item.id == movement.id);
    if (index == -1) return;

    _movements[index] = movement;
    _sortMovementsDescending();
    await _refreshDailyCloseReminder();
    notifyListeners();
  }

  Future<void> deleteMovement(String id) async {
    await AppDatabase.instance.deleteMovement(id);
    _movements.removeWhere((movement) => movement.id == id);
    _sortMovementsDescending();

    if (forToday().isEmpty) {
      await NotificationService.instance.cancelAllMotoCajaReminders();
    } else {
      await _refreshDailyCloseReminder();
    }

    notifyListeners();
  }

  Future<void> updateProfile({
    String? newName,
    String? newVehicle,
    String? newDefaultPayment,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (newName != null) {
      name = newName;
      await prefs.setString(_nameKey, name);
    }
    if (newVehicle != null) {
      vehicle = newVehicle;
      await prefs.setString(_vehicleKey, vehicle);
    }
    if (newDefaultPayment != null) {
      defaultPayment = newDefaultPayment;
      await prefs.setString(_defaultPaymentKey, defaultPayment);
    }
    notifyListeners();
  }

  Future<void> setFrequentRates(List<double> values) async {
    final sanitized = values
        .where((value) => value.isFinite && value > 0)
        .toSet()
        .toList()
      ..sort();

    if (sanitized.isEmpty || sanitized.length > 6) {
      throw ArgumentError('Debes configurar entre 1 y 6 tarifas válidas.');
    }

    _frequentRates
      ..clear()
      ..addAll(sanitized);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _frequentRatesKey,
      _frequentRates.map((value) => value.toString()).toList(),
    );

    notifyListeners();
  }

  BackupData createBackupData({required bool yapeDetectionEnabled}) {
    return BackupData(
      exportedAt: DateTime.now(),
      movements: List<Movement>.from(_movements),
      name: name,
      vehicle: vehicle,
      defaultPayment: defaultPayment,
      frequentRates: List<double>.from(_frequentRates),
      remindIncome: remindIncome,
      remindClose: remindClose,
      reminderIntervalMinutes: reminderIntervalMinutes,
      closeHour: closeHour,
      closeMinute: closeMinute,
      yapeDetectionEnabled: yapeDetectionEnabled,
    );
  }

  Future<void> restoreBackup(BackupData backup) async {
    await AppDatabase.instance.replaceAllMovements(backup.movements);

    _movements
      ..clear()
      ..addAll(backup.movements);
    _sortMovementsDescending();

    name = backup.name.isEmpty ? 'Motociclista' : backup.name;
    vehicle = backup.vehicle.isEmpty ? 'Mi moto' : backup.vehicle;
    defaultPayment = backup.defaultPayment;
    _frequentRates
      ..clear()
      ..addAll(backup.frequentRates);
    remindIncome = backup.remindIncome;
    remindClose = backup.remindClose;
    reminderIntervalMinutes = backup.reminderIntervalMinutes;
    closeHour = backup.closeHour;
    closeMinute = backup.closeMinute;
    onboardingCompleted = true;

    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_nameKey, name),
      prefs.setString(_vehicleKey, vehicle),
      prefs.setString(_defaultPaymentKey, defaultPayment),
      prefs.setStringList(
        _frequentRatesKey,
        _frequentRates.map((value) => value.toString()).toList(),
      ),
      prefs.setBool(_remindIncomeKey, remindIncome),
      prefs.setBool(_remindCloseKey, remindClose),
      prefs.setInt(_reminderIntervalKey, reminderIntervalMinutes),
      prefs.setInt(_closeHourKey, closeHour),
      prefs.setInt(_closeMinuteKey, closeMinute),
      prefs.setBool(_onboardingCompletedKey, true),
    ]);

    await NotificationService.instance.cancelAllMotoCajaReminders();
    try {
      await _refreshScheduledRemindersOnLoad();
    } catch (error) {
      debugPrint('Aviso: no se pudieron restaurar recordatorios: $error');
    }

    notifyListeners();
  }

  Future<void> completeOnboarding({
    required String profileName,
    required String profileVehicle,
    required List<double> rates,
    required String paymentMethod,
    required bool enableReminders,
  }) async {
    final sanitizedRates = rates
        .where((value) => value.isFinite && value > 0)
        .toSet()
        .toList()
      ..sort();

    if (profileName.trim().isEmpty) {
      throw ArgumentError('Ingresa tu nombre.');
    }
    if (profileVehicle.trim().isEmpty) {
      throw ArgumentError('Ingresa los datos de tu moto.');
    }
    if (sanitizedRates.isEmpty || sanitizedRates.length > 6) {
      throw ArgumentError('Configura entre 1 y 6 tarifas válidas.');
    }

    const allowedPayments = {'Efectivo', 'Yape', 'Plin', 'Transferencia'};
    if (!allowedPayments.contains(paymentMethod)) {
      throw ArgumentError('Método de pago no válido.');
    }

    name = profileName.trim();
    vehicle = profileVehicle.trim();
    defaultPayment = paymentMethod;
    _frequentRates
      ..clear()
      ..addAll(sanitizedRates);
    remindIncome = enableReminders;
    remindClose = enableReminders;
    onboardingCompleted = true;

    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_nameKey, name),
      prefs.setString(_vehicleKey, vehicle),
      prefs.setString(_defaultPaymentKey, defaultPayment),
      prefs.setStringList(
        _frequentRatesKey,
        _frequentRates.map((value) => value.toString()).toList(),
      ),
      prefs.setBool(_remindIncomeKey, remindIncome),
      prefs.setBool(_remindCloseKey, remindClose),
      prefs.setBool(_onboardingCompletedKey, true),
    ]);

    notifyListeners();
  }

  Future<void> resetOnboardingForDebug() async {
    onboardingCompleted = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, false);
    notifyListeners();
  }

  Future<void> setReminderIncome(bool value) async {
    remindIncome = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_remindIncomeKey, value);

    if (!value) {
      await NotificationService.instance.cancelInactivityReminder();
    } else {
      final today = forToday();
      if (today.isNotEmpty) {
        await NotificationService.instance.scheduleInactivityReminder(
          lastMovementAt: today.first.date,
          intervalMinutes: reminderIntervalMinutes,
        );
      }
    }

    notifyListeners();
  }

  Future<void> setReminderClose(bool value) async {
    remindClose = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_remindCloseKey, value);

    if (!value) {
      await NotificationService.instance.cancelDailyClose();
    } else {
      await _refreshDailyCloseReminder();
    }

    notifyListeners();
  }

  Future<void> setReminderIntervalMinutes(int minutes) async {
    reminderIntervalMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_reminderIntervalKey, minutes);

    if (remindIncome) {
      final today = forToday();
      if (today.isNotEmpty) {
        await NotificationService.instance.scheduleInactivityReminder(
          lastMovementAt: today.first.date,
          intervalMinutes: reminderIntervalMinutes,
        );
      }
    }

    notifyListeners();
  }

  Future<void> setCloseTime({required int hour, required int minute}) async {
    closeHour = hour;
    closeMinute = minute;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_closeHourKey, hour);
    await prefs.setInt(_closeMinuteKey, minute);

    if (remindClose) {
      await _refreshDailyCloseReminder();
    }

    notifyListeners();
  }

  Future<void> _afterNewMovement(Movement movement) async {
    final notificationsEnabled =
        await NotificationService.instance.areNotificationsEnabled();
    if (!notificationsEnabled) return;

    if (remindIncome) {
      await NotificationService.instance.scheduleInactivityReminder(
        lastMovementAt: movement.date,
        intervalMinutes: reminderIntervalMinutes,
      );
    }

    if (remindClose) {
      await _refreshDailyCloseReminder();
    }
  }

  Future<void> _refreshDailyCloseReminder() async {
    final today = forToday();

    if (!remindClose || today.isEmpty) {
      await NotificationService.instance.cancelDailyClose();
      return;
    }

    final notificationsEnabled =
        await NotificationService.instance.areNotificationsEnabled();
    if (!notificationsEnabled) return;

    await NotificationService.instance.scheduleDailyClose(
      activityDate: DateTime.now(),
      hour: closeHour,
      minute: closeMinute,
      services: servicesOf(today),
      income: incomeOf(today),
      expenses: expensesOf(today),
    );
  }

  Future<void> _refreshScheduledRemindersOnLoad() async {
    final notificationsEnabled =
        await NotificationService.instance.areNotificationsEnabled();
    if (!notificationsEnabled) return;

    final today = forToday();
    if (today.isEmpty) {
      await NotificationService.instance.cancelAllMotoCajaReminders();
      return;
    }

    if (remindIncome) {
      await NotificationService.instance.scheduleInactivityReminder(
        lastMovementAt: today.first.date,
        intervalMinutes: reminderIntervalMinutes,
      );
    }

    if (remindClose) {
      await _refreshDailyCloseReminder();
    }
  }

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<Movement> forDate(DateTime date) =>
      _movements.where((m) => sameDay(m.date, date)).toList();

  List<Movement> forToday() => forDate(DateTime.now());

  List<Movement> from(DateTime start) =>
      _movements.where((m) => !m.date.isBefore(start)).toList();

  double incomeOf(Iterable<Movement> list) => list
      .where((m) => m.type == MovementType.income)
      .fold(0, (sum, movement) => sum + movement.amount);

  double expensesOf(Iterable<Movement> list) => list
      .where((m) => m.type == MovementType.expense)
      .fold(0, (sum, movement) => sum + movement.amount);

  int servicesOf(Iterable<Movement> list) =>
      list.where((m) => m.type == MovementType.income).length;
}
