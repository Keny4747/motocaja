import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/movement.dart';
import '../models/report_summary.dart';

class PdfReportService {
  const PdfReportService._();

  static Future<void> shareReport(ReportSummary summary) async {
    final bytes = await _buildReport(summary);

    await Printing.sharePdf(
      bytes: bytes,
      filename: _fileName(summary),
    );
  }

  // Se conserva para no romper llamadas antiguas mientras la app migra al
  // exportador generico.
  static Future<void> shareDailyReport(ReportSummary summary) async {
    await shareReport(summary);
  }

  static Future<Uint8List> _buildReport(ReportSummary summary) async {
    final periodTitle = _periodTitle(summary.period);
    final document = pw.Document(
      title: 'MotoCaja - $periodTitle',
      author: 'MotoCaja',
      subject: '$periodTitle de ingresos y gastos',
    );

    final movements = summary.movements.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 14),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'MotoCaja',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                periodTitle,
                style: const pw.TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Pagina ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
        ),
        build: (context) => [
          pw.Text(
            _periodLabel(summary),
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 16),
          _summaryBox(summary),
          pw.SizedBox(height: 22),
          pw.Text(
            'Movimientos',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          if (movements.isEmpty)
            pw.Text(
              'No hay movimientos registrados para este periodo.',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            )
          else
            _movementsTable(
              movements,
              includeDate: summary.period != ReportPeriod.day,
            ),
          pw.SizedBox(height: 22),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _breakdown(
                  'Ingresos por medio de pago',
                  summary.paymentMethods,
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: _breakdown(
                  'Gastos por categoria',
                  summary.expenseCategories,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return document.save();
  }

  static pw.Widget _summaryBox(ReportSummary summary) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          _summaryRow('Ingresos', _money(summary.income)),
          pw.SizedBox(height: 6),
          _summaryRow('Gastos', _money(summary.expenses)),
          pw.Divider(height: 18),
          _summaryRow(
            'Ganancia',
            _money(summary.profit),
            bold: true,
          ),
          pw.SizedBox(height: 6),
          _summaryRow('Servicios', '${summary.services}'),
          if (summary.period != ReportPeriod.day) ...[
            pw.SizedBox(height: 6),
            _summaryRow('Dias trabajados', '${summary.activeDays}'),
            pw.SizedBox(height: 6),
            _summaryRow('Promedio por dia', _money(summary.dailyAverage)),
          ],
        ],
      ),
    );
  }

  static pw.Widget _summaryRow(
    String label,
    String value, {
    bool bold = false,
  }) {
    final style = pw.TextStyle(
      fontSize: 11,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text(value, style: style),
      ],
    );
  }

  static pw.Widget _movementsTable(
    List<Movement> movements, {
    required bool includeDate,
  }) {
    final headers = <String>[
      if (includeDate) 'Fecha',
      'Hora',
      'Tipo',
      'Categoria',
      'Pago',
      'Monto',
    ];

    final data = movements.map((movement) {
      final income = movement.type == MovementType.income;
      return <String>[
        if (includeDate) _shortDate(movement.date),
        _hour(movement.date),
        income ? 'Ingreso' : 'Gasto',
        movement.category,
        movement.paymentMethod,
        '${income ? '+' : '-'} ${_money(movement.amount)}',
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
      ),
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.grey200,
      ),
      cellPadding: const pw.EdgeInsets.symmetric(
        horizontal: 5,
        vertical: 6,
      ),
      columnWidths: includeDate
          ? const {
              0: pw.FlexColumnWidth(1.0),
              1: pw.FlexColumnWidth(0.9),
              2: pw.FlexColumnWidth(1.0),
              3: pw.FlexColumnWidth(1.4),
              4: pw.FlexColumnWidth(1.1),
              5: pw.FlexColumnWidth(1.2),
            }
          : const {
              0: pw.FlexColumnWidth(1.0),
              1: pw.FlexColumnWidth(1.0),
              2: pw.FlexColumnWidth(1.5),
              3: pw.FlexColumnWidth(1.2),
              4: pw.FlexColumnWidth(1.2),
            },
    );
  }

  static pw.Widget _breakdown(
    String title,
    Map<String, double> data,
  ) {
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 7),
        if (entries.isEmpty)
          pw.Text(
            'Sin datos',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          )
        else
          ...entries.map(
            (entry) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      entry.key,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                  pw.Text(
                    _money(entry.value),
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  static String _periodTitle(ReportPeriod period) {
    switch (period) {
      case ReportPeriod.day:
        return 'Reporte diario';
      case ReportPeriod.sevenDays:
        return 'Reporte de 7 dias';
      case ReportPeriod.month:
        return 'Reporte mensual';
    }
  }

  static String _periodLabel(ReportSummary summary) {
    switch (summary.period) {
      case ReportPeriod.day:
        return _longDate(summary.selectedDate);
      case ReportPeriod.sevenDays:
        final lastIncluded = summary.range.end.subtract(
          const Duration(days: 1),
        );
        return '${_longDate(summary.range.start)} al ${_longDate(lastIncluded)}';
      case ReportPeriod.month:
        return '${_monthName(summary.selectedDate.month)} '
            '${summary.selectedDate.year}';
    }
  }

  static String _fileName(ReportSummary summary) {
    final date = summary.selectedDate;

    switch (summary.period) {
      case ReportPeriod.day:
        return 'motocaja_${date.year}-${_two(date.month)}-${_two(date.day)}.pdf';
      case ReportPeriod.sevenDays:
        final lastIncluded = summary.range.end.subtract(
          const Duration(days: 1),
        );
        return 'motocaja_semana_'
            '${_fileDate(summary.range.start)}_a_${_fileDate(lastIncluded)}.pdf';
      case ReportPeriod.month:
        return 'motocaja_mes_${date.year}-${_two(date.month)}.pdf';
    }
  }

  static String _money(double value) => 'S/ ${value.toStringAsFixed(2)}';

  static String _hour(DateTime date) {
    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $suffix';
  }

  static String _shortDate(DateTime date) {
    return '${_two(date.day)}/${_two(date.month)}/${date.year}';
  }

  static String _fileDate(DateTime date) {
    return '${date.year}-${_two(date.month)}-${_two(date.day)}';
  }

  static String _longDate(DateTime date) {
    return '${date.day} de ${_monthName(date.month).toLowerCase()} de ${date.year}';
  }

  static String _monthName(int month) {
    const months = [
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
    ];

    return months[month - 1];
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
