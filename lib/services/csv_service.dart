import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import '../models/medicine.dart';
import 'database_service.dart';

class CsvService {
  static Future<List<Medicine>> importFromCsv(String filePath, {int? maxRows}) async {
    try {
      final file = File(filePath);
      
      // Check file size
      final fileSize = await file.length();
      final fileSizeMB = fileSize / (1024 * 1024);
      
      print('CSV file size: ${fileSizeMB.toStringAsFixed(2)} MB');
      
      // For large files, read line by line instead of loading all at once
      if (fileSizeMB > 10) {
        return await _importLargeFile(file, maxRows);
      }
      
      final csvString = await file.readAsString();
      
      final List<List<dynamic>> csvData = const CsvToListConverter().convert(
        csvString,
        eol: '\n',
        shouldParseNumbers: false,
      );

      // Skip header row if present
      final dataRows = csvData.length > 1 && _isHeaderRow(csvData[0])
          ? csvData.sublist(1)
          : csvData;

      // Limit rows if specified
      final rowsToProcess = maxRows != null && maxRows < dataRows.length
          ? dataRows.sublist(0, maxRows)
          : dataRows;

      final List<Medicine> medicines = [];
      for (var row in rowsToProcess) {
        if (row.isEmpty || row.every((cell) => cell == null || cell.toString().trim().isEmpty)) {
          continue; // Skip empty rows
        }
        
        try {
          final medicine = Medicine.fromCsv(row);
          medicines.add(medicine);
        } catch (e) {
          print('Error parsing row: $row - $e');
        }
      }

      return medicines;
    } catch (e) {
      print('Error importing CSV: $e');
      rethrow;
    }
  }

  static Future<List<Medicine>> _importLargeFile(File file, int? maxRows) async {
    final List<Medicine> medicines = [];
    final lines = file.openRead().transform(utf8.decoder).transform(const LineSplitter());
    
    int lineCount = 0;
    bool isFirstLine = true;
    
    await for (var line in lines) {
      if (isFirstLine) {
        isFirstLine = false;
        // Skip header
        if (_isHeaderRow([line])) continue;
      }
      
      if (maxRows != null && lineCount >= maxRows) break;
      
      try {
        final row = line.split(',');
        if (row.isEmpty || row.every((cell) => cell.trim().isEmpty)) continue;
        
        final medicine = Medicine.fromCsv(row);
        medicines.add(medicine);
        lineCount++;
        
        // Print progress every 1000 rows
        if (lineCount % 1000 == 0) {
          print('Imported $lineCount medicines...');
        }
      } catch (e) {
        print('Error parsing line $lineCount: $e');
      }
    }
    
    print('Total imported: $lineCount medicines');
    return medicines;
  }

  static bool _isHeaderRow(List<dynamic> row) {
    final firstCell = row[0]?.toString().toLowerCase() ?? '';
    return firstCell.contains('id') || 
           firstCell.contains('name') || 
           firstCell.contains('medicine');
  }

  static Future<int> importAndSaveMedicines(String filePath) async {
    final medicines = await importFromCsv(filePath);
    await DatabaseService.addMedicines(medicines);
    return medicines.length;
  }

  static Future<String?> pickCsvFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.single.path != null) {
        return result.files.single.path;
      }
      return null;
    } catch (e) {
      print('Error picking file: $e');
      return null;
    }
  }

  static Future<String> exportMedicinesToCsv(List<Medicine> medicines) async {
    final List<List<dynamic>> rows = [
      [
        'ID',
        'Name',
        'Batch',
        'Expiry Date',
        'Quantity',
        'MRP',
        'Purchase Price',
        'Manufacturer',
        'Category',
      ],
    ];

    for (var medicine in medicines) {
      rows.add([
        medicine.id,
        medicine.name,
        medicine.batch ?? '',
        medicine.expiryDate != null
            ? '${medicine.expiryDate!.day}/${medicine.expiryDate!.month}/${medicine.expiryDate!.year}'
            : '',
        medicine.quantity,
        medicine.mrp,
        medicine.purchasePrice ?? '',
        medicine.manufacturer ?? '',
        medicine.category ?? '',
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  static Future<String> exportBillsToCsv(List bills) async {
    final List<List<dynamic>> rows = [
      [
        'Bill Number',
        'Date',
        'Customer Name',
        'Customer Phone',
        'Total Amount',
        'Discount',
        'Final Amount',
        'Payment Mode',
      ],
    ];

    for (var bill in bills) {
      rows.add([
        bill.billNumber,
        '${bill.date.day}/${bill.date.month}/${bill.date.year}',
        bill.customerName ?? '',
        bill.customerPhone ?? '',
        bill.subtotal,
        bill.discount,
        bill.finalAmount,
        bill.paymentMode,
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }
}
