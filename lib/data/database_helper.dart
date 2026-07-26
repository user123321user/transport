import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DatabaseHelper {
  static const _databaseName = "NaqelCompany.db";
  static const _databaseVersion = 1;

  DatabaseHelper._privateConstructor();
  static const DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(path, version: _databaseVersion, onCreate: _onCreate);
  }

  Future _onCreate(Database db, int version) async {
    // 1. جدول الشاحنات
    await db.execute('''
          CREATE TABLE trucks (
            truck_id TEXT PRIMARY KEY,
            type TEXT NOT NULL
          )
          ''');

    // 2. جدول الحسابات والعملاء
    await db.execute('''
          CREATE TABLE accounts (
            account_id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            is_permanent INTEGER DEFAULT 0,
            balance REAL DEFAULT 0.0
          )
          ''');

    // 3. جدول الرحلات والحمولات
    await db.execute('''
          CREATE TABLE trips (
            trip_id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            truck_id TEXT,
            driver_name TEXT,
            loading_place TEXT,
            unloading_place TEXT,
            material_type TEXT,
            quantity REAL,
            price_per_unit REAL,
            receipt_image_path TEXT,
            net_weight REAL,
            discount_admin REAL
          )
          ''');

    // 4. جدول الصندوق المالي
    await db.execute('''
          CREATE TABLE cashbox (
            transaction_id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            details TEXT,
            income REAL DEFAULT 0.0,
            expense REAL DEFAULT 0.0
          )
          ''');
  }
}

extension SetupOperations on DatabaseHelper {
  // ---- عمليات الشاحنات ----
  Future<int> insertTruck(String id, String type) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('trucks', {'truck_id': id, 'type': type},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getTrucks() async {
    final db = await DatabaseHelper.instance.database;
    return await db.query('trucks');
  }

  // ---- عمليات الحسابات ----
  Future<int> insertAccount(String name, String type, int isPermanent, double initialBalance) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('accounts', {
      'name': name,
      'type': type,
      'is_permanent': isPermanent,
      'balance': initialBalance
    });
  }

  Future<List<Map<String, dynamic>>> getAccountsByType(String type) async {
    final db = await DatabaseHelper.instance.database;
    return await db.query('accounts', where: 'type = ?', whereArgs: [type]);
  }

  // ---- عمليات الرحلات ----
  Future<int> insertTrip(Map<String, dynamic> tripData) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('trips', tripData);
  }
}
