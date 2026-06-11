import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LibsignalDb {
  LibsignalDb._(this._accountId);

  final String _accountId;

  static final Map<String, LibsignalDb> _instances = <String, LibsignalDb>{};

  static LibsignalDb forAccount(String accountId) =>
      _instances[accountId] ??= LibsignalDb._(accountId);

  static LibsignalDb instance = forAccount('');

  static void useAccount(String accountId) {
    instance = forAccount(accountId);
  }

  Database? _db;

  static String _fileSafe(String id) =>
      id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  Future<Database> get _database async {
    final existing = _db;
    if (existing != null) return existing;
    final suffix = _accountId.isEmpty ? '' : '_${_fileSafe(_accountId)}';
    final path = p.join(await getDatabasesPath(), 'yapp_libsignal$suffix.db');
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE kv (
            kind TEXT NOT NULL,
            k    TEXT NOT NULL,
            v    BLOB NOT NULL,
            PRIMARY KEY (kind, k)
          )
        ''');
      },
    );
    _db = db;
    return db;
  }

  Future<void> put(String kind, String key, Uint8List value) async {
    final db = await _database;
    await db.insert('kv', <String, Object?>{
      'kind': kind,
      'k': key,
      'v': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Uint8List?> get(String kind, String key) async {
    final db = await _database;
    final rows = await db.query(
      'kv',
      columns: <String>['v'],
      where: 'kind = ? AND k = ?',
      whereArgs: <Object?>[kind, key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final v = rows.first['v'];
    return v is Uint8List ? v : Uint8List.fromList(v as List<int>);
  }

  Future<bool> contains(String kind, String key) async =>
      (await get(kind, key)) != null;

  Future<void> delete(String kind, String key) async {
    final db = await _database;
    await db.delete(
      'kv',
      where: 'kind = ? AND k = ?',
      whereArgs: <Object?>[kind, key],
    );
  }

  Future<List<String>> keys(String kind) async {
    final db = await _database;
    final rows = await db.query(
      'kv',
      columns: <String>['k'],
      where: 'kind = ?',
      whereArgs: <Object?>[kind],
    );
    return rows.map((r) => r['k'] as String).toList(growable: false);
  }

  Future<void> wipe() async {
    final db = await _database;
    await db.delete('kv');
  }
}
