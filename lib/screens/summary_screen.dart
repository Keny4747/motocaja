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
                  selected: _period == ReportPeriod.sevenDays,
                  onTap: () => _setPeriod(ReportPeriod.sevenDays),
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
          Text(
            _periodLabel(summary),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
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
      _selectedDate = _normalize(DateTime.now());
    });
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
      case ReportPeriod.sevenDays:
        return 'Exportar PDF de la semana';
      case ReportPeriod.month:
        return 'Exportar PDF del mes';
    }
  }

  String _profitTitle() {
    switch (_period) {
      case ReportPeriod.day:
        return 'GANANCIA DEL DÍA';
      case ReportPeriod.sevenDays:
        return 'GANANCIA DE 7 DÍAS';
      case ReportPeriod.month:
        return 'GANANCIA DEL MES';
    }
  }

  String _periodLabel(ReportSummary summary) {
    switch (_period) {
      case ReportPeriod.day:
        return _shortLongDate(_selectedDate);
      case ReportPeriod.sevenDays:
        final lastIncluded = summary.range.end.subtract(
          const Duration(days: 1),
        );
        return '${_shortDayMonth(summary.range.start)} - '
            '${_shortDayMonth(lastIncluded)}';
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

  String _shortDayMonth(DateTime date) {
    return '${date.day} ${_monthName(date.month).substring(0, 3).toLowerCase()}';
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
