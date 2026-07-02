import 'package:hive_flutter/hive_flutter.dart';
import 'models.dart';
import 'sync_service.dart';

class DbService {
  static late Box _readingsBox;
  static late Box _equipmentBox;
  static late Box _configBox;

  static Future<void> init() async {
    await Hive.initFlutter();
    _readingsBox = await Hive.openBox('readings');
    _equipmentBox = await Hive.openBox('equipment');
    _configBox = await Hive.openBox('config');
    await Hive.openBox('_pending');
    await Hive.openBox('_blackouts');
    await Hive.openBox('_equipment_usage');
  }

  // Config
  static AppConfig getConfig() {
    final raw = _configBox.get('main');
    if (raw == null) return AppConfig();
    return AppConfig.fromMap(Map<String, dynamic>.from(raw));
  }

  static Future<void> saveConfig(AppConfig config) async {
    await _configBox.put('main', config.toMap());
    // Queue sync
    await SyncService().queueOperation({
      'type': 'upsert',
      'store': 'config',
      'data': SyncService.configToServer(config),
    });
  }

  // Readings
  static List<Reading> getReadings({int? meter}) {
    final all = _readingsBox.values.map((v) => Reading.fromMap(Map<String, dynamic>.from(v))).toList();
    if (meter != null) return all.where((r) => r.meter == meter).toList();
    return all;
  }

  static Future<void> putReading(Reading r) async {
    await _readingsBox.put(r.id, r.toMap());
    // Queue sync
    await SyncService().queueOperation({
      'type': 'upsert',
      'store': 'readings',
      'data': SyncService.readingToServer(r),
    });
  }

  static Future<void> deleteReading(String id) async {
    await _readingsBox.delete(id);
    // Queue sync
    await SyncService().queueOperation({
      'type': 'delete',
      'store': 'readings',
      'itemId': id,
    });
  }

  static Future<void> deleteReadingsByMonth(String month, int meter) async {
    final keys = <dynamic>[];
    for (final key in _readingsBox.keys) {
      final r = Reading.fromMap(Map<String, dynamic>.from(_readingsBox.get(key)));
      if (r.date.startsWith(month) && r.meter == meter) {
        keys.add(key);
        // Queue delete for each one
        await SyncService().queueOperation({
          'type': 'delete',
          'store': 'readings',
          'itemId': r.id,
        });
      }
    }
    await _readingsBox.deleteAll(keys);
  }

  // Equipment
  static List<Equipment> getEquipment({int? meter}) {
    final all = _equipmentBox.values.map((v) => Equipment.fromMap(Map<String, dynamic>.from(v))).toList();
    if (meter != null) return all.where((e) => e.meter == meter).toList();
    return all;
  }

  static Future<void> putEquipment(Equipment e) async {
    await _equipmentBox.put(e.id, e.toMap());
    // Queue sync
    await SyncService().queueOperation({
      'type': 'upsert',
      'store': 'equipment',
      'data': SyncService.equipmentToServer(e),
    });
  }

  static Future<void> deleteEquipment(String id) async {
    await _equipmentBox.delete(id);
    // Queue sync
    await SyncService().queueOperation({
      'type': 'delete',
      'store': 'equipment',
      'itemId': id,
    });
  }

  // Export/Import
  static Map<String, dynamic> exportAll() {
    final blackoutsBox = Hive.box('_blackouts');
    final usageBox = Hive.box('_equipment_usage');
    return {
      'readings': _readingsBox.values.toList(),
      'equipment': _equipmentBox.values.toList(),
      'blackouts': blackoutsBox.values.toList(),
      'equipment_usage': usageBox.values.toList(),
      'config': _configBox.get('main'),
    };
  }

  static Future<void> importAll(Map<String, dynamic> data) async {
    if (data['readings'] != null) {
      for (final r in data['readings']) {
        try {
          final map = Map<String, dynamic>.from(r);
          if (map.containsKey('photo') && !map.containsKey('photoPath')) {
            map['photoPath'] = map['photo'];
          }
          map['id'] = map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
          final reading = Reading.fromMap(map);
          await putReading(reading);
        } catch (_) {}
      }
    }
    if (data['equipment'] != null) {
      for (final e in data['equipment']) {
        try {
          final map = Map<String, dynamic>.from(e);
          map['id'] = map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
          final equip = Equipment.fromMap(map);
          await putEquipment(equip);
        } catch (_) {}
      }
    }
    if (data['blackouts'] != null) {
      final box = Hive.box('_blackouts');
      for (final b in data['blackouts']) {
        try {
          final map = Map<String, dynamic>.from(b);
          map['id'] = map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
          await box.put(map['id'], map);
        } catch (_) {}
      }
    }
    if (data['equipment_usage'] != null) {
      final box = Hive.box('_equipment_usage');
      for (final u in data['equipment_usage']) {
        try {
          final map = Map<String, dynamic>.from(u);
          map['id'] = map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
          await box.put(map['id'], map);
        } catch (_) {}
      }
    }
    if (data['config'] != null) {
      try {
        final configData = Map<String, dynamic>.from(data['config']);
        final config = AppConfig.fromMap(configData);
        await saveConfig(config);
      } catch (_) {}
    }
  }
}
