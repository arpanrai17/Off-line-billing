import 'package:hive/hive.dart';
import '../models/shop_settings.dart';

class SettingsService {
  static const String _boxName = 'settings';
  static const String _settingsKey = 'shop_settings';
  
  static late Box<ShopSettings> _settingsBox;

  static Future<void> init() async {
    _settingsBox = await Hive.openBox<ShopSettings>(_boxName);
    
    // Initialize with default settings if not exists
    if (_settingsBox.get(_settingsKey) == null) {
      await saveSettings(ShopSettings.getDefault());
    }
  }

  static ShopSettings getSettings() {
    return _settingsBox.get(_settingsKey) ?? ShopSettings.getDefault();
  }

  static Future<void> saveSettings(ShopSettings settings) async {
    await _settingsBox.put(_settingsKey, settings);
  }

  static Future<void> resetToDefault() async {
    await saveSettings(ShopSettings.getDefault());
  }
}
