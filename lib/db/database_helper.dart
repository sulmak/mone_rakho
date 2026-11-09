import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/notification_master.dart';

/// Local SQLite store for NotificationMaster rows. Column names/types
/// mirror the SQL Server table 1:1 (see notification_master.dart).
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const String tableName = 'NotificationMaster';
  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'notification_master.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableName (
            Id TEXT PRIMARY KEY,
            Notification TEXT,
            Email TEXT,
            Sequence REAL,
            NotificationDate TEXT,
            RepeatType TEXT,
            AddedBy TEXT,
            AddedDate TEXT,
            UpdatedBy TEXT,
            UpdatedDate TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE $tableName ADD COLUMN RepeatType TEXT DEFAULT 'MONTHLY'",
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            "ALTER TABLE $tableName ADD COLUMN Email TEXT",
          );
        }
      },
    );
  }

  Future<List<NotificationMaster>> getAll() async {
    final db = await database;
    final rows = await db.query(tableName, orderBy: 'Sequence ASC, NotificationDate ASC');
    return rows.map((r) => NotificationMaster.fromMap(r)).toList();
  }

  Future<NotificationMaster?> getById(String id) async {
    final db = await database;
    final rows = await db.query(tableName, where: 'Id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return NotificationMaster.fromMap(rows.first);
  }

  Future<void> insert(NotificationMaster entry) async {
    final db = await database;
    await db.insert(
      tableName,
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(NotificationMaster entry) async {
    final db = await database;
    await db.update(
      tableName,
      entry.toMap(),
      where: 'Id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await database;
    await db.delete(tableName, where: 'Id = ?', whereArgs: [id]);
  }
}
