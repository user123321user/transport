import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

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
  Future<int> insertAccount(String name, String type, int isPermanent,
      double initialBalance) async {
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
  // ---- دالة حفظ الرحلة المطورة: تقوم بحفظ الرحلة وتحديث الصندوق تلقائياً ----
  // ---- دالة حفظ الرحلة الشاملة: تحديث الرحلات، الصندوق، وأرصدة الديون للعملاء تلقائياً ----
  Future<void> insertTripWithAccounting(Map<String, dynamic> tripData, String tripType, double totalBuy, double totalSell, double expenses, String quarryName, String customerName) async {
    final db = await DatabaseHelper.instance.database;

    await db.transaction((txn) async {
      // 1. حفظ بيانات الرحلة
      await txn.insert('trips', tripData);

      String dateStr = tripData['date'] ?? DateTime.now().toIso8601String().split('T');
      String truck = tripData['truck_id'] ?? 'غير محدد';
      String driver = tripData['driver_name'] ?? 'غير محدد';

      // 2. تحديث الصندوق العام للشركة وحسابات الديون للعملاء والمقالع
      if (tripType == 'buy_sell') {
        // قيد مصروف الشراء في الصندوق
        await txn.insert('cashbox', {
          'date': dateStr,
          'details': 'شراء بضاعة تلقائي - رحلة شاحنة ($truck)',
          'income': 0.0,
          'expense': totalBuy,
        });

        // قيد ذمة مالية (دَين للمقلع): رصيد المقلع يزداد بالسالب (طلب مالي لنا)
        await txn.rawUpdate(
            'UPDATE accounts SET balance = balance - ? WHERE name = ? AND type = "quarry"',
            [totalBuy, quarryName]
        );

        // قيد دخل البيع في الصندوق
        await txn.insert('cashbox', {
          'date': dateStr,
          'details': 'بيع بضاعة للزبون ($customerName) - شاحنة ($truck)',
          'income': totalSell,
          'expense': 0.0,
        });

        // قيد ذمة مالية (دَين على الزبون): رصيد الزبون يزداد بالموجب (مستحقات للشركة)
        await txn.rawUpdate(
            'UPDATE accounts SET balance = balance + ? WHERE name = ? AND type = "customer"',
            [totalSell, customerName]
        );
      } else {
        // في حالة النقل فقط: أجار النقل يدخل الصندوق ويسجل ديناً للشركة على الجهة المستلمة
        await txn.insert('cashbox', {
          'date': dateStr,
          'details': 'إيراد أجار نقل تلقائي للزبون ($customerName)',
          'income': totalSell,
          'expense': 0.0,
        });

        await txn.rawUpdate(
            'UPDATE accounts SET balance = balance + ? WHERE name = ? AND type = "customer"',
            [totalSell, customerName]
        );
      }

      // 3. تسجيل مصاريف الطريق في الصندوق
      if (expenses > 0) {
        await txn.insert('cashbox', {
          'date': dateStr,
          'details': 'مصاريف طريق ووقود - رحلة شاحنة ($truck)',
          'income': 0.0,
          'expense': expenses,
        });
      }
    });
  }


// ---- عمليات الصندوق المالي (Cashbox) ----

// دالة لإدخال حركة مالية يدوية أو تلقائية في الصندوق
  Future<int> insertTransaction(String details, double income,
      double expense) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('cashbox', {
      'date': DateTime.now().toIso8601String().split('T')[0],
      // حفظ التاريخ اليومي فقط
      'details': details,
      'income': income,
      'expense': expense,
    });
  }

// دالة لجلب كافة الحركات المالية المسجلة بالترتيب من الأحدث للأقدم
  Future<List<Map<String, dynamic>>> getCashboxTransactions() async {
    final db = await DatabaseHelper.instance.database;
    return await db.query('cashbox', orderBy: 'transaction_id DESC');
  }

// دالة لحساب الرصيد الإجمالي الحالي المتوفر في الصندوق (الوارد - الصادر)
  Future<double> getCashboxBalance() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
        'SELECT SUM(income) as total_income, SUM(expense) as total_expense FROM cashbox'
    );

    double income = result[0]['total_income'] ?? 0.0;
    double expense = result[0]['total_expense'] ?? 0.0;
    return income - expense;
  }
  // ---- دالة جلب الرحلات المخزنة مع صور الإيصالات ----
  Future<List<Map<String, dynamic>>> getTripsWithImages() async {
    final db = await DatabaseHelper.instance.database;
    return await db.query('trips', orderBy: 'trip_id DESC');
  }
  // ---- دالة جلب كافة الحسابات والجهات التعاملية مع أرصدتها المحدثة ----
  Future<List<Map<String, dynamic>>> getAllAccountsWithBalances() async {
    final db = await DatabaseHelper.instance.database;
    return await db.query('accounts', orderBy: 'balance DESC');
  }

  // ---- دالة تحديث رصيد حساب معين عند الدفع أو القبض النقدي ----
  Future<int> updateAccountBalance(int accountId, double amount, String type) async {
    final db = await DatabaseHelper.instance.database;

    // جلب الرصيد الحالي أولاً
    List<Map<String, dynamic>> res = await db.query('accounts', where: 'account_id = ?', whereArgs: [accountId]);
    if (res.isEmpty) return 0;

    double currentBalance = res.first['balance'] ?? 0.0;
    double newBalance = type == 'add' ? currentBalance + amount : currentBalance - amount;

    return await db.update(
      'accounts',
      {'balance': newBalance},
      where: 'account_id = ?',
      whereArgs: [accountId],
    );
  }
  // ---- دالة جلب رحلات سائق معين لحساب كشفه الأسبوعي ----
  Future<List<Map<String, dynamic>>> getTripsByDriver(String driverName) async {
    final db = await DatabaseHelper.instance.database;
    return await db.query(
        'trips',
        where: 'driver_name = ?',
        whereArgs: [driverName],
        orderBy: 'trip_id DESC'
    );
  }
  // ---- دالة البحث المتقدم والفلترة بالتاريخ والنصوص للرحلات ----
  Future<List<Map<String, dynamic>>> searchTripsAdvanced(String query, String? startDate, String? endDate) async {
    final db = await DatabaseHelper.instance.database;

    String whereClause = "1=1";
    List<dynamic> whereArgs = [];

    // الفلترة بنص البحث (اسم السائق أو رقم الشاحنة أو نوع المادة)
    if (query.isNotEmpty) {
      whereClause += " AND (truck_id LIKE ? OR driver_name LIKE ? OR material_type LIKE ?)";
      whereArgs.addAll(['%$query%', '%$query%', '%$query%']);
    }

    // الفلترة بنطاق تاريخ محدد
    if (startDate != null && endDate != null) {
      whereClause += " AND (date >= ? AND date <= ?)";
      whereArgs.addAll([startDate, endDate]);
    }

    return await db.query('trips', where: whereClause, whereArgs: whereArgs, orderBy: 'trip_id DESC');
  }

}