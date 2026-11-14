import 'dart:io';
import 'package:flutter/foundation.dart';

enum StagedFileCategory {
  image,
  video,
  audio,
  document,
  archive,
  code,
  executable,
  other,
}

class StagedFileItem {
  final String id;
  final String name;
  final int size;
  final String? path;
  final Uint8List? bytes;
  final Stream<List<int>> Function()? streamFactory;

  StagedFileItem({
    required this.id,
    required this.name,
    required this.size,
    this.path,
    this.bytes,
    this.streamFactory,
  });

  String get extension {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  StagedFileCategory get category {
    switch (extension) {
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'webp':
      case 'gif':
      case 'bmp':
        return StagedFileCategory.image;
      case 'mp4':
      case 'mkv':
      case 'mov':
      case 'avi':
      case 'webm':
        return StagedFileCategory.video;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'ogg':
      case 'm4a':
      case 'aac':
        return StagedFileCategory.audio;
      case 'pdf':
      case 'doc':
      case 'docx':
      case 'xls':
      case 'xlsx':
      case 'ppt':
      case 'pptx':
      case 'txt':
      case 'md':
      case 'csv':
      case 'rtf':
        return StagedFileCategory.document;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
      case 'bz2':
        return StagedFileCategory.archive;
      case 'dart':
      case 'js':
      case 'ts':
      case 'py':
      case 'json':
      case 'xml':
      case 'yaml':
      case 'yml':
      case 'html':
      case 'css':
      case 'cpp':
      case 'c':
      case 'h':
      case 'kt':
      case 'java':
        return StagedFileCategory.code;
      case 'apk':
      case 'exe':
      case 'msi':
      case 'dmg':
      case 'deb':
      case 'rpm':
        return StagedFileCategory.executable;
      default:
        return StagedFileCategory.other;
    }
  }

  /// Lightweight thumbnail preview is only enabled for supported raster images
  /// backed by a local file path under 25 MB, decoded via ResizeImage to avoid
  /// loading large images into memory.
  bool get canPreviewThumbnail {
    if (category != StagedFileCategory.image) return false;
    if (path == null || path!.isEmpty) return false;
    if (size <= 0 || size > 25 * 1024 * 1024) return false;
    return true;
  }

  Stream<List<int>> openReadStream() {
    if (streamFactory != null) {
      return streamFactory!();
    }
    final p = path;
    if (p != null && p.isNotEmpty) {
      return File(p).openRead();
    }
    final b = bytes;
    if (b != null) {
      return Stream<List<int>>.value(b);
    }
    throw const FileSystemException('Unable to read selected file');
  }
}

class FileStagingController extends ChangeNotifier {
  final List<StagedFileItem> _items = <StagedFileItem>[];

  String? _targetKey;
  String? _targetAlias;
  String? _targetIp;
  bool _isBroadcast = false;

  bool _isTransferring = false;
  int _sentFilesCount = 0;
  int _currentFileIndex = 0;
  String? _lastError;
  bool _lastCancelled = false;

  List<StagedFileItem> get items => List<StagedFileItem>.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
  int get totalCount => _items.length;
  int get totalBytes =>
      _items.fold<int>(0, (sum, item) => sum + (item.size > 0 ? item.size : 0));

  String? get targetKey => _targetKey;
  String? get targetAlias => _targetAlias;
  String? get targetIp => _targetIp;
  bool get isBroadcast => _isBroadcast;

  bool get isTransferring => _isTransferring;
  int get sentFilesCount => _sentFilesCount;
  int get currentFileIndex => _currentFileIndex;
  int get remainingFilesCount =>
      (_items.length - _sentFilesCount).clamp(0, _items.length);
  String? get lastError => _lastError;
  bool get lastCancelled => _lastCancelled;

  void setTarget({
    String? key,
    String? alias,
    String? ip,
    bool broadcast = false,
  }) {
    _targetKey = key;
    _targetAlias = alias;
    _targetIp = ip;
    _isBroadcast = broadcast;
    notifyListeners();
  }

  int addFiles(Iterable<StagedFileItem> newItems) {
    int added = 0;
    for (final item in newItems) {
      final exists = _items.any((existing) {
        if (existing.path != null &&
            item.path != null &&
            existing.path!.isNotEmpty &&
            existing.path == item.path) {
          return true;
        }
        return existing.id == item.id;
      });
      if (!exists) {
        _items.add(item);
        added++;
      }
    }
    if (added > 0) {
      _lastError = null;
      _lastCancelled = false;
      notifyListeners();
    }
    return added;
  }

  Future<int> addLocalPaths(Iterable<String> paths) async {
    final staged = <StagedFileItem>[];
    for (final rawPath in paths) {
      final trimmed = rawPath.trim();
      if (trimmed.isEmpty) continue;
      try {
        final stat = await FileStat.stat(trimmed);
        if (stat.type == FileSystemEntityType.file && stat.size >= 0) {
          final sep = trimmed.contains('\\') ? '\\' : '/';
          final name = trimmed.split(sep).last;
          if (name.isEmpty) continue;
          staged.add(
            StagedFileItem(
              id: 'path:$trimmed',
              name: name,
              size: stat.size,
              path: trimmed,
            ),
          );
        } else if (stat.type == FileSystemEntityType.directory) {
          final dir = Directory(trimmed);
          await for (final entity in dir.list(recursive: false, followLinks: false)) {
            if (entity is File) {
              final fStat = await entity.stat();
              final sep = entity.path.contains('\\') ? '\\' : '/';
              final name = entity.path.split(sep).last;
              staged.add(
                StagedFileItem(
                  id: 'path:${entity.path}',
                  name: name,
                  size: fStat.size,
                  path: entity.path,
                ),
              );
            }
          }
        }
      } catch (_) {
        // Ignore unreadable paths.
      }
    }
    return addFiles(staged);
  }

  void removeAt(int index) {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    if (_items.isEmpty) {
      _lastError = null;
      _lastCancelled = false;
    }
    notifyListeners();
  }

  void removeById(String id) {
    _items.removeWhere((item) => item.id == id);
    if (_items.isEmpty) {
      _lastError = null;
      _lastCancelled = false;
    }
    notifyListeners();
  }

  void clear() {
    if (_items.isEmpty && _lastError == null && !_lastCancelled) return;
    _items.clear();
    _sentFilesCount = 0;
    _currentFileIndex = 0;
    _lastError = null;
    _lastCancelled = false;
    notifyListeners();
  }

  void beginTransfer() {
    _isTransferring = true;
    _sentFilesCount = 0;
    _currentFileIndex = 0;
    _lastError = null;
    _lastCancelled = false;
    notifyListeners();
  }

  void updateProgress({required int currentFileIndex, required int sentFilesCount}) {
    _currentFileIndex = currentFileIndex;
    _sentFilesCount = sentFilesCount;
    notifyListeners();
  }

  void completeTransferSuccess() {
    _isTransferring = false;
    _sentFilesCount = _items.length;
    _lastError = null;
    _lastCancelled = false;
    _items.clear();
    notifyListeners();
  }

  /// Preserves the staged file selection on failure or cancellation so the user
  /// can retry without re-selecting files.
  void failTransfer(String error, {bool cancelled = false}) {
    _isTransferring = false;
    _lastError = error;
    _lastCancelled = cancelled;
    notifyListeners();
  }

  void discardAcknowledgedFiles() {
    if (_sentFilesCount == 0) return;
    _items.removeRange(0, _sentFilesCount.clamp(0, _items.length));
    _sentFilesCount = 0;
    _currentFileIndex = 0;
  }
}
