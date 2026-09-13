import '../models/movement.dart';
import '../models/report_summary.dart';

class ReportService {
  const ReportService._();

  static ReportRange rangeFor(
    ReportPeriod period,
    DateTime selectedDate,
  ) {
    final day = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    switch (period) {
      case ReportPeriod.day:
        return ReportRange(
          start: day,
          end: day.add(const Duration(days: 1)),
        );

      case ReportPeriod.sevenDays:
        return ReportRange(
          start: day.subtract(const Duration(days: 6)),
          end: day.add(const Duration(days: 1)),
        );

      case ReportPeriod.month:
        return ReportRange(
          start: DateTime(day.year, day.month, 1),
          end: DateTime(day.year, day.month + 1, 1),
        );
    }
  }

  static ReportSummary build({
    required Iterable<Movement> movements,
    required ReportPeriod period,
    required DateTime selectedDate,
  }) {
    final range = rangeFor(period, selectedDate);

    final filtered = movements
        .where(
          (movement) =>
              !movement.date.isBefore(range.start) &&
              movement.date.isBefore(range.end),
        )
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final incomeMovements = filtered
        .where((movement) => movement.type == MovementType.income)
        .toList();

    final expenseMovements = filtered
        .where((movement) => movement.type == MovementType.expense)
        .toList();

    final income = incomeMovements.fold<double>(
      0,
      (sum, movement) => sum + movement.amount,
    );

    final expenses = expenseMovements.fold<double>(
      0,
      (sum, movement) => sum + movement.amount,
    );

    final activeDayKeys = incomeMovements
        .map(
          (movement) =>
              '${movement.date.year}-${movement.date.month}-${movement.date.day}',
        )
        .toSet();

    final activeDays = activeDayKeys.length;
    final profit = income - expenses;
    final dailyAverage = activeDays == 0 ? 0.0 : profit / activeDays;

    final paymentMethods = <String, double>{};
    for (final movement in incomeMovements) {
      paymentMethods[movement.paymentMethod] =
          (paymentMethods[movement.paymentMethod] ?? 0) + movement.amount;
    }

    final expenseCategories = <String, double>{};
    for (final movement in expenseMovements) {
      expenseCategories[movement.category] =
          (expenseCategories[movement.category] ?? 0) + movement.amount;
    }

    return ReportSummary(
      period: period,
      selectedDate: selectedDate,
      range: range,
      movements: List.unmodifiable(filtered),
      income: income,
      expenses: expenses,
      profit: profit,
      services: incomeMovements.length,
      activeDays: activeDays,
      dailyAverage: dailyAverage,
      paymentMethods: Map.unmodifiable(paymentMethods),
      expenseCategories: Map.unmodifiable(expenseCategories),
    );
  }
}
