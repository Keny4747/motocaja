import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/report_summary.dart';
import '../services/app_state.dart';
import '../services/pdf_report_service.dart';
import '../services/report_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  ReportPeriod _period = ReportPeriod.month;
  DateTime _selectedDate = DateTime.now();
  bool _exportingPdf = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final summary = ReportService.build(
      movements: state.movements,
      period: _period,
      selectedDate: _selectedDate,
    );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          const Center(
            child: Text(
              'Resumen',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppColors.navy,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Tab(
                  text: 'Día',
                  selected: _period == ReportPeriod.day,
                  onTap: () => _setPeriod(ReportPeriod.day),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Tab(
                  text: 'Semana',
                  selected: _period == ReportPeriod.week,
                  onTap: () => _setPeriod(ReportPeriod.week),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Tab(
                  text: 'Mes',
                  selected: _period == ReportPeriod.month,
                  onTap: () => _setPeriod(ReportPeriod.month),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: _previousTooltip(),
                  onPressed: _canMovePrevious() ? () => _movePeriod(-1) : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _selectPeriodDate,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 9,
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.calendar_month_outlined,
                                size: 18,
                                color: AppColors.greenDark,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _periodLabel(summary),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _pickerHint(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: _nextTooltip(),
                  onPressed: _canMoveNext() ? () => _movePeriod(1) : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  _profitTitle(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  money(summary.profit),
                  style: const TextStyle(
                    color: AppColors.greenDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 29,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ValueLine(
                        'Ingresos',
                        summary.income,
                        true,
                      ),
                    ),
                    Expanded(
                      child: _ValueLine(
                        'Gastos',
                        summary.expenses,
                        false,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  icon: Icons.two_wheeler,
                  title: 'Servicios',
                  value: '${summary.services}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(
                  icon: Icons.event_note,
                  title: 'Promedio por día',
                  value: money(summary.dailyAverage),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  icon: Icons.calendar_today_outlined,
                  title: 'Días trabajados',
                  value: '${summary.activeDays}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(
                  icon: Icons.receipt_long_outlined,
                  title: 'Movimientos',
                  value: '${summary.movements.length}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Breakdown(
                  title: 'Ingresos por medio de pago',
                  data: summary.paymentMethods,
                  income: true,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _Breakdown(
                  title: 'Gastos principales',
                  data: summary.expenseCategories,
                  income: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: _exportingPdf
                  ? null
                  : () => _exportPdf(summary),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: _exportingPdf
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: Text(
                _exportingPdf
                    ? 'Generando PDF...'
                    : _exportPdfLabel(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _setPeriod(ReportPeriod period) {
    setState(() {
      _period = period;
    });
  }

  void _movePeriod(int direction) {
    setState(() {
      switch (_period) {
        case ReportPeriod.day:
          _selectedDate = _normalize(
            _selectedDate.add(Duration(days: direction)),
          );
          break;
        case ReportPeriod.week:
          _selectedDate = _normalize(
            _selectedDate.add(Duration(days: 7 * direction)),
          );
          break;
        case ReportPeriod.month:
          _selectedDate = _shiftMonth(_selectedDate, direction);
          break;
      }
    });
  }

  bool _canMovePrevious() {
    final now = _normalize(DateTime.now());
    final minimumStart = ReportService.rangeFor(
      _period,
      _minimumSelectableDate(now),
    ).start;
    final selectedStart = ReportService.rangeFor(
      _period,
      _selectedDate,
    ).start;
    return selectedStart.isAfter(minimumStart);
  }

  bool _canMoveNext() {
    final currentStart = ReportService.rangeFor(
      _period,
      _normalize(DateTime.now()),
    ).start;
    final selectedStart = ReportService.rangeFor(
      _period,
      _selectedDate,
    ).start;
    return selectedStart.isBefore(currentStart);
  }

  Future<void> _selectPeriodDate() async {
    final now = _normalize(DateTime.now());

    if (_period == ReportPeriod.month) {
      final pickedMonth = await _showMonthPicker(now);
      if (pickedMonth == null || !mounted) return;
      setState(() {
        _selectedDate = _dateInMonth(
          pickedMonth.year,
          pickedMonth.month,
          _selectedDate.day,
        );
      });
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(now) ? now : _selectedDate,
      firstDate: _minimumSelectableDate(now),
      lastDate: now,
      helpText: _period == ReportPeriod.day
          ? 'Selecciona el día del reporte'
          : 'Selecciona una fecha de la semana',
      cancelText: 'Cancelar',
      confirmText: _period == ReportPeriod.day
          ? 'Elegir día'
          : 'Elegir semana',
    );

    if (picked == null || !mounted) return;
    setState(() {
      _selectedDate = _normalize(picked);
    });
  }

  Future<DateTime?> _showMonthPicker(DateTime now) {
    final minimumYear = _minimumSelectableDate(now).year;
    var visibleYear = _selectedDate.year.clamp(minimumYear, now.year).toInt();

    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 4),
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              title: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Selecciona el mes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              content: SizedBox(
                width: 330,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Año anterior',
                          onPressed: visibleYear > minimumYear
                              ? () => setDialogState(() => visibleYear--)
                              : null,
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        SizedBox(
                          width: 90,
                          child: Text(
                            '$visibleYear',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Año siguiente',
                          onPressed: visibleYear < now.year
                              ? () => setDialogState(() => visibleYear++)
                              : null,
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.8,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        final month = index + 1;
                        final isFuture = visibleYear == now.year &&
                            month > now.month;
                        final isSelected = visibleYear == _selectedDate.year &&
                            month == _selectedDate.month;

                        return InkWell(
                          onTap: isFuture
                              ? null
                              : () => Navigator.pop(
                                    dialogContext,
                                    DateTime(visibleYear, month, 1),
                                  ),
                          borderRadius: BorderRadius.circular(9),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.green
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.green
                                    : AppColors.border,
                              ),
                            ),
                            child: Text(
                              _monthName(month).substring(0, 3),
                              style: TextStyle(
                                color: isFuture
                                    ? AppColors.muted.withValues(alpha: 0.45)
                                    : isSelected
                                        ? Colors.white
                                        : AppColors.navy,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  DateTime _minimumSelectableDate(DateTime now) {
    return DateTime(now.year - 20, 1, 1);
  }

  DateTime _shiftMonth(DateTime date, int offset) {
    final target = DateTime(date.year, date.month + offset, 1);
    return _dateInMonth(target.year, target.month, date.day);
  }

  DateTime _dateInMonth(int year, int month, int preferredDay) {
    final lastDay = DateTime(year, month + 1, 0).day;
    final safeDay = preferredDay.clamp(1, lastDay).toInt();
    return DateTime(year, month, safeDay);
  }

  String _pickerHint() {
    switch (_period) {
      case ReportPeriod.day:
        return 'Toca para elegir otro día';
      case ReportPeriod.week:
        return 'Toca para elegir otra semana';
      case ReportPeriod.month:
        return 'Toca para elegir otro mes';
    }
  }

  String _previousTooltip() {
    switch (_period) {
      case ReportPeriod.day:
        return 'Día anterior';
      case ReportPeriod.week:
        return 'Semana anterior';
      case ReportPeriod.month:
        return 'Mes anterior';
    }
  }

  String _nextTooltip() {
    switch (_period) {
      case ReportPeriod.day:
        return 'Día siguiente';
      case ReportPeriod.week:
        return 'Semana siguiente';
      case ReportPeriod.month:
        return 'Mes siguiente';
    }
  }

  Future<void> _exportPdf(ReportSummary summary) async {
    setState(() {
      _exportingPdf = true;
    });

    try {
      await PdfReportService.shareReport(summary);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo generar el PDF: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _exportingPdf = false;
        });
      }
    }
  }

  String _exportPdfLabel() {
    switch (_period) {
      case ReportPeriod.day:
        return 'Exportar PDF del día';
      case ReportPeriod.week:
        return 'Exportar PDF de la semana';
      case ReportPeriod.month:
        return 'Exportar PDF del mes';
    }
  }

  String _profitTitle() {
    switch (_period) {
      case ReportPeriod.day:
        return 'GANANCIA DEL DÍA';
      case ReportPeriod.week:
        return 'GANANCIA DE LA SEMANA';
      case ReportPeriod.month:
        return 'GANANCIA DEL MES';
    }
  }

  String _periodLabel(ReportSummary summary) {
    switch (_period) {
      case ReportPeriod.day:
        return _shortLongDate(_selectedDate);
      case ReportPeriod.week:
        final lastIncluded = summary.range.end.subtract(
          const Duration(days: 1),
        );
        return _weekLabel(summary.range.start, lastIncluded);
      case ReportPeriod.month:
        return '${_monthName(_selectedDate.month)} ${_selectedDate.year}';
    }
  }

  DateTime _normalize(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _shortLongDate(DateTime date) {
    return '${date.day} de ${_monthName(date.month).toLowerCase()} de ${date.year}';
  }

  String _weekLabel(DateTime start, DateTime end) {
    final startMonth = _monthName(start.month).substring(0, 3).toLowerCase();
    final endMonth = _monthName(end.month).substring(0, 3).toLowerCase();

    if (start.year != end.year) {
      return '${start.day} $startMonth ${start.year} - '
          '${end.day} $endMonth ${end.year}';
    }
    if (start.month != end.month) {
      return '${start.day} $startMonth - ${end.day} $endMonth ${end.year}';
    }
    return '${start.day} - ${end.day} $endMonth ${end.year}';
  }

  String _monthName(int month) {
    return const [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ][month - 1];
  }
}

class _Tab extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.green : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.green : AppColors.border,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.navy,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ValueLine extends StatelessWidget {
  final String label;
  final double value;
  final bool positive;

  const _ValueLine(
    this.label,
    this.value,
    this.positive,
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          positive ? Icons.arrow_upward : Icons.arrow_downward,
          color: positive ? AppColors.green : AppColors.red,
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              money(value),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: positive ? AppColors.greenDark : AppColors.red,
                fontSize: 13,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _Metric({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.navy),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.muted,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  final String title;
  final Map<String, double> data;
  final bool income;

  const _Breakdown({
    required this.title,
    required this.data,
    required this.income,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 9),
        if (sorted.isEmpty)
          const Text(
            'Sin datos',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11,
            ),
          )
        else
          ...sorted.take(5).map(
                (entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: income ? AppColors.green : AppColors.red,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      Text(
                        money(entry.value),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ],
    );
  }
}
