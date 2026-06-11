import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StorageUsage {
  const StorageUsage({required this.cacheBytes, required this.documentsBytes});

  final int cacheBytes;
  final int documentsBytes;

  int get totalBytes => cacheBytes + documentsBytes;

  static const StorageUsage empty = StorageUsage(
    cacheBytes: 0,
    documentsBytes: 0,
  );
}

class StorageService {
  StorageService();

  StorageUsage? _lastMeasurement;

  StorageUsage? get lastMeasurement => _lastMeasurement;

  Future<StorageUsage> measure() async {
    final cache = await _safeSize(() async => getTemporaryDirectory());
    final media = await _yappMediaDirSize();
    final docs = await _safeSize(
      () async => getApplicationDocumentsDirectory(),
    );
    final usage = StorageUsage(cacheBytes: cache + media, documentsBytes: docs);
    _lastMeasurement = usage;
    return usage;
  }

  Future<int> clearCache() async {
    int freed = 0;
    try {
      final tmp = await getTemporaryDirectory();
      freed += await _clearDirectory(tmp);
    } catch (_) {}
    try {
      final root = await getApplicationSupportDirectory();
      final media = Directory(p.join(root.path, 'yapp_media'));
      if (await media.exists()) {
        freed += await _directorySize(media);
        await media.delete(recursive: true);
      }
    } catch (_) {}
    _lastMeasurement = StorageUsage(
      cacheBytes: 0,
      documentsBytes: _lastMeasurement?.documentsBytes ?? 0,
    );
    return freed;
  }

  Future<int> _yappMediaDirSize() async {
    try {
      final root = await getApplicationSupportDirectory();
      final d = Directory(p.join(root.path, 'yapp_media'));
      if (!await d.exists()) return 0;
      return _directorySize(d);
    } catch (_) {
      return 0;
    }
  }

  Future<int> _safeSize(Future<Directory> Function() resolver) async {
    try {
      final dir = await resolver();
      return await _directorySize(dir);
    } catch (_) {
      return 0;
    }
  }

  Future<int> _directorySize(Directory dir) async {
    if (!await dir.exists()) return 0;
    int total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {}
      }
    }
    return total;
  }

  Future<int> _clearDirectory(Directory dir) async {
    if (!await dir.exists()) return 0;
    int freed = 0;
    await for (final entity in dir.list(followLinks: false)) {
      try {
        if (entity is File) {
          freed += await entity.length();
          await entity.delete();
        } else if (entity is Directory) {
          freed += await _directorySize(entity);
          await entity.delete(recursive: true);
        }
      } catch (_) {}
    }
    return freed;
  }
}

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  double value = bytes.toDouble();
  int unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  if (value >= 100 || unit == 0) {
    return '${value.toStringAsFixed(0)} ${units[unit]}';
  }
  return '${value.toStringAsFixed(1)} ${units[unit]}';
}
