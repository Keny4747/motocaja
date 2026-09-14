import 'package:flutter_test/flutter_test.dart';
import 'package:motocaja/models/movement.dart';
import 'package:motocaja/services/backup_service.dart';

void main() {
  test('backup round trip preserves financial data and preferences', () {
    final original = BackupData(
      exportedAt: DateTime(2026, 9, 14, 10, 30),
      movements: [
        Movement(
          id: '1',
          type: MovementType.income,
          amount: 8,
          category: 'Servicio',
          paymentMethod: 'Yape',
          date: DateTime(2026, 9, 14, 9),
        ),
        Movement(
          id: '2',
          type: MovementType.expense,
          amount: 5,
          category: 'Gasolina',
          paymentMethod: 'Efectivo',
          date: DateTime(2026, 9, 14, 9, 30),
        ),
      ],
      name: 'Keny',
      vehicle: 'Honda Wave',
      defaultPayment: 'Yape',
      frequentRates: const [5, 7, 8, 10],
      remindIncome: true,
      remindClose: true,
      reminderIntervalMinutes: 90,
      closeHour: 21,
      closeMinute: 0,
      yapeDetectionEnabled: true,
    );

    final restored = BackupData.fromJson(original.toJson());

    expect(restored.movements.length, 2);
    expect(restored.movements.first.id, '2');
    expect(restored.name, 'Keny');
    expect(restored.vehicle, 'Honda Wave');
    expect(restored.defaultPayment, 'Yape');
    expect(restored.frequentRates, [5, 7, 8, 10]);
    expect(restored.reminderIntervalMinutes, 90);
    expect(restored.yapeDetectionEnabled, isTrue);
  });

  test('backup rejects unknown future versions', () {
    expect(
      () => BackupData.fromJson({
        'format': BackupData.format,
        'version': BackupData.currentVersion + 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'data': const {},
      }),
      throwsFormatException,
    );
  });
}
