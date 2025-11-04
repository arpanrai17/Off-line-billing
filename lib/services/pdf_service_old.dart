import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';

class PdfService {
  static const String shopName = 'Ankush Medical Store';
  static const String shopAddress = 'Geeta Bhawan Complex, Near Bus Stand\nKannod, Madhya Pradesh';
  static const String shopPhone = '9329884653';

  static Future<File> generateBillPdf(Bill bill) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 10),

              // Bill Info
              _buildBillInfo(bill),
              pw.SizedBox(height: 20),

              // Items Table
              _buildItemsTable(bill),
              pw.SizedBox(height: 20),

              // Total Section
              _buildTotalSection(bill),
              pw.Spacer(),

              // Footer
              _buildFooter(),
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

  static pw.Widget _buildHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          shopName,
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          shopAddress,
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 12),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          'Mobile: $shopPhone',
          style: const pw.TextStyle(fontSize: 12),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          'GST: Not Applicable',
          style: pw.TextStyle(
            fontSize: 10,
            fontStyle: pw.FontStyle.italic,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildBillInfo(Bill bill) {
    final dateFormat = DateFormat('dd/MM/yyyy hh:mm a');
    
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Bill No: ${bill.billNumber}',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'Date: ${dateFormat.format(bill.date)}',
              style: const pw.TextStyle(fontSize: 11),
            ),
          ],
        ),
        if (bill.customerName != null && bill.customerName!.isNotEmpty)
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Customer: ${bill.customerName}',
                style: const pw.TextStyle(fontSize: 11),
              ),
              if (bill.customerPhone != null && bill.customerPhone!.isNotEmpty)
                pw.Text(
                  'Phone: ${bill.customerPhone}',
                  style: const pw.TextStyle(fontSize: 11),
                ),
            ],
          ),
      ],
    );
  }

  static pw.Widget _buildItemsTable(Bill bill) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(1.5),
        5: const pw.FlexColumnWidth(2),
      },
      children: [
        // Header Row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _buildTableCell('S.No', isHeader: true),
            _buildTableCell('Medicine Name', isHeader: true),
            _buildTableCell('Batch', isHeader: true),
            _buildTableCell('Qty', isHeader: true),
            _buildTableCell('Rate', isHeader: true),
            _buildTableCell('Amount', isHeader: true),
          ],
        ),
        // Data Rows
        ...bill.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return pw.TableRow(
            children: [
              _buildTableCell('${index + 1}'),
              _buildTableCell(item.medicineName),
              _buildTableCell(item.batch ?? '-'),
              _buildTableCell('${item.quantity}'),
              _buildTableCell('₹${item.rate.toStringAsFixed(2)}'),
              _buildTableCell('₹${item.amount.toStringAsFixed(2)}'),
            ],
          );
        }).toList(),
      ],
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: isHeader ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  static pw.Widget _buildTotalSection(Bill bill) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 200,
        child: pw.Column(
          children: [
            _buildTotalRow('Subtotal:', '₹${bill.subtotal.toStringAsFixed(2)}'),
            if (bill.discount > 0)
              _buildTotalRow('Discount:', '- ₹${bill.discount.toStringAsFixed(2)}'),
            pw.Divider(),
            _buildTotalRow(
              'Total Amount:',
              '₹${bill.finalAmount.toStringAsFixed(2)}',
              isBold: true,
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'Payment Mode: ${bill.paymentMode}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildTotalRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: isBold ? 12 : 11,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: isBold ? 12 : 11,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(),
        pw.SizedBox(height: 10),
        pw.Text(
          'Thank you for your business!',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'For any queries, please contact: $shopPhone',
          style: const pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  static Future<void> printBill(Bill bill) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 10),
              _buildBillInfo(bill),
              pw.SizedBox(height: 20),
              _buildItemsTable(bill),
              pw.SizedBox(height: 20),
              _buildTotalSection(bill),
              pw.Spacer(),
              _buildFooter(),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  static Future<void> shareBill(Bill bill) async {
    final file = await generateBillPdf(bill);
    await Printing.sharePdf(
      bytes: await file.readAsBytes(),
      filename: '${bill.billNumber}.pdf',
    );
  }
}
