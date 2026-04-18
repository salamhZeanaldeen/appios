import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class ReportService {
  Future<void> generateDeadlineReport(List<dynamic> documents) async {
    final pdf = pw.Document();
    final now = DateTime.now();

    // Filter documents with deadlines
    final deadlineDocs = documents.where((doc) => doc['deadline'] != null).toList();
    
    // Sort by proximity
    deadlineDocs.sort((a, b) => DateTime.parse(a['deadline']).compareTo(DateTime.parse(b['deadline'])));

    final arabicFont = await PdfGoogleFonts.notoNaskhArabicRegular();

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: arabicFont),
        build: (pw.Context context) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Header(
                    level: 0,
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('تقرير المواعيد والمدد المتبقية', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                        pw.Text(DateFormat('yyyy-MM-dd').format(now), style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.TableHelper.fromTextArray(
                    context: context,
                    headerAlignment: pw.Alignment.centerRight,
                    cellAlignment: pw.Alignment.centerRight,
                    headers: ['الموضوع', 'الحالة', 'تاريخ الاستحقاق', 'المدة المتبقية'],
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 12),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                    cellStyle: const pw.TextStyle(fontSize: 10),
                    data: deadlineDocs.map((doc) {
                      final deadline = DateTime.parse(doc['deadline']);
                      final difference = deadline.difference(now);
                      final daysLeft = difference.inDays;
                      
                      return [
                        doc['title'],
                        doc['status'],
                        DateFormat('yyyy-MM-dd').format(deadline),
                        daysLeft < 0 ? 'منتهي الصلاحية' : '$daysLeft يوم/أيام',
                      ];
                    }).toList(),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

  await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Future<void> generatePendingReport(List<dynamic> documents) async {
    final pdf = pw.Document();
    final now = DateTime.now();

    // Filter documents that are NOT "تم الإنجاز"
    final pendingDocs = documents.where((doc) => doc['status'] != 'تم الإنجاز').toList();
    
    final arabicFont = await PdfGoogleFonts.notoNaskhArabicRegular();

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: arabicFont),
        build: (pw.Context context) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Header(
                    level: 0,
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('قائمة المراسلات العالقة وغير المنجزة', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                        pw.Text(DateFormat('yyyy-MM-dd').format(now), style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.TableHelper.fromTextArray(
                    context: context,
                    headerAlignment: pw.Alignment.centerRight,
                    cellAlignment: pw.Alignment.centerRight,
                    headers: ['الموضوع', 'الحالة', 'النوع', 'الموعد'],
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 12),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.red800),
                    cellStyle: const pw.TextStyle(fontSize: 10),
                    data: pendingDocs.map((doc) {
                      return [
                        doc['title'],
                        doc['status'],
                        doc['type'],
                        doc['deadline'] != null ? DateFormat('yyyy-MM-dd').format(DateTime.parse(doc['deadline'])) : 'بدون موعد',
                      ];
                    }).toList(),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 20),
                    child: pw.Text('إجمالي المراسلات العالقة: ${pendingDocs.length}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
}
