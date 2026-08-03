import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/material.dart';

class DatabaseHelper {
  static const _databaseName = "NaqelCompanyMutiCurrencyV3.db"; // اسم جديد لضمان بناء الهيكل بدون تعارض
  static const _databaseVersion = 1;

  DatabaseHelper._privateConstructor();
  static DatabaseHelper instance = DatabaseHelper._privateConstructor();

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
    await db.execute('CREATE TABLE trucks (truck_id TEXT PRIMARY KEY, type TEXT NOT NULL)');

    // 2. جدول الحسابات والعملاء المحدث بدعم العملة المزدوجة
    await db.execute('''
      CREATE TABLE accounts (
        account_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        is_permanent INTEGER DEFAULT 0,
        balance_syp REAL DEFAULT 0.0,
        balance_usd REAL DEFAULT 0.0
      )
    ''');

    // 3. جدول سجل الرحلات المحدث بدعم اختيار العملة، أجر السائق والمصاريف
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
        currency TEXT NOT NULL,
        receipt_image_path TEXT,
        net_weight REAL,
        discount_admin REAL,
        driver_wage REAL DEFAULT 0.0
      )
    ''');

    // 4. جدول الصندوق المالي المحدث بحسابين منفصلين تماماً
    await db.execute('''
      CREATE TABLE cashbox (
        transaction_id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        details TEXT,
        income_syp REAL DEFAULT 0.0,
        expense_syp REAL DEFAULT 0.0,
        income_usd REAL DEFAULT 0.0,
        expense_usd REAL DEFAULT 0.0
      )
    ''');
  }
}
extension SetupOperations on DatabaseHelper {
  // ---- عمليات الشاحنات ----
  Future<int> insertTruck(String id, String type) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('trucks', {'truck_id': id, 'type': type}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateTruck(String oldId, String newId, String type) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update('trucks', {'truck_id': newId, 'type': type}, where: 'truck_id = ?', whereArgs: [oldId]);
  }

  Future<int> deleteTruck(String id) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete('trucks', where: 'truck_id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getTrucks() async {
    final db = await DatabaseHelper.instance.database;
    return await db.query('trucks');
  }

  // ---- عمليات الحسابات والعملاء ثنائية العملة ----
  Future<int> insertAccount(String name, String type, int isPermanent, double initialBalance, String currency) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('accounts', {
      'name': name,
      'type': type,
      'is_permanent': isPermanent,
      'balance_syp': currency == 'SYP' ? initialBalance : 0.0,
      'balance_usd': currency == 'USD' ? initialBalance : 0.0,
    });
  }

  Future<int> updateAccount(int id, String name, String type, int isPermanent, double balSyp, double balUsd) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update(
      'accounts',
      {'name': name, 'type': type, 'is_permanent': isPermanent, 'balance_syp': balSyp, 'balance_usd': balUsd},
      where: 'account_id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAccount(int id) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete('accounts', where: 'account_id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllAccountsWithBalances() async {
    final db = await DatabaseHelper.instance.database;
    return await db.query('accounts', orderBy: 'name ASC');
  }
}
extension CoreFinanceOperations on DatabaseHelper {
  // ---- تسجيل حركة يدوية في الصندوق مع اختيار العملة ----
  Future<int> insertTransactionMutiCurrency(String details, double amount, String currency, String type) async {
    final db = await DatabaseHelper.instance.database;
    bool isIncome = type == 'income';
    return await db.insert('cashbox', {
      'date': DateTime.now().toIso8601String().split('T').first,
      'details': details,
      'income_syp': (currency == 'SYP' && isIncome) ? amount : 0.0,
      'expense_syp': (currency == 'SYP' && !isIncome) ? amount : 0.0,
      'income_usd': (currency == 'USD' && isIncome) ? amount : 0.0,
      'expense_usd': (currency == 'USD' && !isIncome) ? amount : 0.0,
    });
  }

  // ---- محرك التحويل المالي الذكي بين الحسابين ----
  Future<void> transferBetweenCurrencies(double amountUsd, double rateExchange, String direction) async {
    final db = await DatabaseHelper.instance.database;
    double amountSyp = amountUsd * rateExchange;
    String dateStr = DateTime.now().toIso8601String().split('T').first;

    await db.transaction((txn) async {
      if (direction == 'USD_TO_SYP') {
        await txn.insert('cashbox', {
          'date': dateStr,
          'details': 'تحويل عملة (صادر دولار ووارد ليرة سورية) بسعر صرف $rateExchange',
          'income_syp': amountSyp,
          'expense_syp': 0.0,
          'income_usd': 0.0,
          'expense_usd': amountUsd,
        });
      } else {
        await txn.insert('cashbox', {
          'date': dateStr,
          'details': 'تحويل عملة (صادر ليرة سورية ووارد دولار) بسعر صرف $rateExchange',
          'income_syp': 0.0,
          'expense_syp': amountSyp,
          'income_usd': amountUsd,
          'expense_usd': 0.0,
        });
      }
    });
  }

  Future<int> updateTransaction(int id, String details, double incSyp, double expSyp, double incUsd, double expUsd) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update('cashbox', {
      'details': details,
      'income_syp': incSyp,
      'expense_syp': expSyp,
      'income_usd': incUsd,
      'expense_usd': expUsd
    }, where: 'transaction_id = ?', whereArgs: [id]);
  }

  Future<int> deleteTransaction(int id) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete('cashbox', where: 'transaction_id = ?', whereArgs: [id]);
  }

  Future<Map<String, double>> getDualCashboxBalances() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
        'SELECT SUM(income_syp) as inc_syp, SUM(expense_syp) as exp_syp, SUM(income_usd) as inc_usd, SUM(expense_usd) as exp_usd FROM cashbox'
    );
    double syp = (result.first['inc_syp'] ?? 0.0) - (result.first['exp_syp'] ?? 0.0);
    double usd = (result.first['inc_usd'] ?? 0.0) - (result.first['exp_usd'] ?? 0.0);
    return {'SYP': syp, 'USD': usd};
  }

  Future<List<Map<String, dynamic>>> getCashboxTransactions() async {
    final db = await DatabaseHelper.instance.database;
    return await db.query('cashbox', orderBy: 'transaction_id DESC');
  }

  // ---- ترحيل الرحلة محاسبياً للصندوق بناءً على عملة الفاتورة المحددة والمصاريف ----
  Future<void> insertTripWithAccountingMuti(Map<String, dynamic> tripData, String tripType, double totalBuy, double totalSell, double expenses, String quarryName, String customerName) async {
    final db = await DatabaseHelper.instance.database;
    String currency = tripData['currency'] ?? 'SYP';
    bool isSyp = currency == 'SYP';

    await db.transaction((txn) async {
      await txn.insert('trips', tripData);
      String dateStr = tripData['date'] ?? DateTime.now().toIso8601String().split('T').first;
      String truck = tripData['truck_id'] ?? 'غير محدد';
      String driver = tripData['driver_name'] ?? 'غير محدد';
      double driverWage = tripData['driver_wage'] ?? 0.0;

      if (tripType == 'buy_sell') {
        await txn.insert('cashbox', {
          'date': dateStr, 'details': 'شراء بضاعة - رحلة شاحنة ($truck) بالـ $currency',
          'income_syp': 0.0, 'expense_syp': isSyp ? totalBuy : 0.0,
          'income_usd': 0.0, 'expense_usd': !isSyp ? totalBuy : 0.0,
        });
        await txn.rawUpdate('UPDATE accounts SET balance_${currency.toLowerCase()} = balance_${currency.toLowerCase()} - ? WHERE name = ? AND type = "quarry"', [totalBuy, quarryName]);

        await txn.insert('cashbox', {
          'date': dateStr, 'details': 'بيع بضاعة للزبون ($customerName) - شاحنة ($truck) بالـ $currency',
          'income_syp': isSyp ? totalSell : 0.0, 'expense_syp': 0.0,
          'income_usd': !isSyp ? totalSell : 0.0, 'expense_usd': 0.0,
        });
        await txn.rawUpdate('UPDATE accounts SET balance_${currency.toLowerCase()} = balance_${currency.toLowerCase()} + ? WHERE name = ? AND type = "customer"', [totalSell, customerName]);
      }

      if (driverWage > 0) {
        await txn.insert('cashbox', {
          'date': dateStr, 'details': 'أجرة ومهمة السائق ($driver) بالـ $currency',
          'income_syp': 0.0, 'expense_syp': isSyp ? driverWage : 0.0,
          'income_usd': 0.0, 'expense_usd': !isSyp ? driverWage : 0.0,
        });
        await txn.rawUpdate('UPDATE accounts SET balance_${currency.toLowerCase()} = balance_${currency.toLowerCase()} + ? WHERE name = ? AND type = "driver"', [driverWage, driver]);
      }

      if (expenses > 0) {
        await txn.insert('cashbox', {
          'date': dateStr, 'details': 'مصاريف طريق ووقود شاحنة ($truck) بالـ $currency',
          'income_syp': 0.0, 'expense_syp': isSyp ? expenses : 0.0,
          'income_usd': 0.0, 'expense_usd': !isSyp ? expenses : 0.0,
        });
      }
    });
  }

  Future<int> updateTrip(int id, Map<String, dynamic> tripData) async { final db = await DatabaseHelper.instance.database; return await db.update('trips', tripData, where: 'trip_id = ?', whereArgs: [id]); }
  Future<int> deleteTrip(int id) async { final db = await DatabaseHelper.instance.database; return await db.delete('trips', where: 'trip_id = ?', whereArgs: [id]); }
  Future<List<Map<String, dynamic>>> getTripsWithImages() async { final db = await DatabaseHelper.instance.database; return await db.query('trips', orderBy: 'trip_id DESC'); }
  Future<List<Map<String, dynamic>>> getCashboxByDateRange(String start, String end) async { final db = await DatabaseHelper.instance.database; return await db.query('cashbox', where: 'date >= ? AND date <= ?', whereArgs: [start, end], orderBy: 'transaction_id DESC'); }
  Future<List<Map<String, dynamic>>> getDriverTripsByDateRange(String name, String start, String end) async { final db = await DatabaseHelper.instance.database; return await db.query('trips', where: 'driver_name = ? AND date >= ? AND date <= ?', whereArgs: [name, start, end], orderBy: 'trip_id DESC'); }
  Future<List<Map<String, dynamic>>> searchTripsAdvanced(String q, String? start, String? end) async { final db = await DatabaseHelper.instance.database; String w = "1=1"; List<dynamic> args = []; if (q.isNotEmpty) { w += " AND (truck_id LIKE ? OR driver_name LIKE ? OR material_type LIKE ?)"; args.addAll(['%$q%', '%$q%', '%$q%']); } if (start != null && end != null) { w += " AND (date >= ? AND date <= ?)"; args.addAll([start, end]); } return await db.query('trips', where: w, whereArgs: args, orderBy: 'trip_id DESC'); }
  Future<String> exportDatabaseBackup() async { try { Directory appDocDir = await getApplicationDocumentsDirectory(); String dbPath = join(appDocDir.path, "NaqelCompanyMutiCurrencyV3.db"); File dbFile = File(dbPath); String backupPath = "/storage/emulated/0/Download/Naqel_Backup.db"; await dbFile.copy(backupPath); return "تم حفظ النسخة بنجاح في مجلد التنزيلات العام"; } catch (e) { return "فشل: $e"; } }
  Future<String> importDatabaseBackup() async { try { String backupPath = "/storage/emulated/0/Download/Naqel_Backup.db"; File backupFile = File(backupPath); final db = await DatabaseHelper.instance.database; await db.close(); Directory appDocDir = await getApplicationDocumentsDirectory(); String dbPath = join(appDocDir.path, "NaqelCompanyMutiCurrencyV3.db"); await backupFile.copy(dbPath); return "تم استعادة البيانات بنجاح! أعد تشغيل التطبيق."; } catch (e) { return "فشل: $e"; } }
}
