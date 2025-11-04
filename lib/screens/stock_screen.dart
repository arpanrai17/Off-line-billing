import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medicine.dart';
import '../services/database_service.dart';
import '../services/csv_service.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Medicine> _medicines = [];
  List<Medicine> _filteredMedicines = [];
  String _filterType = 'all'; // all, low_stock, expiring, expired

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadMedicines() {
    setState(() {
      _medicines = DatabaseService.getAllMedicines();
      _applyFilter();
    });
  }

  void _applyFilter() {
    List<Medicine> filtered;
    
    switch (_filterType) {
      case 'low_stock':
        filtered = DatabaseService.getLowStockMedicines();
        break;
      case 'expiring':
        filtered = DatabaseService.getExpiringSoonMedicines();
        break;
      case 'expired':
        filtered = DatabaseService.getExpiredMedicines();
        break;
      default:
        filtered = _medicines;
    }

    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((medicine) {
        return medicine.name.toLowerCase().contains(query) ||
               (medicine.manufacturer?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    setState(() {
      _filteredMedicines = filtered;
    });
  }

  Future<void> _importCsv() async {
    try {
      final filePath = await CsvService.pickCsvFile();
      if (filePath == null) return;

      // Check file size first
      final file = File(filePath);
      final fileSize = await file.length();
      final fileSizeMB = fileSize / (1024 * 1024);

      int? maxRows;
      
      // If file is large, ask user how many to import
      if (fileSizeMB > 5) {
        if (!mounted) return;
        final result = await _showImportLimitDialog(fileSizeMB);
        if (result == -1) return; // User cancelled
        maxRows = result == 0 ? null : result; // 0 means import all
      }

      if (!mounted) return;
      
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Importing medicines...'),
                ],
              ),
            ),
          ),
        ),
      );

      final medicines = await CsvService.importFromCsv(filePath, maxRows: maxRows);
      await DatabaseService.addMedicines(medicines);
      
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported ${medicines.length} medicines'),
            backgroundColor: Colors.green,
          ),
        );
        _loadMedicines();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<int> _showImportLimitDialog(double fileSizeMB) async {
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Large File Detected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File size: ${fileSizeMB.toStringAsFixed(2)} MB'),
            const SizedBox(height: 16),
            const Text('How many medicines do you want to import?'),
            const SizedBox(height: 8),
            const Text(
              'Note: Importing all medicines will take time but search is optimized.',
              style: TextStyle(fontSize: 12, color: Colors.blue),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, -1),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 1000),
            child: const Text('1,000'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 5000),
            child: const Text('5,000'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 10000),
            child: const Text('10,000'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 0),
            child: const Text('Import All'),
          ),
        ],
      ),
    ).then((value) => value ?? -1);
  }

  Future<void> _showAddMedicineDialog() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController mrpController = TextEditingController();
    final TextEditingController batchController = TextEditingController();
    final TextEditingController expiryController = TextEditingController();
    final TextEditingController manufacturerController = TextEditingController();
    final TextEditingController categoryController = TextEditingController();
    final TextEditingController quantityController = TextEditingController(text: '50');
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Medicine Manually'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Medicine Name *',
                  hintText: 'Required',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mrpController,
                decoration: const InputDecoration(
                  labelText: 'MRP *',
                  prefixText: '₹ ',
                  hintText: 'Required',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: batchController,
                decoration: const InputDecoration(
                  labelText: 'Batch Number (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: expiryController,
                decoration: const InputDecoration(
                  labelText: 'Expiry Date (Optional)',
                  hintText: 'MM/YYYY',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: manufacturerController,
                decoration: const InputDecoration(
                  labelText: 'Manufacturer (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.isEmpty || mrpController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Name and MRP are required!'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              final medicine = Medicine(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameController.text,
                mrp: double.parse(mrpController.text),
                quantity: int.tryParse(quantityController.text) ?? 50,
                batch: batchController.text.isEmpty ? null : batchController.text,
                manufacturer: manufacturerController.text.isEmpty 
                    ? null 
                    : manufacturerController.text,
                category: categoryController.text.isEmpty 
                    ? null 
                    : categoryController.text,
                lastUpdated: DateTime.now(),
              );
              
              await DatabaseService.addMedicine(medicine);
              Navigator.pop(context);
              _loadMedicines();
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Medicine added successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Add Medicine'),
          ),
        ],
      ),
    );
  }
  
  void _showMedicineDetails(Medicine medicine) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(medicine.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Batch', medicine.batch ?? 'N/A'),
              _buildDetailRow('Quantity', '${medicine.quantity}'),
              _buildDetailRow('MRP', '₹${medicine.mrp.toStringAsFixed(2)}'),
              if (medicine.purchasePrice != null)
                _buildDetailRow('Purchase Price', '₹${medicine.purchasePrice!.toStringAsFixed(2)}'),
              if (medicine.manufacturer != null)
                _buildDetailRow('Manufacturer', medicine.manufacturer!),
              if (medicine.category != null)
                _buildDetailRow('Category', medicine.category!),
              if (medicine.expiryDate != null)
                _buildDetailRow(
                  'Expiry Date',
                  DateFormat('dd/MM/yyyy').format(medicine.expiryDate!),
                ),
              if (medicine.lastUpdated != null)
                _buildDetailRow(
                  'Last Updated',
                  DateFormat('dd/MM/yyyy hh:mm a').format(medicine.lastUpdated!),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Management'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            onPressed: _showAddMedicineDialog,
            icon: const Icon(Icons.add),
            tooltip: 'Add Medicine Manually',
          ),
          IconButton(
            onPressed: _importCsv,
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import CSV',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search medicines...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilter();
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) => _applyFilter(),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Low Stock', 'low_stock'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Expiring Soon', 'expiring'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Expired', 'expired'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Stock Count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: ${_filteredMedicines.length} medicines',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Stock Value: ₹${_calculateTotalValue().toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Medicine List
          Expanded(
            child: _filteredMedicines.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _medicines.isEmpty
                              ? 'No medicines in stock'
                              : 'No medicines found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (_medicines.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Import CSV to add medicines',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _importCsv,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Import CSV'),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredMedicines.length,
                    itemBuilder: (context, index) {
                      final medicine = _filteredMedicines[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          title: Text(
                            medicine.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              if (medicine.batch != null)
                                Text('Batch: ${medicine.batch}'),
                              Text('Stock: ${medicine.quantity}'),
                              if (medicine.expiryDate != null)
                                Text(
                                  'Expiry: ${DateFormat('dd/MM/yyyy').format(medicine.expiryDate!)}',
                                  style: TextStyle(
                                    color: medicine.isExpired
                                        ? Colors.red
                                        : medicine.isExpiringSoon
                                            ? Colors.orange
                                            : null,
                                  ),
                                ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${medicine.mrp.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (medicine.isLowStock)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Low Stock',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.red.shade900,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          onTap: () => _showMedicineDetails(medicine),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterType == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterType = value;
          _applyFilter();
        });
      },
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
    );
  }

  double _calculateTotalValue() {
    return _filteredMedicines.fold(
      0.0,
      (sum, medicine) => sum + (medicine.mrp * medicine.quantity),
    );
  }
}
