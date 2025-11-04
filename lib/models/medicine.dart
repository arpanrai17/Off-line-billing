import 'package:hive/hive.dart';

part 'medicine.g.dart';

@HiveType(typeId: 0)
class Medicine extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? batch;

  @HiveField(3)
  DateTime? expiryDate;

  @HiveField(4)
  int quantity;

  @HiveField(5)
  double mrp;

  @HiveField(6)
  double? purchasePrice;

  @HiveField(7)
  String? manufacturer;

  @HiveField(8)
  String? category;

  @HiveField(9)
  DateTime? lastUpdated;

  Medicine({
    required this.id,
    required this.name,
    this.batch,
    this.expiryDate,
    required this.quantity,
    required this.mrp,
    this.purchasePrice,
    this.manufacturer,
    this.category,
    this.lastUpdated,
  });

  // Create from CSV row
  // Supports two formats:
  // Format 1: ID,Name,Batch,Expiry Date,Quantity,MRP,Purchase Price,Manufacturer,Category
  // Format 2: id,name,price,Is_discontinued,manufacturer_name,type,pack_size_label,...
  factory Medicine.fromCsv(List<dynamic> row) {
    // Check if this is the new format (has 'price' in column 2)
    if (row.length >= 5) {
      // New format: id,name,price,Is_discontinued,manufacturer_name,type...
      return Medicine(
        id: row[0]?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: row[1]?.toString() ?? '',
        batch: null, // Not in this format
        expiryDate: null, // Not in this format
        quantity: 50, // Default quantity
        mrp: double.tryParse(row[2]?.toString() ?? '0') ?? 0.0,
        purchasePrice: null,
        manufacturer: row.length > 4 ? row[4]?.toString() : null,
        category: row.length > 5 ? row[5]?.toString() : null,
        lastUpdated: DateTime.now(),
      );
    } else {
      // Old format: ID,Name,Batch,Expiry Date,Quantity,MRP,Purchase Price,Manufacturer,Category
      return Medicine(
        id: row[0]?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: row[1]?.toString() ?? '',
        batch: row[2]?.toString(),
        expiryDate: _parseDate(row[3]?.toString()),
        quantity: int.tryParse(row[4]?.toString() ?? '0') ?? 0,
        mrp: double.tryParse(row[5]?.toString() ?? '0') ?? 0.0,
        purchasePrice: double.tryParse(row[6]?.toString() ?? '0'),
        manufacturer: row.length > 7 ? row[7]?.toString() : null,
        category: row.length > 8 ? row[8]?.toString() : null,
        lastUpdated: DateTime.now(),
      );
    }
  }

  static DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      // Try multiple date formats
      if (dateStr.contains('/')) {
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          return DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      } else if (dateStr.contains('-')) {
        return DateTime.parse(dateStr);
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'batch': batch,
      'expiryDate': expiryDate?.toIso8601String(),
      'quantity': quantity,
      'mrp': mrp,
      'purchasePrice': purchasePrice,
      'manufacturer': manufacturer,
      'category': category,
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  bool get isLowStock => quantity < 10;
  
  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final daysUntilExpiry = expiryDate!.difference(DateTime.now()).inDays;
    return daysUntilExpiry < 90 && daysUntilExpiry >= 0;
  }

  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }
}
