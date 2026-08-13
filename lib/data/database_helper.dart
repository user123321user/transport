import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/material.dart';

class DatabaseHelper {
  static const _databaseName = "NaqelCompanyUltimateSystemV1.db"; // اسم جديد نظيف لبناء الهيكل الخالي من العيوب
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
    await db.execute('CREATE TABLE trucks (truck_id TEXT PRIMARY KEY, type TEXT NOT NULL)');

    // 2. جدول الحسابات ثنائي العملة (ليرة ودولار)
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

    // 3. جدول سجل الرحلات المطور الشامل لحقول البيع والشراء والوقود والميكانيكي
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
        price_per_unit REAL,              -- سعر البيع الفردي للطن للزبون
        buy_price_per_unit REAL,          -- سعر الشراء الفردي للطن من المقلع
        currency TEXT NOT NULL,
        receipt_image_path TEXT,
        net_weight REAL,
        discount_admin REAL DEFAULT 0.0,  -- مجموع نفقات الطريق للتقرير
        driver_wage REAL DEFAULT 0.0,
        payment_type TEXT DEFAULT 'debt',
        paid_amount REAL DEFAULT 0.0,
        quarry_name TEXT,
        customer_name TEXT
      )
    ''');

    // 4. جدول فواتير الوقود المتعددة الفرعي
    await db.execute('''
      CREATE TABLE trip_fuel (
        fuel_id INTEGER PRIMARY KEY AUTOINCREMENT,
        trip_id INTEGER,
        amount REAL NOT NULL,
        station_name TEXT,
        FOREIGN KEY (trip_id) REFERENCES trips (trip_id) ON DELETE CASCADE
      )
    ''');

    // 5. جدول فواتير الميكانيكي المتعددة الفرعي
    await db.execute('''
      CREATE TABLE trip_mechanic (
        mechanic_id INTEGER PRIMARY KEY AUTOINCREMENT,
        trip_id INTEGER,
        amount REAL NOT NULL,
        workshop_name TEXT,
        FOREIGN KEY (trip_id) REFERENCES trips (trip_id) ON DELETE CASCADE
      )
    ''');

    // 6. جدول الصندوق المالي المزدوج
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
  // ---- عمليات إدارة الشاحنات ----
  Future<int> insertTruck(String id, String type) async { final db = await DatabaseHelper.instance.database; return await db.insert('trucks', {'truck_id': id, 'type': type}, conflictAlgorithm: ConflictAlgorithm.replace); }
  Future<int> updateTruck(String oldId, String newId, String type) async { final db = await DatabaseHelper.instance.database; return await db.update('trucks', {'truck_id': newId, 'type': type}, where: 'truck_id = ?', whereArgs: [oldId]); }
  Future<int> deleteTruck(String id) async { final db = await DatabaseHelper.instance.database; return await db.delete('trucks', where: 'truck_id = ?', whereArgs: [id]); }
  Future<List<Map<String, dynamic>>> getTrucks() async { final db = await DatabaseHelper.instance.database; return await db.query('trucks'); }

  // ---- عمليات إدارة الحسابات المالية ----
  Future<int> insertAccount(String name, String type, int isPermanent, double initialBalance, String currency) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('accounts', { 'name': name, 'type': type, 'is_permanent': isPermanent, 'balance_syp': currency == 'SYP' ? initialBalance : 0.0, 'balance_usd': currency == 'USD' ? initialBalance : 0.0 });
  }
  Future<int> updateAccount(int id, String name, String type, int isPermanent, double balSyp, double balUsd) async { final db = await DatabaseHelper.instance.database; return await db.update('accounts', {'name': name, 'type': type, 'is_permanent': isPermanent, 'balance_syp': balSyp, 'balance_usd': balUsd}, where: 'account_id = ?', whereArgs: [id]); }
  Future<int> deleteAccount(int id) async { final db = await DatabaseHelper.instance.database; return await db.delete('accounts', where: 'account_id = ?', whereArgs: [id]); }
  Future<List<Map<String, dynamic>>> getAllAccountsWithBalances() async { final db = await DatabaseHelper.instance.database; return await db.query('accounts', orderBy: 'name ASC'); }

  // ---- محرك إدارة الصندوق المالي والتحويل ----
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

  // محرك تسوية الدفعات اليومية المتوازن تلقائياً (قيد مزدوج حقيقي)
  Future<void> insertPaymentWithDoubleEntry(String accountName, String accountType, double amount, String currency, String transactionType) async {
    final db = await DatabaseHelper.instance.database; String dateStr = DateTime.now().toIso8601String().split('T').first; bool isIncome = transactionType == 'income';
    await db.transaction((txn) async {
      String details = isIncome ? 'استلام دفعة نقدية من ($accountName)' : 'تسديد دفعة نقدية إلى ($accountName)';
      await txn.insert('cashbox', { 'date': dateStr, 'details': '$details ($currency)', 'income_syp': (currency == 'SYP' && isIncome) ? amount : 0.0, 'expense_syp': (currency == 'SYP' && !isIncome) ? amount : 0.0, 'income_usd': (currency == 'USD' && isIncome) ? amount : 0.0, 'expense_usd': (currency == 'USD' && !isIncome) ? amount : 0.0 });
      if (isIncome) { await txn.rawUpdate('UPDATE accounts SET balance_${currency.toLowerCase()} = balance_${currency.toLowerCase()} - ? WHERE name = ? AND type = ?', [amount, accountName, accountType]); }
      else { await txn.rawUpdate('UPDATE accounts SET balance_${currency.toLowerCase()} = balance_${currency.toLowerCase()} + ? WHERE name = ? AND type = ?', [amount, accountName, accountType]); }
    });
  }

  Future<Map<String, double>> getDualCashboxBalances() async { final db = await DatabaseHelper.instance.database; final List<Map<String, dynamic>> result = await db.rawQuery('SELECT SUM(income_syp) as inc_syp, SUM(expense_syp) as exp_syp, SUM(income_usd) as inc_usd, SUM(expense_usd) as exp_usd FROM cashbox'); return {'SYP': (result.first['inc_syp'] ?? 0.0) - (result.first['exp_syp'] ?? 0.0), 'USD': (result.first['inc_usd'] ?? 0.0) - (result.first['exp_usd'] ?? 0.0)}; }
  Future<List<Map<String, dynamic>>> getCashboxTransactions() async { final db = await DatabaseHelper.instance.database; return await db.query('cashbox', orderBy: 'transaction_id DESC'); }
  Future<List<Map<String, dynamic>>> getTripFuels(int tripId) async { final db = await DatabaseHelper.instance.database; return await db.query('trip_fuel', where: 'trip_id = ?', whereArgs: [tripId]); }
  Future<List<Map<String, dynamic>>> getTripMechanics(int tripId) async { final db = await DatabaseHelper.instance.database; return await db.query('trip_mechanic', where: 'trip_id = ?', whereArgs: [tripId]); }
}
extension AdvancedFinanceOperations on DatabaseHelper {

  // قفل الأمان: التحقق من وجود الحساب وإنشائه تلقائياً إذا كان مجهولاً
  Future<void> _ensureAccountExists(Transaction txn, String name, String type) async {
    final List<Map<String, dynamic>> res = await txn.query('accounts', where: 'name = ? AND type = ?', whereArgs: [name, type]);
    if (res.isEmpty) { await txn.insert('accounts', {'name': name, 'type': type, 'is_permanent': 1, 'balance_syp': 0.0, 'balance_usd': 0.0}); }
  }

  // محرك ترحيل وإدخال الرحلات المطور مع توزيع فواتير البيع والشراء والوقود المتعددة بالتوازن
  Future<void> insertTripWithAccountingAdvanced(Map<String, dynamic> tripData, String tripType, double buyPricePerUnit, double sellPricePerUnit, List<Map<String, dynamic>> fuelList, List<Map<String, dynamic>> mechanicList, String quarryName, String customerName, String paymentType, double paidAmount) async {
    final db = await DatabaseHelper.instance.database;
    String currency = tripData['currency'] ?? 'SYP'; String dateStr = tripData['date']; String truck = tripData['truck_id']; String driver = tripData['driver_name']; double qty = tripData['quantity'] ?? 0.0; double driverWage = tripData['driver_wage'] ?? 0.0; bool isSyp = currency == 'SYP';
    double totalBuy = qty * buyPricePerUnit; double totalSell = qty * sellPricePerUnit;

    await db.transaction((txn) async {
      await _ensureAccountExists(txn, driver, 'driver');
      await _ensureAccountExists(txn, customerName, 'customer');
      if (tripType == 'buy_sell') await _ensureAccountExists(txn, quarryName, 'quarry');

      Map<String, dynamic> finalTripData = Map<String, dynamic>.from(tripData);
      finalTripData['quarry_name'] = quarryName; finalTripData['customer_name'] = customerName;
      int tripId = await txn.insert('trips', finalTripData);

      for (var fuel in fuelList) {
        double amt = fuel['amount'] ?? 0.0; String station = fuel['station_name'] ?? 'محطة افتراضية';
        if (amt > 0) {
          await _ensureAccountExists(txn, station, 'station');
          await txn.insert('trip_fuel', {'trip_id': tripId, 'amount': amt, 'station_name': station});
          await txn.insert('cashbox', {'date': dateStr, 'details': 'مصروف وقود محطة ($station) - شاحنة ($truck)', 'income_syp': 0.0, 'expense_syp': isSyp ? amt : 0.0, 'income_usd': 0.0, 'expense_usd': !isSyp ? amt : 0.0});
          await txn.rawUpdate('UPDATE accounts SET balance_${currency.toLowerCase()} = balance_${currency.toLowerCase()} - ? WHERE name = ? AND type = "station"', [amt, station]);
        }
      }

      for (var mech in mechanicList) {
        double amt = mech['amount'] ?? 0.0; String workshop = mech['workshop_name'] ?? 'ورشة افتراضية';
        if (amt > 0) {
          await _ensureAccountExists(txn, workshop, 'mechanic');
          await txn.insert('trip_mechanic', {'trip_id': tripId, 'amount': amt, 'workshop_name': workshop});
          await txn.insert('cashbox', {'date': dateStr, 'details': 'مصروف تصليح ورشة ($workshop) - شاحنة ($truck)', 'income_syp': 0.0, 'expense_syp': isSyp ? amt : 0.0, 'income_usd': 0.0, 'expense_usd': !isSyp ? amt : 0.0});
          await txn.rawUpdate('UPDATE accounts SET balance_${currency.toLowerCase()} = balance_${currency.toLowerCase()} - ? WHERE name = ? AND type = "mechanic"', [amt, workshop]);
        }
      }

      if (tripType == 'buy_sell') {
        await txn.rawUpdate('UPDATE accounts SET balance_${currency.toLowerCase()} = balance_${currency.toLowerCase()} - ? WHERE name = ? AND type = "quarry"', [totalBuy, quarryName]);
        double remainingDebt = totalSell - paidAmount;
        if (paidAmount > 0) await txn.insert('cashbox', {'date': dateStr, 'details': 'دفعة كاش من الزبون ($customerName)', 'income_syp': isSyp ? paidAmount : 0.0, 'expense_syp': 0.0, 'income_usd': !isSyp ? paidAmount : 0.0, 'expense_usd': 0.0});
        if (remainingDebt > 0) await txn.rawUpdate('UPDATE accounts SET balance_${currency.toLowerCase()} = balance_${currency.toLowerCase()} + ? WHERE name = ? AND type = "customer"', [remainingDebt, customerName]);
      } else {
        double remainingDebt = totalSell - paidAmount;
        if (paidAmount > 0) await txn.insert('cashbox', {'date': dateStr, 'details': 'كاش أجار نقل من الزبون ($customerName)', 'income_syp': isSyp ? paidAmount : 0.0, 'expense_syp': 0.0, 'income_usd': !isSyp ? paidAmount : 0.0, 'expense_usd': 0.0});
        if (remainingDebt > 0) await txn.rawUpdate('UPDATE accounts SET balance_${currency.toLowerCase()} = balance_${currency.toLowerCase()} + ? WHERE name = ? AND type = "customer"', [remainingDebt, customerName]);
      }
      if (driverWage > 0) await txn.rawUpdate('UPDATE accounts SET balance_${currency.toLowerCase()} = balance_${currency.toLowerCase()} + ? WHERE name = ? AND type = "driver"', [driverWage, driver]);
    });
  }
  // محرك التعديل المحاسبي الذكي والعاكس للقيود الشامل المصلح لغلق الثغرات مئة بالمئة
  Future<void> updateTripWithAccountingAdvanced(int tripId, Map<String, dynamic> oldTrip, Map<String, dynamic> updatedTripData, String tripType, double buyPrice, double sellPrice) async {
    final db = await DatabaseHelper.instance.database;
    await _executeInternalTripReversal(oldTrip, tripType); // عكس وإلغاء الأثر المالي القديم للرحلة بالكامل أولاً

    double qty = updatedTripData['quantity'] ?? 0.0;
    double paidAmount = updatedTripData['paid_amount'] ?? 0.0;

    Map<String, dynamic> finalUpdated = Map<String, dynamic>.from(updatedTripData);
    finalUpdated['quarry_name'] = oldTrip['quarry_name']; finalUpdated['customer_name'] = oldTrip['customer_name'];
    finalUpdated['price_per_unit'] = sellPrice; finalUpdated['buy_price_per_unit'] = buyPrice;

    // إعادة احتساب وترحيل القيود المحدثة الجديدة بالتوازن
    await insertTripWithAccountingAdvanced(finalUpdated, tripType, buyPrice, sellPrice, [], [], oldTrip['quarry_name'] ?? 'مقلع افتراضي', oldTrip['customer_name'] ?? 'زبون افتراضي', updatedTripData['payment_type'] ?? 'debt', paidAmount);
    await db.delete('trips', where: 'trip_id = ?', whereArgs: [tripId]);
  }

  // محرك الحذف المحاسبي الآمن: يصفي حسابات الصندوق والعملاء والمازوت والميكانيكي تماماً فور مسح الرحلة
  Future<void> deleteTripWithAccountingAdvanced(Map<String, dynamic> trip) async {
    final db = await DatabaseHelper.instance.database;
    int tripId = trip['trip_id'];
    String tripType = trip['buy_price_per_unit'] != null ? 'buy_sell' : 'transport_only';

    await db.transaction((txn) async {
      await _executeInternalTripReversal(trip, tripType); // تصفير كامل الأثر المالي للرحلة الممسوحة من الحسابات
      await txn.delete('trips', where: 'trip_id = ?', whereArgs: [tripId]);
    });
  }

  // محرك العكس البرمجي المشترك لإلغاء وتصفير أي أرقام قديمة أو ملغاة من كشوف المحطات والعملاء
  Future<void> _executeInternalTripReversal(Map<String, dynamic> trip, String tripType) async {
    final db = await DatabaseHelper.instance.database;
    String currency = trip['currency'] ?? 'SYP'; String dateStr = trip['date'];
    double qty = trip['quantity'] ?? 0.0;
    double buyP = trip['buy_price_per_unit'] ?? (trip['price_per_unit'] ?? 0.0) * 0.8;
    double sellP = trip['price_per_unit'] ?? 0.0;
    double wage = trip['driver_wage'] ?? 0.0;
    double paid = trip['paid_amount'] ?? 0.0;

    double totalBuy = qty * buyP; double totalSell = qty * sellP;
    double remainingDebt = totalSell - paid;
    bool isSyp = currency == 'SYP';

    if (tripType == 'buy_sell') {
      await db.rawUpdate('UPDATE accounts SET balance_${currency.toLowerCase()} = balance_${currency.toLowerCase()} + ? WHERE name = ? AND type = "quarry"', [totalBuy, trip['quarry_name'] ?? 'مقلع افتراضي']);
      if (paid > 0) await db.insert('cashbox', {'date': dateStr, 'details': 'عكس قيد (إلغاء/تعديل رحلة) - استرجاع كاش', 'income_syp': isSyp ? -paid : 0.0, 'expense_syp': 0.0, 'income_usd': !isSyp ? -paid : 0.0, 'expense_usd': 0.0});
      if (remainingDebt > 0) await db.rawUpdate('UPDATE accounts SET balance_${currency.toLowerCase()} = balance_${currency.toLowerCase()} - ? WHERE name = ? AND type = "customer"', [remainingDebt, trip['customer_name'] ?? 'زبون افتراضي']);
    } else {
      if (paid > 0) await db.insert('cashbox', {'date': dateStr, 'details': 'عكس قيد أجار نقل كاش - استرجاع مالي', 'income_syp': isSyp ? -paid : 0.0, 'expense_syp': 0.0, 'income_usd': !isSyp ? -paid : 0.0, 'expense_usd': 0.0});
      if (remainingDebt > 0) await db.rawUpdate('UPDATE accounts SET balance_${currency.toLowerCase()} = balance_${currency.toLowerCase()} - ? WHERE name = ? AND type = "customer"', [remainingDebt, trip['customer_name'] ?? 'زبون افتراضي']);
    }
    if (wage > 0) await db.rawUpdate('UPDATE accounts SET balance_${currency.toLowerCase()} = balance_${currency.toLowerCase()} - ? WHERE name = ? AND type = "driver"', [wage, trip['driver_name']]);

    // مسح وعكس فواتير الوقود التابعة للرحلة من كشف الحسابات التراكمي للمحطات
    final List<Map<String, dynamic>> fuels = await db.query('trip_fuel', where: 'trip_id = ?', whereArgs: [trip['trip_id']]);
    for (var f in fuels) {
      double amt = f['amount'];
      await db.rawUpdate('UPDATE accounts SET balance_${currency.toLowerCase()} = balance_${currency.toLowerCase()} + ? WHERE name = ? AND type = "station"', [amt, f['station_name']]);
      await db.insert('cashbox', {'date': dateStr, 'details': 'إلغاء قيد قسري: مصروف وقود محطة (${f['station_name']})', 'income_syp': (isSyp) ? amt : 0.0, 'expense_syp': 0.0, 'income_usd': (!isSyp) ? amt : 0.0, 'expense_usd': 0.0});
    }
    // مسح وعكس فواتير الورش والميكانيكي التابعة للرحلة من كشف حساب الورشات
    final List<Map<String, dynamic>> mechanics = await db.query('trip_mechanic', where: 'trip_id = ?', whereArgs: [trip['trip_id']]);
    for (var m in mechanics) {
      double amt = m['amount'];
      await db.rawUpdate('UPDATE accounts SET balance_${currency.toLowerCase()} = balance_${currency.toLowerCase()} + ? WHERE name = ? AND type = "mechanic"', [amt, m['workshop_name']]);
      await db.insert('cashbox', {'date': dateStr, 'details': 'إلغاء قيد قسري: مصروف ميكانيكي ورشة (${m['workshop_name']})', 'income_syp': (isSyp) ? amt : 0.0, 'expense_syp': 0.0, 'income_usd': (!isSyp) ? amt : 0.0, 'expense_usd': 0.0});
    }
  }
  // دالة الإضافة اللاحقة والتكميلية للوقود لأي رحلة سابقة بأي وقت من شاشة السجل
  Future<void> addSingleFuelToTrip(int tripId, double amount, String station, String dateStr, String currency) async {
    final db = await DatabaseHelper.instance.database; bool isSyp = currency == 'SYP';
    await db.transaction((txn) async {
      await _ensureAccountExists(txn, station, 'station');
      await txn.insert('trip_fuel', {'trip_id': tripId, 'amount': amount, 'station_name': station});
      await txn.insert('cashbox', {'date': dateStr, 'details': 'إضافة لاحقة: وقود محطة ($station)', 'income_syp': 0.0, 'expense_syp': isSyp ? amount : 0.0, 'income_usd': 0.0, 'expense_usd': !isSyp ? amount : 0.0});
      await txn.rawUpdate('UPDATE accounts SET balance_${currency.toLowerCase()} = balance_${currency.toLowerCase()} - ? WHERE name = ? AND type = "station"', [amount, station]);
    });
  }

  // دالة الإضافة اللاحقة والتكميلية للميكانيكي لأي رحلة سابقة بأي وقت من شاشة السجل
  Future<void> addSingleMechanicToTrip(int tripId, double amount, String workshop, String dateStr, String currency) async {
    final db = await DatabaseHelper.instance.database; bool isSyp = currency == 'SYP';
    await db.transaction((txn) async {
      await _ensureAccountExists(txn, workshop, 'mechanic');
      await txn.insert('trip_mechanic', {'trip_id': tripId, 'amount': amount, 'workshop_name': workshop});
      await txn.insert('cashbox', {'date': dateStr, 'details': 'إضافة لاحقة: تصليح ورشة ($workshop)', 'income_syp': 0.0, 'expense_syp': isSyp ? amount : 0.0, 'income_usd': 0.0, 'expense_usd': !isSyp ? amount : 0.0});
      await txn.rawUpdate('UPDATE accounts SET balance_${currency.toLowerCase()} = balance_${currency.toLowerCase()} - ? WHERE name = ? AND type = "mechanic"', [amount, workshop]);
    });
  }

  Future<String> exportDatabaseBackup() async { try { Directory appDocDir = await getApplicationDocumentsDirectory(); String dbPath = join(appDocDir.path, "NaqelCompanyUltimateSystemV1.db"); File dbFile = File(dbPath); String backupPath = "/storage/emulated/0/Download/Naqel_Backup.db"; await dbFile.copy(backupPath); return "تم حفظ النسخة الاحتياطية بنجاح"; } catch (e) { return "فشل: $e"; } }
  Future<String> importDatabaseBackup() async { try { String backupPath = "/storage/emulated/0/Download/Naqel_Backup.db"; File backupFile = File(backupPath); final db = await DatabaseHelper.instance.database; await db.close(); Directory appDocDir = await getApplicationDocumentsDirectory(); String dbPath = join(appDocDir.path, "NaqelCompanyUltimateSystemV1.db"); await backupFile.copy(dbPath); return "تم استعادة قاعدة البيانات بنجاح! أعد تشغيل التطبيق."; } catch (e) { return "فشل: $e"; } }
  Future<List<Map<String, dynamic>> > getTripsWithImages() async { final db = await DatabaseHelper.instance.database; return await db.query('trips', orderBy: 'trip_id DESC'); }
  Future<List<Map<String, dynamic>> > getCashboxByDateRange(String start, String end) async { final db = await DatabaseHelper.instance.database; return await db.query('cashbox', where: 'date >= ? AND date <= ?', whereArgs: [start, end], orderBy: 'transaction_id DESC'); }
  Future<List<Map<String, dynamic>> > getDriverTripsByDateRange(String name, String start, String end) async { final db = await DatabaseHelper.instance.database; return await db.query('trips', where: 'driver_name = ? AND date >= ? AND date <= ?', whereArgs: [name, start, end], orderBy: 'trip_id DESC'); }
  Future<List<Map<String, dynamic>> > searchTripsAdvanced(String q, String? start, String? end) async { final db = await DatabaseHelper.instance.database; String w = "1=1"; List<dynamic> args = []; if (q.isNotEmpty) { w += " AND (truck_id LIKE ? OR driver_name LIKE ? OR material_type LIKE ?)"; args.addAll(['%$q%', '%$q%', '%$q%']); } if (start != null && end != null) { w += " AND (date >= ? AND date <= ?)"; args.addAll([start, end]); } return await db.query('trips', where: w, whereArgs: args, orderBy: 'trip_id DESC'); }
}
