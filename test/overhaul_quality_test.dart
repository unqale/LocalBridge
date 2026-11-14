import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localbridge/localization/extra_strings.dart';
import 'package:localbridge/main.dart';
import 'package:qr_flutter/qr_flutter.dart';

final class _QrTestPlatformFile extends PlatformFile {
  @override
  String get name => 'qr-share.txt';
  @override
  Uri get uri => Uri.dataFromString('qr-payload');
  @override
  Never get xFile => throw UnsupportedError('xFile is unused');
  @override
  int lengthSync() => 10;
  @override
  Future<int> length() async => 10;
  @override
  Future<Uint8List> readAsBytes() async =>
      Uint8List.fromList(utf8.encode('qr-payload'));
  @override
  Stream<Uint8List> readAsByteStream() async* {
    yield await readAsBytes();
  }
}

Future<int> _freePort() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = server.port;
  await server.close();
  return port;
}

Future<T> _waitFor<T>(T? Function() value) async {
  final timeout = Stopwatch()..start();
  while (timeout.elapsed < const Duration(seconds: 8)) {
    final result = value();
    if (result != null) return result;
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
  throw StateError('Timed out waiting for condition');
}

Future<void> _safeDeleteDir(Directory dir) async {
  for (var i = 0; i < 5; i++) {
    try {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      return;
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
  }
}

void main() {
  test('Browser share approval is scoped to its cookie and one-time downloads', () async {
    HttpOverrides.global = null;
    final directory = await Directory.systemTemp.createTemp('lb-browser-share-');
    addTearDown(() => _safeDeleteDir(directory));
    final port = await _freePort();
    final service = DropService(
      Settings()
        ..port = port
        ..autoScan = false
        ..haptics = false
        ..keepHistory = false
        ..askShare = false
        ..sharePin = '2048'
        ..oneTimeDownload = true,
      storageDirectory: directory,
    );
    addTearDown(service.dispose);
    unawaited(service.start());
    await _waitFor(() => service.serverUp ? true : null);
    await service.startShare([_QrTestPlatformFile()]);
    final url = Uri.parse('http://127.0.0.1:$port/s/${service.share!.token}');
    final file = url.replace(path: '${url.path}/f/0');
    final client = HttpClient();
    addTearDown(() => client.close(force: true));

    final unlock = await client.postUrl(url);
    unlock.followRedirects = false;
    unlock.write('pin=2048');
    final approved = await unlock.close();
    expect(approved.statusCode, 303);
    final browserCookie = approved.cookies.single;
    await approved.drain<void>();

    final otherBrowser = await client.getUrl(file);
    otherBrowser.followRedirects = false;
    final blocked = await otherBrowser.close();
    expect(blocked.statusCode, 302);
    await blocked.drain<void>();

    final authorized = await client.getUrl(file);
    authorized.cookies.add(browserCookie);
    final download = await authorized.close();
    expect(download.statusCode, 200);
    expect(await utf8.decoder.bind(download).join(), 'qr-payload');
    await _waitFor(() => service.share == null ? true : null);
  });

  group('FileStagingController & FileStagingModal', () {
    test('manages staged files, deduplicates, computes totals, and preserves state on failure', () {
      final ctrl = FileStagingController();
      final imgSmall = StagedFileItem(
        id: 'f1',
        name: 'photo.png',
        size: 1024 * 100,
        path: '/tmp/photo.png',
        streamFactory: () => const Stream.empty(),
      );
      final imgHuge = StagedFileItem(
        id: 'f2',
        name: 'raw_4k.jpg',
        size: 30 * 1024 * 1024, // > 25 MB
        path: '/tmp/raw_4k.jpg',
        streamFactory: () => const Stream.empty(),
      );
      final docFile = StagedFileItem(
        id: 'f3',
        name: 'report.pdf',
        size: 2048,
        streamFactory: () => const Stream.empty(),
      );

      expect(imgSmall.category, StagedFileCategory.image);
      expect(imgSmall.canPreviewThumbnail, isTrue);
      expect(imgHuge.category, StagedFileCategory.image);
      expect(imgHuge.canPreviewThumbnail, isFalse);
      expect(docFile.category, StagedFileCategory.document);

      expect(ctrl.addFiles([imgSmall, docFile]), 2);
      // Duplicate ID should not be added again
      expect(ctrl.addFiles([imgSmall]), 0);
      expect(ctrl.totalCount, 2);
      expect(ctrl.totalBytes, 1024 * 100 + 2048);

      ctrl.setTarget(key: '192.168.1.20:53317', alias: 'Pixel 9', ip: '192.168.1.20');
      expect(ctrl.targetAlias, 'Pixel 9');

      // Simulate transfer start -> progress -> failure (must keep files staged for retry)
      ctrl.beginTransfer();
      expect(ctrl.isTransferring, isTrue);
      ctrl.updateProgress(currentFileIndex: 1, sentFilesCount: 1);
      expect(ctrl.sentFilesCount, 1);
      expect(ctrl.remainingFilesCount, 1);

      ctrl.failTransfer('Network disconnected');
      expect(ctrl.isTransferring, isFalse);
      expect(ctrl.lastError, 'Network disconnected');
      expect(ctrl.totalCount, 2);

      // Remove one file and complete transfer
      ctrl.removeAt(0);
      expect(ctrl.totalCount, 1);
      expect(ctrl.items.single.name, 'report.pdf');

      ctrl.completeTransferSuccess();
      expect(ctrl.isEmpty, isTrue);
      expect(ctrl.lastError, isNull);
    });

    testWidgets('FileStagingModal renders desktop and mobile layouts and supports actions',
        (tester) async {
      final ctrl = FileStagingController();
      ctrl.addFiles([
        StagedFileItem(
          id: '1',
          name: 'presentation.pptx',
          size: 4096,
          streamFactory: () => const Stream.empty(),
        ),
        StagedFileItem(
          id: '2',
          name: 'archive.zip',
          size: 8192,
          streamFactory: () => const Stream.empty(),
        ),
      ]);
      ctrl.setTarget(key: '192.168.1.10:53317', alias: 'Studio PC', ip: '192.168.1.10');

      var sendTriggered = false;
      final settings = Settings();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: FileStagingModal(
              controller: ctrl,
              targetOptions: const [
                StagedTargetOption(
                  key: '192.168.1.10:53317',
                  alias: 'Studio PC',
                  subtitle: '192.168.1.10',
                  isTrusted: true,
                ),
              ],
              tr: settings.tr,
              formatBytes: fmtSize,
              onAddMoreFiles: () async {},
              onStartSend: () async {
                sendTriggered = true;
              },
              isDesktopLayout: false,
            ),
          ),
        ),
      );

      expect(find.text('presentation.pptx'), findsOneWidget);
      expect(find.text('archive.zip'), findsOneWidget);
      expect(find.text('Studio PC'), findsWidgets);

      // Remove first file via remove button
      await tester.tap(find.byTooltip(settings.tr('stageRemoveFile')).first);
      await tester.pump();
      expect(ctrl.totalCount, 1);
      expect(find.text('presentation.pptx'), findsNothing);

      // Trigger send button
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      expect(sendTriggered, isTrue);
    });
  });

  group('File Transfer Integrity & Atomic Protection', () {
    setUp(() {
      HttpOverrides.global = null;
    });
    test('rejects truncated upload, cleans up .lbpart file, and never overwrites existing file',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('lb-integrity-test-');
      addTearDown(() => _safeDeleteDir(tempDir));

      final existingTarget = File('${tempDir.path}/important.txt');
      await existingTarget.writeAsString('ORIGINAL_SAFE_CONTENT');

      final port = await _freePort();
      final receiver = DropService(
        Settings()
          ..deviceName = 'SafeReceiver'
          ..port = port
          ..autoAccept = true
          ..overwrite = true
          ..haptics = false
          ..autoScan = false
          ..saveDir = tempDir.path,
        storageDirectory: Directory('${tempDir.path}/storage'),
      );
      addTearDown(receiver.dispose);
      unawaited(receiver.start());
      await _waitFor(() => receiver.serverUp ? true : null);

      final client = HttpClient();
      addTearDown(() => client.close(force: true));

      // 1) Request session for a 100-byte file named important.txt
      final req = await client.postUrl(Uri.parse('http://127.0.0.1:$port/api/send-request'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'alias': 'SenderPC',
        'files': [
          {'name': 'important.txt', 'size': 100}
        ],
      }));
      final resp = await req.close();
      expect(resp.statusCode, 200);
      final body = jsonDecode(await utf8.decoder.bind(resp).join()) as Map<String, dynamic>;
      final sid = body['sessionId'] as String;

      // 2) Upload only 12 bytes instead of 100 bytes (simulating interrupted stream)
      final up = await client.putUrl(
        Uri.parse('http://127.0.0.1:$port/api/upload?sessionId=$sid&index=0'),
      );
      up.add(utf8.encode('partial_data'));
      final upResp = await up.close();
      expect(upResp.statusCode, 400);
      await upResp.drain<void>();

      // Verify original file was NOT overwritten and no .lbpart files remain
      expect(await existingTarget.readAsString(), 'ORIGINAL_SAFE_CONTENT');
      final partFiles = tempDir
          .listSync()
          .where((e) => e.path.endsWith('.lbpart'))
          .toList();
      expect(partFiles, isEmpty);
      expect(receiver.history.first.status, 'failed');
    });

    test('verifies FNV-1a checksum on staged file transfer and rejects corrupted payload',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('lb-checksum-test-');
      addTearDown(() => _safeDeleteDir(tempDir));

      final port = await _freePort();
      final receiver = DropService(
        Settings()
          ..deviceName = 'ChecksumReceiver'
          ..port = port
          ..autoAccept = true
          ..haptics = false
          ..autoScan = false
          ..saveDir = tempDir.path,
        storageDirectory: Directory('${tempDir.path}/storage'),
      );
      addTearDown(receiver.dispose);
      unawaited(receiver.start());
      await _waitFor(() => receiver.serverUp ? true : null);

      final client = HttpClient();
      addTearDown(() => client.close(force: true));

      // Request session for 5-byte file
      final req = await client.postUrl(Uri.parse('http://127.0.0.1:$port/api/send-request'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'alias': 'SenderPC',
        'files': [
          {'name': 'corrupted.bin', 'size': 5}
        ],
      }));
      final resp = await req.close();
      final sid = (jsonDecode(await utf8.decoder.bind(resp).join()) as Map)['sessionId'];

      // Send 5 bytes with a wrong x-lb-fnv32 checksum header
      final up = await client.putUrl(
        Uri.parse('http://127.0.0.1:$port/api/upload?sessionId=$sid&index=0'),
      );
      up.headers.set('x-lb-fnv32', 'deadbeef');
      up.add(utf8.encode('hello'));
      final upResp = await up.close();
      expect(upResp.statusCode, 400);
      await upResp.drain<void>();
      expect(await File('${tempDir.path}/corrupted.bin').exists(), isFalse);
    });
  });

  group('Trusted Device Verification & Anti-Spoofing', () {
    setUp(() {
      HttpOverrides.global = null;
    });
    test('does not auto-accept unverified alias spoofing from unknown IP', () async {
      final tempDir = await Directory.systemTemp.createTemp('lb-trust-test-');
      addTearDown(() => _safeDeleteDir(tempDir));

      final port = await _freePort();
      final settings = Settings()
        ..deviceName = 'SecureHost'
        ..port = port
        ..autoAccept = false
        ..autoAcceptTrusted = true
        ..haptics = false
        ..autoScan = false
        ..saveDir = tempDir.path;

      // Trust a specific device at 192.168.1.99
      final trustedPeer = Device('BossLaptop', '192.168.1.99', 'windows', deskId: 'BOSS1234');
      settings.toggleTrustedDevice(trustedPeer);
      expect(settings.isDeviceTrusted(trustedPeer), isTrue);

      final receiver = DropService(
        settings,
        storageDirectory: Directory('${tempDir.path}/storage'),
      );
      addTearDown(receiver.dispose);
      unawaited(receiver.start());
      await _waitFor(() => receiver.serverUp ? true : null);

      final client = HttpClient();
      addTearDown(() => client.close(force: true));

      // Connect from 127.0.0.1 (different IP, not in receiver.devices) claiming alias 'BossLaptop'
      final reqFuture = () async {
        final req = await client.postUrl(Uri.parse('http://127.0.0.1:$port/api/send-request'));
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({
          'alias': 'BossLaptop',
          'files': [
            {'name': 'payload.exe', 'size': 10}
          ],
        }));
        final resp = await req.close();
        return resp.statusCode;
      }();

      // Must pause for manual user confirmation with unverifiedTrustClaim = true!
      final pendingReq = await _waitFor(() => receiver.pending);
      expect(pendingReq.from, 'BossLaptop');
      expect(pendingReq.unverifiedTrustClaim, isTrue);
      receiver.resolve(pendingReq, false);
      expect(await reqFuture, 403);
    });
  });

  group('Local QR Code, History Search, and 6-Language Localization', () {
    testWidgets('HistoryPage filters by search query and warns when file is missing on disk',
        (tester) async {
      final settings = Settings();
      final svc = DropService(settings);
      addTearDown(svc.dispose);

      svc.history.addAll([
        HistoryItem(
          'invoice_2026.pdf',
          12400,
          true,
          'Accounting PC',
          DateTime(2026, 5, 1, 14, 30),
          '/nonexistent/path/invoice_2026.pdf',
        ),
        HistoryItem(
          'vacation_clip.mp4',
          980000,
          false,
          'Galaxy S25',
          DateTime(2026, 5, 1, 15, 0),
          null,
        ),
      ]);

      tester.view.physicalSize = const Size(1100, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(body: HistoryPage(svc: svc)),
        ),
      );
      await tester.pump();

      expect(find.text('invoice_2026.pdf'), findsOneWidget);
      expect(find.text('vacation_clip.mp4'), findsOneWidget);

      // Filter by search text
      await tester.enterText(find.byType(TextField), 'Galaxy');
      await tester.pump();
      expect(find.text('invoice_2026.pdf'), findsNothing);
      expect(find.text('vacation_clip.mp4'), findsOneWidget);

      // Clear search and tap folder icon on missing file
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.folder_open_rounded).first);
      await tester.pumpAndSettle();
      expect(find.text(settings.tr('historyFileMissing')), findsOneWidget);
    });

    testWidgets('Share via Link renders local QrImageView without network image dependency',
        (tester) async {
      final settings = Settings()
        ..showQr = true
        ..autoScan = false;
      final svc = DropService(settings);
      addTearDown(svc.dispose);
      svc.myIps
        ..clear()
        ..add('192.168.1.42');
      svc.share = ShareSession('tok123456', [_QrTestPlatformFile()], [10], null);

      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: DevicesPage(
              svc: svc,
              onSend: (_) {},
              onShare: () {},
              onChat: (_) {},
              onConnect: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(QrImageView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('All 6 supported languages provide complete translations for extra and core keys', () {
      for (final lang in AppLang.values) {
        final s = Settings()..language = lang;
        for (final key in kExtraLocalizedStrings['en']!.keys) {
          final val = s.tr(key);
          expect(val.trim(), isNotEmpty, reason: 'Missing translation for $key in ${lang.name}');
          expect(val, isNot(equals(key)), reason: 'Untranslated key $key in ${lang.name}');
        }
      }
    });
  });

  group('Editorial Atelier Design System & 120Hz Telemetry', () {
    test('EditorialPalette derives Warm Dark, Paper Light, and True AMOLED tokens', () {
      const seed = Color(0xFFE06D53);
      final dark = EditorialPalette.fromSettings(
        brightness: Brightness.dark,
        accent: seed,
        amoled: false,
      );
      final light = EditorialPalette.fromSettings(
        brightness: Brightness.light,
        accent: seed,
        amoled: false,
      );
      final amoled = EditorialPalette.fromSettings(
        brightness: Brightness.dark,
        accent: seed,
        amoled: true,
      );

      expect(dark.isDark, isTrue);
      expect(dark.canvas, const Color(0xFF070814));
      expect(light.isDark, isFalse);
      expect(light.canvas, const Color(0xFFF5F2EB));
      expect(amoled.isAmoled, isTrue);
      expect(amoled.canvas, const Color(0xFF000000));
      expect(dark.secondaryAccent, isNot(equals(seed)));
      expect(dark.warmHighlight, isNot(equals(seed)));
    });

    test('classifyEditorialFile and FrameTimingSnapshot evaluate categories and 120Hz budget', () {
      expect(classifyEditorialFile('photo.webp'), EditorialFileKind.image);
      expect(classifyEditorialFile('clip.mp4'), EditorialFileKind.video);
      expect(classifyEditorialFile('song.flac'), EditorialFileKind.audio);
      expect(classifyEditorialFile('bundle.tar.gz'), EditorialFileKind.archive);
      expect(classifyEditorialFile('thesis.pdf'), EditorialFileKind.document);
      expect(classifyEditorialFile('main.dart'), EditorialFileKind.code);

      const fastSnap = FrameTimingSnapshot(
        avgUiMs: 2.1,
        avgRasterMs: 2.4,
        p95TotalMs: 5.8,
        sampleCount: 60,
        hz120BudgetPassRate: 98.0,
      );
      expect(fastSnap.avgTotalMs, closeTo(4.5, 0.01));
      expect(fastSnap.is120HzReady, isTrue);
    });
  });
}
