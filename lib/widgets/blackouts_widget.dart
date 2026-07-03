import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models.dart';

class BlackoutsWidget extends StatefulWidget {
  final AppConfig config;
  const BlackoutsWidget({super.key, required this.config});
  @override
  State<BlackoutsWidget> createState() => _BlackoutsWidgetState();
}

class _BlackoutsWidgetState extends State<BlackoutsWidget> {
  List<Map<String, dynamic>> _blackouts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final box = Hive.box('_blackouts');
    _blackouts = box.values
        .map((v) => Map<String, dynamic>.from(v))
        .where((b) => (b['metroId'] ?? 0) == widget.config.activeMeter)
        .toList();
    _blackouts.sort((a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));
    setState(() {});
  }

  bool get _isOff {
    if (_blackouts.isEmpty) return false;
    return _blackouts.last['tipo'] == 'inicio';
  }

  Future<void> _toggle() async {
    final box = Hive.box('_blackouts');
    final entry = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'tipo': _isOff ? 'fin' : 'inicio',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'metroId': widget.config.activeMeter,
    };
    await box.put(entry['id'], entry);
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isOff ? '⚡ Apagón registrado' : '💡 Luz registrada'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Map<String, double> get _stats {
    final now = DateTime.now().millisecondsSinceEpoch;
    final monthAgo = now - 30 * 24 * 3600 * 1000;
    final recent = _blackouts.where((b) => (b['timestamp'] as int) >= monthAgo).toList();
    double totalHours = 0, longest = 0;
    for (int i = 0; i < recent.length; i++) {
      if (recent[i]['tipo'] == 'inicio') {
        final end = recent.skip(i + 1).where((b) => b['tipo'] == 'fin').firstOrNull;
        final dur = ((end != null ? end['timestamp'] as int : now) - (recent[i]['timestamp'] as int)) / 3600000;
        totalHours += dur;
        if (dur > longest) longest = dur;
      }
    }
    return {'total': totalHours, 'longest': longest, 'avgPerDay': totalHours / 30};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = _stats;
    final isOff = _isOff;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.power_off, size: 18, color: theme.colorScheme.secondary),
            const SizedBox(width: 8),
            Text('Control de Apagones', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
          ]),
          const SizedBox(height: 12),
          // Toggle button
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: _toggle,
              icon: Icon(isOff ? Icons.lightbulb : Icons.flash_off, size: 22),
              label: Text(isOff ? '💡 VOLVIÓ LA LUZ' : '⚡ SE FUE LA LUZ', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: isOff ? Colors.green : theme.colorScheme.secondary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          // Stats
          if (stats['total']! > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _StatItem(value: '${stats['total']!.toStringAsFixed(1)}h', label: 'Total 30d'),
                _StatItem(value: '${stats['avgPerDay']!.toStringAsFixed(1)}h', label: 'Prom/día'),
                _StatItem(value: '${stats['longest']!.toStringAsFixed(1)}h', label: 'Racha máx'),
              ]),
            ),
          ],
          if (isOff) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(Icons.warning_amber, size: 16, color: theme.colorScheme.secondary),
                const SizedBox(width: 6),
                Text('Sin electricidad actualmente', style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary, fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.secondary)),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}
