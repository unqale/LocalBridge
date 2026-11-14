import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localbridge/main.dart';

final class _TestFile extends PlatformFile {
  @override
  String get name => 'desk-test.txt';
  @override
  Uri get uri => Uri.dataFromString('hello');
  @override
  Never get xFile => throw UnsupportedError('xFile is unused');
  @override
  int lengthSync() => 5;
  @override
  Future<int> length() async => lengthSync();
  @override
  Future<Uint8List> readAsBytes() async =>
      Uint8List.fromList(utf8.encode('hello'));
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
  throw StateError('Timed out waiting for connection state');
}

void main() {
  test(
    'Desk Code asks consent, then supports two-way chat and file transfer',
    () async {
      final destination = await Directory.systemTemp.createTemp(
        'localbridge-desk-test-',
      );
      addTearDown(() => destination.delete(recursive: true));
      final receiver = DropService(
        Settings()
          ..deskId = 'ABCD2345'
          ..deviceName = 'Receiving PC'
          ..port = await _freePort()
          ..haptics = false
          ..autoScan = false
          ..saveDir = destination.path,
        storageDirectory: Directory('${destination.path}/receiver'),
      );
      final sender = DropService(
        Settings()
          ..deskId = 'WXYZ6789'
          ..deviceName = 'Sending PC'
          ..port = await _freePort()
          ..haptics = false
          ..autoScan = false
          ..saveDir = destination.path,
        storageDirectory: Directory('${destination.path}/sender'),
      );
      addTearDown(receiver.dispose);
      addTearDown(sender.dispose);
      unawaited(receiver.start());
      await _waitFor(() => receiver.serverUp ? true : null);
      unawaited(sender.start());
      await _waitFor(() => sender.serverUp ? true : null);

      expect(
        (await sender.connectDesk(sender.deskCode)).error,
        'deskOwnCodeError',
      );
      final declined = sender.connectDesk(receiver.deskCode);
      final first = await _waitFor(() => receiver.pending);
      expect(first.connection, isTrue);
      receiver.resolve(first, false);
      expect((await declined).error, 'deskDeclined');

      final accepted = sender.connectDesk(receiver.deskCode);
      final second = await _waitFor(() => receiver.pending);
      expect(second.from, 'Sending PC');
      receiver.resolve(second, true);
      final other = (await accepted).device!;
      final replyTo = receiver.sortedDevices().single;
      expect(other.alias, 'Receiving PC');
      expect(replyTo.alias, 'Sending PC');

      expect(await sender.sendChatMessage(other, 'hello there'), isTrue);
      expect(await receiver.sendChatMessage(replyTo, 'hello back'), isTrue);
      expect(
        receiver.messages.any(
          (m) =>
              !m.outgoing &&
              m.sender == 'Sending PC' &&
              m.text == 'hello there' &&
              m.peerIp == receiver.addressOf(replyTo),
        ),
        isTrue,
      );
      expect(
        sender.messages.any(
          (m) =>
              !m.outgoing &&
              m.sender == 'Receiving PC' &&
              m.text == 'hello back' &&
              m.peerIp == sender.addressOf(other),
        ),
        isTrue,
      );

      final transfer = sender.sendFiles(other, [_TestFile()]);
      final file = await _waitFor(() => receiver.pending);
      expect(file.connection, isFalse);
      expect(file.from, 'Sending PC');
      receiver.resolve(file, true);
      await transfer;
      expect(
        await File('${destination.path}/desk-test.txt').readAsString(),
        'hello',
      );
      expect(receiver.history.single.peer, 'Sending PC');

      final returnTransfer = receiver.sendFiles(replyTo, [_TestFile()]);
      final returnFile = await _waitFor(() => sender.pending);
      expect(returnFile.from, 'Receiving PC');
      sender.resolve(returnFile, true);
      await returnTransfer;
      expect(sender.history.first.sent, isFalse);

      sender.removeDevice(other);
      await _waitFor(
        () => receiver.connectedDevice(receiver.addressOf(replyTo)) == null
            ? true
            : null,
      );
      expect(await sender.sendChatMessage(other, 'stale'), isFalse);

      final chat = sender.connectChat(Device(other.alias, other.ip, other.platform,
          port: other.port));
      final chatRequest = await _waitFor(() => receiver.pending);
      receiver.resolve(chatRequest, true);
      final chatPeer = (await chat).device!;
      expect(await sender.sendChatMessage(chatPeer, 'back in chat'), isTrue);
      expect(sender.cfg.remotes, isEmpty);

      // Simulate NAT by advertising a port with no listener on the initiator.
      final originalPort = sender.cfg.port;
      sender.cfg.port = await _freePort();
      final remote = sender.connectDesk('127.0.0.1:${receiver.cfg.port}');
      final remoteRequest = await _waitFor(() => receiver.pending);
      receiver.resolve(remoteRequest, true);
      final remotePeer = (await remote).device!;
      final unreachableAddress = '127.0.0.1:${sender.cfg.port}';
      final remoteReply = receiver.connectedDevice(unreachableAddress)!;
      expect(await receiver.sendChatMessage(remoteReply, 'reply through the stream'), isTrue);
      expect(sender.messages.first.text, 'reply through the stream');
      expect(await sender.sendChatMessage(remotePeer, 'received the reply'), isTrue);
      expect(receiver.messages.first.text, 'received the reply');
      sender.cfg.port = originalPort;

      await receiver.setOnline(false);
      final address = sender.addressOf(chatPeer);
      await _waitFor(() => sender.connectedDevice(address) == null ? true : null);
      await receiver.setOnline(true);
      await sender.rescan();
      expect(sender.connectedDevice(address)?.alias, 'Receiving PC');
    },
  );
}
