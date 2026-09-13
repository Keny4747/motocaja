import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/movement.dart';
import '../models/report_summary.dart';

class PdfReportService {
  const PdfReportService._();

  static Future<void> shareDailyReport(ReportSummary summary) async {
    if (summary.period != ReportPeriod.day) {
      throw ArgumentError('El PDF del MVP solo admite reportes diarios.');
    }

    final bytes = await _buildDailyReport(summary);
    final date = summary.selectedDate;
    final fileName =
        'motocaja_${date.year}-${_two(date.month)}-${_two(date.day)}.pdf';

    await Printing.sharePdf(
      bytes: bytes,
      filename: fileName,
    );
  }

  static Future<Uint8List> _buildDailyReport(ReportSummary summary) async {
    final document = pw.Document(
      title: 'MotoCaja - Reporte diario',
      author: 'MotoCaja',
      subject: 'Reporte diario de ingresos y gastos',
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
                'Reporte diario',
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
            _longDate(summary.selectedDate),
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
              'No hay movimientos registrados para este dia.',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            )
          else
            _movementsTable(movements),
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

  static pw.Widget _movementsTable(List<Movement> movements) {
    return pw.TableHelper.fromTextArray(
      headers: const [
        'Hora',
        'Tipo',
        'Categoria',
        'Pago',
        'Monto',
      ],
      data: movements.map((movement) {
        final income = movement.type == MovementType.income;
        return [
          _hour(movement.date),
          income ? 'Ingreso' : 'Gasto',
          movement.category,
          movement.paymentMethod,
          '${income ? '+' : '-'} ${_money(movement.amount)}',
        ];
      }).toList(),
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
      columnWidths: const {
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


  static String _money(double value) => 'S/ ${value.toStringAsFixed(2)}';

  static String _hour(DateTime date) {
    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $suffix';
  }

  static String _longDate(DateTime date) {
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];

    return '${date.day} de ${months[date.month - 1]} de ${date.year}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
