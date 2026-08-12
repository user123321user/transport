import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/material.dart';

class DatabaseHelper {
  static const _databaseName = "NaqelCompanyMutiExpensesV1.db"; // اسم جديد لبناء الهيكل الفرعي
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
    await db.execute('CREATE TABLE trucks (truck_id TEXT PRIMARY KEY, type TEXT NOT NULL)');

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
        discount_admin REAL DEFAULT 0.0,
        driver_wage REAL DEFAULT 0.0,
        payment_type TEXT DEFAULT 'debt',
        paid_amount REAL DEFAULT 0.0
      )
    ''');

    // 4. جدول فواتير الوقود المتعددة التابع للرحلة
    await db.execute('''
      CREATE TABLE trip_fuel (
        fuel_id INTEGER PRIMARY KEY AUTOINCREMENT,
        trip_id INTEGER,
        amount REAL NOT NULL,
        station_name TEXT,
        FOREIGN KEY (trip_id) REFERENCES trips (trip_id) ON DELETE CASCADE
      )
    ''');

    // 5. جدول فواتير الميكانيكي المتعددة التابع للرحلة
    await db.execute('''
      CREATE TABLE trip_mechanic (
        mechanic_id INTEGER PRIMARY KEY AUTOINCREMENT,
        trip_id INTEGER,
        amount REAL NOT NULL,
        workshop_name TEXT,
        FOREIGN KEY (trip_id) REFERENCES trips (trip_id) ON DELETE CASCADE
      )
    ''');

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
  Future<int> insertTruck(String id, String type) async { final db = await DatabaseHelper.instance.database; return await db.insert('trucks', {'truck_id': id, 'type': type}, conflictAlgorithm: ConflictAlgorithm.replace); }
  Future<int> updateTruck(String oldId, String newId, String type) async { final db = await DatabaseHelper.instance.database; return await db.update('trucks', {'truck_id': newId, 'type': type}, where: 'truck_id = ?', whereArgs: [oldId]); }
  Future<int> deleteTruck(String id) async { final db = await DatabaseHelper.instance.database; return await db.delete('trucks', where: 'truck_id = ?', whereArgs: [id]); }
  Future<List<Map<String, dynamic>>> getTrucks() async { final db = await DatabaseHelper.instance.database; return await db.query('trucks'); }

  Future<int> insertAccount(String name, String type, int isPermanent, double initialBalance, String currency) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('accounts', { 'name': name, 'type': type, 'is_permanent': isPermanent, 'balance_syp': currency == 'SYP' ? initialBalance : 0.0, 'balance_usd': currency == 'USD' ? initialBalance : 0.0 });
  }
  Future<int> updateAccount(int id, String name, String type, int isPermanent, double balSyp, double balUsd) async { final db = await DatabaseHelper.instance.database; return await db.update('accounts', {'name': name, 'type': type, 'is_permanent': isPermanent, 'balance_syp': balSyp, 'balance_usd': balUsd}, where: 'account_id = ?', whereArgs: [id]); }
  Future<int> deleteAccount(int id) async { final db = await DatabaseHelper.instance.database; return await db.delete('accounts', where: 'account_id = ?', whereArgs: [id]); }
  Future<List<Map<String, dynamic>>> getAllAccountsWithBalances() async { final db = await DatabaseHelper.instance.database; return await db.query('accounts', orderBy: 'name ASC'); }

  Future<int> insertTransactionMutiCurrency(String details, double amount, String currency, String type) async {
    final db = await DatabaseHelper.instance.database; bool isIncome = type == 'income';
    return await db.insert('cashbox', { 'date': DateTime.now().toIso8601String().split('T').first, 'details': details, 'income_syp': (currency == 'SYP' && isIncome) ? amount : 0.0, 'expense_syp': (currency == 'SYP' && !isIncome) ? amount : 0.0, 'income_usd': (currency == 'USD' && isIncome) ? amount : 0.0, 'expense_usd': (currency == 'USD' && !isIncome) ? amount : 0.0 });
  }
  Future<void> transferBetweenCurrencies(double amountUsd, double rateExchange, String direction) async {
    final db = await DatabaseHelper.instance.database; double amountSyp = amountUsd * rateExchange; String dateStr = DateTime.now().toIso8601String().split('T').first;
    await db.transaction((txn) async {
      if (direction == 'USD_TO_SYP') { await txn.insert('cashbox', {'date': dateStr, 'details': 'تحويل عملة (صادر دولار ووارد ليرة سورية)', 'income_syp': amountSyp, 'expense_syp': 0.0, 'income_usd': 0.0, 'expense_usd': amountUsd}); }
      else { await txn.insert('cashbox', {'date': dateStr, 'details': 'تحويل عملة (صادر ليرة سورية ووارد دولار)', 'income_syp': 0.0, 'expense_syp': amountSyp, 'income_usd': amountUsd, 'expense_usd': 0.0}); }
    });
  }
  Future<Map<String, double>> getDualCashboxBalances() async { final db = await DatabaseHelper.instance.database; final List<Map<String, dynamic>> result = await db.rawQuery('SELECT SUM(income_syp) as inc_syp, SUM(expense_syp) as exp_syp, SUM(income_usd) as inc_usd, SUM(expense_usd) as exp_usd FROM cashbox'); return {'SYP': (result.first['inc_syp'] ?? 0.0) - (result.first['exp_syp'] ?? 0.0), 'USD': (result.first['inc_usd'] ?? 0.0) - (result.first['exp_usd'] ?? 0.0)}; }
  Future<List<Map<String, dynamic>>> getCashboxTransactions() async { final db = await DatabaseHelper.instance.database; return await db.query('cashbox', orderBy: 'transaction_id DESC'); }
}
extension CoreFinanceOperations on DatabaseHelper {

  // دالة الحفظ المتقدمة مع ترحيل مصفوفات تعبئة الوقود والميكانيكي المتعددة
  Future<void> insertTripWithAccountingAdvanced(Map<String, dynamic> tripData, String tripType, double totalBuy, double totalSell, List<Map<String, dynamic>> fuelList, List<Map<String, dynamic>> mechanicList, String quarryName, String customerName, String paymentType, double paidAmount) async {
    final db = await DatabaseHelper.instance.database;
    String currency = tripData['currency'] ?? 'SYP';
    String dateStr = tripData['date'];
    String truck = tripData['truck_id'] ?? 'غير محدد';
    String driver = tripData['driver_name'] ?? 'غير محدد';
    double driverWage = tripData['driver_wage'] ?? 0.0;
    bool isSyp = currency == 'SYP';

    await db.transaction((txn) async {
      int tripId = await txn.insert('trips', tripData);

      // حفظ تكرارات تعبئة الوقود المتعددة
      for (var fuel in fuelList) {
        double amt = fuel['amount'] ?? 0.0;
        String station = fuel['station_name'] ?? 'محطة افتراضية';
        if (amt > 0) {
          await txn.insert('trip_fuel', {'trip_id': tripId, 'amount': amt, 'station_name': station});
          await txn.insert('cashbox', {'date': dateStr, 'details': 'مصروف تعبئة وقود شاحنة ($truck) - محطة ($station)', 'income_syp': 0.0, 'expense_syp': isSyp ? amt : 0.0, 'income_usd': 0.0, 'expense_usd': !isSyp ? amt : 0.0});
          await txn.rawUpdate('UPDATE accounts SET balance_${currency.toLowerCase()} = balance_${currency.toLowerCase()} - ? WHERE name = ? AND type = "station"', [amt, station]);
        }
      }

      // حفظ تكرارات أجور الميكانيكي المتعددة
      for (var mech in mechanicList) {
        double amt = mech['amount'] ?? 0.0;
        String workshop = mech['workshop_name'] ?? 'ورشة افتراضية';
        if (amt > 0) {
          await txn.insert('trip_mechanic', {'trip_id': tripId, 'amount': amt, 'workshop_name': workshop});
          await txn.insert('cashbox', {'date': dateStr, 'details': 'مصروف ميكانيكي وتصليح شاحنة ($truck) - ورشة ($workshop)', 'income_syp': 0.0, 'expense_syp': isSyp ? amt : 0.0, 'income_usd': 0.0, 'expense_usd': !isSyp ? amt : 0.0});
          await txn.rawUpdate('UPDATE accounts SET balance_${currency.toLowerCase()} = balance_${currency.toLowerCase()} - ? WHERE name = ? AND type = "mechanic"', [amt, workshop]);
        }
      }

      // معالجة حسابات البيع والشراء والدفع الجزئي
      if (tripType == 'buy_sell') {
        await txn.rawUpdate('UPDATE accounts SET balance_${currency.toLowerCase()} = balance_${currency.toLowerCase()} - ? WHERE name = ? AND type = "quarry"', [totalBuy, quarryName]);
        double remainingDebt = totalSell - paidAmount;
        if (paidAmount > 0) { await txn.insert('cashbox', {'date': dateStr, 'details': 'دفعة كاش ($paymentType) من الزبون ($customerName)', 'income_syp': isSyp ? paidAmount : 0.0, 'expense_syp': 0.0, 'income_usd': !isSyp ? paidAmount : 0.0, 'expense_usd': 0.0}); }
        if (remainingDebt > 0) { await txn.rawUpdate('UPDATE accounts SET balance_${currency.toLowerCase()} = balance_${currency.toLowerCase()} + ? WHERE name = ? AND type = "customer"', [remainingDebt, customerName]); }
      }
      if (driverWage > 0) { await txn.rawUpdate('UPDATE accounts SET balance_${currency.toLowerCase()} = balance_${currency.toLowerCase()} + ? WHERE name = ? AND type = "driver"', [driverWage, driver]); }
    });
  }

  // دوال جلب قوائم تعبئة الوقود والميكانيكي التابعة لرحلة محددة عند العرض والتعديل
  Future<List<Map<String, dynamic>>> getTripFuels(int tripId) async { final db = await DatabaseHelper.instance.database; return await db.query('trip_fuel', where: 'trip_id = ?', whereArgs: [tripId]); }
  Future<List<Map<String, dynamic>>> getTripMechanics(int tripId) async { final db = await DatabaseHelper.instance.database; return await db.query('trip_mechanic', where: 'trip_id = ?', whereArgs: [tripId]); }

  // دالة مستقلة لإضافة تعبئة وقود جديدة إلى رحلة سابقة في أي وقت من شاشة التعديل
  Future<void> addSingleFuelToTrip(int tripId, double amount, String station, String dateStr, String currency) async {
    final db = await DatabaseHelper.instance.database; bool isSyp = currency == 'SYP';
    await db.transaction((txn) async {
      await txn.insert('trip_fuel', {'trip_id': tripId, 'amount': amount, 'station_name': station});
      await txn.insert('cashbox', {'date': dateStr, 'details': 'إضافة لاحقة: تعبئة وقود - محطة ($station)', 'income_syp': 0.0, 'expense_syp': isSyp ? amount : 0.0, 'income_usd': 0.0, 'expense_usd': !isSyp ? amount : 0.0});
      await txn.rawUpdate('UPDATE accounts SET balance_${currency.toLowerCase()} = balance_${currency.toLowerCase()} - ? WHERE name = ? AND type = "station"', [amount, station]);
    });
  }

  // دالة مستقلة لإضافة فاتورة ميكانيكي جديدة إلى رحلة سابقة في أي وقت من شاشة التعديل
  Future<void> addSingleMechanicToTrip(int tripId, double amount, String workshop, String dateStr, String currency) async {
    final db = await DatabaseHelper.instance.database; bool isSyp = currency == 'SYP';
    await db.transaction((txn) async {
      await txn.insert('trip_mechanic', {'trip_id': tripId, 'amount': amount, 'workshop_name': workshop});
      await txn.insert('cashbox', {'date': dateStr, 'details': 'إضافة لاحقة: إصلاح ميكانيكي - ورشة ($workshop)', 'income_syp': 0.0, 'expense_syp': isSyp ? amount : 0.0, 'income_usd': 0.0, 'expense_usd': !isSyp ? amount : 0.0});
      await txn.rawUpdate('UPDATE accounts SET balance_${currency.toLowerCase()} = balance_${currency.toLowerCase()} - ? WHERE name = ? AND type = "mechanic"', [amount, workshop]);
    });
  }

  Future<int> updateTrip(int id, Map<String, dynamic> tripData) async { final db = await DatabaseHelper.instance.database; return await db.update('trips', tripData, where: 'trip_id = ?', whereArgs: [id]); }
  Future<int> deleteTrip(int id) async { final db = await DatabaseHelper.instance.database; return await db.delete('trips', where: 'trip_id = ?', whereArgs: [id]); }
  Future<List<Map<String, dynamic>>> getTripsWithImages() async { final db = await DatabaseHelper.instance.database; return await db.query('trips', orderBy: 'trip_id DESC'); }
  Future<List<Map<String, dynamic>>> getCashboxByDateRange(String start, String end) async { final db = await DatabaseHelper.instance.database; return await db.query('cashbox', where: 'date >= ? AND date <= ?', whereArgs: [start, end], orderBy: 'transaction_id DESC'); }
  Future<List<Map<String, dynamic>>> getDriverTripsByDateRange(String name, String start, String end) async { final db = await DatabaseHelper.instance.database; return await db.query('trips', where: 'driver_name = ? AND date >= ? AND date <= ?', whereArgs: [name, start, end], orderBy: 'trip_id DESC'); }
  Future<List<Map<String, dynamic>>> searchTripsAdvanced(String q, String? start, String? end) async { final db = await DatabaseHelper.instance.database; String w = "1=1"; List<dynamic> args = []; if (q.isNotEmpty) { w += " AND (truck_id LIKE ? OR driver_name LIKE ? OR material_type LIKE ?)"; args.addAll(['%$q%', '%$q%', '%$q%']); } if (start != null && end != null) { w += " AND (date >= ? AND date <= ?)"; args.addAll([start, end]); } return await db.query('trips', where: w, whereArgs: args, orderBy: 'trip_id DESC'); }
  Future<String> exportDatabaseBackup() async { try { Directory appDocDir = await getApplicationDocumentsDirectory(); String dbPath = join(appDocDir.path, "NaqelCompanyMutiExpensesV1.db"); File dbFile = File(dbPath); String backupPath = "/storage/emulated/0/Download/Naqel_Backup.db"; await dbFile.copy(backupPath); return "تم حفظ النسخة بنجاح"; } catch (e) { return "فشل: $e"; } }
  Future<String> importDatabaseBackup() async { try { String backupPath = "/storage/emulated/0/Download/Naqel_Backup.db"; File backupFile = File(backupPath); final db = await DatabaseHelper.instance.database; await db.close(); Directory appDocDir = await getApplicationDocumentsDirectory(); String dbPath = join(appDocDir.path, "NaqelCompanyMutiExpensesV1.db"); await backupFile.copy(dbPath); return "تم استعادة البيانات بنجاح"; } catch (e) { return "فشل: $e"; } }
}
