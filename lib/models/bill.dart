import 'package:hive/hive.dart';
import 'bill_item.dart';

part 'bill.g.dart';

@HiveType(typeId: 2)
class Bill extends HiveObject {
  @HiveField(0)
  String billNumber;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  String? customerName;

  @HiveField(3)
  String? customerPhone;

  @HiveField(4)
  List<BillItem> items;

  @HiveField(5)
  double totalAmount;

  @HiveField(6)
  double discount;

  @HiveField(7)
  String paymentMode;

  @HiveField(8)
  String? doctorName;

  @HiveField(9)
  bool isDiscountPercentage;

  Bill({
    required this.billNumber,
    required this.date,
    this.customerName,
    this.customerPhone,
    required this.items,
    required this.totalAmount,
    this.discount = 0.0,
    this.paymentMode = 'Cash',
    this.doctorName,
    this.isDiscountPercentage = false,
  });

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.amount);
  
  double get discountAmount {
    if (isDiscountPercentage) {
      return (subtotal * discount / 100);
    }
    return discount;
  }
  
  double get finalAmount {
    final amount = subtotal - discountAmount;
    return amount.roundToDouble(); // Round to whole rupees
  }

  Map<String, dynamic> toJson() {
    return {
      'billNumber': billNumber,
      'date': date.toIso8601String(),
      'customerName': customerName,
      'customerPhone': customerPhone,
      'items': items.map((item) => item.toJson()).toList(),
      'totalAmount': totalAmount,
      'discount': discount,
      'paymentMode': paymentMode,
      'subtotal': subtotal,
      'finalAmount': finalAmount,
    };
  }
}
