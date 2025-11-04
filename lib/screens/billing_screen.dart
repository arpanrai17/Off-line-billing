import 'package:flutter/material.dart';
// ignore: unused_import
import 'package:intl/intl.dart';
import '../models/medicine.dart';
import '../models/bill.dart';
import '../models/bill_item.dart';
import '../services/database_service.dart';
import '../services/pdf_service.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _doctorNameController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  
  List<Medicine> _searchResults = [];
  List<BillItem> _billItems = [];
  bool _isSearching = false;
  double _billDiscount = 0.0;
  bool _isDiscountPercentage = false;

  @override
  void dispose() {
    _searchController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _doctorNameController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  void _searchMedicines(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResults = DatabaseService.searchMedicines(query);
    });
  }

  void _addMedicineToBill(Medicine medicine) async {
    // Show dialog to edit MRP
    final mrp = await _showEditMrpDialog(medicine);
    if (mrp == null) return;
    
    // Check if medicine already exists in bill
    final existingIndex = _billItems.indexWhere(
      (item) => item.medicineId == medicine.id,
    );

    setState(() {
      if (existingIndex >= 0) {
        // Increase quantity
        _billItems[existingIndex].quantity++;
      } else {
        // Add new item
        _billItems.add(BillItem(
          medicineId: medicine.id,
          medicineName: medicine.name,
          quantity: 1,
          rate: mrp,
          batch: medicine.batch,
          expiryDate: medicine.expiryDate,
        ));
      }
      
      // Clear search
      _searchController.clear();
      _searchResults = [];
      _isSearching = false;
    });
  }
  
  Future<double?> _showEditMrpDialog(Medicine medicine) async {
    final TextEditingController mrpController = TextEditingController(
      text: medicine.mrp.toStringAsFixed(0),
    );
    
    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit MRP - ${medicine.name}'),
        content: TextField(
          controller: mrpController,
          decoration: const InputDecoration(
            labelText: 'MRP',
            prefixText: '₹ ',
          ),
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final mrp = double.tryParse(mrpController.text) ?? medicine.mrp;
              Navigator.pop(context, mrp);
            },
            child: const Text('Add to Bill'),
          ),
        ],
      ),
    );
  }

  void _updateQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      _removeBillItem(index);
      return;
    }

    setState(() {
      _billItems[index].quantity = newQuantity;
    });
  }

  void _removeBillItem(int index) {
    setState(() {
      _billItems.removeAt(index);
    });
  }

  double get _subtotal {
    return _billItems.fold(0.0, (sum, item) => sum + item.amount);
  }

  double get _discountAmount {
    if (_isDiscountPercentage) {
      return (_subtotal * _billDiscount / 100);
    }
    return _billDiscount;
  }
  
  double get _finalAmount {
    final amount = _subtotal - _discountAmount;
    return amount.roundToDouble(); // Always whole rupees
  }

  Future<void> _generateBill() async {
    if (_billItems.isEmpty) {
      _showMessage('Please add items to the bill');
      return;
    }

    try {
      // Generate bill number
      final billNumber = DatabaseService.generateBillNumber();

      // Create bill
      final bill = Bill(
        billNumber: billNumber,
        date: DateTime.now(),
        customerName: _customerNameController.text.trim().isEmpty
            ? null
            : _customerNameController.text.trim(),
        customerPhone: _customerPhoneController.text.trim().isEmpty
            ? null
            : _customerPhoneController.text.trim(),
        doctorName: _doctorNameController.text.trim().isEmpty
            ? null
            : _doctorNameController.text.trim(),
        items: List.from(_billItems),
        totalAmount: _finalAmount,
        discount: _billDiscount,
        isDiscountPercentage: _isDiscountPercentage,
      );

      // Save bill to database
      await DatabaseService.addBill(bill);

      // Generate PDF
      await PdfService.generateBillPdf(bill);

      // Show success dialog
      if (mounted) {
        _showBillSuccessDialog(bill);
      }
    } catch (e) {
      _showMessage('Error generating bill: $e');
    }
  }

  void _showBillSuccessDialog(Bill bill) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bill Generated Successfully'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bill Number: ${bill.billNumber}'),
            Text('Total Amount: ₹${bill.finalAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            const Text('What would you like to do?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearBill();
            },
            child: const Text('New Bill'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await PdfService.printBill(bill);
            },
            icon: const Icon(Icons.print),
            label: const Text('Print'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await PdfService.shareBill(bill);
            },
            icon: const Icon(Icons.share),
            label: const Text('Share'),
          ),
        ],
      ),
    );
  }

  void _clearBill() {
    setState(() {
      _billItems.clear();
      _customerNameController.clear();
      _customerPhoneController.clear();
      _doctorNameController.clear();
      _discountController.clear();
      _billDiscount = 0.0;
      _isDiscountPercentage = false;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Bill'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          if (_billItems.isNotEmpty)
            IconButton(
              onPressed: _clearBill,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear Bill',
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search medicine by name...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _searchMedicines('');
                            },
                          )
                        : null,
                  ),
                  onChanged: _searchMedicines,
                ),
                if (_isSearching && _searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final medicine = _searchResults[index];
                        return ListTile(
                          title: Text(medicine.name),
                          subtitle: Text(
                            'Stock: ${medicine.quantity} | MRP: ₹${medicine.mrp}',
                          ),
                          trailing: Text(
                            '₹${medicine.mrp.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          onTap: () => _addMedicineToBill(medicine),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Bill Items Section
          Expanded(
            child: _billItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No items in bill',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Search and add medicines to start billing',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _billItems.length,
                    itemBuilder: (context, index) {
                      final item = _billItems[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.medicineName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        if (item.batch != null)
                                          Text(
                                            'Batch: ${item.batch}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _removeBillItem(index),
                                    color: Colors.red,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline),
                                        onPressed: () => _updateQuantity(
                                          index,
                                          item.quantity - 1,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primaryContainer,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${item.quantity}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline),
                                        onPressed: () => _updateQuantity(
                                          index,
                                          item.quantity + 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹${item.rate.toStringAsFixed(2)} each',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      Text(
                                        '₹${item.amount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Section
          if (_billItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Customer Details
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customerNameController,
                          decoration: const InputDecoration(
                            labelText: 'Customer Name (Optional)',
                            prefixIcon: Icon(Icons.person_outline),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _customerPhoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone (Optional)',
                            prefixIcon: Icon(Icons.phone_outlined),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Doctor Name
                  TextField(
                    controller: _doctorNameController,
                    decoration: const InputDecoration(
                      labelText: 'Doctor Name (Optional)',
                      prefixIcon: Icon(Icons.medical_services_outlined),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Totals
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Subtotal:',
                        style: TextStyle(fontSize: 16),
                      ),
                      Text(
                        '₹${_subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Discount:',
                        style: TextStyle(fontSize: 16),
                      ),
                      Row(
                        children: [
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: _discountController,
                              decoration: InputDecoration(
                                prefixText: _isDiscountPercentage ? '' : '₹ ',
                                suffixText: _isDiscountPercentage ? '%' : '',
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                setState(() {
                                  _billDiscount = double.tryParse(value) ?? 0.0;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: false,
                                label: Text('₹'),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text('%'),
                              ),
                            ],
                            selected: {_isDiscountPercentage},
                            onSelectionChanged: (Set<bool> newSelection) {
                              setState(() {
                                _isDiscountPercentage = newSelection.first;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount:',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹${_finalAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: _generateBill,
                      icon: const Icon(Icons.receipt_long),
                      label: const Text(
                        'Generate Bill',
                        style: TextStyle(fontSize: 18),
                      ),
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
