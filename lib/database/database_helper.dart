import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('timetable.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE batch(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        className TEXT NOT NULL,
        startDate TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE subject(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        batchId INTEGER NOT NULL,
        name TEXT NOT NULL,
        dayOfWeek TEXT NOT NULL,
        FOREIGN KEY(batchId) REFERENCES batch(id)
      )
    ''');
  }

  Future<int> insertBatch(String name, String className, String startDate) async {
    final db = await instance.database;
    return await db.insert('batch', {
      'name': name,
      'className': className,
      'startDate': startDate,
    });
  }

  Future<int> insertSubject(int batchId, String name, String dayOfWeek) async {
    final db = await instance.database;
    return await db.insert('subject', {
      'batchId': batchId,
      'name': name,
      'dayOfWeek': dayOfWeek,
    });
  }

  Future<List<Map<String, dynamic>>> getAllBatches() async {
    final db = await instance.database;
    return await db.query('batch');
  }

  Future<List<Map<String, dynamic>>> getSubjectsForBatch(int batchId) async {
    final db = await instance.database;
    return await db.query('subject', where: 'batchId = ?', whereArgs: [batchId]);
  }

  Future<int> deleteBatch(int batchId) async {
    final db = await instance.database;
    await db.delete('subject', where: 'batchId = ?', whereArgs: [batchId]);
    return await db.delete('batch', where: 'id = ?', whereArgs: [batchId]);
  }

  Future<void> resetDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'timetable.db');
    await deleteDatabase(path);
    // Re-initialize a fresh database
    _database = await _initDB('timetable.db');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
