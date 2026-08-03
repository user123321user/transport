import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/material.dart';

class DatabaseHelper {
  static const _databaseName = "NaqelCompany.db";
  static const _databaseVersion = 1;

  DatabaseHelper._privateConstructor();
  static  DatabaseHelper instance = DatabaseHelper._privateConstructor();

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
    await db.execute('''
          CREATE TABLE trucks (
            truck_id TEXT PRIMARY KEY,
            type TEXT NOT NULL
          )
          ''');

    await db.execute('''
          CREATE TABLE accounts (
            account_id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            is_permanent INTEGER DEFAULT 0,
            balance REAL DEFAULT 0.0
          )
          ''');

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
            driver_wage REAL DEFAULT 0.0 -- تم إضافة حقل مهمة (أجرة) السائق هنا

          )
          ''');

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

  // ---- عمليات الصندوق اليدوية ----
  Future<int> insertTransaction(String details, double income, double expense) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('cashbox', {
      'date': DateTime.now().toIso8601String().split('T').first,
      'details': details,
      'income': income,
      'expense': expense,
    });
  }

  Future<void> insertTripWithAccounting(Map<String, dynamic> tripData, String tripType, double totalBuy, double totalSell, double expenses, String quarryName, String customerName) async {
    final db = await DatabaseHelper.instance.database;

    await db.transaction((txn) async {
      await txn.insert('trips', tripData);
      String dateStr = tripData['date'] ?? DateTime.now().toIso8601String().split('T').first;
      String truck = tripData['truck_id'] ?? 'غير محدد';
      String driver = tripData['driver_name'] ?? 'غير محدد';
      double driverWage = tripData['driver_wage'] ?? 0.0; // جلب أجرة السائق من البيانات

      if (tripType == 'buy_sell') {
        await txn.insert('cashbox', {'date': dateStr, 'details': 'شراء بضاعة تلقائي - رحلة شاحنة ($truck)', 'income': 0.0, 'expense': totalBuy});
        await txn.rawUpdate('UPDATE accounts SET balance = balance - ? WHERE name = ? AND type = "quarry"', [totalBuy, quarryName]);
        await txn.insert('cashbox', {'date': dateStr, 'details': 'بيع بضاعة للزبون ($customerName) - شاحنة ($truck)', 'income': totalSell, 'expense': 0.0});
        await txn.rawUpdate('UPDATE accounts SET balance = balance + ? WHERE name = ? AND type = "customer"', [totalSell, customerName]);
      } else {
        await txn.insert('cashbox', {'date': dateStr, 'details': 'إيراد أجار نقل تلقائي للزبون ($customerName)', 'income': totalSell, 'expense': 0.0});
        await txn.rawUpdate('UPDATE accounts SET balance = balance + ? WHERE name = ? AND type = "customer"', [totalSell, customerName]);
      }

      // ---- الترحيل الآلي لأجرة السائق ----
      if (driverWage > 0) {
        // 1. قيد مصروف أجرة الشحن بداخل الصندوق المالي
        await txn.insert('cashbox', {'date': dateStr, 'details': 'أجرة ومهمة السائق ($driver) - رحلة شاحنة ($truck)', 'income': 0.0, 'expense': driverWage});
        // 2. قيد المبلغ المالي بداخل ذمة وكشف حساب السائق (تسجيل مستحقات له)
        await txn.rawUpdate('UPDATE accounts SET balance = balance + ? WHERE name = ? AND type = "driver"', [driverWage, driver]);
      }

      if (expenses > 0) {
        await txn.insert('cashbox', {'date': dateStr, 'details': 'مصاريف طريق ووقود - رحلة شاحنة ($truck)', 'income': 0.0, 'expense': expenses});
      }
    });
  }


  // ---- دالات النسخ الاحتياطي اليدوي لأندرويد 8 (مجلد التنزيلات العام المحمي من الحذف) ----
  Future<String> exportDatabaseBackup() async {
    try {
      Directory appDocDir = await getApplicationDocumentsDirectory();
      String dbPath = join(appDocDir.path, "NaqelCompany.db");
      File dbFile = File(dbPath);

      if (!await dbFile.exists()) return "لا توجد بيانات حالية لتصديرها";

      String backupPath = "/storage/emulated/0/Download/Naqel_Backup.db";
      await dbFile.copy(backupPath);
      return "تم تصدير النسخة الاحتياطية بنجاح إلى مجلد التنزيلات باسم Naqel_Backup.db";
    } catch (e) {
      return "فشل التصدير: $e";
    }
  }

  Future<String> importDatabaseBackup() async {
    try {
      String backupPath = "/storage/emulated/0/Download/Naqel_Backup.db";
      File backupFile = File(backupPath);

      if (!await backupFile.exists()) {
        return "لم يتم العثور على ملف نسخة احتياطية باسم Naqel_Backup.db في مجلد التنزيلات العام!";
      }

      final db = await DatabaseHelper.instance.database;
      await db.close();

      Directory appDocDir = await getApplicationDocumentsDirectory();
      String dbPath = join(appDocDir.path, "NaqelCompany.db");
      await backupFile.copy(dbPath);

      return "تم استعادة كافة البيانات والرحلات بنجاح! يرجى إعادة تشغيل التطبيق.";
    } catch (e) {
      return "فشل استعادة البيانات: $e";
    }
  }

  // دالات جلب واستعراض البيانات للتقارير والواجهات
  Future<List<Map<String, dynamic>>> getTripsWithImages() async { final db = await DatabaseHelper.instance.database; return await db.query('trips', orderBy: 'trip_id DESC'); }
  Future<List<Map<String, dynamic>>> getCashboxTransactions() async { final db = await DatabaseHelper.instance.database; return await db.query('cashbox', orderBy: 'transaction_id DESC'); }
  Future<double> getCashboxBalance() async { final db = await DatabaseHelper.instance.database; final List<Map<String, dynamic>> result = await db.rawQuery('SELECT SUM(income) as total_income, SUM(expense) as total_expense FROM cashbox'); double income = result.first['total_income'] ?? 0.0; double expense = result.first['total_expense'] ?? 0.0; return income - expense; }
  Future<List<Map<String, dynamic>>> getAllAccountsWithBalances() async { final db = await DatabaseHelper.instance.database; return await db.query('accounts', orderBy: 'balance DESC'); }
  Future<List<Map<String, dynamic>>> getTripsByDriver(String driverName) async { final db = await DatabaseHelper.instance.database; return await db.query('trips', where: 'driver_name = ?', whereArgs: [driverName], orderBy: 'trip_id DESC'); }
  Future<List<Map<String, dynamic>>> getCashboxByDateRange(String startDate, String endDate) async { final db = await DatabaseHelper.instance.database; return await db.query('cashbox', where: 'date >= ? AND date <= ?', whereArgs: [startDate, endDate], orderBy: 'transaction_id DESC'); }
  Future<List<Map<String, dynamic>>> getDriverTripsByDateRange(String driverName, String startDate, String endDate) async { final db = await DatabaseHelper.instance.database; return await db.query('trips', where: 'driver_name = ? AND date >= ? AND date <= ?', whereArgs: [driverName, startDate, endDate], orderBy: 'trip_id DESC'); }
  Future<List<Map<String, dynamic>>> searchTripsAdvanced(String query, String? startDate, String? endDate) async { final db = await DatabaseHelper.instance.database; String whereClause = "1=1"; List<dynamic> whereArgs = []; if (query.isNotEmpty) { whereClause += " AND (truck_id LIKE ? OR driver_name LIKE ? OR material_type LIKE ?)"; whereArgs.addAll(['%$query%', '%$query%', '%$query%']); } if (startDate != null && endDate != null) { whereClause += " AND (date >= ? AND date <= ?)"; whereArgs.addAll([startDate, endDate]); } return await db.query('trips', where: whereClause, whereArgs: whereArgs, orderBy: 'trip_id DESC'); }
  // ==================== حقول الشاحنات ====================
  Future<int> updateTruck(String oldId, String newId, String type) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update(
      'trucks',
      {'truck_id': newId, 'type': type},
      where: 'truck_id = ?',
      whereArgs: [oldId],
    );
  }

  Future<int> deleteTruck(String id) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete('trucks', where: 'truck_id = ?', whereArgs: [id]);
  }

  // ==================== حقول الحسابات والعملاء ====================
  Future<int> updateAccount(int id, String name, String type, int isPermanent, double balance) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update(
      'accounts',
      {'name': name, 'type': type, 'is_permanent': isPermanent, 'balance': balance},
      where: 'account_id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAccount(int id) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete('accounts', where: 'account_id = ?', whereArgs: [id]);
  }

  // ==================== حقول الصندوق والقيود المالية ====================
  Future<int> updateTransaction(int id, String details, double income, double expense) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update(
      'cashbox',
      {'details': details, 'income': income, 'expense': expense},
      where: 'transaction_id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete('cashbox', where: 'transaction_id = ?', whereArgs: [id]);
  }

  // ==================== حقول سجل الرحلات ====================
  Future<int> updateTrip(int id, Map<String, dynamic> tripData) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update('trips', tripData, where: 'trip_id = ?', whereArgs: [id]);
  }

  Future<int> deleteTrip(int id) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete('trips', where: 'trip_id = ?', whereArgs: [id]);
  }

}
