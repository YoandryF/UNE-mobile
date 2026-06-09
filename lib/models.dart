class TariffRange {
  final double size;
  final double rate;
  TariffRange(this.size, this.rate);
  Map<String, dynamic> toMap() => {'size': size, 'rate': rate};
  factory TariffRange.fromMap(Map m) => TariffRange(m['size'].toDouble(), m['rate'].toDouble());
}

class TariffConfig {
  List<TariffRange> ranges;
  double surcharge;
  TariffConfig({required this.ranges, this.surcharge = 25});

  Map<String, dynamic> toMap() => {
    'ranges': ranges.map((r) => r.toMap()).toList(),
    'surcharge': surcharge,
  };

  factory TariffConfig.fromMap(Map m) => TariffConfig(
    ranges: (m['ranges'] as List).map((r) => TariffRange.fromMap(r)).toList(),
    surcharge: (m['surcharge'] ?? 25).toDouble(),
  );

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
    id: m['id'], reading: (m['reading']).toDouble(), date: m['date'],
    time: m['time'] ?? '', photoPath: m['photoPath'], meter: m['meter'] ?? 0,
    tariffs: Map<String, dynamic>.from(m['tariffs'] ?? {}),
    createdAt: m['createdAt'] ?? '', updatedAt: m['updatedAt'] ?? '',
  );
}

class Equipment {
  String id;
  String name;
  double watts;
  double hours;

  Equipment({required this.id, required this.name, required this.watts, required this.hours});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'watts': watts, 'hours': hours};
  factory Equipment.fromMap(Map m) => Equipment(
    id: m['id'], name: m['name'],
    watts: (m['watts']).toDouble(), hours: (m['hours']).toDouble(),
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

  AppConfig({
    TariffConfig? tariffs,
    this.alertThreshold = 450,
    this.billCycleDay = 1,
    List<String>? meters,
    this.activeMeter = 0,
    this.darkMode = true,
  }) : tariffs = tariffs ?? TariffConfig.defaultConfig(),
       meters = meters ?? ['Metro 1'];

  Map<String, dynamic> toMap() => {
    'tariffs': tariffs.toMap(), 'alertThreshold': alertThreshold,
    'billCycleDay': billCycleDay, 'meters': meters,
    'activeMeter': activeMeter, 'darkMode': darkMode,
  };

  factory AppConfig.fromMap(Map m) => AppConfig(
    tariffs: m['tariffs'] != null ? TariffConfig.fromMap(m['tariffs']) : null,
    alertThreshold: (m['alertThreshold'] ?? 450).toDouble(),
    billCycleDay: m['billCycleDay'] ?? 1,
    meters: List<String>.from(m['meters'] ?? ['Metro 1']),
    activeMeter: m['activeMeter'] ?? 0,
    darkMode: m['darkMode'] ?? true,
  );
}
