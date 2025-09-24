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
        startDate TEXT NOT NULL,
        lastDate TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1
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

    await db.execute('''
      CREATE TABLE lecture(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        batchId INTEGER NOT NULL,
        subject TEXT NOT NULL,
        date TEXT NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY(batchId) REFERENCES batch(id)
      )
    ''');
  }

  // ------------------- Batch -------------------
  Future<int> insertBatch(String name, String className, String startDate) async {
    final db = await instance.database;
    return await db.insert('batch', {
      'name': name,
      'className': className,
      'startDate': startDate,
      'lastDate': startDate,
      'isActive': 1,
    });
  }

  Future<List<Map<String, dynamic>>> getAllBatches() async {
    final db = await instance.database;
    return await db.query('batch');
  }

  Future<int> deleteBatch(int batchId) async {
    final db = await instance.database;
    await db.delete('subject', where: 'batchId = ?', whereArgs: [batchId]);
    await db.delete('lecture', where: 'batchId = ?', whereArgs: [batchId]);
    return await db.delete('batch', where: 'id = ?', whereArgs: [batchId]);
  }

  Future<void> stopSemester(int batchId) async {
    final db = await instance.database;
    await db.update('batch', {'isActive': 0}, where: 'id = ?', whereArgs: [batchId]);
  }

  // ------------------- Subject -------------------
  Future<int> insertSubject(int batchId, String name, String dayOfWeek) async {
    final db = await instance.database;
    return await db.insert('subject', {
      'batchId': batchId,
      'name': name,
      'dayOfWeek': dayOfWeek,
    });
  }

  Future<List<Map<String, dynamic>>> getSubjectsForBatch(int batchId) async {
    final db = await instance.database;
    return await db.query('subject', where: 'batchId = ?', whereArgs: [batchId]);
  }

  // ------------------- Lecture -------------------
  Future<int> insertLecture(int batchId, String subject, String date, String status) async {
    final db = await instance.database;
    return await db.insert('lecture', {
      'batchId': batchId,
      'subject': subject,
      'date': date,
      'status': status, // present / absent / canceled
    });
  }

  Future<List<Map<String, dynamic>>> getLecturesForDate(int batchId, String date) async {
    final db = await instance.database;
    return await db.query(
      'lecture',
      where: 'batchId = ? AND date = ?',
      whereArgs: [batchId, date],
    );
  }

  Future<List<Map<String, dynamic>>> getLecturesForSubject(int batchId, String subjectName) async {
    final db = await instance.database;
    return await db.query(
      'lecture',
      where: 'batchId = ? AND subject = ?',
      whereArgs: [batchId, subjectName],
      orderBy: 'date ASC',
    );
  }

  // ------------------- Auto-fill lectures -------------------
  Future<void> autoFillLectures(int batchId) async {
    final db = await instance.database;

    // Get batch info
    final batchList = await db.query('batch', where: 'id = ?', whereArgs: [batchId]);
    if (batchList.isEmpty) return;
    final batch = batchList.first;
    if (batch['isActive'] == 0) return; // skip inactive batch

    DateTime lastDate = DateTime.parse(batch['lastDate'] as String);
    DateTime today = DateTime.now();

    if (lastDate.isAfter(today)) return; // only skip if lastDate > today

    // Get subjects
    final subjects = await db.query('subject', where: 'batchId = ?', whereArgs: [batchId]);

    try {
      DateTime current = lastDate; // start from lastDate itself
      while (!current.isAfter(today)) {
        String dayOfWeek = _dayName(current.weekday);
        for (var sub in subjects) {
          if (sub['dayOfWeek'] == dayOfWeek) {
            // Check if lecture already exists
            final existing = await db.query(
              'lecture',
              where: 'batchId = ? AND subject = ? AND date = ?',
              whereArgs: [batchId, sub['name'], current.toIso8601String().split('T')[0]],
            );
            if (existing.isEmpty) {
              await insertLecture(batchId, sub['name'] as String,
                  current.toIso8601String().split('T')[0], 'present');
            }
          }
        }
        current = current.add(const Duration(days: 1));
      }

      // Update lastDate
      await db.update(
        'batch',
        {'lastDate': today.toIso8601String().split('T')[0]},
        where: 'id = ?',
        whereArgs: [batchId],
      );
    } catch (e) {
      print("Error while auto-filling lectures: $e");
    }
  }


  // ------------------- Helpers -------------------
  String _dayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }

  // ------------------- Reset / Close -------------------
  Future<void> resetDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'timetable.db');
    await deleteDatabase(path);
    _database = await _initDB('timetable.db');
  }

  Future<int> deleteLecture(int lectureId) async {
    final db = await instance.database;
    return await db.delete('lecture', where: 'id = ?', whereArgs: [lectureId]);
  }

  // Update markNextLectureAbsent
  Future<void> markNextLectureAbsent(int batchId, String subject, String date) async {
    final db = await instance.database;
    final lectures = await db.query(
      'lecture',
      where: 'batchId = ? AND subject = ? AND date = ? AND status = ?',
      whereArgs: [batchId, subject, date, 'present'],
      orderBy: 'id ASC',
    );

    if (lectures.isNotEmpty) {
      await db.update(
        'lecture',
        {'status': 'absent'},
        where: 'id = ?',
        whereArgs: [lectures.first['id']],
      );
    }
  }

  Future<void> cancelNextLecture(int batchId, String subject, String date) async {
    final db = await instance.database;
    final lectures = await db.query(
      'lecture',
      where: 'batchId = ? AND subject = ? AND date = ? AND status = ?',
      whereArgs: [batchId, subject, date, 'present'],
      orderBy: 'id ASC',
    );

    if (lectures.isNotEmpty) {
      await db.delete('lecture', where: 'id = ?', whereArgs: [lectures.first['id']]);
    }
  }

  // Update lecture status by lecture ID
  Future<int> updateLectureStatus(int lectureId, String newStatus) async {
    final db = await instance.database;
    return await db.update(
      'lecture',
      {'status': newStatus},
      where: 'id = ?',
      whereArgs: [lectureId],
    );
  }


  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
