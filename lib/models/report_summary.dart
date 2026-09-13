import 'movement.dart';

enum ReportPeriod {
  day,
  sevenDays,
  month,
}

class ReportRange {
  final DateTime start;
  final DateTime end;

  const ReportRange({
    required this.start,
    required this.end,
  });
}

class ReportSummary {
  final ReportPeriod period;
  final DateTime selectedDate;
  final ReportRange range;
  final List<Movement> movements;
  final double income;
  final double expenses;
  final double profit;
  final int services;
  final int activeDays;
  final double dailyAverage;
  final Map<String, double> paymentMethods;
  final Map<String, double> expenseCategories;

  const ReportSummary({
    required this.period,
    required this.selectedDate,
    required this.range,
    required this.movements,
    required this.income,
    required this.expenses,
    required this.profit,
    required this.services,
    required this.activeDays,
    required this.dailyAverage,
    required this.paymentMethods,
    required this.expenseCategories,
  });
}
