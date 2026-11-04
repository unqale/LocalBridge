import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const int kDefaultPort = 53317;
const String kAppId = 'localbridge';
const String kAppName = 'LocalBridge';
const String kVersion = '1.3.0';

// Newest first. Every batch of changes gets its own version entry.
const List<(String, String, List<String>)> kChangelog = [
  (
    '1.3.0',
    'More settings',
    [
      'Appearance: pure black (AMOLED) mode, text size, radar animation, compact header, hide IP addresses, haptic feedback, 11 accent colors',
      'Receive: trusted devices (star a device to auto-accept from it), group files by sender, overwrite option, request timeout, open save folder (desktop)',
      'Link sharing: auto-stop timer',
      'Network: visible to other devices toggle',
      'History: configurable history size',
      'Added this changelog',
    ],
  ),
  (
    '1.2.0',
    'Link sharing & English UI',
    [
      'Share via link: pick files and let anyone on your Wi-Fi download them from a browser',
      'Optional PIN and approval prompt for link downloads',
      'Whole interface translated to English',
    ],
  ),
  (
    '1.1.0',
    'LocalBridge redesign',
    [
      'Renamed from LocalDrop to LocalBridge',
      'New Material 3 interface with animated radar header',
      'Devices, History and Settings tabs',
      'Transfer history saved on device',
      'Settings: device name, theme, accent color, auto-accept, save folder, scan interval, port',
    ],
  ),
  (
    '1.0.0',
    'LocalDrop',
    [
      'Find devices on the same Wi-Fi automatically',
      'Send files with an accept/decline prompt on the receiving side',
    ],
  ),
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = Settings();
  await settings.load();
  runApp(LocalBridgeApp(settings: settings));
}

// ------------------------------------------------------------- settings

const List<Color> kAccents = [
  Colors.indigo,
  Colors.teal,
  Colors.deepPurple,
  Colors.pink,
  Colors.orange,
  Colors.green,
  Colors.blue,
  Colors.red,
  Colors.cyan,
  Colors.brown,
  Colors.blueGrey,
];

class Settings extends ChangeNotifier {
  String deviceName = _defaultName();
  ThemeMode themeMode = ThemeMode.system;
  int accent = 0;
  bool autoAccept = false;
  bool autoScan = true;
  int scanSeconds = 8;
  int port = kDefaultPort;
  String saveDir = '';
  bool keepHistory = true;
  bool askShare = true;
  String sharePin = '';
  bool autoAcceptTrusted = true;
  Set<String> trusted = {};
  int requestTimeout = 60;
  bool overwrite = false;
  bool groupBySender = false;
  int historyLimit = 200;
  int shareMinutes = 0;
  bool discoverable = true;
  double textScale = 1.0;
  bool amoled = false;
  bool showRadar = true;
  bool showIps = true;
  bool haptics = true;
  bool compactHeader = false;

  static String _defaultName() {
    final os = Platform.isAndroid
        ? 'Android'
        : Platform.isIOS
            ? 'iPhone'
            : Platform.isWindows
                ? 'Windows'
                : Platform.isMacOS
                    ? 'Mac'
                    : 'Linux';
    return '$os-${Random().nextInt(900) + 100}';
  }

  Future<File> _file() async {
    final d = await getApplicationSupportDirectory();
    await d.create(recursive: true);
    return File(p.join(d.path, 'settings.json'));
  }

  Future<void> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      deviceName = (j['deviceName'] as String?) ?? deviceName;
      themeMode = ThemeMode.values[(j['themeMode'] as int?) ?? 0];
      accent = ((j['accent'] as int?) ?? 0).clamp(0, kAccents.length - 1);
      autoAccept = (j['autoAccept'] as bool?) ?? false;
      autoScan = (j['autoScan'] as bool?) ?? true;
      scanSeconds = ((j['scanSeconds'] as int?) ?? 8).clamp(3, 120);
      port = ((j['port'] as int?) ?? kDefaultPort).clamp(1024, 65535);
      saveDir = (j['saveDir'] as String?) ?? '';
      keepHistory = (j['keepHistory'] as bool?) ?? true;
      askShare = (j['askShare'] as bool?) ?? true;
      sharePin = (j['sharePin'] as String?) ?? '';
      autoAcceptTrusted = (j['autoAcceptTrusted'] as bool?) ?? true;
      trusted = ((j['trusted'] as List?) ?? []).map((e) => '$e').toSet();
      requestTimeout = ((j['requestTimeout'] as int?) ?? 60).clamp(15, 120);
      overwrite = (j['overwrite'] as bool?) ?? false;
      groupBySender = (j['groupBySender'] as bool?) ?? false;
      historyLimit = ((j['historyLimit'] as int?) ?? 200).clamp(10, 1000);
      shareMinutes = (j['shareMinutes'] as int?) ?? 0;
      discoverable = (j['discoverable'] as bool?) ?? true;
      textScale = ((j['textScale'] as num?)?.toDouble() ?? 1.0).clamp(0.8, 1.4).toDouble();
      amoled = (j['amoled'] as bool?) ?? false;
      showRadar = (j['showRadar'] as bool?) ?? true;
      showIps = (j['showIps'] as bool?) ?? true;
      haptics = (j['haptics'] as bool?) ?? true;
      compactHeader = (j['compactHeader'] as bool?) ?? false;
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode({
        'deviceName': deviceName,
        'themeMode': themeMode.index,
        'accent': accent,
        'autoAccept': autoAccept,
        'autoScan': autoScan,
        'scanSeconds': scanSeconds,
        'port': port,
        'saveDir': saveDir,
        'keepHistory': keepHistory,
        'askShare': askShare,
        'sharePin': sharePin,
        'autoAcceptTrusted': autoAcceptTrusted,
        'trusted': trusted.toList(),
        'requestTimeout': requestTimeout,
        'overwrite': overwrite,
        'groupBySender': groupBySender,
        'historyLimit': historyLimit,
        'shareMinutes': shareMinutes,
        'discoverable': discoverable,
        'textScale': textScale,
        'amoled': amoled,
        'showRadar': showRadar,
        'showIps': showIps,
        'haptics': haptics,
        'compactHeader': compactHeader,
      }));
    } catch (_) {}
  }

  void update(void Function() change) {
    change();
    notifyListeners();
    _save();
  }

  void reset() {
    update(() {
      deviceName = _defaultName();
      themeMode = ThemeMode.system;
      accent = 0;
      autoAccept = false;
      autoScan = true;
      scanSeconds = 8;
      port = kDefaultPort;
      saveDir = '';
      keepHistory = true;
      askShare = true;
      sharePin = '';
      autoAcceptTrusted = true;
      trusted = {};
      requestTimeout = 60;
      overwrite = false;
      groupBySender = false;
      historyLimit = 200;
      shareMinutes = 0;
      discoverable = true;
      textScale = 1.0;
      amoled = false;
      showRadar = true;
      showIps = true;
      haptics = true;
      compactHeader = false;
    });
  }

  void toggleTrusted(String name) {
    update(() {
      if (!trusted.remove(name)) trusted.add(name);
    });
  }
}

// --------------------------------------------------------------- models

class Device {
  final String alias;
  final String ip;
  final String platform;
  Device(this.alias, this.ip, this.platform);

  bool get isPhone => platform == 'android' || platform == 'ios';
}

class IncomingRequest {
  final String from;
  final List<Map<String, dynamic>> files;
  final bool download; // true: a browser wants to download our shared files
  final Completer<bool> decision = Completer<bool>();
  IncomingRequest(this.from, this.files, {this.download = false});
}

class _Session {
  final List<String> names;
  final List<int> sizes;
  final String from;
  int done = 0;
  _Session(this.names, this.sizes, this.from);
}

class ShareSession {
  final String token;
  final List<PlatformFile> files;
  final List<int> sizes;
  final String? pin;
  final Set<String> unlocked = {};
  final Set<String> allowed = {};
  int downloads = 0;
  ShareSession(this.token, this.files, this.sizes, this.pin);
}

class HistoryItem {
  final String name;
  final int size;
  final bool sent;
  final String peer;
  final DateTime time;
  final String? path;

  HistoryItem(this.name, this.size, this.sent, this.peer, this.time, this.path);

  Map<String, dynamic> toJson() => {
        'name': name,
        'size': size,
        'sent': sent,
        'peer': peer,
        'time': time.millisecondsSinceEpoch,
        'path': path,
      };

  factory HistoryItem.fromJson(Map<String, dynamic> j) => HistoryItem(
        '${j['name']}',
        (j['size'] as num?)?.toInt() ?? 0,
        (j['sent'] as bool?) ?? false,
        '${j['peer']}',
        DateTime.fromMillisecondsSinceEpoch((j['time'] as num?)?.toInt() ?? 0),
        j['path'] as String?,
      );
}

enum StatusKind { info, success, error }

String fmtSize(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  if (b < 1024 * 1024 * 1024) return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

String fmtTime(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}.${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _page(String inner) => '''<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>$kAppName</title><style>
body{font-family:system-ui,sans-serif;margin:0;padding:24px;background:#f4f4fb;color:#1b1b2f}
@media(prefers-color-scheme:dark){body{background:#12121c;color:#eee}.card{background:#1d1d2b!important}}
.wrap{max-width:560px;margin:0 auto}
h1{font-size:22px}
.card{background:#fff;border-radius:16px;padding:14px 16px;margin:10px 0;display:flex;align-items:center;justify-content:space-between;gap:12px}
.name{overflow:hidden;text-overflow:ellipsis;white-space:nowrap;max-width:300px}
.size{opacity:.6;font-size:13px}
a.btn,button{background:#4f46e5;color:#fff;border:0;border-radius:20px;padding:8px 16px;text-decoration:none;font-size:14px;cursor:pointer}
input{padding:10px;border-radius:10px;border:1px solid #888;font-size:16px}
</style></head><body><div class="wrap">$inner</div></body></html>''';

// --------------------------------------------------------------- service

class DropService extends ChangeNotifier {
  final Settings cfg;
  DropService(this.cfg);

  final Map<String, Device> devices = {};
  final Set<String> myIps = {};
  final Map<String, _Session> _sessions = {};
  final List<HistoryItem> history = [];
  HttpServer? _server;
  Timer? _timer;
  IncomingRequest? pending;
  ShareSession? share;
  Timer? _shareTimer;
  String status = '';
  StatusKind kind = StatusKind.info;
  double? progress;
  bool scanning = false;
  bool serverUp = false;
  bool _disposed = false;

  String get alias => cfg.deviceName;

  List<String> get shareUrls {
    final s = share;
    if (s == null) return [];
    return [for (final ip in myIps) 'http://$ip:${cfg.port}/s/${s.token}'];
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _setStatus(String s, [StatusKind k = StatusKind.info]) {
    status = s;
    kind = k;
  }

  void clearStatus() {
    status = '';
    progress = null;
    _notify();
  }

  void _buzz() {
    if (cfg.haptics) HapticFeedback.mediumImpact();
  }

  Future<void> start() async {
    await _loadHistory();
    await _bind();
    myIps
      ..clear()
      ..addAll(await _localIps());
    _notify();
    await scan();
    reschedule();
  }

  void reschedule() {
    _timer?.cancel();
    _timer = null;
    if (!cfg.autoScan) return;
    _timer = Timer.periodic(Duration(seconds: cfg.scanSeconds), (_) => scan());
  }

  Future<void> _bind() async {
    try {
      await _server?.close(force: true);
      _server = await HttpServer.bind(InternetAddress.anyIPv4, cfg.port);
      _server!.listen(_handle, onError: (_) {});
      serverUp = true;
    } catch (e) {
      serverUp = false;
      _setStatus('Could not start server (port ${cfg.port}): $e', StatusKind.error);
    }
    _notify();
  }

  Future<void> restartServer() async {
    await _bind();
    devices.clear();
    await scan();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _shareTimer?.cancel();
    _server?.close(force: true);
    super.dispose();
  }

  Future<Set<String>> _localIps() async {
    final out = <String>{};
    try {
      for (final i in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
        for (final a in i.addresses) {
          if (a.isLoopback || a.address.startsWith('169.254.')) continue;
          out.add(a.address);
        }
      }
    } catch (_) {}
    return out;
  }

  // -------------------------------------------------------------- history

  Future<File> _historyFile() async {
    final d = await getApplicationSupportDirectory();
    await d.create(recursive: true);
    return File(p.join(d.path, 'history.json'));
  }

  Future<void> _loadHistory() async {
    try {
      final f = await _historyFile();
      if (!await f.exists()) return;
      final list = jsonDecode(await f.readAsString()) as List;
      history
        ..clear()
        ..addAll(list.map((e) => HistoryItem.fromJson(Map<String, dynamic>.from(e as Map))));
    } catch (_) {}
  }

  Future<void> _saveHistory() async {
    try {
      final f = await _historyFile();
      await f.writeAsString(jsonEncode(history.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  void _addHistory(HistoryItem h) {
    if (!cfg.keepHistory) return;
    history.insert(0, h);
    final lim = cfg.historyLimit;
    if (history.length > lim) history.removeRange(lim, history.length);
    _saveHistory();
  }

  void clearHistory() {
    history.clear();
    _saveHistory();
    _notify();
  }

  // ---------------------------------------------------------- server side

  Future<void> _json(HttpRequest req, int code, Object body) async {
    req.response.statusCode = code;
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode(body));
    await req.response.close();
  }

  Future<void> _html(HttpRequest req, int code, String body) async {
    req.response.statusCode = code;
    req.response.headers.contentType = ContentType.html;
    req.response.write(body);
    await req.response.close();
  }

  Future<void> _handle(HttpRequest req) async {
    try {
      final path = req.uri.path;
      final segs = req.uri.pathSegments;
      if (req.method == 'GET' && segs.isNotEmpty && segs[0] == 's') {
        await _onShare(req, segs);
      } else if (req.method == 'GET' && path == '/api/info') {
        if (!cfg.discoverable) {
          await _json(req, 403, {'error': 'hidden'});
          return;
        }
        await _json(req, 200, {
          'app': kAppId,
          'alias': alias,
          'platform': Platform.operatingSystem,
        });
      } else if (req.method == 'POST' && path == '/api/send-request') {
        await _onSendRequest(req);
      } else if (req.method == 'PUT' && path == '/api/upload') {
        await _onUpload(req);
      } else {
        await _json(req, 404, {'error': 'not found'});
      }
    } catch (e) {
      try {
        await _json(req, 500, {'error': '$e'});
      } catch (_) {}
    }
  }

  String _safeName(String name) {
    var n = p.basename(name).replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_');
    if (n.trim().isEmpty) n = 'file';
    return n;
  }

  Future<bool> _awaitDecision(IncomingRequest r) async {
    pending = r;
    _notify();
    final ok = await r.decision.future
        .timeout(Duration(seconds: cfg.requestTimeout), onTimeout: () => false);
    pending = null;
    _notify();
    return ok;
  }

  Future<void> _onSendRequest(HttpRequest req) async {
    final text = await utf8.decoder.bind(req).join();
    final body = jsonDecode(text) as Map<String, dynamic>;
    final files = (body['files'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (files.isEmpty) {
      await _json(req, 400, {'error': 'no files'});
      return;
    }
    if (pending != null) {
      await _json(req, 409, {'error': 'busy'});
      return;
    }
    final from = '${body['alias'] ?? req.connectionInfo?.remoteAddress.address}';
    final fromTrusted = cfg.autoAcceptTrusted && cfg.trusted.contains(from);
    final ok = (cfg.autoAccept || fromTrusted)
        ? true
        : await _awaitDecision(IncomingRequest(from, files));
    if (!ok) {
      await _json(req, 403, {'accepted': false});
      return;
    }
    final rnd = Random.secure();
    final sid = List.generate(16, (_) => rnd.nextInt(16).toRadixString(16)).join();
    _sessions[sid] = _Session(
      files.map((f) => _safeName('${f['name']}')).toList(),
      files.map((f) => (f['size'] as num?)?.toInt() ?? 0).toList(),
      from,
    );
    await _json(req, 200, {'accepted': true, 'sessionId': sid});
  }

  void resolve(IncomingRequest r, bool ok) {
    if (!r.decision.isCompleted) r.decision.complete(ok);
  }

  Future<Directory> defaultSaveDir() async {
    Directory? base;
    if (Platform.isAndroid) {
      final d = Directory('/storage/emulated/0/Download/$kAppName');
      try {
        await d.create(recursive: true);
        final t = File(p.join(d.path, '.write_test'));
        await t.writeAsString('x');
        await t.delete();
        return d;
      } catch (_) {}
      base = await getExternalStorageDirectory();
    } else {
      base = await getDownloadsDirectory();
    }
    base ??= await getApplicationDocumentsDirectory();
    final d = Directory(p.join(base.path, kAppName));
    await d.create(recursive: true);
    return d;
  }

  Future<Directory> _saveDir() async {
    if (cfg.saveDir.trim().isNotEmpty) {
      try {
        final d = Directory(cfg.saveDir.trim());
        await d.create(recursive: true);
        return d;
      } catch (_) {}
    }
    return defaultSaveDir();
  }

  Future<File> _uniqueFile(Directory dir, String name) async {
    var f = File(p.join(dir.path, name));
    if (cfg.overwrite) return f;
    final base = p.basenameWithoutExtension(name);
    final ext = p.extension(name);
    var i = 1;
    while (await f.exists()) {
      f = File(p.join(dir.path, '$base ($i)$ext'));
      i++;
    }
    return f;
  }

  Future<void> _onUpload(HttpRequest req) async {
    final sid = req.uri.queryParameters['sessionId'];
    final idx = int.tryParse(req.uri.queryParameters['index'] ?? '');
    final s = sid == null ? null : _sessions[sid];
    if (s == null || idx == null || idx < 0 || idx >= s.names.length) {
      await _json(req, 403, {'error': 'invalid session'});
      return;
    }
    var dir = await _saveDir();
    if (cfg.groupBySender) {
      dir = Directory(p.join(dir.path, _safeName(s.from)));
      await dir.create(recursive: true);
    }
    final target = await _uniqueFile(dir, s.names[idx]);
    final sink = target.openWrite();
    final total = s.sizes[idx];
    var got = 0;
    final sw = Stopwatch()..start();
    try {
      await for (final chunk in req) {
        sink.add(chunk);
        got += chunk.length;
        if (sw.elapsedMilliseconds > 100) {
          sw.reset();
          progress = total > 0 ? (got / total).clamp(0.0, 1.0) : null;
          _setStatus('Receiving from ${s.from}: ${p.basename(target.path)}');
          _notify();
        }
      }
      await sink.flush();
      await sink.close();
    } catch (e) {
      try {
        await sink.close();
      } catch (_) {}
      progress = null;
      _setStatus('Receive error: $e', StatusKind.error);
      _notify();
      rethrow;
    }
    s.done++;
    if (s.done >= s.names.length) _sessions.remove(sid);
    progress = null;
    _setStatus('Saved: ${target.path}', StatusKind.success);
    _buzz();
    _addHistory(HistoryItem(p.basename(target.path), got, false, s.from, DateTime.now(), target.path));
    _notify();
    await _json(req, 200, {'ok': true});
  }

  // ----------------------------------------------------------- link share

  Future<void> startShare(List<PlatformFile> files) async {
    try {
      final sizes = <int>[];
      for (final f in files) {
        final n = f.lengthSync() ?? await f.length();
        if (n == null) throw 'Could not read file size: ${f.name}';
        sizes.add(n);
      }
      final rnd = Random.secure();
      final token = List.generate(10, (_) => rnd.nextInt(16).toRadixString(16)).join();
      final pin = cfg.sharePin.trim();
      share = ShareSession(token, files, sizes, pin.isEmpty ? null : pin);
      _shareTimer?.cancel();
      if (cfg.shareMinutes > 0) {
        _shareTimer = Timer(Duration(minutes: cfg.shareMinutes), stopShare);
      }
      myIps
        ..clear()
        ..addAll(await _localIps());
    } catch (e) {
      _setStatus('Error: $e', StatusKind.error);
    }
    _notify();
  }

  void stopShare() {
    _shareTimer?.cancel();
    _shareTimer = null;
    share = null;
    _notify();
  }

  Future<void> _onShare(HttpRequest req, List<String> segs) async {
    final s = share;
    if (s == null || segs.length < 2 || segs[1] != s.token) {
      await _html(req, 404,
          _page('<h1>$kAppName</h1><p>This link is no longer active.</p>'));
      return;
    }
    final ip = req.connectionInfo?.remoteAddress.address ?? '';

    // Download a single file.
    if (segs.length == 4 && segs[2] == 'f') {
      final idx = int.tryParse(segs[3]);
      if (!s.allowed.contains(ip) || idx == null || idx < 0 || idx >= s.files.length) {
        await req.response.redirect(Uri(path: '/s/${s.token}'));
        return;
      }
      final f = s.files[idx];
      final len = s.sizes[idx];
      final out = req.response;
      out.statusCode = 200;
      out.headers.contentType = ContentType.binary;
      out.headers.contentLength = len;
      out.headers.set('content-disposition',
          "attachment; filename*=UTF-8''${Uri.encodeComponent(f.name)}");
      var sent = 0;
      final sw = Stopwatch()..start();
      try {
        await out.addStream(f.readAsByteStream().map((chunk) {
          sent += chunk.length;
          if (sw.elapsedMilliseconds > 100) {
            sw.reset();
            progress = len > 0 ? (sent / len).clamp(0.0, 1.0) : null;
            _setStatus('Sending ${f.name} to $ip');
            _notify();
          }
          return chunk;
        }));
        await out.close();
        s.downloads++;
        progress = null;
        _setStatus('${f.name} downloaded by $ip', StatusKind.success);
        _addHistory(HistoryItem(f.name, len, true, 'Browser ($ip)', DateTime.now(), null));
      } catch (e) {
        progress = null;
        _setStatus('Download interrupted: ${f.name}', StatusKind.error);
      }
      _notify();
      return;
    }

    // The file list page.
    if (!s.allowed.contains(ip)) {
      if (s.pin != null && !s.unlocked.contains(ip)) {
        final given = req.uri.queryParameters['pin'];
        if (given != null && given == s.pin) {
          s.unlocked.add(ip);
        } else {
          final wrong = given != null;
          await _html(
            req,
            wrong ? 401 : 200,
            _page('<h1>$kAppName</h1><p>${wrong ? 'Wrong PIN. Try again.' : 'Enter the PIN to continue.'}</p>'
                '<form method="get"><input name="pin" inputmode="numeric" autofocus> <button>Open</button></form>'),
          );
          return;
        }
      }
      if (cfg.askShare) {
        if (pending != null) {
          await _html(req, 409,
              _page('<h1>$kAppName</h1><p>The owner is busy with another request. Refresh in a moment.</p>'));
          return;
        }
        final r = IncomingRequest(
          'Browser ($ip)',
          [
            for (var i = 0; i < s.files.length; i++)
              {'name': s.files[i].name, 'size': s.sizes[i]}
          ],
          download: true,
        );
        final ok = await _awaitDecision(r);
        if (!ok) {
          await _html(req, 403,
              _page('<h1>$kAppName</h1><p>The owner declined your request.</p>'));
          return;
        }
      }
      s.allowed.add(ip);
    }

    final rows = StringBuffer();
    for (var i = 0; i < s.files.length; i++) {
      rows.write('<div class="card"><div><div class="name">${_esc(s.files[i].name)}</div>'
          '<div class="size">${fmtSize(s.sizes[i])}</div></div>'
          '<a class="btn" href="/s/${s.token}/f/$i">Download</a></div>');
    }
    await _html(req, 200,
        _page('<h1>${_esc(alias)} shared ${s.files.length} file${s.files.length == 1 ? '' : 's'}</h1>$rows'));
  }

  // ------------------------------------------------------------ discovery

  Future<Device?> _probe(String ip) async {
    final c = HttpClient()..connectionTimeout = const Duration(milliseconds: 600);
    try {
      final r = await c.getUrl(Uri.parse('http://$ip:${cfg.port}/api/info'));
      final resp = await r.close().timeout(const Duration(seconds: 2));
      final text = await utf8.decoder.bind(resp).join();
      final j = jsonDecode(text) as Map<String, dynamic>;
      if (j['app'] != kAppId && j['app'] != 'localdrop') return null;
      return Device('${j['alias']}', ip, '${j['platform'] ?? ''}');
    } catch (_) {
      return null;
    } finally {
      c.close(force: true);
    }
  }

  Future<void> scan() async {
    if (scanning) return;
    scanning = true;
    _notify();
    try {
      final ips = <String>{};
      final mine = <String>{};
      for (final i in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
        for (final a in i.addresses) {
          if (a.isLoopback || a.address.startsWith('169.254.')) continue;
          mine.add(a.address);
          final parts = a.address.split('.');
          if (parts.length != 4) continue;
          final prefix = parts.sublist(0, 3).join('.');
          for (var n = 1; n < 255; n++) {
            ips.add('$prefix.$n');
          }
        }
      }
      ips.removeAll(mine);
      myIps
        ..clear()
        ..addAll(mine);
      final list = ips.toList();
      final found = <String, Device>{};
      for (var i = 0; i < list.length; i += 64) {
        await Future.wait(list.skip(i).take(64).map((ip) async {
          final d = await _probe(ip);
          if (d != null) found[ip] = d;
        }));
        if (_disposed) return;
      }
      devices
        ..clear()
        ..addAll(found);
    } catch (e) {
      _setStatus('Scan error: $e', StatusKind.error);
    } finally {
      scanning = false;
      _notify();
    }
  }

  // ------------------------------------------------------------ client side

  Future<void> sendFiles(Device d, List<PlatformFile> files) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      _setStatus('Waiting for ${d.alias} to accept…');
      progress = null;
      _notify();
      final sizes = <int>[];
      for (final f in files) {
        final n = f.lengthSync() ?? await f.length();
        if (n == null) throw 'Could not read file size: ${f.name}';
        sizes.add(n);
      }
      final req = await client
          .postUrl(Uri.parse('http://${d.ip}:${cfg.port}/api/send-request'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'alias': alias,
        'files': [
          for (var i = 0; i < files.length; i++)
            {'name': files[i].name, 'size': sizes[i]}
        ],
      }));
      final resp = await req.close().timeout(const Duration(seconds: 150));
      final text = await utf8.decoder.bind(resp).join();
      if (resp.statusCode != 200) {
        _setStatus(
          resp.statusCode == 403
              ? 'The other device declined'
              : 'Error: ${resp.statusCode} $text',
          StatusKind.error,
        );
        return;
      }
      final sid = (jsonDecode(text) as Map)['sessionId'] as String;
      for (var i = 0; i < files.length; i++) {
        final f = files[i];
        final len = sizes[i];
        final up = await client.putUrl(Uri.parse(
            'http://${d.ip}:${cfg.port}/api/upload?sessionId=$sid&index=$i'));
        up.contentLength = len;
        var sent = 0;
        var lastPct = -1;
        await up.addStream(f.readAsByteStream().map((chunk) {
          sent += chunk.length;
          final pct = len > 0 ? (sent * 100 ~/ len) : 0;
          if (pct != lastPct) {
            lastPct = pct;
            progress = len > 0 ? sent / len : null;
            _setStatus('Sending (${i + 1}/${files.length}): ${f.name}');
            _notify();
          }
          return chunk;
        }));
        final r2 = await up.close();
        await r2.drain<void>();
        if (r2.statusCode != 200) throw 'Upload failed (${r2.statusCode})';
        _addHistory(HistoryItem(f.name, len, true, d.alias, DateTime.now(), null));
      }
      _setStatus(
          '${files.length} file${files.length == 1 ? '' : 's'} sent to ${d.alias}',
          StatusKind.success);
      _buzz();
    } catch (e) {
      _setStatus('Error: $e', StatusKind.error);
    } finally {
      progress = null;
      client.close(force: true);
      _notify();
    }
  }
}

// -------------------------------------------------------------------- UI

class LocalBridgeApp extends StatelessWidget {
  final Settings settings;
  const LocalBridgeApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final seed = kAccents[settings.accent];
        ThemeData theme(Brightness b) => ThemeData(
              colorSchemeSeed: seed,
              brightness: b,
              useMaterial3: true,
              scaffoldBackgroundColor:
                  (b == Brightness.dark && settings.amoled) ? Colors.black : null,
              appBarTheme: AppBarTheme(
                centerTitle: false,
                scrolledUnderElevation: 0,
                backgroundColor:
                    (b == Brightness.dark && settings.amoled) ? Colors.black : null,
              ),
              navigationBarTheme: NavigationBarThemeData(
                backgroundColor:
                    (b == Brightness.dark && settings.amoled) ? Colors.black : null,
              ),
            );
        return MaterialApp(
          title: kAppName,
          debugShowCheckedModeBanner: false,
          theme: theme(Brightness.light),
          darkTheme: theme(Brightness.dark),
          themeMode: settings.themeMode,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(settings.textScale)),
            child: child!,
          ),
          home: Shell(settings: settings),
        );
      },
    );
  }
}

class Shell extends StatefulWidget {
  final Settings settings;
  const Shell({super.key, required this.settings});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  late final DropService svc;
  bool _dialogOpen = false;
  int _tab = 0;
  int _lastPort = 0;
  int _lastScan = 0;
  bool _lastAutoScan = true;

  @override
  void initState() {
    super.initState();
    svc = DropService(widget.settings);
    _lastPort = widget.settings.port;
    _lastScan = widget.settings.scanSeconds;
    _lastAutoScan = widget.settings.autoScan;
    svc.addListener(_onChange);
    widget.settings.addListener(_onSettings);
    svc.start();
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettings);
    svc.removeListener(_onChange);
    svc.dispose();
    super.dispose();
  }

  void _onSettings() {
    final s = widget.settings;
    if (s.port != _lastPort) {
      _lastPort = s.port;
      svc.stopShare();
      svc.restartServer();
    }
    if (s.scanSeconds != _lastScan || s.autoScan != _lastAutoScan) {
      _lastScan = s.scanSeconds;
      _lastAutoScan = s.autoScan;
      svc.reschedule();
    }
    if (mounted) setState(() {});
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    final r = svc.pending;
    if (r != null && !_dialogOpen) {
      _dialogOpen = true;
      _showRequest(r);
    } else if (r == null && _dialogOpen) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _showRequest(IncomingRequest r) async {
    final total = r.files.fold<int>(0, (a, f) => a + ((f['size'] as num?)?.toInt() ?? 0));
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          icon: Icon(
              r.download ? Icons.link_rounded : Icons.download_for_offline_rounded,
              size: 36,
              color: cs.primary),
          title: Text(
            r.download
                ? '${r.from} wants to download your shared files'
                : '${r.from} wants to send you files',
            textAlign: TextAlign.center,
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${r.files.length} file${r.files.length == 1 ? '' : 's'} • ${fmtSize(total)}',
                    style: Theme.of(ctx).textTheme.labelLarge?.copyWith(color: cs.primary)),
                const SizedBox(height: 8),
                for (final f in r.files.take(8))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.insert_drive_file_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text('${f['name']}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Text(fmtSize((f['size'] as num?)?.toInt() ?? 0),
                            style: Theme.of(ctx).textTheme.bodySmall),
                      ],
                    ),
                  ),
                if (r.files.length > 8)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('… +${r.files.length - 8} more'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(false),
                child: const Text('Decline')),
            FilledButton(
                onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true),
                child: Text(r.download ? 'Allow' : 'Accept')),
          ],
        );
      },
    );
    _dialogOpen = false;
    svc.resolve(r, ok ?? false);
  }

  Future<void> _pickAndSend(Device d) async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return;
    svc.sendFiles(d, files);
  }

  Future<void> _pickAndShare() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return;
    await svc.startShare(files);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DevicesPage(svc: svc, onSend: _pickAndSend, onShare: _pickAndShare),
      HistoryPage(svc: svc),
      SettingsPage(settings: widget.settings, svc: svc),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _tab, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.radar_outlined),
              selectedIcon: Icon(Icons.radar),
              label: 'Devices'),
          NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'History'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings'),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ devices tab

class DevicesPage extends StatelessWidget {
  final DropService svc;
  final void Function(Device) onSend;
  final VoidCallback onShare;
  const DevicesPage({super.key, required this.svc, required this.onSend, required this.onShare});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final devs = svc.devices.values.toList();
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: Row(
            children: [
              Icon(Icons.swap_horiz_rounded, color: cs.primary),
              const SizedBox(width: 8),
              const Text(kAppName, style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Rescan',
              onPressed: svc.scanning ? null : () => svc.scan(),
              icon: const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(width: 4),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _Hero(svc: svc),
              if (svc.status.isNotEmpty || svc.progress != null) ...[
                const SizedBox(height: 12),
                _StatusCard(svc: svc),
              ],
              const SizedBox(height: 12),
              _ShareCard(svc: svc, onStart: onShare),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text('Nearby devices', style: tt.titleMedium),
                  const SizedBox(width: 8),
                  if (devs.isNotEmpty)
                    Badge(label: Text('${devs.length}'), backgroundColor: cs.primary),
                  const Spacer(),
                  if (svc.scanning)
                    Text('Scanning…', style: tt.labelMedium?.copyWith(color: cs.outline)),
                ],
              ),
              const SizedBox(height: 8),
              if (devs.isEmpty)
                _EmptyDevices(svc: svc)
              else
                for (final d in devs)
                  _DeviceTile(
                    device: d,
                    showIp: svc.cfg.showIps,
                    trusted: svc.cfg.trusted.contains(d.alias),
                    onTrust: () => svc.cfg.toggleTrusted(d.alias),
                    onTap: () => onSend(d),
                  ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatefulWidget {
  final DropService svc;
  const _Hero({required this.svc});

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final svc = widget.svc;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary, cs.tertiary],
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (!svc.cfg.compactHeader)
            SizedBox(
            height: 170,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(
                painter: _RadarPainter(
                    svc.scanning && svc.cfg.showRadar ? _c.value : 0.0,
                    cs.onPrimary,
                    svc.scanning && svc.cfg.showRadar),
                child: Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cs.onPrimary.withAlpha(235),
                    ),
                    child: Icon(
                      Platform.isAndroid || Platform.isIOS
                          ? Icons.smartphone_rounded
                          : Icons.laptop_rounded,
                      size: 36,
                      color: cs.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            svc.alias,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            svc.myIps.isEmpty
                ? 'No network found'
                : (svc.cfg.showIps ? svc.myIps.join(' • ') : 'IP address hidden'),
            style: TextStyle(color: cs.onPrimary.withAlpha(220)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _Pill(
                icon: svc.serverUp ? Icons.check_circle_rounded : Icons.error_rounded,
                text: svc.serverUp ? 'Ready to receive' : 'Server off',
                color: cs.onPrimary,
              ),
              _Pill(
                icon: svc.cfg.autoAccept ? Icons.bolt_rounded : Icons.shield_rounded,
                text: svc.cfg.autoAccept ? 'Auto-accept' : 'Ask first',
                color: cs.onPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _Pill({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double t;
  final Color color;
  final bool active;
  _RadarPainter(this.t, this.color, this.active);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = min(size.width, size.height) / 2 + 20;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withAlpha(50);
    for (final f in [0.45, 0.7, 0.95]) {
      canvas.drawCircle(c, maxR * f, base);
    }
    if (!active) return;
    for (var i = 0; i < 3; i++) {
      final pr = (t + i / 3) % 1.0;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withAlpha(((1 - pr) * 140).toInt());
      canvas.drawCircle(c, 36 + (maxR - 36) * pr, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.t != t || old.color != color || old.active != active;
}

class _StatusCard extends StatelessWidget {
  final DropService svc;
  const _StatusCard({required this.svc});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (Color bg, Color fg, IconData icon) = switch (svc.kind) {
      StatusKind.success => (cs.primaryContainer, cs.onPrimaryContainer, Icons.check_circle_rounded),
      StatusKind.error => (cs.errorContainer, cs.onErrorContainer, Icons.error_rounded),
      StatusKind.info => (cs.secondaryContainer, cs.onSecondaryContainer, Icons.sync_rounded),
    };
    final busy = svc.progress != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: fg),
              const SizedBox(width: 12),
              Expanded(child: Text(svc.status, style: TextStyle(color: fg))),
              if (!busy)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: svc.clearStatus,
                  icon: Icon(Icons.close_rounded, color: fg, size: 20),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text('${((svc.progress ?? 0) * 100).toStringAsFixed(0)}%',
                      style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          if (busy)
            Padding(
              padding: const EdgeInsets.only(top: 10, right: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: svc.progress, minHeight: 8),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  final DropService svc;
  final VoidCallback onStart;
  const _ShareCard({required this.svc, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final s = svc.share;
    final urls = svc.shareUrls;

    Widget body;
    if (s == null) {
      body = Row(
        children: [
          CircleAvatar(
            backgroundColor: cs.primaryContainer,
            child: Icon(Icons.link_rounded, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Share via link',
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text('Anyone on your Wi-Fi can download in a browser',
                    style: tt.bodySmall?.copyWith(color: cs.outline)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(onPressed: svc.serverUp ? onStart : null, child: const Text('Share')),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: cs.primary,
                child: Icon(Icons.link_rounded, color: cs.onPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sharing ${s.files.length} file${s.files.length == 1 ? '' : 's'}',
                        style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    Text(
                        '${s.downloads} download${s.downloads == 1 ? '' : 's'}'
                        '${s.pin != null ? ' • PIN: ${s.pin}' : ''}'
                        '${svc.cfg.askShare ? ' • approval required' : ''}'
                        '${svc.cfg.shareMinutes > 0 ? ' • stops after ${svc.cfg.shareMinutes} min' : ''}',
                        style: tt.bodySmall?.copyWith(color: cs.outline)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (urls.isEmpty)
            Text('No network found', style: TextStyle(color: cs.error))
          else
            for (final u in urls)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(child: SelectableText(u, style: tt.bodyMedium)),
                    IconButton(
                      tooltip: 'Copy link',
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: u));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Link copied')));
                      },
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: svc.stopShare,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Stop sharing'),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: body,
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final Device device;
  final VoidCallback onTap;
  final VoidCallback onTrust;
  final bool showIp;
  final bool trusted;
  const _DeviceTile({
    required this.device,
    required this.onTap,
    required this.onTrust,
    required this.showIp,
    required this.trusted,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHigh,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: cs.primaryContainer,
                child: Icon(
                  device.isPhone ? Icons.smartphone_rounded : Icons.computer_rounded,
                  color: cs.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.alias,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    Text(showIp ? device.ip : 'Hidden',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: cs.outline)),
                  ],
                ),
              ),
              IconButton(
                tooltip: trusted ? 'Trusted (tap to remove)' : 'Mark as trusted',
                icon: Icon(
                  trusted ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: trusted ? cs.primary : cs.outline,
                ),
                onPressed: onTrust,
              ),
              FilledButton.tonalIcon(
                onPressed: onTap,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Send'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDevices extends StatelessWidget {
  final DropService svc;
  const _EmptyDevices({required this.svc});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.wifi_find_rounded, size: 44, color: cs.outline),
          const SizedBox(height: 12),
          Text('No devices found', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Make sure $kAppName is open on the other device and both are on the same Wi-Fi. '
            'If Windows Firewall asks, allow "Private networks".',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.outline),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: svc.scanning ? null : svc.scan,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Scan again'),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ history tab

class HistoryPage extends StatelessWidget {
  final DropService svc;
  const HistoryPage({super.key, required this.svc});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = svc.history;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: const Text('History', style: TextStyle(fontWeight: FontWeight.w700)),
          actions: [
            if (items.isNotEmpty)
              IconButton(
                tooltip: 'Clear history',
                icon: const Icon(Icons.delete_sweep_rounded),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Clear history?'),
                      content: const Text('Files are not deleted, only the list is cleared.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel')),
                        FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Clear')),
                      ],
                    ),
                  );
                  if (ok == true) svc.clearHistory();
                },
              ),
          ],
        ),
        if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_toggle_off_rounded, size: 56, color: cs.outline),
                  const SizedBox(height: 12),
                  Text('No transfers yet', style: TextStyle(color: cs.outline)),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, i) {
                final h = items[i];
                return Card(
                  elevation: 0,
                  color: cs.surfaceContainerHigh,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    leading: CircleAvatar(
                      backgroundColor: h.sent ? cs.primaryContainer : cs.tertiaryContainer,
                      child: Icon(
                        h.sent ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        color: h.sent ? cs.onPrimaryContainer : cs.onTertiaryContainer,
                      ),
                    ),
                    title: Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        '${fmtSize(h.size)} • ${h.sent ? 'To' : 'From'}: ${h.peer} • ${fmtTime(h.time)}'),
                    onTap: h.path == null
                        ? null
                        : () => ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(h.path!)),
                            ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ----------------------------------------------------------- settings tab

class SettingsPage extends StatefulWidget {
  final Settings settings;
  final DropService svc;
  const SettingsPage({super.key, required this.settings, required this.svc});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Settings get s => widget.settings;
  String _defaultDir = '';

  @override
  void initState() {
    super.initState();
    widget.svc.defaultSaveDir().then((d) {
      if (mounted) setState(() => _defaultDir = d.path);
    });
  }

  Future<void> _openSaveFolder() async {
    try {
      final d = s.saveDir.trim().isNotEmpty
          ? Directory(s.saveDir.trim())
          : await widget.svc.defaultSaveDir();
      await d.create(recursive: true);
      if (Platform.isWindows) {
        await Process.run('explorer', [d.path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [d.path]);
      } else {
        await Process.run('xdg-open', [d.path]);
      }
    } catch (_) {}
  }

  Future<String?> _ask(String title, String initial,
      {String? hint, TextInputType? type}) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: type,
          decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => CustomScrollView(
        slivers: [
          const SliverAppBar(
            floating: true,
            title: Text('Settings', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _Section(title: 'Device', children: [
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('Device name'),
                    subtitle: Text(s.deviceName),
                    trailing: const Icon(Icons.edit_outlined, size: 20),
                    onTap: () async {
                      final v = await _ask('Device name', s.deviceName);
                      if (v != null && v.isNotEmpty) s.update(() => s.deviceName = v);
                    },
                  ),
                ]),
                _Section(title: 'Appearance', children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                            value: ThemeMode.system,
                            icon: Icon(Icons.brightness_auto_rounded),
                            label: Text('System')),
                        ButtonSegment(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode_rounded),
                            label: Text('Light')),
                        ButtonSegment(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode_rounded),
                            label: Text('Dark')),
                      ],
                      selected: {s.themeMode},
                      onSelectionChanged: (v) => s.update(() => s.themeMode = v.first),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (var i = 0; i < kAccents.length; i++)
                          GestureDetector(
                            onTap: () => s.update(() => s.accent = i),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: kAccents[i],
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: s.accent == i ? cs.onSurface : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              child: s.accent == i
                                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.contrast_rounded),
                    title: const Text('Pure black (AMOLED)'),
                    subtitle: const Text('True black background in dark mode'),
                    value: s.amoled,
                    onChanged: (v) => s.update(() => s.amoled = v),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.radar_rounded),
                    title: const Text('Radar animation'),
                    subtitle: const Text('Animate the header while scanning'),
                    value: s.showRadar,
                    onChanged: (v) => s.update(() => s.showRadar = v),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.view_compact_rounded),
                    title: const Text('Compact header'),
                    subtitle: const Text('Hide the big radar to fit more on screen'),
                    value: s.compactHeader,
                    onChanged: (v) => s.update(() => s.compactHeader = v),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.visibility_off_outlined),
                    title: const Text('Show IP addresses'),
                    subtitle: const Text('Turn off to hide IPs on screen (e.g. for screenshots)'),
                    value: s.showIps,
                    onChanged: (v) => s.update(() => s.showIps = v),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.vibration_rounded),
                    title: const Text('Haptic feedback'),
                    subtitle: const Text('Vibrate when a transfer finishes'),
                    value: s.haptics,
                    onChanged: (v) => s.update(() => s.haptics = v),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.format_size_rounded),
                          const SizedBox(width: 16),
                          Text('Text size: ${(s.textScale * 100).round()}%'),
                        ]),
                        Slider(
                          min: 0.8,
                          max: 1.4,
                          divisions: 12,
                          value: s.textScale.clamp(0.8, 1.4).toDouble(),
                          label: '${(s.textScale * 100).round()}%',
                          onChanged: (v) =>
                              s.update(() => s.textScale = double.parse(v.toStringAsFixed(2))),
                        ),
                      ],
                    ),
                  ),
                ]),
                _Section(title: 'Receive', children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.bolt_rounded),
                    title: const Text('Auto-accept'),
                    subtitle: const Text('Save incoming files without asking. Only enable on networks you trust.'),
                    value: s.autoAccept,
                    onChanged: (v) => s.update(() => s.autoAccept = v),
                  ),
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: const Text('Save folder'),
                    subtitle: Text(s.saveDir.isEmpty
                        ? (_defaultDir.isEmpty ? 'Default' : 'Default: $_defaultDir')
                        : s.saveDir),
                    trailing: s.saveDir.isEmpty
                        ? const Icon(Icons.edit_outlined, size: 20)
                        : IconButton(
                            tooltip: 'Reset to default',
                            icon: const Icon(Icons.restart_alt_rounded),
                            onPressed: () => s.update(() => s.saveDir = ''),
                          ),
                    onTap: () async {
                      final v = await _ask('Save folder', s.saveDir,
                          hint: Platform.isAndroid
                              ? '/storage/emulated/0/Download/MyFiles'
                              : r'C:\Users\you\Downloads\MyFiles');
                      if (v != null) s.update(() => s.saveDir = v);
                    },
                  ),
                  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
                    ListTile(
                      leading: const Icon(Icons.folder_open_rounded),
                      title: const Text('Open save folder'),
                      onTap: _openSaveFolder,
                    ),
                  SwitchListTile(
                    secondary: const Icon(Icons.folder_copy_outlined),
                    title: const Text('Group by sender'),
                    subtitle: const Text('Save files into a folder named after the sender'),
                    value: s.groupBySender,
                    onChanged: (v) => s.update(() => s.groupBySender = v),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.file_copy_outlined),
                    title: const Text('Overwrite existing files'),
                    subtitle: const Text('Off: keeps both and adds (1), (2)… to the name'),
                    value: s.overwrite,
                    onChanged: (v) => s.update(() => s.overwrite = v),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.star_outline_rounded),
                    title: const Text('Auto-accept from trusted devices'),
                    subtitle: const Text('Tap the star next to a device on the Devices tab to trust it'),
                    value: s.autoAcceptTrusted,
                    onChanged: (v) => s.update(() => s.autoAcceptTrusted = v),
                  ),
                  ListTile(
                    leading: const Icon(Icons.verified_user_outlined),
                    title: const Text('Trusted devices'),
                    subtitle: Text(s.trusted.isEmpty ? 'None yet' : s.trusted.join(', ')),
                    trailing: s.trusted.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear trusted devices',
                            icon: const Icon(Icons.clear_all_rounded),
                            onPressed: () => s.update(() => s.trusted.clear()),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.timer_outlined),
                          const SizedBox(width: 16),
                          Text('Request timeout: ${s.requestTimeout} s'),
                        ]),
                        Slider(
                          min: 15,
                          max: 120,
                          divisions: 21,
                          value: s.requestTimeout.toDouble().clamp(15.0, 120.0).toDouble(),
                          label: '${s.requestTimeout} s',
                          onChanged: (v) =>
                              s.update(() => s.requestTimeout = (v / 5).round() * 5),
                        ),
                      ],
                    ),
                  ),
                ]),
                _Section(title: 'Link sharing', children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.how_to_reg_outlined),
                    title: const Text('Ask before download'),
                    subtitle: const Text('Approve each browser before it can see your shared files'),
                    value: s.askShare,
                    onChanged: (v) => s.update(() => s.askShare = v),
                  ),
                  ListTile(
                    leading: const Icon(Icons.pin_outlined),
                    title: const Text('PIN'),
                    subtitle: Text(s.sharePin.isEmpty
                        ? 'Off (applies to new shares)'
                        : 'Enabled (applies to new shares)'),
                    trailing: s.sharePin.isEmpty
                        ? const Icon(Icons.edit_outlined, size: 20)
                        : IconButton(
                            tooltip: 'Remove PIN',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => s.update(() => s.sharePin = ''),
                          ),
                    onTap: () async {
                      final v = await _ask('Share PIN', s.sharePin,
                          hint: 'Leave empty to disable', type: TextInputType.number);
                      if (v != null) s.update(() => s.sharePin = v);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.timer_off_outlined),
                    title: const Text('Auto-stop sharing'),
                    subtitle: Text(s.shareMinutes == 0
                        ? 'Never (applies to new shares)'
                        : 'After ${s.shareMinutes} min (applies to new shares)'),
                    trailing: PopupMenuButton<int>(
                      initialValue: s.shareMinutes,
                      onSelected: (v) => s.update(() => s.shareMinutes = v),
                      itemBuilder: (_) => [
                        for (final m in [0, 5, 15, 30, 60, 180])
                          PopupMenuItem(value: m, child: Text(m == 0 ? 'Never' : '$m min')),
                      ],
                    ),
                  ),
                ]),
                _Section(title: 'Network', children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.podcasts_rounded),
                    title: const Text('Visible to other devices'),
                    subtitle: const Text('Off: others cannot find you in a scan, but you can still send'),
                    value: s.discoverable,
                    onChanged: (v) => s.update(() => s.discoverable = v),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.wifi_tethering_rounded),
                    title: const Text('Auto scan'),
                    subtitle: const Text('Look for devices periodically'),
                    value: s.autoScan,
                    onChanged: (v) => s.update(() => s.autoScan = v),
                  ),
                  if (s.autoScan)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Scan interval: ${s.scanSeconds} s'),
                          Slider(
                            min: 3,
                            max: 60,
                            divisions: 57,
                            value: s.scanSeconds.toDouble().clamp(3.0, 60.0).toDouble(),
                            label: '${s.scanSeconds} s',
                            onChanged: (v) => s.update(() => s.scanSeconds = v.round()),
                          ),
                        ],
                      ),
                    ),
                  ListTile(
                    leading: const Icon(Icons.lan_outlined),
                    title: const Text('Port'),
                    subtitle: Text('${s.port} (must match on both devices)'),
                    trailing: const Icon(Icons.edit_outlined, size: 20),
                    onTap: () async {
                      final v = await _ask('Port', '${s.port}', type: TextInputType.number);
                      final n = int.tryParse(v ?? '');
                      if (n != null && n >= 1024 && n <= 65535) {
                        s.update(() => s.port = n);
                      } else if (v != null && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Port must be between 1024 and 65535')),
                        );
                      }
                    },
                  ),
                ]),
                _Section(title: 'History', children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.history_rounded),
                    title: const Text('Save history'),
                    value: s.keepHistory,
                    onChanged: (v) => s.update(() => s.keepHistory = v),
                  ),
                  ListTile(
                    leading: const Icon(Icons.format_list_numbered_rounded),
                    title: const Text('History size'),
                    subtitle: Text('Keep the last ${s.historyLimit} transfers'),
                    trailing: PopupMenuButton<int>(
                      initialValue: s.historyLimit,
                      onSelected: (v) => s.update(() => s.historyLimit = v),
                      itemBuilder: (_) => [
                        for (final n in [50, 100, 200, 500])
                          PopupMenuItem(value: n, child: Text('$n')),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded),
                    title: const Text('Clear history'),
                    onTap: () {
                      widget.svc.clearHistory();
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('History cleared')));
                    },
                  ),
                ]),
                _Section(title: 'About', children: [
                  const ListTile(
                    leading: Icon(Icons.swap_horiz_rounded),
                    title: Text(kAppName),
                    subtitle: Text('Version $kVersion'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.new_releases_outlined),
                    title: const Text("What's new"),
                    subtitle: Text('Update $kVersion — ${kChangelog.first.$2}'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => showChangelog(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.restore_rounded),
                    title: const Text('Reset settings'),
                    onTap: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Reset all settings?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel')),
                            FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Reset')),
                          ],
                        ),
                      );
                      if (ok == true) s.reset();
                    },
                  ),
                ]),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: cs.primary,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            color: cs.surfaceContainerHigh,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- changelog

void showChangelog(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      final tt = Theme.of(ctx).textTheme;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (ctx, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            Text("What's new", style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            for (var i = 0; i < kChangelog.length; i++) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: i == 0 ? cs.primary : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Update ${kChangelog[i].$1}',
                      style: TextStyle(
                        color: i == 0 ? cs.onPrimary : cs.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(kChangelog[i].$2,
                        style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  if (i == 0)
                    Text('Current', style: tt.labelMedium?.copyWith(color: cs.primary)),
                ],
              ),
              const SizedBox(height: 8),
              for (final line in kChangelog[i].$3)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Icon(Icons.check_circle_outline_rounded, size: 16, color: cs.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(line)),
                    ],
                  ),
                ),
              if (i != kChangelog.length - 1) const Divider(height: 28),
            ],
          ],
        ),
      );
    },
  );
}
