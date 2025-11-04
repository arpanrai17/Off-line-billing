import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../services/pdf_service.dart';
import 'package:printing/printing.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  Widget build(BuildContext context) {
    final todaySales = DatabaseService.getTodaySales();
    final monthSales = DatabaseService.getMonthSales();
    final todayBills = DatabaseService.getTodayBillCount();
    final monthBills = DatabaseService.getMonthBillCount();
    final lowStockCount = DatabaseService.getLowStockMedicines().length;
    final expiringCount = DatabaseService.getExpiringSoonMedicines().length;
    final expiredCount = DatabaseService.getExpiredMedicines().length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sales Summary
            const Text(
              'Sales Summary',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Today\'s Sales',
                    '₹${todaySales.toStringAsFixed(2)}',
                    '$todayBills Bills',
                    Icons.today,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'This Month',
                    '₹${monthSales.toStringAsFixed(2)}',
                    '$monthBills Bills',
                    Icons.calendar_month,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Stock Alerts
            const Text(
              'Stock Alerts',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildAlertCard(
              'Low Stock Items',
              lowStockCount,
              Icons.inventory_2,
              Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildAlertCard(
              'Expiring Soon',
              expiringCount,
              Icons.warning_amber,
              Colors.amber,
            ),
            const SizedBox(height: 12),
            _buildAlertCard(
              'Expired Items',
              expiredCount,
              Icons.dangerous,
              Colors.red,
            ),
            const SizedBox(height: 24),

            // Recent Bills
            const Text(
              'Recent Bills',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildRecentBills(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String amount,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              amount,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(
    String title,
    int count,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _viewBillPdf(bill) async {
    try {
      final file = await PdfService.generateBillPdf(bill);
      final bytes = await file.readAsBytes();
      
      if (mounted) {
        await Printing.layoutPdf(
          onLayout: (_) => bytes,
          name: bill.billNumber,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error viewing PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Widget _buildRecentBills() {
    final recentBills = DatabaseService.getAllBills().take(10).toList();

    if (recentBills.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              'No bills generated yet',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ),
      );
    }

    return Column(
      children: recentBills.map((bill) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: const Icon(Icons.receipt),
            ),
            title: Text(bill.billNumber),
            subtitle: Text(
              DateFormat('dd/MM/yyyy hh:mm a').format(bill.date),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '₹${bill.finalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  onPressed: () => _viewBillPdf(bill),
                  tooltip: 'View PDF',
                  color: Colors.red,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
