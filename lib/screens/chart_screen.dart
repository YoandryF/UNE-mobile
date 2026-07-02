import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models.dart';
import '../db_service.dart';
import '../tariff_calc.dart';
import '../theme.dart';

class ChartScreen extends StatefulWidget {
  final AppConfig config;
  const ChartScreen({super.key, required this.config});
  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  List<Reading> _readings = [];
  String _selectedMonth = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ChartScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  void _load() {
    _readings = DbService.getReadings(meter: widget.config.activeMeter);
    _readings.sort((a, b) => a.date.compareTo(b.date));
    final months = _readings.map((r) => r.date.substring(0, 7)).toSet().toList()..sort();
    if (months.isNotEmpty && (_selectedMonth.isEmpty || !months.contains(_selectedMonth))) {
      _selectedMonth = months.last;
    }
    setState(() {});
  }

  List<String> get _months => _readings.map((r) => r.date.substring(0, 7)).toSet().toList()..sort();
  List<Reading> _getMonth(String m) => _readings.where((r) => r.date.startsWith(m)).toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthData = _getMonth(_selectedMonth);
    final dailyValues = <double>[];
    final dailyLabels = <String>[];
    for (int i = 1; i < monthData.length; i++) {
      dailyValues.add(monthData[i].reading - monthData[i - 1].reading);
      dailyLabels.add(monthData[i].date.substring(8));
    }

    final months = _months;
    final mIdx = months.indexOf(_selectedMonth);
    double? prevTotal;
    double curTotal = monthData.length >= 2 ? monthData.last.reading - monthData.first.reading : 0;
    if (mIdx > 0) {
      final prev = _getMonth(months[mIdx - 1]);
      if (prev.length >= 2) prevTotal = prev.last.reading - prev.first.reading;
    }

    double? costPerDay, kwhPerDay;
    if (monthData.length >= 2 && curTotal > 0) {
      final days = DateTime.parse(monthData.last.date).difference(DateTime.parse(monthData.first.date)).inDays;
      if (days > 0) {
        kwhPerDay = curTotal / days;
        costPerDay = calcBill(curTotal, widget.config.tariffs).total / days;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const GradientText('📈 Análisis', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        actions: [
          if (months.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                value: _selectedMonth,
                style: TextStyle(color: theme.colorScheme.primary, fontSize: 13),
                items: months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => setState(() => _selectedMonth = v!),
              )),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Consumo Diario', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                const SizedBox(height: 16),
                if (dailyValues.isEmpty)
                  const SizedBox(height: 150, child: Center(child: Text('Registra más lecturas para ver el gráfico', style: TextStyle(color: Colors.grey))))
                else
                  SizedBox(
                    height: 180,
                    child: BarChart(BarChartData(
                      barGroups: dailyValues.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [
                        BarChartRodData(
                          toY: e.value,
                          gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [theme.colorScheme.primary, theme.colorScheme.tertiary]),
                          width: dailyValues.length > 15 ? 8 : 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ])).toList(),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, m) => v.toInt() < dailyLabels.length ? Padding(padding: const EdgeInsets.only(top: 6), child: Text(dailyLabels[v.toInt()], style: const TextStyle(fontSize: 10))) : const SizedBox(),
                        )),
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 35, getTitlesWidget: (v, m) => Text('${v.toInt()}', style: const TextStyle(fontSize: 10)))),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: theme.dividerColor, strokeWidth: 1)),
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (g, gi, r, ri) => BarTooltipItem('${r.toY.toStringAsFixed(0)} kWh', const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                        ),
                      ),
                    )),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          // Stats row
          if (kwhPerDay != null)
            Row(children: [
              Expanded(child: StatChip(label: 'kWh/día', value: kwhPerDay.toStringAsFixed(1))),
              const SizedBox(width: 8),
              Expanded(child: StatChip(label: 'CUP/día', value: costPerDay!.toStringAsFixed(0), color: theme.colorScheme.secondary)),
              const SizedBox(width: 8),
              Expanded(child: StatChip(label: 'Total kWh', value: curTotal.toStringAsFixed(0), color: theme.colorScheme.tertiary)),
            ]),
          // End of month estimation
          if (kwhPerDay != null && kwhPerDay > 0) ...[
            const SizedBox(height: 12),
            () {
              final days = DateTime.parse(monthData.last.date).difference(DateTime.parse(monthData.first.date)).inDays;
              final daysLeft = (30 - days).clamp(0, 30);
              final estimated = curTotal + kwhPerDay! * daysLeft;
              final estimatedBill = calcBill(estimated, widget.config.tariffs).total;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    Row(children: [
                      const Text('📊', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text('Estimación fin de mes', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                    ]),
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                      Column(children: [
                        Text('${estimated.toStringAsFixed(0)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
                        Text('kWh estimados', style: theme.textTheme.bodySmall),
                      ]),
                      Column(children: [
                        Text('${estimatedBill.toStringAsFixed(0)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: theme.colorScheme.secondary)),
                        Text('CUP estimados', style: theme.textTheme.bodySmall),
                      ]),
                    ]),
                    if (daysLeft > 0) ...[
                      const SizedBox(height: 8),
                      Text('Faltan ~$daysLeft días del ciclo', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                    ],
                  ]),
                ),
              );
            }(),
          ],
          // Alert: approaching 500 kWh
          if (curTotal > 400 && curTotal < 500) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('⚡ Te acercas a los 500 kWh. Después se aplica recargo del ${widget.config.tariffs.surcharge.toStringAsFixed(0)}%.', style: const TextStyle(color: Colors.orange, fontSize: 12))),
              ]),
            ),
          ],
          // Comparison
          if (prevTotal != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Text('vs Mes anterior', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: StatChip(label: 'Este mes', value: '${curTotal.toStringAsFixed(0)}')),
                    const SizedBox(width: 8),
                    Expanded(child: StatChip(label: 'Anterior', value: '${prevTotal.toStringAsFixed(0)}')),
                  ]),
                  const SizedBox(height: 10),
                  _DiffBadge(current: curTotal, previous: prevTotal),
                ]),
              ),
            ),
          ],
          // Top consumers chart
          const SizedBox(height: 12),
          _TopConsumersChart(config: widget.config),
        ]),
      ),
    );
  }
}

class _DiffBadge extends StatelessWidget {
  final double current, previous;
  const _DiffBadge({required this.current, required this.previous});
  @override
  Widget build(BuildContext context) {
    final diff = current - previous;
    final pct = previous > 0 ? (diff / previous * 100) : 0.0;
    final up = diff > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: (up ? Colors.red : Colors.green).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(up ? Icons.trending_up : Icons.trending_down, size: 18, color: up ? Colors.red : Colors.green),
        const SizedBox(width: 6),
        Text(
          '${pct.abs().toStringAsFixed(1)}% (${diff > 0 ? "+" : ""}${diff.toStringAsFixed(0)} kWh)',
          style: TextStyle(color: up ? Colors.red : Colors.green, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ]),
    );
  }
}


class _TopConsumersChart extends StatelessWidget {
  final AppConfig config;
  const _TopConsumersChart({required this.config});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final equipment = DbService.getEquipment(meter: config.activeMeter);
    if (equipment.isEmpty) return const SizedBox();

    // Calculate effective kWh per equipment (adjusted for blackouts for 24/7)
    final blackoutHrs = _getMonthBlackoutHours(config.activeMeter);
    final effectiveHours24 = (24 * 30) - blackoutHrs;
    final sorted = equipment.map((e) {
      final kwh = e.alwaysOn ? (e.watts * effectiveHours24) / 1000 : e.monthlyKwh;
      return _EquipKwh(e.name, kwh, e.alwaysOn);
    }).toList()..sort((a, b) => b.kwh.compareTo(a.kwh));

    final maxKwh = sorted.first.kwh;
    final totalKwh = sorted.fold<double>(0, (s, e) => s + e.kwh);
    final colors = [theme.colorScheme.primary, theme.colorScheme.secondary, theme.colorScheme.tertiary, Colors.orange, Colors.green, Colors.purple, Colors.cyan, Colors.deepOrange];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.electrical_services, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text('Top Consumidores', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
          ]),
          if (blackoutHrs > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Ajustado por ${blackoutHrs.toStringAsFixed(1)}h de apagones', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            ),
          const SizedBox(height: 12),
          ...sorted.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            final pct = maxKwh > 0 ? (e.kwh / maxKwh) : 0.0;
            final pctTotal = totalKwh > 0 ? (e.kwh / totalKwh * 100).toStringAsFixed(0) : '0';
            final color = colors[i % colors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    Text(e.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    if (e.alwaysOn) ...[
                      const SizedBox(width: 4),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(4)), child: Text('24/7', style: TextStyle(fontSize: 8, color: theme.colorScheme.primary))),
                    ],
                  ]),
                  Text('${e.kwh.toStringAsFixed(1)} kWh ($pctTotal%)', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: color.withOpacity(0.08), color: color),
                ),
              ]),
            );
          }),
          if (blackoutHrs > 0) ...[
            const Divider(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: theme.colorScheme.secondary.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border(left: BorderSide(color: theme.colorScheme.secondary, width: 3))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('⚡ Impacto de apagones', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.secondary)),
                const SizedBox(height: 2),
                Text('${blackoutHrs.toStringAsFixed(1)}h sin luz → ~${equipment.where((e) => e.alwaysOn).fold<double>(0, (s, e) => s + (e.watts * blackoutHrs) / 1000).toStringAsFixed(1)} kWh menos', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  static double _getMonthBlackoutHours(int meter) {
    final box = Hive.box('_blackouts');
    final now = DateTime.now().millisecondsSinceEpoch;
    final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1).millisecondsSinceEpoch;
    final entries = box.values.map((v) => Map<String, dynamic>.from(v)).where((b) => (b['metroId'] ?? 0) == meter).toList();
    entries.sort((a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));
    double total = 0;
    for (int i = 0; i < entries.length; i++) {
      if (entries[i]['tipo'] == 'inicio') {
        final start = (entries[i]['timestamp'] as int).clamp(monthStart, now);
        final end = entries.skip(i + 1).where((b) => b['tipo'] == 'fin').firstOrNull;
        final endTs = (end != null ? end['timestamp'] as int : now).clamp(monthStart, now);
        if (start < endTs && start >= monthStart) total += (endTs - start) / 3600000;
      }
    }
    return total;
  }
}

class _EquipKwh {
  final String name;
  final double kwh;
  final bool alwaysOn;
  _EquipKwh(this.name, this.kwh, this.alwaysOn);
}
