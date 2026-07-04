import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'models.dart';

enum SyncStatus { offline, syncing, synced, error }

class SyncService extends ChangeNotifier {
  static final SyncService _instance = SyncService._();
  factory SyncService() => _instance;
  SyncService._();

  SyncStatus _status = SyncStatus.offline;
  String _message = 'Modo offline';
  String _serverUrl = '';
  String _lastSync = '';
  Timer? _periodicTimer;
  bool _enabled = false;

  SyncStatus get status => _status;
  String get message => _message;
  String get serverUrl => _serverUrl;
  bool get isEnabled => _enabled && _serverUrl.isNotEmpty;
  int get pendingCount => Hive.box('_pending').length;

  set serverUrl(String url) {
    _serverUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    _enabled = _serverUrl.isNotEmpty;
    notifyListeners();
  }

  void init(String url) {
    serverUrl = url;
    if (!isEnabled) {
      _setStatus(SyncStatus.offline, 'Modo offline — datos guardados localmente');
      return;
    }
    // Sync every 60 seconds
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(seconds: 60), (_) => sync());
    // Initial sync (non-blocking)
    sync();
  }

  void stop() {
    _periodicTimer?.cancel();
    _enabled = false;
    _setStatus(SyncStatus.offline, 'Sincronización desactivada');
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }

  void _setStatus(SyncStatus s, [String msg = '']) {
    _status = s;
    _message = msg;
    notifyListeners();
  }

  /// Queue a pending operation for later sync.
  /// This NEVER blocks or throws — data is always saved locally first.
  Future<void> queueOperation(Map<String, dynamic> action) async {
    try {
      final box = Hive.box('_pending');
      await box.add({...action, 'ts': DateTime.now().millisecondsSinceEpoch});
    } catch (_) {
      // Silently ignore queue errors — local data is already saved via Hive
    }
    // Try sync in background only if enabled (fire and forget, never await)
    if (isEnabled) {
      Future.microtask(() => sync());
    }
  }

  /// Push pending changes then pull full state from server.
  /// Returns true if sync succeeded, false otherwise.
  /// NEVER throws — always safe to call.
  Future<bool> sync() async {
    if (!isEnabled) {
      _setStatus(SyncStatus.offline, 'Modo offline — ${pendingCount} cambios pendientes');
      return false;
    }
    if (_status == SyncStatus.syncing) return false;

    _setStatus(SyncStatus.syncing, 'Sincronizando...');

    try {
      // 0. Ping to verify connectivity quickly
      final ping = await http.get(Uri.parse('$_serverUrl/api/ping'))
          .timeout(const Duration(seconds: 3));
      if (ping.statusCode != 200) throw Exception('Ping failed');

      // 1. Push pending operations
      await _pushPending();

      // 2. Pull state from server (incremental if possible)
      await _pullFromServer();

      // 3. Save last sync timestamp
      _lastSync = DateTime.now().toUtc().toIso8601String();

      _setStatus(SyncStatus.synced, 'Sincronizado ✓');
      return true;
    } catch (e) {
      final pending = pendingCount;
      _setStatus(SyncStatus.error, 'Sin conexión${pending > 0 ? ' — $pending pendientes' : ''}');
      return false;
    }
  }

  Future<void> _pushPending() async {
    final box = Hive.box('_pending');
    if (box.isEmpty) return;

    final pending = box.values.toList();
    for (final p in pending) {
      final action = Map<String, dynamic>.from(p);
      final type = action['type'] as String;
      final store = action['store'] as String;

      try {
        if (type == 'delete') {
          final itemId = action['itemId'] as String;
          await http.delete(Uri.parse('$_serverUrl/api/$store/$itemId'))
              .timeout(const Duration(seconds: 5));
        } else {
          final data = action['data'];
          await http.post(
            Uri.parse('$_serverUrl/api/$store'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          ).timeout(const Duration(seconds: 5));
        }
      } catch (_) {
        // If any push fails, stop pushing and try again later
        // Don't clear the box so pending items are retried
        rethrow;
      }
    }
    // Only clear if ALL pushes succeeded
    await box.clear();
  }

  Future<void> _pullFromServer() async {
    // Use incremental sync if we have a last sync timestamp
    final syncUrl = _lastSync.isNotEmpty
        ? '$_serverUrl/api/sync?since=$_lastSync'
        : '$_serverUrl/api/sync';
    final resp = await http.get(Uri.parse(syncUrl))
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) throw Exception('Sync failed: ${resp.statusCode}');

    final remote = jsonDecode(resp.body) as Map<String, dynamic>;
    final isIncremental = remote['incremental'] == true;

    final readingsBox = Hive.box('readings');
    final equipmentBox = Hive.box('equipment');
    final configBox = Hive.box('config');

    if (remote['readings'] != null) {
      if (!isIncremental) await readingsBox.clear();
      for (final r in remote['readings']) {
        final map = Map<String, dynamic>.from(r);
        // Handle photo: if it's base64, save to file
        final photo = map['photo'];
        if (photo != null && photo is String && photo.startsWith('data:')) {
          final localPath = await _savePhotoFromBase64(photo, map['id'].toString());
          map['photoPath'] = localPath;
        } else {
          map['photoPath'] = photo;
        }
        map.remove('photo');
        if (map['tariffs'] is String) {
          map['tariffs'] = jsonDecode(map['tariffs']);
        }
        map['tariffs'] ??= {};
        await readingsBox.put(map['id'], map);
      }
    }

    if (remote['equipment'] != null) {
      await equipmentBox.clear();
      for (final e in remote['equipment']) {
        final map = Map<String, dynamic>.from(e);
        await equipmentBox.put(map['id'], map);
      }
    }

    if (remote['config'] != null) {
      for (final c in remote['config']) {
        final key = c['key'] as String;
        final value = c['value'];
        if (key == 'main' && value != null) {
          // Merge: keep local-only fields, update shared fields from server
          final current = configBox.get('main');
          final local = current != null ? Map<String, dynamic>.from(current) : <String, dynamic>{};
          final remote = Map<String, dynamic>.from(value);
          // Only update shared fields from server
          if (remote['tariffs'] != null) local['tariffs'] = remote['tariffs'];
          if (remote['meters'] != null) local['meters'] = remote['meters'];
          if (remote['alertThreshold'] != null) local['alertThreshold'] = remote['alertThreshold'];
          if (remote['billCycleDay'] != null) local['billCycleDay'] = remote['billCycleDay'];
          if (remote['activeMeter'] != null) local['activeMeter'] = remote['activeMeter'];
          // Keep local-only fields: serverUrl, updateSource, syncPhotos, darkMode
          await configBox.put('main', local);
        }
      }
    }
  }

  static Future<Map<String, dynamic>> readingToServer(Reading r, {bool includePhoto = true}) async {
    String? photoBase64;
    if (includePhoto && r.photoPath != null && r.photoPath!.isNotEmpty) {
      try {
        final file = File(r.photoPath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          photoBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        }
      } catch (_) {}
    }
    return {
      'id': r.id,
      'reading': r.reading,
      'date': r.date,
      'time': r.time,
      'photo': photoBase64 ?? r.photoPath,
      'meter': r.meter,
      'tariffs': r.tariffs,
      'createdAt': r.createdAt,
      'updatedAt': r.updatedAt,
    };
  }

  /// Save a base64 photo to local file and return the path
  static Future<String?> _savePhotoFromBase64(String base64Data, String readingId) async {
    try {
      String data = base64Data;
      if (data.contains(',')) data = data.split(',').last;
      final bytes = base64Decode(data);
      final dir = await getApplicationDocumentsDirectory();
      final photoDir = Directory('${dir.path}/photos');
      if (!await photoDir.exists()) await photoDir.create(recursive: true);
      final file = File('${photoDir.path}/$readingId.jpg');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> equipmentToServer(Equipment e) {
    return {
      'id': e.id,
      'name': e.name,
      'watts': e.watts,
      'hours': e.hours,
      'meter': e.meter,
    };
  }

  static Map<String, dynamic> configToServer(AppConfig c) {
    return {'key': 'main', 'value': c.toMap()};
  }
}
