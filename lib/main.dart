import 'package:flutter/material.dart';
import 'db_service.dart';
import 'models.dart';
import 'theme.dart';
import 'screens/calculator_screen.dart';
import 'screens/readings_screen.dart';
import 'screens/chart_screen.dart';
import 'screens/equipment_screen.dart';
import 'screens/config_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DbService.init();
  runApp(const UneApp());
}

class UneApp extends StatefulWidget {
  const UneApp({super.key});
  @override
  State<UneApp> createState() => _UneAppState();
}

class _UneAppState extends State<UneApp> {
  late AppConfig config;

  @override
  void initState() {
    super.initState();
    config = DbService.getConfig();
  }

  void refresh() => setState(() => config = DbService.getConfig());

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Consumo Eléctrico UNE',
      debugShowCheckedModeBanner: false,
      theme: config.darkMode ? AppTheme.dark() : AppTheme.light(),
      home: HomeScreen(onConfigChanged: refresh),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final VoidCallback onConfigChanged;
  const HomeScreen({super.key, required this.onConfigChanged});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final config = DbService.getConfig();
    final screens = [
      CalculatorScreen(config: config),
      ReadingsScreen(config: config, onChanged: () => setState(() {})),
      ChartScreen(config: config),
      EquipmentScreen(config: config),
      ConfigScreen(config: config, onChanged: () { widget.onConfigChanged(); setState(() {}); }),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        height: 65,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calculate_outlined), selectedIcon: Icon(Icons.calculate), label: 'Calc'),
          NavigationDestination(icon: Icon(Icons.edit_note_outlined), selectedIcon: Icon(Icons.edit_note), label: 'Registro'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Gráficos'),
          NavigationDestination(icon: Icon(Icons.electrical_services_outlined), selectedIcon: Icon(Icons.electrical_services), label: 'Equipos'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Config'),
        ],
      ),
    );
  }
}
