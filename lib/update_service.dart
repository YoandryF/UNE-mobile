import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class AppVersion {
  final String latest;
  final String minRequired;
  final String forceDate;
  final String downloadUrl;
  final String changelog;

  AppVersion({
    required this.latest,
    required this.minRequired,
    required this.forceDate,
    required this.downloadUrl,
    this.changelog = '',
  });

  factory AppVersion.fromJson(Map<String, dynamic> json) => AppVersion(
    latest: json['latest'] ?? '0.0.0',
    minRequired: json['minRequired'] ?? '0.0.0',
    forceDate: json['forceDate'] ?? '2099-12-31',
    downloadUrl: json['downloadUrl'] ?? '',
    changelog: json['changelog'] ?? '',
  );
}

class UpdateService {
  static const String currentVersion = '1.2.4';

  static const String githubRepo = 'YoandryF/UNE-mobile';

  /// Check from local server
  static Future<AppVersion?> _checkFromServer(String serverUrl) async {
    if (serverUrl.isEmpty) return null;
    try {
      final url = serverUrl.endsWith('/') ? serverUrl.substring(0, serverUrl.length - 1) : serverUrl;
      final resp = await http.get(Uri.parse('$url/api/app-version')).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) return null;
      return AppVersion.fromJson(jsonDecode(resp.body));
    } catch (_) {
      return null;
    }
  }

  /// Check from GitHub Releases API
  static Future<AppVersion?> _checkFromGitHub() async {
    try {
      final resp = await http.get(
        Uri.parse('https://api.github.com/repos/$githubRepo/releases/latest'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;
      final release = jsonDecode(resp.body) as Map<String, dynamic>;
      final tagName = (release['tag_name'] ?? '') as String;
      final version = tagName.startsWith('v') ? tagName.substring(1) : tagName;
      if (version.isEmpty) return null;
      // Find APK asset
      String downloadUrl = '';
      final assets = release['assets'] as List? ?? [];
      for (final asset in assets) {
        if ((asset['name'] ?? '').toString().endsWith('.apk')) {
          downloadUrl = asset['browser_download_url'] ?? '';
          break;
        }
      }
      return AppVersion(
        latest: version,
        minRequired: '0.0.0',
        forceDate: '2099-12-31',
        downloadUrl: downloadUrl,
        changelog: release['body'] ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  /// Check for update based on configured source ('auto', 'github', 'server')
  static Future<AppVersion?> checkForUpdate(String serverUrl, {String source = 'auto'}) async {
    switch (source) {
      case 'github':
        return _checkFromGitHub();
      case 'server':
        return _checkFromServer(serverUrl);
      case 'auto':
      default:
        final github = await _checkFromGitHub();
        if (github != null && hasUpdate(github)) return github;
        return _checkFromServer(serverUrl);
    }
  }

  static int compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map(int.parse).toList();
    final parts2 = v2.split('.').map(int.parse).toList();
    for (int i = 0; i < 3; i++) {
      final a = i < parts1.length ? parts1[i] : 0;
      final b = i < parts2.length ? parts2[i] : 0;
      if (a > b) return 1;
      if (a < b) return -1;
    }
    return 0;
  }

  static bool isMandatory(AppVersion version) {
    if (compareVersions(currentVersion, version.minRequired) < 0) return true;
    try {
      final force = DateTime.parse(version.forceDate);
      if (DateTime.now().isAfter(force) && compareVersions(currentVersion, version.latest) < 0) return true;
    } catch (_) {}
    return false;
  }

  static bool hasUpdate(AppVersion version) {
    return compareVersions(currentVersion, version.latest) < 0;
  }

  static int daysUntilForced(AppVersion version) {
    try {
      final force = DateTime.parse(version.forceDate);
      final diff = force.difference(DateTime.now()).inDays;
      return diff > 0 ? diff : 0;
    } catch (_) {
      return 999;
    }
  }

  static Future<String?> downloadApk(String downloadUrl, void Function(double) onProgress) async {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);
      if (response.statusCode != 200) { client.close(); return null; }

      final contentLength = response.contentLength ?? 0;
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/une-consumo-update.apk';
      final file = File(filePath);
      final sink = file.openWrite();

      int received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength > 0) onProgress(received / contentLength);
      }
      await sink.close();
      client.close();
      return filePath;
    } catch (_) {
      return null;
    }
  }

  static const _channel = MethodChannel('une_consumo/installer');

  static Future<bool> canInstallApk() async {
    try {
      final result = await _channel.invokeMethod('canInstallApk');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestInstallPermission() async {
    try {
      await _channel.invokeMethod('requestInstallPermission');
    } catch (_) {}
  }

  static Future<bool> installApk(String filePath) async {
    try {
      final result = await _channel.invokeMethod('installApk', {'path': filePath});
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> checkAndPrompt(BuildContext context, String serverUrl, {String source = 'auto'}) async {
    final version = await checkForUpdate(serverUrl, source: source);
    if (version == null || !hasUpdate(version)) return;
    if (!context.mounted) return;

    final mandatory = isMandatory(version);
    final daysLeft = daysUntilForced(version);

    showDialog(
      context: context,
      barrierDismissible: !mandatory,
      builder: (ctx) => _UpdateDialog(version: version, mandatory: mandatory, daysLeft: daysLeft),
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final AppVersion version;
  final bool mandatory;
  final int daysLeft;
  const _UpdateDialog({required this.version, required this.mandatory, required this.daysLeft});
  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  Future<void> _download() async {
    // Check install permission first
    final canInstall = await UpdateService.canInstallApk();
    if (!canInstall) {
      if (!mounted) return;
      final grant = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.security, size: 48, color: Colors.orange),
          title: const Text('Permiso requerido', textAlign: TextAlign.center),
          content: const Text('Para instalar actualizaciones, necesitas permitir la instalación desde esta app.\n\nSe abrirá la configuración de Android. Activa "Permitir desde esta fuente" y vuelve aquí.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13)),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Abrir configuración')),
          ],
        ),
      );
      if (grant == true) {
        await UpdateService.requestInstallPermission();
      }
      return;
    }

    setState(() { _downloading = true; _error = null; _progress = 0; });

    final path = await UpdateService.downloadApk(
      widget.version.downloadUrl,
      (p) => setState(() => _progress = p),
    );

    if (path == null) {
      setState(() { _downloading = false; _error = 'Error al descargar. Verifica tu conexión.'; });
      return;
    }

    // Install
    final installed = await UpdateService.installApk(path);
    if (!installed && mounted) {
      setState(() { _downloading = false; _error = 'No se pudo abrir el instalador. Busca el archivo en: $path'; });
    } else {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !widget.mandatory,
      child: AlertDialog(
        icon: Icon(
          widget.mandatory ? Icons.system_update : Icons.upgrade,
          size: 48,
          color: widget.mandatory ? theme.colorScheme.secondary : theme.colorScheme.primary,
        ),
        title: Text(widget.mandatory ? 'Actualización Obligatoria' : 'Nueva Versión Disponible', textAlign: TextAlign.center, style: const TextStyle(fontSize: 17)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text('v${UpdateService.currentVersion} → v${widget.version.latest}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
          ),
          const SizedBox(height: 12),
          Text(widget.version.changelog, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          if (!widget.mandatory && widget.daysLeft > 0 && widget.daysLeft < 999)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.schedule, size: 14, color: Colors.orange),
                const SizedBox(width: 6),
                Text('Obligatoria en ${widget.daysLeft} días', style: const TextStyle(fontSize: 12, color: Colors.orange)),
              ]),
            ),
          if (widget.mandatory)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.block, size: 14, color: Colors.red),
                SizedBox(width: 6),
                Text('Debes actualizar para continuar', style: TextStyle(fontSize: 12, color: Colors.red)),
              ]),
            ),
          if (_downloading) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: _progress, minHeight: 8),
            ),
            const SizedBox(height: 6),
            Text('Descargando... ${(_progress * 100).toStringAsFixed(0)}%', style: theme.textTheme.bodySmall),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary), textAlign: TextAlign.center),
          ],
        ]),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          if (!widget.mandatory && !_downloading)
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Después')),
          if (!_downloading)
            FilledButton.icon(
              onPressed: _download,
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Actualizar'),
            ),
        ],
      ),
    );
  }
}
