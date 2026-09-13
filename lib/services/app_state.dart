import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import '../models/movement.dart';

class AppState extends ChangeNotifier {
  // Se mantiene temporalmente para migrar instalaciones anteriores.
  static const _legacyMovementsKey = 'movements';
  static const _nameKey = 'profile_name';
  static const _vehicleKey = 'vehicle';
  static const _defaultPaymentKey = 'default_payment';
  static const _remindIncomeKey = 'remind_income';
  static const _remindCloseKey = 'remind_close';

  final List<Movement> _movements = [];
  String name = 'Carlos Ramírez';
  String vehicle = 'Honda Wave';
  String defaultPayment = 'Efectivo';
  bool remindIncome = true;
  bool remindClose = true;
  bool loaded = false;
  String? loadError;

  List<Movement> get movements => List.unmodifiable(_movements);

  void _sortMovementsDescending() {
    _movements.sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> load() async {
    try {
      debugPrint('AppState.load(): iniciando...');

      final prefs = await SharedPreferences.getInstance();

      debugPrint('AppState.load(): SharedPreferences OK');

      name = prefs.getString(_nameKey) ?? name;
      vehicle = prefs.getString(_vehicleKey) ?? vehicle;
      defaultPayment = prefs.getString(_defaultPaymentKey) ?? defaultPayment;
      remindIncome = prefs.getBool(_remindIncomeKey) ?? true;
      remindClose = prefs.getBool(_remindCloseKey) ?? true;

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
    notifyListeners();
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
    notifyListeners();
  }

  Future<void> updateMovement(Movement movement) async {
    await AppDatabase.instance.updateMovement(movement);

    final index = _movements.indexWhere((item) => item.id == movement.id);
    if (index == -1) return;

    _movements[index] = movement;
    _sortMovementsDescending();
    notifyListeners();
  }

  Future<void> deleteMovement(String id) async {
    await AppDatabase.instance.deleteMovement(id);
    _movements.removeWhere((movement) => movement.id == id);
    _sortMovementsDescending();
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

  Future<void> setReminderIncome(bool value) async {
    remindIncome = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_remindIncomeKey, value);
    notifyListeners();
  }

  Future<void> setReminderClose(bool value) async {
    remindClose = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_remindCloseKey, value);
    notifyListeners();
  }

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<Movement> forToday() =>
      _movements.where((m) => sameDay(m.date, DateTime.now())).toList();

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
