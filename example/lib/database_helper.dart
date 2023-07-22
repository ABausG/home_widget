import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'stored_daily_log.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper.internal();

  factory DatabaseHelper() => _instance;

  static Database? _db;

  Future<Database?> get db async {
    if (_db != null) {
      return _db;
    }
    _db = await initDb();
    return _db;
  }

  DatabaseHelper.internal();

  Future<Database> initDb() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'medwidget.3.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(
      'CREATE TABLE my_table(id PRIMARY KEY, date TEXT, time TEXT)',
    );
    await db.execute(
      'CREATE TABLE dailylog(id PRIMARY KEY, date TEXT, time TEXT)',
    );
    await db.execute(
      'CREATE TABLE config(config_name TEXT PRIMARY KEY, config_value TEXT)',
    );
  }

  Future<void> insertDateTime(DateTime dateTime) async {
    final dbClient = await db;
    await dbClient!.insert(
      'dailylog',
      {'date': dateTime.toIso8601String(), 'time': dateTime.toString()},
    );
  }
Future<List<DateTime>> getStoredDates() async {
    final dbClient = await db;
    final List<Map<String, dynamic>> maps = await dbClient!.query('dailylog');
    return List.generate(maps.length, (index) {
      final dateStr = maps[index]['date'];
      return DateTime.parse(dateStr);
    });
}

Future<List<StoredDailyLog>> getStoredDailyLog() async {
  final dbClient = await db;
  final List<Map<String, dynamic>> maps = await dbClient!.query('dailylog');
  return List.generate(maps.length, (index) {
    final id = maps[index]['id'];
    final dateTimeStr = maps[index]['datetime'];
    final count = maps[index]['count'];
    return StoredDailyLog(
      id: id,
      dateTime: DateTime.parse(dateTimeStr),
      count: count,
    );
  });
}
/*
Future<DateTime?> getLastStoredDateTime() async {
  final dbClient = await db;
  final List<Map<String, dynamic>> maps = await dbClient!.rawQuery(
    'SELECT date, time FROM dailylog ORDER BY id DESC LIMIT 1',
  );
  if (maps.isEmpty) {
    return null;
  }
  final dateStr = maps.first['date'];
  final timeStr = maps.first['time'];
  return DateTime.parse(dateStr! + ' ' + timeStr!);
}
*/
  Future<DateTime?> getLastStoredDateTime() async {
    final dbClient = await db;
    final List<Map<String, dynamic>> maps = await dbClient!.query(
      'dailylog',
      orderBy: 'id DESC',
      limit: 1,
    );
    if (maps.isEmpty) {
      return null;
    }
    final dateStr = maps.first['date'];
    final timeStr = maps.first['time'];
    return DateTime.parse(dateStr + ' ' + timeStr);
  }
    Future<void> setConfig(String name, String value) async {
      print("${name} = ${value}");
    final dbClient = await db;
    await dbClient!.insert(
      'config',
      {
        'config_name': name,
        'config_value': value,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getConfigValue(String name) async {
    final dbClient = await db;
    final List<Map<String, dynamic>> maps = await dbClient!.query(
      'config',
      where: 'config_name = ?',
      whereArgs: [name],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return maps.first['config_value'] as String?;
    }
    return null;
  }
}
