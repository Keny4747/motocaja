import 'package:flutter_test/flutter_test.dart';
import 'package:motocaja/models/movement.dart';
import 'package:motocaja/models/report_summary.dart';
import 'package:motocaja/services/report_service.dart';

Movement movement({
  required String id,
  required MovementType type,
  required double amount,
  required DateTime date,
  String category = 'Servicio',
  String payment = 'Efectivo',
}) {
  return Movement(
    id: id,
    type: type,
    amount: amount,
    category: category,
    paymentMethod: payment,
    date: date,
  );
}

void main() {
  group('ReportService.rangeFor month', () {
    test('handles a 30-day month without hardcoded day counts', () {
      final range = ReportService.rangeFor(
        ReportPeriod.month,
        DateTime(2026, 9, 14),
      );

      expect(range.start, DateTime(2026, 9, 1));
      expect(range.end, DateTime(2026, 10, 1));
    });

    test('handles December crossing into the next year', () {
      final range = ReportService.rangeFor(
        ReportPeriod.month,
        DateTime(2026, 12, 31),
      );

      expect(range.start, DateTime(2026, 12, 1));
      expect(range.end, DateTime(2027, 1, 1));
    });

    test('handles leap-year February', () {
      final range = ReportService.rangeFor(
        ReportPeriod.month,
        DateTime(2028, 2, 29),
      );

      expect(range.start, DateTime(2028, 2, 1));
      expect(range.end, DateTime(2028, 3, 1));
    });
  });

  test('daily average uses active income days', () {
    final summary = ReportService.build(
      movements: [
        movement(
          id: '1',
          type: MovementType.income,
          amount: 100,
          date: DateTime(2026, 9, 10, 9),
        ),
        movement(
          id: '2',
          type: MovementType.income,
          amount: 80,
          date: DateTime(2026, 9, 12, 9),
        ),
        movement(
          id: '3',
          type: MovementType.expense,
          amount: 20,
          category: 'Gasolina',
          date: DateTime(2026, 9, 12, 10),
        ),
      ],
      period: ReportPeriod.sevenDays,
      selectedDate: DateTime(2026, 9, 14),
    );

    expect(summary.activeDays, 2);
    expect(summary.profit, 160);
    expect(summary.dailyAverage, 80);
  });
}
