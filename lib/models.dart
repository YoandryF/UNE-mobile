class TariffRange {
  final double size;
  final double rate;
  TariffRange(this.size, this.rate);
  Map<String, dynamic> toMap() => {'size': size, 'rate': rate};
  factory TariffRange.fromMap(Map m) => TariffRange(
    _parseSize(m['size'] ?? m[0]),
    _parseNum(m['rate'] ?? m[1]),
  );

  /// Parse size value: null or Infinity string → double.infinity
  static double _parseSize(dynamic v) {
    if (v == null) return double.infinity;
    if (v == 'Infinity' || v == double.infinity) return double.infinity;
    if (v is num) return v.toDouble();
    final parsed = double.tryParse(v.toString());
    return parsed ?? double.infinity;
  }

  /// Parse a numeric value safely
  static double _parseNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  /// Parse from either [size, rate] array or {size, rate} map
  static TariffRange parse(dynamic item) {
    if (item is List) {
      final size = item.isNotEmpty ? _parseSize(item[0]) : 0.0;
      final rate = item.length > 1 ? _parseNum(item[1]) : 0.0;
      return TariffRange(size, rate);
    } else if (item is Map) {
      return TariffRange.fromMap(item);
    }
    return TariffRange(0, 0);
  }
}

class TariffConfig {
  List<TariffRange> ranges;
  double surcharge;
  TariffConfig({required this.ranges, this.surcharge = 25});

  Map<String, dynamic> toMap() => {
    'ranges': ranges.map((r) => r.toMap()).toList(),
    'surcharge': surcharge,
  };

  factory TariffConfig.fromMap(Map m) {
    final defaultRanges = TariffConfig.defaultConfig().ranges;
    List<TariffRange> parsed;
    try {
      parsed = (m['ranges'] as List?)?.map((r) => TariffRange.parse(r)).toList() ?? defaultRanges;
    } catch (_) {
      parsed = defaultRanges;
    }
    // Always ensure exactly 18 ranges
    final ranges = List<TariffRange>.generate(18, (i) {
      if (i < parsed.length) return parsed[i];
      if (i < defaultRanges.length) return defaultRanges[i];
      return TariffRange(0, 0);
    });
    return TariffConfig(
      ranges: ranges,
      surcharge: (m['surcharge'] ?? 25).toDouble(),
    );
  }

  static TariffConfig defaultConfig() => TariffConfig(
    ranges: [
      TariffRange(100, 0.33), TariffRange(50, 1.07), TariffRange(50, 1.43),
      TariffRange(50, 2.46), TariffRange(50, 3.00), TariffRange(50, 4.00),
      TariffRange(50, 5.00), TariffRange(50, 6.00), TariffRange(50, 7.00),
      TariffRange(100, 9.20), TariffRange(100, 9.45), TariffRange(300, 9.85),
      TariffRange(800, 10.80), TariffRange(800, 11.80), TariffRange(800, 12.90),
      TariffRange(800, 13.95), TariffRange(800, 15.00), TariffRange(double.infinity, 20.00),
    ],
    surcharge: 25,
  );
}

class Reading {
  String id;
  double reading;
  String date;
  String time;
  String? photoPath;
  int meter;
  Map<String, dynamic> tariffs;
  String createdAt;
  String updatedAt;

  Reading({
    required this.id,
    required this.reading,
    required this.date,
    this.time = '',
    this.photoPath,
    this.meter = 0,
    required this.tariffs,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'reading': reading, 'date': date, 'time': time,
    'photoPath': photoPath, 'meter': meter, 'tariffs': tariffs,
    'createdAt': createdAt, 'updatedAt': updatedAt,
  };

  factory Reading.fromMap(Map m) => Reading(
    id: m['id']?.toString() ?? '',
    reading: (m['reading'] ?? 0).toDouble(),
    date: m['date'] ?? '',
    time: m['time'] ?? '',
    photoPath: m['photoPath'] ?? m['photo'],
    meter: m['meter'] ?? 0,
    tariffs: m['tariffs'] != null ? Map<String, dynamic>.from(m['tariffs']) : {},
    createdAt: m['createdAt'] ?? '',
    updatedAt: m['updatedAt'] ?? '',
  );
}

class Equipment {
  String id;
  String name;
  double watts;
  double hours;
  int meter;
  bool alwaysOn;

  Equipment({required this.id, required this.name, required this.watts, required this.hours, this.meter = 0, this.alwaysOn = false});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'watts': watts, 'hours': hours, 'meter': meter, 'alwaysOn': alwaysOn};
  factory Equipment.fromMap(Map m) => Equipment(
    id: m['id']?.toString() ?? '', name: m['name'] ?? '',
    watts: (m['watts'] ?? 0).toDouble(), hours: (m['hours'] ?? 0).toDouble(),
    meter: m['meter'] ?? 0, alwaysOn: m['alwaysOn'] == true,
  );

  double get monthlyKwh => (watts * hours * 30) / 1000;
}

class AppConfig {
  TariffConfig tariffs;
  double alertThreshold;
  int billCycleDay;
  List<String> meters;
  int activeMeter;
  bool darkMode;
  String serverUrl;
  String updateSource; // 'auto', 'github', 'server'

  AppConfig({
    TariffConfig? tariffs,
    this.alertThreshold = 450,
    this.billCycleDay = 1,
    List<String>? meters,
    this.activeMeter = 0,
    this.darkMode = true,
    this.serverUrl = '',
    this.updateSource = 'auto',
  }) : tariffs = tariffs ?? TariffConfig.defaultConfig(),
       meters = meters ?? ['Metro 1'];

  Map<String, dynamic> toMap() => {
    'tariffs': tariffs.toMap(), 'alertThreshold': alertThreshold,
    'billCycleDay': billCycleDay, 'meters': meters,
    'activeMeter': activeMeter, 'darkMode': darkMode,
    'serverUrl': serverUrl, 'updateSource': updateSource,
  };

  factory AppConfig.fromMap(Map m) {
    TariffConfig? tariffs;
    if (m['tariffs'] != null) {
      try {
        tariffs = TariffConfig.fromMap(Map<String, dynamic>.from(m['tariffs']));
      } catch (_) {
        tariffs = TariffConfig.defaultConfig();
      }
    }
    return AppConfig(
      tariffs: tariffs,
      alertThreshold: (m['alertThreshold'] ?? 450).toDouble(),
      billCycleDay: m['billCycleDay'] ?? 1,
      meters: m['meters'] != null ? List<String>.from(m['meters']) : null,
      activeMeter: m['activeMeter'] ?? 0,
      darkMode: m['darkMode'] ?? m['theme'] == 'dark' || m['theme'] == null,
      serverUrl: m['serverUrl'] ?? '',
      updateSource: m['updateSource'] ?? 'auto',
    );
  }
}
