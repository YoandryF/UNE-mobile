import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../models.dart';
import '../db_service.dart';
import '../sync_service.dart';
import '../update_service.dart';
import '../widgets/confirm_dialog.dart';

class ConfigScreen extends StatefulWidget {
  final AppConfig config;
  final VoidCallback onChanged;
  const ConfigScreen({super.key, required this.config, required this.onChanged});
  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  late List<TextEditingController> _rateControllers;
  late TextEditingController _surchargeCtrl;
  late TextEditingController _alertCtrl;
  late TextEditingController _cycleCtrl;
  late TextEditingController _serverUrlCtrl;
  late TextEditingController _serverPortCtrl;
  late List<TextEditingController> _meterCtrls;

  static const _labels = ['0–100','101–150','151–200','201–250','251–300','301–350','351–400','401–450','451–500','501–600','601–700','701–1000','1001–1800','1801–2600','2601–3400','3401–4200','4201–5000','>5000'];

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(covariant ConfigScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _initControllers();
    }
  }

  String _parseHost(String url) {
    if (url.isEmpty) return '';
    final u = url.replaceAll('http://', '').replaceAll('https://', '');
    return u.contains(':') ? u.split(':').first : u;
  }

  String _parsePort(String url) {
    if (url.isEmpty) return '3000';
    final u = url.replaceAll('http://', '').replaceAll('https://', '');
    return u.contains(':') ? u.split(':').last.replaceAll('/', '') : '3000';
  }

  String _buildServerUrl() {
    final host = _serverUrlCtrl.text.trim();
    final port = _serverPortCtrl.text.trim();
    if (host.isEmpty) return '';
    return 'http://$host:${port.isEmpty ? '3000' : port}';
  }

  void _initControllers() {
    final c = widget.config;
    // Ensure tariffs always has exactly 18 ranges (fill with defaults if needed)
    final defaultRanges = TariffConfig.defaultConfig().ranges;
    final ranges = List<TariffRange>.generate(18, (i) {
      if (i < c.tariffs.ranges.length) return c.tariffs.ranges[i];
      if (i < defaultRanges.length) return defaultRanges[i];
      return TariffRange(0, 0);
    });
    // Fix config ranges in memory too
    c.tariffs.ranges = ranges;

    _rateControllers = ranges.map((r) => TextEditingController(text: r.rate.toString())).toList();
    _surchargeCtrl = TextEditingController(text: c.tariffs.surcharge.toString());
    _alertCtrl = TextEditingController(text: c.alertThreshold.toString());
    _cycleCtrl = TextEditingController(text: c.billCycleDay.toString());
    _serverUrlCtrl = TextEditingController(text: _parseHost(c.serverUrl));
    _serverPortCtrl = TextEditingController(text: _parsePort(c.serverUrl));
    _meterCtrls = c.meters.map((m) => TextEditingController(text: m)).toList();
  }

  Future<void> _save() async {
    final ok = await showConfirmDialog(context, '¿Guardar configuración?', type: ConfirmType.info);
    if (!ok) return;
    final ranges = widget.config.tariffs.ranges.asMap().entries.map((e) =>
      TariffRange(e.value.size, double.tryParse(_rateControllers[e.key].text) ?? e.value.rate)
    ).toList();
    widget.config.tariffs = TariffConfig(ranges: ranges, surcharge: double.tryParse(_surchargeCtrl.text) ?? 25);
    widget.config.alertThreshold = double.tryParse(_alertCtrl.text) ?? 450;
    widget.config.billCycleDay = int.tryParse(_cycleCtrl.text) ?? 1;
    widget.config.meters = _meterCtrls.map((c) => c.text.trim().isEmpty ? 'Metro' : c.text.trim()).toList();
    widget.config.serverUrl = _buildServerUrl();
    await DbService.saveConfig(widget.config);
    // Update sync service URL
    SyncService().init(widget.config.serverUrl);
    widget.onChanged();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✓ Configuración guardada')));
  }

  Future<void> _resetTariffs() async {
    final ok = await showConfirmDialog(context, '¿Restaurar tarifas por defecto?');
    if (!ok) return;
    widget.config.tariffs = TariffConfig.defaultConfig();
    await DbService.saveConfig(widget.config);
    setState(() => _initControllers());
    widget.onChanged();
  }

  void _addMeter() {
    widget.config.meters.add('Metro ${widget.config.meters.length + 1}');
    _meterCtrls.add(TextEditingController(text: widget.config.meters.last));
    setState(() {});
  }

  Future<void> _deleteMeter(int idx) async {
    if (widget.config.meters.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debe haber al menos un metro')));
      return;
    }
    final ok = await showConfirmDialog(context, '¿Eliminar "${widget.config.meters[idx]}"?', type: ConfirmType.danger);
    if (!ok) return;
    widget.config.meters.removeAt(idx);
    _meterCtrls.removeAt(idx);
    if (widget.config.activeMeter >= widget.config.meters.length) widget.config.activeMeter = 0;
    setState(() {});
  }

  Future<void> _export() async {
    final data = DbService.exportAll();
    final json = jsonEncode(data);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/une-backup-${DateTime.now().toIso8601String().substring(0, 10)}.json');
    await file.writeAsString(json);
    await Share.shareXFiles([XFile(file.path)], text: 'Backup Consumo UNE');
  }

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (result == null || result.files.isEmpty) return;
    final ok = await showConfirmDialog(context, '¿Importar datos? Puede sobrescribir registros existentes.');
    if (!ok) return;
    try {
      final content = await File(result.files.first.path!).readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      await DbService.importAll(data);
      widget.onChanged();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✓ Datos importados')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('⚙️ Configuración')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Theme & Backup
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                SwitchListTile(
                  title: const Text('Modo oscuro'),
                  value: widget.config.darkMode,
                  onChanged: (v) async {
                    widget.config.darkMode = v;
                    await DbService.saveConfig(widget.config);
                    widget.onChanged();
                  },
                ),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(onPressed: _export, icon: const Icon(Icons.download), label: const Text('Exportar'))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton.icon(onPressed: _import, icon: const Icon(Icons.upload), label: const Text('Importar'))),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          // Server sync
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sincronización', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    flex: 3,
                    child: TextField(controller: _serverUrlCtrl, decoration: const InputDecoration(labelText: 'IP del servidor', hintText: '192.168.1.100', border: OutlineInputBorder(), prefixIcon: Icon(Icons.cloud, size: 18), isDense: true)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextField(controller: _serverPortCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Puerto', hintText: '3000', border: OutlineInputBorder(), isDense: true)),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final url = _buildServerUrl();
                        if (url.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa la IP del servidor'))); return; }
                        try {
                          final resp = await http.get(Uri.parse('$url/api/ping')).timeout(const Duration(seconds: 5));
                          if (mounted) {
                            if (resp.statusCode == 200) {
                              SyncService().serverUrl = url;
                              SyncService().init(url);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✓ Conectado al servidor')));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✗ Servidor respondió con error: ${resp.statusCode}')));
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✗ No se pudo conectar: $e')));
                          }
                        }
                      },
                      icon: const Icon(Icons.sync, size: 16),
                      label: const Text('Probar conexión', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final url = _buildServerUrl();
                        final source = widget.config.updateSource;
                        await UpdateService.checkAndPrompt(context, url, source: source);
                        if (mounted) {
                          final version = await UpdateService.checkForUpdate(url, source: source);
                          if (version != null && !UpdateService.hasUpdate(version)) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✓ Ya tienes la última versión')));
                          } else if (version == null) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✗ No se pudo verificar')));
                          }
                        }
                      },
                      icon: const Icon(Icons.system_update, size: 16),
                      label: const Text('Actualizaciones', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                // Update source selector
                Row(children: [
                  Text('Fuente de actualización: ', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: widget.config.updateSource,
                      isDense: true,
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      items: const [
                        DropdownMenuItem(value: 'auto', child: Text('Auto (GitHub → Servidor)', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'github', child: Text('GitHub Releases', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'server', child: Text('Servidor local', style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (v) => setState(() => widget.config.updateSource = v ?? 'auto'),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          // Meters
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Metros Contadores', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                const SizedBox(height: 8),
                ...widget.config.meters.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Expanded(child: TextField(controller: _meterCtrls[e.key], decoration: InputDecoration(labelText: '#${e.key + 1}', border: const OutlineInputBorder(), isDense: true))),
                    IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () => _deleteMeter(e.key)),
                  ]),
                )),
                TextButton.icon(onPressed: _addMeter, icon: const Icon(Icons.add), label: const Text('Agregar metro')),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          // Cycle & Alert
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                TextField(controller: _cycleCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Día de corte del ciclo', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                TextField(controller: _alertCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Umbral de alerta (kWh)', border: OutlineInputBorder())),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          // Tariffs
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Tarifas por rango', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                const SizedBox(height: 8),
                ...List.generate(_labels.length, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    SizedBox(width: 90, child: Text(_labels[i], style: theme.textTheme.bodySmall)),
                    Expanded(child: TextField(controller: _rateControllers[i], keyboardType: TextInputType.number, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, suffixText: 'CUP'))),
                  ]),
                )),
                const SizedBox(height: 8),
                TextField(controller: _surchargeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Recargo >500 kWh (%)', border: OutlineInputBorder())),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Guardar Configuración'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48))),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _resetTariffs, icon: const Icon(Icons.restore), label: const Text('Restaurar Tarifas por Defecto')),
        ]),
      ),
    );
  }
}
