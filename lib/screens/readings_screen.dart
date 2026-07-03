import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../db_service.dart';
import '../tariff_calc.dart';
import '../theme.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/blackouts_widget.dart';

class ReadingsScreen extends StatefulWidget {
  final AppConfig config;
  final VoidCallback onChanged;
  const ReadingsScreen({super.key, required this.config, required this.onChanged});
  @override
  State<ReadingsScreen> createState() => _ReadingsScreenState();
}

class _ReadingsScreenState extends State<ReadingsScreen> {
  final _readingCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  String? _photoPath;
  List<Reading> _readings = [];
  String _selectedMonth = '';

  @override
  void initState() {
    super.initState();
    _loadReadings();
  }

  @override
  void didUpdateWidget(covariant ReadingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadReadings();
  }

  void _loadReadings() {
    _readings = DbService.getReadings(meter: widget.config.activeMeter);
    _readings.sort((a, b) => a.date.compareTo(b.date) != 0 ? a.date.compareTo(b.date) : a.time.compareTo(b.time));
    final months = _readings.map((r) => r.date.substring(0, 7)).toSet().toList()..sort();
    if (months.isNotEmpty && (_selectedMonth.isEmpty || !months.contains(_selectedMonth))) {
      _selectedMonth = months.last;
    }
    setState(() {});
  }

  List<Reading> get _monthReadings => _readings.where((r) => r.date.startsWith(_selectedMonth)).toList();
  List<String> get _months => _readings.map((r) => r.date.substring(0, 7)).toSet().toList()..sort();

  double get _monthConsumed {
    final m = _monthReadings;
    return m.length >= 2 ? m.last.reading - m.first.reading : 0;
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Adjuntar foto', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ListTile(
              leading: CircleAvatar(backgroundColor: Theme.of(ctx).colorScheme.primary.withOpacity(0.1), child: Icon(Icons.camera_alt, color: Theme.of(ctx).colorScheme.primary)),
              title: const Text('Tomar foto'),
              subtitle: const Text('Usar la cámara del teléfono'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: CircleAvatar(backgroundColor: Theme.of(ctx).colorScheme.tertiary.withOpacity(0.1), child: Icon(Icons.photo_library, color: Theme.of(ctx).colorScheme.tertiary)),
              title: const Text('Elegir de galería'),
              subtitle: const Text('Seleccionar una foto existente'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            if (_photoPath != null)
              ListTile(
                leading: CircleAvatar(backgroundColor: Colors.red.withOpacity(0.1), child: const Icon(Icons.delete, color: Colors.red)),
                title: const Text('Quitar foto'),
                onTap: () { Navigator.pop(ctx); setState(() => _photoPath = null); },
              ),
          ]),
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 800, imageQuality: 70);
    if (picked != null) setState(() => _photoPath = picked.path);
  }

  Future<void> _addReading() async {
    final reading = double.tryParse(_readingCtrl.text);
    if (reading == null || reading <= 0) {
      _showToast('Ingresa una lectura válida', error: true);
      return;
    }
    if (_readings.isNotEmpty && reading < _readings.last.reading) {
      final ok = await showConfirmDialog(context, 'La lectura $reading es menor que la anterior (${_readings.last.reading}). ¿Continuar?');
      if (!ok) return;
    }
    final now = DateTime.now().toIso8601String();
    final r = Reading(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      reading: reading,
      date: DateFormat('yyyy-MM-dd').format(_date),
      time: '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
      photoPath: _photoPath,
      meter: widget.config.activeMeter,
      tariffs: widget.config.tariffs.toMap(),
      createdAt: now,
      updatedAt: now,
    );
    await DbService.putReading(r);
    _readingCtrl.clear();
    _photoPath = null;
    _loadReadings();
    widget.onChanged();
    _showToast('✓ Lectura registrada');
  }

  Future<void> _deleteReading(Reading r) async {
    final ok = await showConfirmDialog(context, '¿Eliminar este registro?', type: ConfirmType.danger);
    if (!ok) return;
    await DbService.deleteReading(r.id);
    _loadReadings();
    widget.onChanged();
  }

  Future<void> _editReading(Reading r) async {
    final readingCtrl = TextEditingController(text: r.reading.toString());
    String? editPhotoPath = r.photoPath;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(children: [
            Icon(Icons.edit, color: Theme.of(ctx).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Editar Registro'),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: readingCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Lectura (kWh)')),
            const SizedBox(height: 12),
            // Photo option
            OutlinedButton.icon(
              onPressed: () async {
                final source = await showModalBottomSheet<dynamic>(
                  context: ctx,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (bCtx) => SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        ListTile(
                          leading: const Icon(Icons.camera_alt),
                          title: const Text('Tomar foto'),
                          onTap: () => Navigator.pop(bCtx, ImageSource.camera),
                        ),
                        ListTile(
                          leading: const Icon(Icons.photo_library),
                          title: const Text('Elegir de galería'),
                          onTap: () => Navigator.pop(bCtx, ImageSource.gallery),
                        ),
                        if (editPhotoPath != null)
                          ListTile(
                            leading: const Icon(Icons.delete, color: Colors.red),
                            title: const Text('Quitar foto'),
                            onTap: () => Navigator.pop(bCtx, 'remove'),
                          ),
                      ]),
                    ),
                  ),
                );
                if (source == 'remove') {
                  setDialogState(() => editPhotoPath = null);
                } else if (source is ImageSource) {
                  final picked = await ImagePicker().pickImage(source: source, maxWidth: 800, imageQuality: 70);
                  if (picked != null) setDialogState(() => editPhotoPath = picked.path);
                }
              },
              icon: Icon(editPhotoPath != null ? Icons.check_circle : Icons.attach_file, size: 16, color: editPhotoPath != null ? Colors.green : null),
              label: Text(editPhotoPath != null ? 'Foto adjunta ✓' : 'Adjuntar evidencia', style: const TextStyle(fontSize: 13)),
              style: editPhotoPath != null ? OutlinedButton.styleFrom(side: BorderSide(color: Colors.green.withOpacity(0.5))) : null,
            ),
            const SizedBox(height: 12),
            Text('📅 Fecha: ${r.date}  ${r.time}', style: Theme.of(ctx).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            if (r.updatedAt != r.createdAt)
              Text('✏️ Editado: ${r.updatedAt.length >= 16 ? r.updatedAt.substring(0, 16).replaceAll('T', ' ') : r.updatedAt}', style: TextStyle(color: Theme.of(ctx).colorScheme.secondary, fontSize: 12)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (result != true) return;
    final newReading = double.tryParse(readingCtrl.text);
    if (newReading == null) return;
    r.reading = newReading;
    r.photoPath = editPhotoPath;
    r.updatedAt = DateTime.now().toIso8601String();
    await DbService.putReading(r);
    _loadReadings();
    widget.onChanged();
    _showToast('✓ Registro actualizado');
  }

  void _viewPhoto(Reading r) {
    if (r.photoPath == null) { _showToast('No hay foto', error: true); return; }
    showDialog(context: context, builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('📷 ${r.date} ${r.time}', style: Theme.of(ctx).textTheme.titleSmall),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
          ]),
        ),
        ClipRRect(
          borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
          child: Image.file(File(r.photoPath!), fit: BoxFit.cover),
        ),
      ]),
    ));
  }

  Future<void> _resetMonth() async {
    if (_selectedMonth.isEmpty) return;
    final ok = await showConfirmDialog(context, '¿Eliminar todos los registros de $_selectedMonth?', type: ConfirmType.danger);
    if (!ok) return;
    await DbService.deleteReadingsByMonth(_selectedMonth, widget.config.activeMeter);
    _loadReadings();
    widget.onChanged();
  }

  void _showToast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: error ? Theme.of(context).colorScheme.secondary : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final consumed = _monthConsumed;
    final bill = consumed > 0 ? calcBill(consumed, widget.config.tariffs) : null;

    return Scaffold(
      appBar: AppBar(
        title: const GradientText('📊 Registro', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        actions: [
          if (_months.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedMonth,
                  style: TextStyle(color: theme.colorScheme.primary, fontSize: 13),
                  items: _months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => setState(() => _selectedMonth = v!),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Input card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Nueva lectura', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                const SizedBox(height: 12),
                TextField(
                  controller: _readingCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(hintText: '0', suffixText: 'kWh'),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () async { final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now()); if (d != null) setState(() => _date = d); },
                    icon: const Icon(Icons.calendar_today, size: 15),
                    label: Text(DateFormat('dd/MM/yyyy').format(_date), style: const TextStyle(fontSize: 13)),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () async { final t = await showTimePicker(context: context, initialTime: _time); if (t != null) setState(() => _time = t); },
                    icon: const Icon(Icons.access_time, size: 15),
                    label: Text('${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 13)),
                  )),
                ]),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickPhoto,
                  icon: Icon(_photoPath != null ? Icons.check_circle : Icons.attach_file, size: 16),
                  label: Text(_photoPath != null ? 'Foto adjunta ✓' : 'Adjuntar foto (cámara/galería)', style: const TextStyle(fontSize: 13)),
                  style: _photoPath != null ? OutlinedButton.styleFrom(side: BorderSide(color: Colors.green.withOpacity(0.5))) : null,
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _addReading,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Registrar'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                ),
              ]),
            ),
          ),
          // Summary
          if (bill != null) ...[
            const SizedBox(height: 12),
            AccentCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Consumo del mes', style: theme.textTheme.bodySmall),
                    Text('${consumed.toStringAsFixed(0)} kWh', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ]),
                  GradientText('${bill.total.toStringAsFixed(2)} CUP', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800), gradient: AppTheme.dangerGradient),
                ]),
                // Thermometer bar
                const SizedBox(height: 12),
                () {
                  final threshold = widget.config.alertThreshold;
                  final pct = (consumed / threshold).clamp(0.0, 1.0);
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('0 kWh', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                      Text('${consumed.toStringAsFixed(0)} / ${threshold.toStringAsFixed(0)} kWh', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                    ]),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 10,
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
                        color: pct >= 0.8 ? theme.colorScheme.secondary : theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${(pct * 100).toStringAsFixed(0)}% del umbral', style: TextStyle(fontSize: 11, color: pct >= 0.8 ? theme.colorScheme.secondary : Colors.grey)),
                  ]);
                }(),
                // Estimation
                if (_monthReadings.length >= 2) ...[
                  const Divider(height: 20),
                  () {
                    final days = DateTime.parse(_monthReadings.last.date).difference(DateTime.parse(_monthReadings.first.date)).inDays;
                    if (days <= 0) return const SizedBox();
                    final avgPerDay = consumed / days;
                    final daysLeft = (30 - days).clamp(0, 30);
                    final estimated = consumed + avgPerDay * daysLeft;
                    final estimatedBill = calcBill(estimated, widget.config.tariffs).total;
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('📊 Estimación fin de mes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
                      const SizedBox(height: 6),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Prom: ${avgPerDay.toStringAsFixed(1)} kWh/día', style: theme.textTheme.bodySmall),
                        Text('~${estimated.toStringAsFixed(0)} kWh → ${estimatedBill.toStringAsFixed(0)} CUP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.secondary)),
                      ]),
                      if (daysLeft > 0)
                        Text('Faltan ~$daysLeft días del ciclo', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ]);
                  }(),
                ],
              ]),
            ),
          ],
          // Alert
          if (consumed >= widget.config.alertThreshold && consumed > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.3)),
              ),
              child: Row(children: [
                Icon(Icons.warning_amber, color: theme.colorScheme.secondary, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('⚠️ Consumo alcanzó umbral de ${widget.config.alertThreshold.toStringAsFixed(0)} kWh', style: TextStyle(color: theme.colorScheme.secondary, fontSize: 13))),
              ]),
            ),
          ],
          if (consumed > 400 && consumed < 500) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.bolt, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('⚡ Te acercas a los 500 kWh. Después se aplica recargo del ${widget.config.tariffs.surcharge.toStringAsFixed(0)}%.', style: const TextStyle(color: Colors.orange, fontSize: 12))),
              ]),
            ),
          ],
          // History
          const SizedBox(height: 16),
          if (_monthReadings.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Sin registros este mes', style: TextStyle(color: Colors.grey))))
          else
            ..._monthReadings.asMap().entries.map((entry) {
              final i = entry.key;
              final r = entry.value;
              final daily = i > 0 ? (r.reading - _monthReadings[i - 1].reading) : 0.0;
              final updated = r.updatedAt != r.createdAt;
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    child: Text('${i + 1}', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
                  ),
                  title: Text('${r.reading.toStringAsFixed(0)} kWh', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${r.date} ${r.time}${i > 0 ? '  •  +${daily.toStringAsFixed(0)}' : ''}${updated ? '\n✏️ Editado' : ''}',
                    style: TextStyle(fontSize: 12, color: updated ? theme.colorScheme.secondary : null),
                  ),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (r.photoPath != null) IconButton(icon: Icon(Icons.photo, size: 20, color: theme.colorScheme.primary), onPressed: () => _viewPhoto(r)),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20),
                      onSelected: (v) { if (v == 'edit') _editReading(r); else _deleteReading(r); },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Editar')])),
                        const PopupMenuItem(value: 'del', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Eliminar')])),
                      ],
                    ),
                  ]),
                ),
              );
            }),
          if (_monthReadings.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _resetMonth,
              icon: const Icon(Icons.delete_sweep, size: 18),
              label: Text('Reiniciar $_selectedMonth'),
              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.secondary),
            ),
          ],
          // Blackouts section
          const SizedBox(height: 16),
          BlackoutsWidget(config: widget.config),
        ]),
      ),
    );
  }
}
