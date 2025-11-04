import 'package:hive/hive.dart';

part 'bill_item.g.dart';

@HiveType(typeId: 1)
class BillItem extends HiveObject {
  @HiveField(0)
  String medicineId;

  @HiveField(1)
  String medicineName;

  @HiveField(2)
  int quantity;

  @HiveField(3)
  double rate;

  @HiveField(4)
  double discount;

  @HiveField(5)
  String? batch;

  @HiveField(6)
  DateTime? expiryDate;

  @HiveField(7)
  DateTime? mfgDate;

  BillItem({
    required this.medicineId,
    required this.medicineName,
    required this.quantity,
    required this.rate,
    this.discount = 0.0,
    this.batch,
    this.expiryDate,
    this.mfgDate,
  });

  double get amount => (quantity * rate) - discount;

  Map<String, dynamic> toJson() {
    return {
      'medicineId': medicineId,
      'medicineName': medicineName,
      'quantity': quantity,
      'rate': rate,
      'discount': discount,
      'batch': batch,
      'expiryDate': expiryDate?.toIso8601String(),
      'amount': amount,
    };
  }
}
