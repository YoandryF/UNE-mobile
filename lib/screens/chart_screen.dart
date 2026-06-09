import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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
