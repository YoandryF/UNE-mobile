import 'package:hive_flutter/hive_flutter.dart';
import 'models.dart';

class DbService {
  static late Box _readingsBox;
  static late Box _equipmentBox;
  static late Box _configBox;

  static Future<void> init() async {
    await Hive.initFlutter();
    _readingsBox = await Hive.openBox('readings');
    _equipmentBox = await Hive.openBox('equipment');
    _configBox = await Hive.openBox('config');
  }

  // Config
  static AppConfig getConfig() {
    final raw = _configBox.get('main');
    if (raw == null) return AppConfig();
    return AppConfig.fromMap(Map<String, dynamic>.from(raw));
  }

  static Future<void> saveConfig(AppConfig config) async {
    await _configBox.put('main', config.toMap());
  }

  // Readings
  static List<Reading> getReadings({int? meter}) {
    final all = _readingsBox.values.map((v) => Reading.fromMap(Map<String, dynamic>.from(v))).toList();
    if (meter != null) return all.where((r) => r.meter == meter).toList();
    return all;
  }

  static Future<void> putReading(Reading r) async {
    await _readingsBox.put(r.id, r.toMap());
  }

  static Future<void> deleteReading(String id) async {
    await _readingsBox.delete(id);
  }

  static Future<void> deleteReadingsByMonth(String month, int meter) async {
    final keys = <dynamic>[];
    for (final key in _readingsBox.keys) {
      final r = Reading.fromMap(Map<String, dynamic>.from(_readingsBox.get(key)));
      if (r.date.startsWith(month) && r.meter == meter) keys.add(key);
    }
    await _readingsBox.deleteAll(keys);
  }

  // Equipment
  static List<Equipment> getEquipment() {
    return _equipmentBox.values.map((v) => Equipment.fromMap(Map<String, dynamic>.from(v))).toList();
  }

  static Future<void> putEquipment(Equipment e) async {
    await _equipmentBox.put(e.id, e.toMap());
  }

  static Future<void> deleteEquipment(String id) async {
    await _equipmentBox.delete(id);
  }

  // Export/Import
  static Map<String, dynamic> exportAll() {
    return {
      'readings': _readingsBox.values.toList(),
      'equipment': _equipmentBox.values.toList(),
      'config': _configBox.get('main'),
    };
  }

  static Future<void> importAll(Map<String, dynamic> data) async {
    if (data['readings'] != null) {
      for (final r in data['readings']) {
        final reading = Reading.fromMap(Map<String, dynamic>.from(r));
        await putReading(reading);
      }
    }
    if (data['equipment'] != null) {
      for (final e in data['equipment']) {
        final equip = Equipment.fromMap(Map<String, dynamic>.from(e));
        await putEquipment(equip);
      }
    }
    if (data['config'] != null) {
      await _configBox.put('main', data['config']);
    }
  }
}
