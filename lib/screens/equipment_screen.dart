import 'package:flutter/material.dart';
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
  List<Equipment> _equipment = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() => _equipment = DbService.getEquipment(meter: widget.config.activeMeter));

  Future<void> _add() async {
    final name = _nameCtrl.text.trim();
    final watts = double.tryParse(_wattsCtrl.text);
    final hours = double.tryParse(_hoursCtrl.text);
    if (name.isEmpty || watts == null || hours == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa todos los campos'), behavior: SnackBarBehavior.floating));
      return;
    }
    await DbService.putEquipment(Equipment(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name, watts: watts, hours: hours, meter: widget.config.activeMeter));
    _nameCtrl.clear(); _wattsCtrl.clear(); _hoursCtrl.clear();
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
    final result = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Row(children: [Icon(Icons.edit, color: Theme.of(ctx).colorScheme.primary), const SizedBox(width: 8), const Text('Editar Equipo')]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
        const SizedBox(height: 8),
        TextField(controller: wattsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Potencia (W)')),
        const SizedBox(height: 8),
        TextField(controller: hoursCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Horas/día')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
      ],
    ));
    if (result != true) return;
    e.name = nameCtrl.text.trim();
    e.watts = double.tryParse(wattsCtrl.text) ?? e.watts;
    e.hours = double.tryParse(hoursCtrl.text) ?? e.hours;
    await DbService.putEquipment(e);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalKwh = _equipment.fold<double>(0, (s, e) => s + e.monthlyKwh);
    final bill = totalKwh > 0 ? calcBill(totalKwh, widget.config.tariffs) : null;

    return Scaffold(
      appBar: AppBar(title: const GradientText('🔌 Equipos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Summary
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
                  Expanded(child: TextField(controller: _hoursCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Hrs/día', suffixText: 'h'))),
                ]),
                const SizedBox(height: 12),
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
          // List
          if (_equipment.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Agrega tu primer equipo', style: TextStyle(color: Colors.grey))))
          else
            ..._equipment.map((e) {
              final pct = totalKwh > 0 ? (e.monthlyKwh / totalKwh * 100) : 0.0;
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.tertiary.withOpacity(0.12),
                    child: Icon(Icons.electrical_services, color: theme.colorScheme.tertiary, size: 20),
                  ),
                  title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${e.watts.toStringAsFixed(0)}W • ${e.hours}h/día • ${e.monthlyKwh.toStringAsFixed(1)} kWh/mes'),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: pct / 100,
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ]),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (v) { if (v == 'edit') _edit(e); else _delete(e); },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Editar')])),
                      const PopupMenuItem(value: 'del', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Eliminar')])),
                    ],
                  ),
                ),
              );
            }),
        ]),
      ),
    );
  }
}
