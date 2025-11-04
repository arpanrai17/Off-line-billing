import 'package:hive/hive.dart';

part 'shop_settings.g.dart';

@HiveType(typeId: 3)
class ShopSettings extends HiveObject {
  @HiveField(0)
  String shopName;

  @HiveField(1)
  String address;

  @HiveField(2)
  String mobile;

  @HiveField(3)
  String? email;

  ShopSettings({
    required this.shopName,
    required this.address,
    required this.mobile,
    this.email,
  });

  // Default settings
  static ShopSettings getDefault() {
    return ShopSettings(
      shopName: 'Ankush Medical Store',
      address: 'Shop No. 14, Geeta Bhawan Complex\nNear Bus Stand, Kannod\nDistrict Dewas, Madhya Pradesh',
      mobile: '9329884653',
      email: null,
    );
  }
}
