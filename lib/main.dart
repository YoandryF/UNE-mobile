import 'package:flutter/material.dart';
import 'db_service.dart';
import 'models.dart';
import 'sync_service.dart';
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
    // Initialize sync with server URL from config or default
    final serverUrl = config.serverUrl.isNotEmpty ? config.serverUrl : 'http://192.168.1.100:3000';
    SyncService().init(serverUrl);
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

  Future<void> _switchMeter(int meter) async {
    final config = DbService.getConfig();
    config.activeMeter = meter;
    await DbService.saveConfig(config);
    widget.onConfigChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final config = DbService.getConfig();
    final theme = Theme.of(context);
    final screens = [
      CalculatorScreen(config: config),
      ReadingsScreen(config: config, onChanged: () => setState(() {})),
      ChartScreen(config: config),
      EquipmentScreen(config: config),
      ConfigScreen(config: config, onChanged: () { widget.onConfigChanged(); setState(() {}); }),
    ];

    return Scaffold(
      body: Column(
        children: [
          // Meter selector bar
          if (config.meters.length > 1)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: theme.colorScheme.surface,
              child: Row(
                  children: [
                    Icon(Icons.speed, size: 14, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: config.meters.asMap().entries.map((e) {
                            final isActive = e.key == config.activeMeter;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(e.value, style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                                  color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                                )),
                                selected: isActive,
                                onSelected: (_) => _switchMeter(e.key),
                                visualDensity: VisualDensity.compact,
                                selectedColor: theme.colorScheme.primary.withOpacity(0.2),
                                backgroundColor: theme.colorScheme.surface,
                                side: BorderSide(color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.3)),
                                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          Expanded(child: IndexedStack(index: _index, children: screens)),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sync status indicator
          const _SyncStatusBar(),
          NavigationBar(
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
        ],
      ),
    );
  }
}

class _SyncStatusBar extends StatefulWidget {
  const _SyncStatusBar();
  @override
  State<_SyncStatusBar> createState() => _SyncStatusBarState();
}

class _SyncStatusBarState extends State<_SyncStatusBar> {
  @override
  void initState() {
    super.initState();
    SyncService().addListener(_update);
  }

  @override
  void dispose() {
    SyncService().removeListener(_update);
    super.dispose();
  }

  void _update() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final sync = SyncService();
    final theme = Theme.of(context);

    Color bgColor;
    IconData icon;
    switch (sync.status) {
      case SyncStatus.syncing:
        bgColor = theme.colorScheme.primary.withOpacity(0.1);
        icon = Icons.sync;
        break;
      case SyncStatus.synced:
        bgColor = Colors.green.withOpacity(0.1);
        icon = Icons.cloud_done;
        break;
      case SyncStatus.error:
        bgColor = theme.colorScheme.secondary.withOpacity(0.1);
        icon = Icons.cloud_off;
        break;
      case SyncStatus.offline:
        bgColor = Colors.grey.withOpacity(0.05);
        icon = Icons.offline_bolt;
        break;
    }

    return GestureDetector(
      onTap: () => sync.sync(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        color: bgColor,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: sync.status == SyncStatus.error ? theme.colorScheme.secondary : sync.status == SyncStatus.offline ? Colors.grey : theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              sync.message.isEmpty ? 'Modo offline' : sync.message,
              style: TextStyle(fontSize: 11, color: sync.status == SyncStatus.error ? theme.colorScheme.secondary : sync.status == SyncStatus.offline ? Colors.grey : theme.colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
