// offline.dart — on-device store so the phone keeps working without a signal.
//
// Two jobs, one small SQLite database:
//   1. Read cache — every successful GET is saved, keyed by (user, url). When a
//      later GET can't reach the server, the last-known answer is served, so
//      stock, orders and deliveries stay viewable in a dead spot.
//   2. Write outbox — a short list of safe, idempotent-ish actions (clock
//      in/out, order status, line actions, corrections) made while offline are
//      queued and replayed when the connection returns.
//
// Everything is scoped to the signed-in user's id. A shared phone handed to the
// next shift must not show or send the previous person's data, and a queued
// action must replay under the account that made it — never whoever is holding
// the phone at sync time.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class Offline {
  Offline._();
  static final Offline instance = Offline._();

  Database? _db;
  int _uid = 0; // 0 = signed out / unknown

  /// Live counters the UI can watch: writes waiting to sync, and whether the
  /// last request actually reached the server.
  final ValueNotifier<int> pending = ValueNotifier<int>(0);
  final ValueNotifier<bool> online = ValueNotifier<bool>(true);

  Future<void> init() async {
    if (_db != null) return;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'alomforce_cache.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('CREATE TABLE cache ('
            'uid INTEGER, k TEXT, body TEXT, ts INTEGER, '
            'PRIMARY KEY (uid, k))');
        await db.execute('CREATE TABLE outbox ('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'uid INTEGER, method TEXT, path TEXT, body TEXT, ts INTEGER)');
      },
    );
  }

  /// Point the store at the current user (0 when signed out). Scopes every
  /// read and write below and refreshes the pending badge.
  void setUser(int uid) {
    _uid = uid;
    _refreshPending();
  }

  int get _now => DateTime.now().millisecondsSinceEpoch;

  Future<void> _refreshPending() async {
    final db = _db;
    if (db == null || _uid == 0) {
      pending.value = 0;
      return;
    }
    final rows =
        await db.rawQuery('SELECT COUNT(*) c FROM outbox WHERE uid = ?', [_uid]);
    pending.value = (rows.first['c'] as int?) ?? 0;
  }

  // ---- read cache ----

  Future<void> cachePut(String key, dynamic data) async {
    final db = _db;
    if (db == null || _uid == 0) return;
    await db.insert(
      'cache',
      {'uid': _uid, 'k': key, 'body': jsonEncode(data), 'ts': _now},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<dynamic> cacheGet(String key) async {
    final db = _db;
    if (db == null || _uid == 0) return null;
    final rows = await db.query('cache',
        where: 'uid = ? AND k = ?', whereArgs: [_uid, key], limit: 1);
    if (rows.isEmpty) return null;
    try {
      return jsonDecode(rows.first['body'] as String);
    } catch (_) {
      return null;
    }
  }

  /// Wipe this user's cached reads (on sign-out, for privacy on a shared phone).
  /// The outbox is intentionally left: those actions belong to the user and
  /// replay only under their own account when they sign back in.
  Future<void> clearCache() async {
    final db = _db;
    if (db == null) return;
    await db.delete('cache', where: 'uid = ?', whereArgs: [_uid]);
  }

  // ---- write outbox ----

  Future<void> enqueue(String method, String path, dynamic body) async {
    final db = _db;
    if (db == null || _uid == 0) return;
    await db.insert('outbox', {
      'uid': _uid,
      'method': method,
      'path': path,
      'body': jsonEncode(body),
      'ts': _now,
    });
    await _refreshPending();
  }

  Future<List<Map<String, Object?>>> pendingWrites() async {
    final db = _db;
    if (db == null || _uid == 0) return const [];
    return db.query('outbox',
        where: 'uid = ?', whereArgs: [_uid], orderBy: 'id ASC');
  }

  Future<void> removeWrite(int id) async {
    final db = _db;
    if (db == null) return;
    await db.delete('outbox', where: 'id = ?', whereArgs: [id]);
    await _refreshPending();
  }
}

final offline = Offline.instance;
