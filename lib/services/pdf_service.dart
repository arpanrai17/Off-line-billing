import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/bill.dart';
import 'settings_service.dart';

class PdfService {
  static Future<File> generateBillPdf(Bill bill) async {
    final pdf = pw.Document();
    final settings = SettingsService.getSettings();

    pw.ImageProvider? logoImage;
    try {
      final ByteData data = await rootBundle.load('Logos/Bill.png');
      logoImage = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      logoImage = null;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          return pw.Stack(
            children: [
              // Watermark (semi-transparent logo in the background)
              if (logoImage != null)
                pw.Positioned.fill(
                  child: pw.Opacity(
                    opacity: 0.05, // 5% opacity for the watermark (reduced for better clarity)
                    child: pw.Center(
                      child: pw.Container(
                        width: 300,
                        height: 300,
                        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                      ),
                    ),
                  ),
                ),
              // Main content
              pw.Column(
                children: [
                  // Header (centered)
                  _buildHeader(settings, logoImage),
                  pw.SizedBox(height: 15),
                  pw.Divider(thickness: 1.5),
                  pw.SizedBox(height: 10),

                  // Bill Info
                  _buildBillInfo(bill),
                  pw.SizedBox(height: 15),

                  // Items Table
                  _buildItemsTable(bill),
                  pw.SizedBox(height: 15),

                  // Total Section
                  _buildTotalSection(bill),
                  pw.Spacer(),

                  // Footer
                  _buildFooter(settings),
                ],
              ),
            ],
          );
        },
      ),
    );

    // Save PDF
    final directory = await getApplicationDocumentsDirectory();
    final billsDir = Directory('${directory.path}/bills');
    if (!await billsDir.exists()) {
      await billsDir.create(recursive: true);
    }

    final file = File('${billsDir.path}/${bill.billNumber}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _buildHeader(settings, [pw.ImageProvider? logoImage]) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // Logo and shop name in a row
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Logo on the left
            if (logoImage != null) ...[
              pw.Image(
                logoImage,
                height: 60,
                width: 60,
                fit: pw.BoxFit.contain,
              ),
              pw.SizedBox(width: 15),
            ],
            // Shop name
            pw.Text(
              settings.shopName,
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        // Address and mobile below
        pw.Text(
          settings.address,
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 11),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'Mobile: ${settings.mobile}',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildBillInfo(Bill bill) {
    final dateFormat = DateFormat('dd/MM/yyyy hh:mm a');
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Bill No: ${bill.billNumber}',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'Date: ${dateFormat.format(bill.date)}',
              style: const pw.TextStyle(fontSize: 11),
            ),
          ],
        ),
        if (bill.customerName != null && bill.customerName!.isNotEmpty) ...[
          pw.SizedBox(height: 5),
          pw.Text(
            'Customer: ${bill.customerName}',
            style: const pw.TextStyle(fontSize: 11),
          ),
        ],
        if (bill.customerPhone != null && bill.customerPhone!.isNotEmpty) ...[
          pw.Text(
            'Phone: ${bill.customerPhone}',
            style: const pw.TextStyle(fontSize: 11),
          ),
        ],
        if (bill.doctorName != null && bill.doctorName!.isNotEmpty) ...[
          pw.Text(
            'Doctor: ${bill.doctorName}',
            style: const pw.TextStyle(fontSize: 11),
          ),
        ],
      ],
    );
  }

  static pw.Widget _buildItemsTable(Bill bill) {
    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColors.grey600,
        width: 0.5, // Thinner borders for better clarity
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.8),  // S.No
        1: const pw.FlexColumnWidth(3),    // Particulars
        2: const pw.FlexColumnWidth(1.5),  // MFG Date
        3: const pw.FlexColumnWidth(1.5),  // Batch
        4: const pw.FlexColumnWidth(1.5),  // Expiry
        5: const pw.FlexColumnWidth(1.5),  // Amount
      },
      children: [
        // Header Row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _buildTableCell('S.No', isHeader: true),
            _buildTableCell('Particulars', isHeader: true),
            _buildTableCell('MFG Date', isHeader: true),
            _buildTableCell('Batch', isHeader: true),
            _buildTableCell('Expiry', isHeader: true),
            _buildTableCell('Amount', isHeader: true),
          ],
        ),
        // Data Rows
        ...bill.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final dateFormat = DateFormat('MM/yyyy');
          
          return pw.TableRow(
            children: [
              _buildTableCell('${index + 1}'),
              _buildTableCell(item.medicineName, align: pw.TextAlign.left),
              _buildTableCell(
                item.mfgDate != null ? dateFormat.format(item.mfgDate!) : '-'
              ),
              _buildTableCell(item.batch ?? '-'),
              _buildTableCell(
                item.expiryDate != null ? dateFormat.format(item.expiryDate!) : '-'
              ),
              _buildTableCell('Rs.${item.amount.toStringAsFixed(0)}'),
            ],
          );
        }).toList(),
      ],
    );
  }

  static pw.Widget _buildTotalSection(Bill bill) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              'Subtotal:',
              style: const pw.TextStyle(fontSize: 11),
            ),
            pw.SizedBox(width: 20),
            pw.Container(
              width: 100,
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Rs.${bill.subtotal.toStringAsFixed(0)}',
                style: const pw.TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
        if (bill.discount > 0) ...[
          pw.SizedBox(height: 5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text(
                bill.isDiscountPercentage 
                    ? 'Discount (${bill.discount}%):' 
                    : 'Discount:',
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.SizedBox(width: 20),
              pw.Container(
                width: 100,
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Rs.${bill.discountAmount.toStringAsFixed(0)}',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ],
        pw.SizedBox(height: 10),
        // Separator line above total
        pw.Container(
          width: 200,
          alignment: pw.Alignment.centerRight,
          child: pw.Divider(thickness: 0.5, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              'Total Amount:',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(width: 20),
            pw.Container(
              width: 100,
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Rs.${bill.finalAmount.toStringAsFixed(0)}',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'Payment Mode: ${bill.paymentMode}',
          style: const pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(settings) {
    return pw.Column(
      children: [
        pw.Divider(thickness: 1),
        pw.SizedBox(height: 8),
        pw.Text(
          'Thank you! Visit again.',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 11,
            fontStyle: pw.FontStyle.italic,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'For any queries, please contact: ${settings.mobile}',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 9),
        ),
      ],
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static Future<void> printBill(Bill bill) async {
    final file = await generateBillPdf(bill);
    final bytes = await file.readAsBytes();
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  static Future<void> shareBill(Bill bill) async {
    final file = await generateBillPdf(bill);
    await Printing.sharePdf(
      bytes: await file.readAsBytes(),
      filename: '${bill.billNumber}.pdf',
    );
  }
}
