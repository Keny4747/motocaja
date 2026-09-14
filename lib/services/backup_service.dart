import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../models/movement.dart';

class BackupData {
  static const String format = 'motocaja-backup';
  static const int currentVersion = 1;

  final DateTime exportedAt;
  final List<Movement> movements;
  final String name;
  final String vehicle;
  final String defaultPayment;
  final List<double> frequentRates;
  final bool remindIncome;
  final bool remindClose;
  final int reminderIntervalMinutes;
  final int closeHour;
  final int closeMinute;
  final bool yapeDetectionEnabled;

  const BackupData({
    required this.exportedAt,
    required this.movements,
    required this.name,
    required this.vehicle,
    required this.defaultPayment,
    required this.frequentRates,
    required this.remindIncome,
    required this.remindClose,
    required this.reminderIntervalMinutes,
    required this.closeHour,
    required this.closeMinute,
    required this.yapeDetectionEnabled,
  });

  Map<String, dynamic> toJson() => {
        'format': format,
        'version': currentVersion,
        'exportedAt': exportedAt.toIso8601String(),
        'data': {
          'profile': {
            'name': name,
            'vehicle': vehicle,
            'defaultPayment': defaultPayment,
          },
          'frequentRates': frequentRates,
          'reminders': {
            'income': remindIncome,
            'close': remindClose,
            'intervalMinutes': reminderIntervalMinutes,
            'closeHour': closeHour,
            'closeMinute': closeMinute,
          },
          'yapeDetectionEnabled': yapeDetectionEnabled,
          'movements': movements.map((movement) => movement.toMap()).toList(),
        },
      };

  factory BackupData.fromJson(Map<String, dynamic> json) {
    if (json['format'] != format) {
      throw const FormatException('El archivo no es un respaldo de MotoCaja.');
    }

    final version = (json['version'] as num?)?.toInt();
    if (version == null || version < 1 || version > currentVersion) {
      throw FormatException(
        'Versión de respaldo no compatible: ${json['version']}.',
      );
    }

    final exportedAt = DateTime.tryParse(json['exportedAt']?.toString() ?? '');
    if (exportedAt == null) {
      throw const FormatException('El respaldo no tiene una fecha válida.');
    }

    final rawData = json['data'];
    if (rawData is! Map) {
      throw const FormatException('El respaldo no contiene datos válidos.');
    }
    final data = Map<String, dynamic>.from(rawData);

    final rawProfile = data['profile'];
    final profile = rawProfile is Map
        ? Map<String, dynamic>.from(rawProfile)
        : <String, dynamic>{};

    final rawReminders = data['reminders'];
    final reminders = rawReminders is Map
        ? Map<String, dynamic>.from(rawReminders)
        : <String, dynamic>{};

    final rawRates = data['frequentRates'];
    final rates = rawRates is List
        ? rawRates
            .map((value) => value is num
                ? value.toDouble()
                : double.tryParse(value.toString()))
            .whereType<double>()
            .where((value) => value.isFinite && value > 0)
            .toSet()
            .toList()
        : <double>[];
    rates.sort();

    if (rates.isEmpty || rates.length > 6) {
      throw const FormatException('Las tarifas del respaldo no son válidas.');
    }

    final rawMovements = data['movements'];
    if (rawMovements is! List) {
      throw const FormatException('El respaldo no contiene movimientos.');
    }

    final movements = <Movement>[];
    final ids = <String>{};
    for (final raw in rawMovements) {
      if (raw is! Map) {
        throw const FormatException('Hay un movimiento inválido en el respaldo.');
      }
      final movement = Movement.fromMap(Map<String, dynamic>.from(raw));
      if (movement.amount <= 0 || !movement.amount.isFinite) {
        throw const FormatException('Hay un monto inválido en el respaldo.');
      }
      if (!ids.add(movement.id)) {
        throw FormatException('El respaldo contiene el ID duplicado ${movement.id}.');
      }
      movements.add(movement);
    }
    movements.sort((a, b) => b.date.compareTo(a.date));

    final defaultPayment = profile['defaultPayment']?.toString() ?? 'Efectivo';
    const allowedPayments = {'Efectivo', 'Yape', 'Plin', 'Transferencia'};

    final interval = (reminders['intervalMinutes'] as num?)?.toInt() ?? 90;
    final safeInterval = const {60, 90, 120}.contains(interval) ? interval : 90;

    final hour = (reminders['closeHour'] as num?)?.toInt() ?? 21;
    final minute = (reminders['closeMinute'] as num?)?.toInt() ?? 0;

    return BackupData(
      exportedAt: exportedAt,
      movements: movements,
      name: (profile['name']?.toString() ?? '').trim(),
      vehicle: (profile['vehicle']?.toString() ?? '').trim(),
      defaultPayment:
          allowedPayments.contains(defaultPayment) ? defaultPayment : 'Efectivo',
      frequentRates: rates,
      remindIncome: reminders['income'] == true,
      remindClose: reminders['close'] == true,
      reminderIntervalMinutes: safeInterval,
      closeHour: hour >= 0 && hour <= 23 ? hour : 21,
      closeMinute: minute >= 0 && minute <= 59 ? minute : 0,
      yapeDetectionEnabled: data['yapeDetectionEnabled'] == true,
    );
  }
}

class BackupService {
  BackupService._();

  static final BackupService instance = BackupService._();

  Future<Uri?> exportBackup(BackupData backup) async {
    final content = const JsonEncoder.withIndent('  ').convert(backup.toJson());
    final bytes = Uint8List.fromList(utf8.encode(content));
    final stamp = _fileTimestamp(backup.exportedAt);

    return FilePicker.saveFile(
      dialogTitle: 'Guardar respaldo de MotoCaja',
      fileName: 'motocaja_respaldo_$stamp.json',
      bytes: bytes,
      mimeType: 'application/json',
    );
  }

  Future<BackupData?> pickBackup() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );

    if (file == null) return null;

    final length = file.lengthSync() ?? await file.length();
    if (length > 20 * 1024 * 1024) {
      throw const FormatException('El respaldo es demasiado grande.');
    }

    final bytes = await file.readAsBytes();
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException('El archivo no contiene JSON válido.');
    }

    return BackupData.fromJson(Map<String, dynamic>.from(decoded));
  }

  String _fileTimestamp(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}${two(date.month)}${two(date.day)}_'
        '${two(date.hour)}${two(date.minute)}';
  }
}
