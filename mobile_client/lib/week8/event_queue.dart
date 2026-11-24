import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'config.dart';
import 'geo_event.dart';

/// Offline-safe queue of geofence events: the Week 7 outbox idea, reused.
/// YOU COMPLETE add (TODO 3).
///
/// An event is saved here first and sent later, so an event detected with no
/// network is not lost. A row is deleted only after the server replied OK.
class EventQueue {
  EventQueue._(this.db);

  final Database db;
  static const _uuid = Uuid();

  static Future<EventQueue> open() async {
    final path = p.join(await getDatabasesPath(), 'week8.db');
    final db = await openDatabase(path, version: 1, onCreate: (db, v) async {
      await db.execute('''
        CREATE TABLE event_outbox(
          seq       INTEGER PRIMARY KEY AUTOINCREMENT,
          idem_key  TEXT NOT NULL,
          fence_id  TEXT NOT NULL,
          type      TEXT NOT NULL,
          at        TEXT NOT NULL)''');
      await db.execute('CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT)');
    });
    return EventQueue._(db);
  }

  /// Queue one geofence event ('enter' or 'exit').
  Future<void> add(String type) async {
    // TODO 3 (about 6 lines)
    // Insert ONE row into the table 'event_outbox' (see open() above) with:
    //   idem_key: a new _uuid.v4()   (the server stores a repeated key only once)
    //   fence_id: kFenceId
    //   type:     type               ('enter' or 'exit')
    //   at:       DateTime.now().toUtc().toIso8601String()
    // Do NOT put the latitude or longitude in the row: only the event leaves the phone.
    // The provided EventSync sends the queue and deletes a row only after an OK.
    throw UnimplementedError('TODO 3: add');
  }

  /// Unsent events, oldest first.
  Future<List<GeoEvent>> pending() async {
    final rows = await db.query('event_outbox', orderBy: 'seq ASC');
    return rows.map(GeoEvent.fromDb).toList();
  }

  Future<int> count() async =>
      Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM event_outbox')) ??
      0;

  /// Delete an event. Call this only AFTER the server replied OK.
  Future<void> remove(int seq) =>
      db.delete('event_outbox', where: 'seq = ?', whereArgs: [seq]);

  /// Start of a run: empty the queue.
  Future<void> clear() => db.delete('event_outbox');

  Future<bool> online() async => (await _meta('online') ?? '1') == '1';
  Future<void> setOnline(bool v) => _setMeta('online', v ? '1' : '0');

  Future<String?> _meta(String key) async {
    final rows = await db.query('meta', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> _setMeta(String key, String value) => db.insert(
      'meta', {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace);
}
