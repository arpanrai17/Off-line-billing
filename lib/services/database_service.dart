import 'package:hive_flutter/hive_flutter.dart';
import '../models/medicine.dart';
import '../models/bill.dart';
import '../models/bill_item.dart';
import '../models/shop_settings.dart';

class DatabaseService {
  static const String medicineBoxName = 'medicines';
  static const String billBoxName = 'bills';
  static const String settingsBoxName = 'settings';

  static Future<void> init() async {
    await Hive.initFlutter();
    
    // Register adapters
    Hive.registerAdapter(MedicineAdapter());
    Hive.registerAdapter(BillAdapter());
    Hive.registerAdapter(BillItemAdapter());
    Hive.registerAdapter(ShopSettingsAdapter());
    
    // Open boxes
    await Hive.openBox<Medicine>(medicineBoxName);
    await Hive.openBox<Bill>(billBoxName);
    // Settings box opened by SettingsService
  }

  // Medicine operations
  static Box<Medicine> get medicineBox => Hive.box<Medicine>(medicineBoxName);
  
  static Future<void> addMedicine(Medicine medicine) async {
    await medicineBox.put(medicine.id, medicine);
  }

  static Future<void> addMedicines(List<Medicine> medicines) async {
    final Map<String, Medicine> medicineMap = {
      for (var medicine in medicines) medicine.id: medicine
    };
    await medicineBox.putAll(medicineMap);
  }

  static Future<void> updateMedicine(Medicine medicine) async {
    await medicineBox.put(medicine.id, medicine);
  }

  static Future<void> deleteMedicine(String id) async {
    await medicineBox.delete(id);
  }

  static Medicine? getMedicine(String id) {
    return medicineBox.get(id);
  }

  static List<Medicine> getAllMedicines() {
    return medicineBox.values.toList();
  }

  static List<Medicine> searchMedicines(String query, {int limit = 50}) {
    if (query.isEmpty) return [];
    
    final lowerQuery = query.toLowerCase();
    final results = <Medicine>[];
    
    // Optimized search: stop after finding 'limit' results
    for (var medicine in medicineBox.values) {
      if (results.length >= limit) break;
      
      if (medicine.name.toLowerCase().contains(lowerQuery) ||
          (medicine.manufacturer?.toLowerCase().contains(lowerQuery) ?? false) ||
          (medicine.category?.toLowerCase().contains(lowerQuery) ?? false)) {
        results.add(medicine);
      }
    }
    
    return results;
  }

  static Future<void> updateMedicineQuantity(String id, int newQuantity) async {
    final medicine = getMedicine(id);
    if (medicine != null) {
      medicine.quantity = newQuantity;
      medicine.lastUpdated = DateTime.now();
      await updateMedicine(medicine);
    }
  }

  static List<Medicine> getLowStockMedicines() {
    return medicineBox.values.where((m) => m.isLowStock).toList();
  }

  static List<Medicine> getExpiringSoonMedicines() {
    return medicineBox.values.where((m) => m.isExpiringSoon).toList();
  }

  static List<Medicine> getExpiredMedicines() {
    return medicineBox.values.where((m) => m.isExpired).toList();
  }

  // Bill operations
  static Box<Bill> get billBox => Hive.box<Bill>(billBoxName);

  static Future<void> addBill(Bill bill) async {
    await billBox.put(bill.billNumber, bill);
    
    // Update medicine quantities
    for (var item in bill.items) {
      final medicine = getMedicine(item.medicineId);
      if (medicine != null) {
        await updateMedicineQuantity(
          item.medicineId,
          medicine.quantity - item.quantity,
        );
      }
    }
  }

  static Bill? getBill(String billNumber) {
    return billBox.get(billNumber);
  }

  static List<Bill> getAllBills() {
    return billBox.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  static List<Bill> getBillsByDate(DateTime date) {
    return billBox.values.where((bill) {
      return bill.date.year == date.year &&
             bill.date.month == date.month &&
             bill.date.day == date.day;
    }).toList();
  }

  static List<Bill> getBillsByDateRange(DateTime start, DateTime end) {
    return billBox.values.where((bill) {
      return bill.date.isAfter(start.subtract(const Duration(days: 1))) &&
             bill.date.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  static String generateBillNumber() {
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final todayBills = getBillsByDate(now);
    final sequence = (todayBills.length + 1).toString().padLeft(4, '0');
    return 'AMS$dateStr$sequence';
  }

  // Settings operations
  static Box get settingsBox => Hive.box(settingsBoxName);

  static Future<void> saveSetting(String key, dynamic value) async {
    await settingsBox.put(key, value);
  }

  static dynamic getSetting(String key, {dynamic defaultValue}) {
    return settingsBox.get(key, defaultValue: defaultValue);
  }

  // Analytics
  static double getTodaySales() {
    final today = DateTime.now();
    final todayBills = getBillsByDate(today);
    return todayBills.fold(0.0, (sum, bill) => sum + bill.finalAmount);
  }

  static double getMonthSales() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    final monthBills = getBillsByDateRange(startOfMonth, endOfMonth);
    return monthBills.fold(0.0, (sum, bill) => sum + bill.finalAmount);
  }

  static int getTodayBillCount() {
    return getBillsByDate(DateTime.now()).length;
  }

  static int getMonthBillCount() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    return getBillsByDateRange(startOfMonth, endOfMonth).length;
  }

  // Clear all data
  static Future<void> clearAllData() async {
    await medicineBox.clear();
    await billBox.clear();
  }

  // Backup and restore
  static Future<void> close() async {
    await Hive.close();
  }
}
