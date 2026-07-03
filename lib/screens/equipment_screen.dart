import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models.dart';
import '../db_service.dart';
import '../tariff_calc.dart';
import '../theme.dart';
import '../widgets/confirm_dialog.dart';

class EquipmentScreen extends StatefulWidget {
  final AppConfig config;
  const EquipmentScreen({super.key, required this.config});
  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  final _nameCtrl = TextEditingController();
  final _wattsCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  bool _alwaysOn = false;
  List<Equipment> _equipment = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant EquipmentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  void _load() => setState(() => _equipment = DbService.getEquipment(meter: widget.config.activeMeter));

  double get _blackoutHours {
    final box = Hive.box('_blackouts');
    final now = DateTime.now().millisecondsSinceEpoch;
    final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1).millisecondsSinceEpoch;
    final entries = box.values
        .map((v) => Map<String, dynamic>.from(v))
        .where((b) => (b['metroId'] ?? 0) == widget.config.activeMeter)
        .toList();
    entries.sort((a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));
    double total = 0;
    for (int i = 0; i < entries.length; i++) {
      if (entries[i]['tipo'] == 'inicio') {
        final start = (entries[i]['timestamp'] as int).clamp(monthStart, now);
        final end = entries.skip(i + 1).where((b) => b['tipo'] == 'fin').firstOrNull;
        final endTs = (end != null ? end['timestamp'] as int : now).clamp(monthStart, now);
        if (start < endTs && start >= monthStart) {
          total += (endTs - start) / 3600000;
        }
      }
    }
    return total;
  }

  double _effectiveMonthlyKwh(Equipment e) {
    if (e.alwaysOn) {
      final effectiveHours = (24 * 30) - _blackoutHours;
      return (e.watts * effectiveHours) / 1000;
    }
    return e.monthlyKwh;
  }

  Future<void> _add() async {
    final name = _nameCtrl.text.trim();
    final watts = double.tryParse(_wattsCtrl.text);
    final hours = _alwaysOn ? 24.0 : double.tryParse(_hoursCtrl.text);
    if (name.isEmpty || watts == null || hours == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa todos los campos'), behavior: SnackBarBehavior.floating));
      return;
    }
    await DbService.putEquipment(Equipment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name, watts: watts, hours: hours,
      meter: widget.config.activeMeter, alwaysOn: _alwaysOn,
    ));
    _nameCtrl.clear(); _wattsCtrl.clear(); _hoursCtrl.clear();
    setState(() => _alwaysOn = false);
    FocusScope.of(context).unfocus();
    _load();
  }

  Future<void> _delete(Equipment e) async {
    final ok = await showConfirmDialog(context, '¿Eliminar "${e.name}"?', type: ConfirmType.danger);
    if (!ok) return;
    await DbService.deleteEquipment(e.id);
    _load();
  }

  Future<void> _edit(Equipment e) async {
    final nameCtrl = TextEditingController(text: e.name);
    final wattsCtrl = TextEditingController(text: e.watts.toString());
    final hoursCtrl = TextEditingController(text: e.hours.toString());
    bool editAlwaysOn = e.alwaysOn;

    final result = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: Row(children: [Icon(Icons.edit, color: Theme.of(ctx).colorScheme.primary), const SizedBox(width: 8), const Text('Editar Equipo')]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
          const SizedBox(height: 8),
          TextField(controller: wattsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Potencia (W)')),
          const SizedBox(height: 8),
          TextField(controller: hoursCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Horas/día'), enabled: !editAlwaysOn),
          const SizedBox(height: 8),
          Row(children: [
            Checkbox(value: editAlwaysOn, onChanged: (v) => setD(() { editAlwaysOn = v!; if (v) hoursCtrl.text = '24'; })),
            const Text('⚡ Siempre encendido (24/7)', style: TextStyle(fontSize: 13)),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    ));
    if (result != true) return;
    e.name = nameCtrl.text.trim();
    e.watts = double.tryParse(wattsCtrl.text) ?? e.watts;
    e.hours = editAlwaysOn ? 24 : (double.tryParse(hoursCtrl.text) ?? e.hours);
    e.alwaysOn = editAlwaysOn;
    await DbService.putEquipment(e);
    _load();
  }

  Future<void> _showUsageLog(Equipment e) async {
    final box = Hive.box('_equipment_usage');
    final allUsage = box.values
        .map((v) => Map<String, dynamic>.from(v))
        .where((u) => u['equipId'] == e.id)
        .toList();
    allUsage.sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _UsageLogSheet(equipment: e, usageList: allUsage, config: widget.config),
    );
    setState(() {}); // Refresh after changes
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bHrs = _blackoutHours;
    final totalKwh = _equipment.fold<double>(0, (s, e) => s + _effectiveMonthlyKwh(e));
    final bill = totalKwh > 0 ? calcBill(totalKwh, widget.config.tariffs) : null;
    final permanent = _equipment.where((e) => e.alwaysOn).toList();
    final intermittent = _equipment.where((e) => !e.alwaysOn).toList();

    return Scaffold(
      appBar: AppBar(title: const GradientText('🔌 Equipos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Summary with blackout adjustment
          if (bill != null)
            AccentCard(
              accentColor: theme.colorScheme.secondary,
              child: Column(children: [
                Text('Estimación mensual', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  StatChip(label: 'kWh/mes', value: totalKwh.toStringAsFixed(0)),
                  GradientText('${bill.total.toStringAsFixed(0)} CUP', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800), gradient: AppTheme.dangerGradient),
                ]),
                if (bHrs > 0) ...[
                  const SizedBox(height: 8),
                  Text('⚡ Descontando ${bHrs.toStringAsFixed(1)}h de apagones', style: TextStyle(fontSize: 11, color: theme.colorScheme.secondary)),
                ],
              ]),
            ),
          const SizedBox(height: 12),
          // Add form
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nombre del equipo', prefixIcon: Icon(Icons.devices, size: 20))),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(controller: _wattsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Watts', suffixText: 'W'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _hoursCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Hrs/día', suffixText: 'h'), enabled: !_alwaysOn)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Checkbox(value: _alwaysOn, onChanged: (v) => setState(() { _alwaysOn = v!; if (v!) _hoursCtrl.text = '24'; })),
                  const Text('⚡ Siempre encendido (24/7)', style: TextStyle(fontSize: 13)),
                ]),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar Equipo'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          // Always-on list
          if (permanent.isNotEmpty) ...[
            Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('⚡ Siempre encendidos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: theme.colorScheme.primary))),
            ...permanent.map((e) => _equipCard(e, theme, totalKwh)),
          ],
          // Intermittent list
          if (intermittent.isNotEmpty) ...[
            Padding(padding: const EdgeInsets.only(top: 8, bottom: 6), child: Text('🔄 Uso intermitente', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: theme.colorScheme.secondary))),
            ...intermittent.map((e) => _equipCard(e, theme, totalKwh)),
          ],
          if (_equipment.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Agrega tu primer equipo', style: TextStyle(color: Colors.grey)))),
        ]),
      ),
    );
  }

  Widget _equipCard(Equipment e, ThemeData theme, double totalKwh) {
    final kwh = _effectiveMonthlyKwh(e);
    final pct = totalKwh > 0 ? (kwh / totalKwh * 100) : 0.0;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: (e.alwaysOn ? theme.colorScheme.primary : theme.colorScheme.tertiary).withOpacity(0.12),
          child: Icon(e.alwaysOn ? Icons.power : Icons.electrical_services, color: e.alwaysOn ? theme.colorScheme.primary : theme.colorScheme.tertiary, size: 20),
        ),
        title: Row(children: [
          Expanded(child: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600))),
          if (e.alwaysOn) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: Text('24/7', style: TextStyle(fontSize: 10, color: theme.colorScheme.primary, fontWeight: FontWeight.w700))),
        ]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${e.watts.toStringAsFixed(0)}W • ${kwh.toStringAsFixed(1)} kWh/mes', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: pct / 100, backgroundColor: theme.colorScheme.primary.withOpacity(0.08), color: e.alwaysOn ? theme.colorScheme.primary : theme.colorScheme.tertiary, borderRadius: BorderRadius.circular(4)),
        ]),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20),
          onSelected: (v) {
            if (v == 'edit') _edit(e);
            else if (v == 'usage') _showUsageLog(e);
            else _delete(e);
          },
          itemBuilder: (_) => [
            if (!e.alwaysOn) const PopupMenuItem(value: 'usage', child: Row(children: [Icon(Icons.history, size: 18), SizedBox(width: 8), Text('Registro de uso')])),
            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Editar')])),
            const PopupMenuItem(value: 'del', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Eliminar')])),
          ],
        ),
      ),
    );
  }
}

// Bottom sheet for usage log
class _UsageLogSheet extends StatefulWidget {
  final Equipment equipment;
  final List<Map<String, dynamic>> usageList;
  final AppConfig config;
  const _UsageLogSheet({required this.equipment, required this.usageList, required this.config});
  @override
  State<_UsageLogSheet> createState() => _UsageLogSheetState();
}

class _UsageLogSheetState extends State<_UsageLogSheet> {
  late List<Map<String, dynamic>> _usage;
  DateTime _date = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    _usage = List.from(widget.usageList);
  }

  Future<void> _addUsage() async {
    if (_endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona hora fin')));
      return;
    }
    final startMins = _startTime.hour * 60 + _startTime.minute;
    final endMins = _endTime!.hour * 60 + _endTime!.minute;
    if (endMins <= startMins) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hora fin debe ser mayor que inicio')));
      return;
    }
    // Check 24h limit
    final dateStr = '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';
    final dayUsage = _usage.where((u) => u['date'] == dateStr).toList();
    int dayMins = 0;
    for (final u in dayUsage) {
      if (u['startTime'] != null && u['endTime'] != null) {
        final parts1 = (u['startTime'] as String).split(':').map(int.parse).toList();
        final parts2 = (u['endTime'] as String).split(':').map(int.parse).toList();
        dayMins += (parts2[0] * 60 + parts2[1]) - (parts1[0] * 60 + parts1[1]);
      }
    }
    if (dayMins + (endMins - startMins) > 1440) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Excede 24h. Ya tienes ${(dayMins / 60).toStringAsFixed(1)}h ese día.')));
      return;
    }

    final entry = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'equipId': widget.equipment.id,
      'date': dateStr,
      'startTime': '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
      'endTime': '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}',
      'meter': widget.config.activeMeter,
      'createdAt': DateTime.now().toIso8601String(),
    };
    final box = Hive.box('_equipment_usage');
    await box.put(entry['id'], entry);
    setState(() => _usage.insert(0, entry));
    _endTime = null;
  }

  Future<void> _addUsage24h() async {
    final dateStr = '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';
    final dayUsage = _usage.where((u) => u['date'] == dateStr).toList();
    if (dayUsage.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ya hay registros ese día. Elimínalos primero.')));
      return;
    }
    final entry = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'equipId': widget.equipment.id,
      'date': dateStr,
      'startTime': '00:00',
      'endTime': '23:59',
      'meter': widget.config.activeMeter,
      'createdAt': DateTime.now().toIso8601String(),
    };
    final box = Hive.box('_equipment_usage');
    await box.put(entry['id'], entry);
    setState(() => _usage.insert(0, entry));
  }

  Future<void> _delete(Map<String, dynamic> u) async {
    final box = Hive.box('_equipment_usage');
    await box.delete(u['id']);
    setState(() => _usage.remove(u));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = widget.equipment;

    // Month stats
    final month = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
    int totalMins = 0;
    for (final u in _usage.where((u) => (u['date'] ?? '').startsWith(month))) {
      if (u['startTime'] != null && u['endTime'] != null) {
        final p1 = (u['startTime'] as String).split(':').map(int.parse).toList();
        final p2 = (u['endTime'] as String).split(':').map(int.parse).toList();
        totalMins += (p2[0] * 60 + p2[1]) - (p1[0] * 60 + p1[1]);
      }
    }
    final totalKwh = (e.watts * totalMins / 60 / 1000);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: ListView(controller: ctrl, padding: const EdgeInsets.all(16), children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          Text('📋 Uso de: ${e.name}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          Text('${e.watts}W • Mes: ${(totalMins / 60).toStringAsFixed(1)}h = ${totalKwh.toStringAsFixed(2)} kWh', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
          const SizedBox(height: 16),
          // Add form
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () async { final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now()); if (d != null) setState(() => _date = d); },
              icon: const Icon(Icons.calendar_today, size: 14),
              label: Text('${_date.day}/${_date.month}', style: const TextStyle(fontSize: 12)),
            )),
            const SizedBox(width: 6),
            Expanded(child: OutlinedButton.icon(
              onPressed: () async { final t = await showTimePicker(context: context, initialTime: _startTime); if (t != null) setState(() => _startTime = t); },
              icon: const Icon(Icons.access_time, size: 14),
              label: Text('${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 12)),
            )),
            const SizedBox(width: 6),
            Expanded(child: OutlinedButton.icon(
              onPressed: () async { final t = await showTimePicker(context: context, initialTime: _endTime ?? TimeOfDay(hour: _startTime.hour + 1, minute: _startTime.minute)); if (t != null) setState(() => _endTime = t); },
              icon: const Icon(Icons.access_time, size: 14),
              label: Text(_endTime != null ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}' : 'Fin', style: const TextStyle(fontSize: 12)),
            )),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: FilledButton(onPressed: _addUsage, child: const Text('+ Registrar', style: TextStyle(fontSize: 13)))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: _addUsage24h, child: const Text('⚡ 24h', style: TextStyle(fontSize: 13)))),
          ]),
          const SizedBox(height: 16),
          // History
          if (_usage.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Sin registros de uso', style: TextStyle(color: Colors.grey))))
          else
            ..._usage.take(30).map((u) {
              final start = u['startTime'] ?? '';
              final end = u['endTime'] ?? '';
              int mins = 0;
              if (start.isNotEmpty && end.isNotEmpty) {
                final p1 = start.split(':').map(int.parse).toList();
                final p2 = end.split(':').map(int.parse).toList();
                mins = (p2[0] * 60 + p2[1]) - (p1[0] * 60 + p1[1]);
              }
              final kwh = (e.watts * mins / 60 / 1000).toStringAsFixed(3);
              final durLabel = mins >= 60 ? '${(mins / 60).toStringAsFixed(1)}h' : '${mins}min';
              final is24 = start == '00:00' && end == '23:59';
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${u['date']} • ${is24 ? '24h completo' : '$start – $end'}', style: const TextStyle(fontSize: 13)),
                subtitle: Text('$durLabel • $kwh kWh', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                trailing: IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => _delete(u)),
              );
            }),
        ]),
      ),
    );
  }
}
