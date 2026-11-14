import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localbridge/main.dart';

class _RadarTestService extends DropService {
  _RadarTestService() : super(Settings());

  @override
  Future<void> scan({bool full = true, bool auto = false}) async {
    scanning = true;
    notifyListeners();
  }

  void finishScan() {
    scanning = false;
    notifyListeners();
  }
}

class _ChatTestService extends DropService {
  _ChatTestService() : super(Settings());
  final approval = Completer<({Device? device, String? error})>();
  String? sentText;

  @override
  Future<({Device? device, String? error})> connectChat(Device device) =>
      approval.future;

  @override
  Future<bool> sendChatMessage(Device? target, String text) async {
    sentText = text;
    return true;
  }
}

void main() {
  testWidgets('Startup covers the app and uses undecorated text', (tester) async {
    final settings = Settings()..startOnline = false;
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(LocalBridgeApp(settings: settings));
    await tester.pump();

    final splash = find.byKey(const ValueKey('launch-screen'));
    expect(tester.getSize(splash), const Size(800, 600));
    expect(tester.widget<Material>(splash).color!.a, 1);
    for (final label in [kAppName, 'v$kVersion']) {
      final text = find.descendant(of: splash, matching: find.text(label));
      expect(tester.widget<Text>(text).style!.decoration, TextDecoration.none);
    }
    expect(find.byType(DevicesPage), findsNothing);
    await tester.pump(const Duration(milliseconds: 1650));
    expect(splash, findsOneWidget);
    expect(find.byType(DevicesPage), findsNothing);
    await tester.pump(const Duration(milliseconds: 120));
    expect(splash, findsNothing);
    expect(find.byType(DevicesPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Startup skips animation when reduced motion is enabled', (tester) async {
    final settings = Settings()..startOnline = false;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(LocalBridgeApp(settings: settings));
    expect(find.byKey(const ValueKey('launch-screen')), findsNothing);
    expect(find.byType(DevicesPage), findsOneWidget);
  });

  testWidgets('Background light follows the mouse and responds to settings',
      (tester) async {
    final settings = Settings()
      ..bootAnim = 0
      ..startOnline = false;
    await tester.pumpWidget(LocalBridgeApp(settings: settings));
    await tester.pump(const Duration(milliseconds: 300));

    final backgroundLight = find.byWidgetPredicate(
      (widget) => widget is Flow && widget.clipBehavior == Clip.hardEdge,
    );
    final light = find.descendant(
      of: backgroundLight,
      matching: find.byType(DecoratedBox),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(220, 200));
    await tester.pump();
    expect(tester.getCenter(light), const Offset(220, 200));
    await mouse.moveTo(const Offset(330, 280));
    await tester.pump();
    expect(tester.getCenter(light), const Offset(330, 280));

    settings.update(() => settings.mouseGlow = false);
    await tester.pump();
    expect(backgroundLight, findsNothing);
    await mouse.removePointer();
  });

  testWidgets('Desktop sidebar responds to press and keeps the selected state',
      (tester) async {
    final settings = Settings()
      ..bootAnim = 0
      ..startOnline = false;
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(LocalBridgeApp(settings: settings));
    await tester.pump(const Duration(milliseconds: 300));

    final sidebar = find.byKey(const ValueKey('desktop-sidebar'));
    final label = find.descendant(of: sidebar, matching: find.text('History'));
    final slide = find.ancestor(of: label, matching: find.byType(AnimatedSlide));
    final selected = find.ancestor(
      of: label,
      matching: find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.selected == true,
      ),
    );
    expect(selected, findsNothing);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(label));
    await tester.pump();
    expect(tester.widget<AnimatedSlide>(slide).offset.dx, greaterThan(0));
    await mouse.moveTo(const Offset(400, 70));
    await tester.pump();
    expect(tester.widget<AnimatedSlide>(slide).offset, Offset.zero);
    expect(tester.widget<AnimatedSlide>(slide).duration, const Duration(milliseconds: 240));
    await mouse.moveTo(tester.getCenter(label));
    await tester.pump();
    await mouse.down(tester.getCenter(label));
    await tester.pump(const Duration(milliseconds: 75));
    expect(tester.widget<AnimatedSlide>(slide).offset.dx, greaterThan(0));
    await mouse.up();
    await tester.pump(const Duration(milliseconds: 170));
    expect(tester.widget<AnimatedSlide>(slide).offset, Offset.zero);
    expect(selected, findsOneWidget);
    expect(find.text('No transfers yet'), findsOneWidget);
    await mouse.removePointer();
  });

  testWidgets('Release notes show the current Beta and the separate 3.0.5 entry',
      (tester) async {
    final settings = Settings()..language = AppLang.turkish;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return TextButton(
            onPressed: () => showChangelog(context, settings),
            child: const Text('Open changelog'),
          );
        }),
      ),
    ));
    await tester.tap(find.text('Open changelog'));
    await tester.pumpAndSettle();

    expect(find.text('Güncelleme 3.0.6 Beta'), findsOneWidget);
    expect(find.textContaining('Tarayıcı paylaşımı için QR kodu'), findsOneWidget);
    final previous = find.text('Güncelleme 3.0.5');
    await tester.scrollUntilVisible(previous, 250, scrollable: find.byType(Scrollable).last);
    await tester.tap(previous);
    await tester.pumpAndSettle();
    expect(find.textContaining('mevcut çözünürlükteki en yüksek yenileme'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Main pages fit a short Windows window at increased text size',
      (tester) async {
    final settings = Settings()
      ..bootAnim = 0
      ..startOnline = false
      ..textScale = 1.4;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final size in [const Size(800, 600), const Size(1024, 600)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(LocalBridgeApp(settings: settings, key: ValueKey(size)));
      await tester.pump(const Duration(milliseconds: 300));
      for (final name in ['Global Connect', 'Global Transfer', 'Bridge Chat', 'History', 'Settings']) {
        final label = find.text(name).hitTestable().first;
        await tester.tap(label);
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: '$size $name');
      }
    }
  });

  testWidgets('Language changes the navigation and Desk Code card', (tester) async {
    final settings = Settings()
      ..bootAnim = 0
      ..startOnline = false;
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(LocalBridgeApp(settings: settings));
    await tester.pump(const Duration(milliseconds: 300));
    for (final (lang, nav, code) in [
      (AppLang.german, 'Geräte', 'Dein Desk Code'),
      (AppLang.spanish, 'Dispositivos', 'Tu Desk Code'),
      (AppLang.french, 'Appareils', 'Votre Desk Code'),
    ]) {
      settings.update(() => settings.language = lang);
      await tester.pump();
      expect(find.text(nav), findsWidgets);
      expect(find.text(code), findsWidgets);
    }
  });

  testWidgets('Radar selects a real device and sends actions to that device', (tester) async {
    final service = _RadarTestService();
    final device = Device('Studio laptop', '192.168.1.28', 'windows');
    service.devices[service.addressOf(device)] = device;
    Device? chatTarget;
    Device? fileTarget;
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(service.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListenableBuilder(
          listenable: service,
          builder: (context, _) => DevicesPage(
            svc: service,
            onSend: (target) => fileTarget = target,
            onChat: (target) => chatTarget = target,
            onShare: () {},
            onConnect: (_) {},
          ),
        ),
      ),
    ));
    final sweep = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is RadarSweepPainter,
    );
    expect(sweep, findsNothing);
    expect(find.text('1 active device(s) on radar'), findsOneWidget);
    await tester.tap(find.byTooltip(service.cfg.tr('scan')).first);
    await tester.pump();
    expect(sweep, findsOneWidget);
    final painter = tester.widget<CustomPaint>(sweep).painter! as RadarSweepPainter;
    final start = painter.phase.value;
    await tester.pump(const Duration(milliseconds: 250));
    expect(painter.phase.value, greaterThan(start));
    expect(tester.widget<CustomPaint>(sweep).painter, same(painter));
    service.finishScan();
    await tester.pump();
    expect(sweep, findsNothing);

    await tester.tap(find.byTooltip('Studio laptop'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Bridge Chat'));
    await tester.tap(find.byKey(const ValueKey('radar-send')));
    expect(chatTarget, same(device));
    expect(fileTarget, same(device));
    await tester.tap(find.byTooltip('Studio laptop'));
    await tester.pump();
    expect(find.byKey(const ValueKey('radar-send')), findsNothing);
  });

  testWidgets('Nearby chat accepts a draft and sends after approval', (tester) async {
    final svc = _ChatTestService();
    final device = Device('Android', '192.168.0.8', 'android');
    final address = svc.addressOf(device);
    svc.devices[address] = device;
    addTearDown(svc.dispose);
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BridgeChatPage(
          svc: svc, address: address, onTargetChanged: (_) {}, onSendFiles: (_) {},
        ),
      ),
    ));
    final input = find.byType(TextField);
    expect(input.hitTestable(), findsOneWidget);
    await tester.enterText(input, 'Hello Android');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(find.text(svc.cfg.tr('chatApprovalPending')), findsOneWidget);
    expect(svc.sentText, isNull);
    svc.approval.complete((device: device, error: null));
    await tester.pump();
    expect(svc.sentText, 'Hello Android');
    expect(tester.widget<TextField>(input).controller!.text, isEmpty);
  });

  testWidgets(
    'LocalBridge 3.0.6 boots and renders radar, navigation, sidebar statistics, and pages',
    (WidgetTester tester) async {
      final settings = Settings()
        ..bootAnim = 0
        ..startOnline = false;

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(LocalBridgeApp(settings: settings));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify navigation & radar
      expect(find.text('Devices'), findsWidgets);
      expect(find.text('Global Connect'), findsWidgets);
      expect(find.text('Global Transfer'), findsWidgets);
      expect(find.text('Bridge Chat'), findsWidgets);
      expect(find.text('History'), findsWidgets);
      expect(find.text('Settings'), findsWidgets);
      expect(find.byIcon(Icons.radar_rounded), findsWidgets);

      final sidebar = find.byKey(const ValueKey('desktop-sidebar'));
      expect(sidebar, findsOneWidget);
      expect(tester.getTopLeft(sidebar).dy, lessThan(55));
      expect(find.descendant(of: sidebar, matching: find.text('Made by unqale')), findsOneWidget);

      final stats = find.byKey(const ValueKey('sidebar-statistics'));
      expect(stats, findsOneWidget);
      for (final label in ['Nearby', 'Sent', 'Received']) {
        expect(find.descendant(of: stats, matching: find.text(label)), findsOneWidget);
      }
      expect(find.descendant(of: stats, matching: find.text('0')), findsNWidgets(3));
      settings.update(() => settings.showRailStats = false);
      await tester.pump();
      expect(stats, findsNothing);
      settings.update(() => settings.showRailStats = true);
      await tester.pump();
      expect(stats, findsOneWidget);

      // Navigate to Global Connect page
      await tester.tap(find.text('Global Connect').last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Your Desk Code'), findsWidgets);

      // Navigate to Global Transfer page
      await tester.tap(find.text('Global Transfer').last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Send files'), findsWidgets);

      // Navigate to Bridge Chat page
      await tester.tap(find.text('Bridge Chat').last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('All Devices (Broadcast)'), findsWidgets);

      // Navigate to History page
      await tester.tap(find.text('History').last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Sent'), findsWidgets);
      expect(find.text('Received'), findsWidgets);

      // Navigate to Settings page
      await tester.tap(find.text('Settings').last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Remote access'), findsWidgets);
    },
  );

  test('DropService.scan(full: true) runs background Isolate without closure capture error',
      () async {
    final settings = Settings()
      ..scanSpeed = 2
      ..autoScan = false;
    final service = DropService(settings);
    addTearDown(service.dispose);
    service.online = true;
    await service.scan(full: true);
    expect(service.status, isNot(contains('Scan error')));
    expect(service.status, isNot(contains('unsendable')));
  });
}
