import 'package:flutter/material.dart';
import '../data/database_helper.dart';

class AddTripScreen extends StatefulWidget {
  const AddTripScreen({Key? key}) : super(key: key);

  @override
  State<AddTripScreen> createState() => _AddTripScreenState();
}

class _AddTripScreenState extends State<AddTripScreen> {
  final dbHelper = DatabaseHelper.instance;

  final _truckIdController = TextEditingController();
  final _driverNameController = TextEditingController();
  final _materialTypeController = TextEditingController();
  final _quantityController = TextEditingController();

  final _buyPriceController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _driverWageController = TextEditingController();

  final _quarryNameController = TextEditingController();
  final _customerNameController = TextEditingController();

  final _fuelExpensesController = TextEditingController();
  final _fuelStationController = TextEditingController();
  final _mechanicExpensesController = TextEditingController();
  final _mechanicWorkshopController = TextEditingController();
  final _paidAmountController = TextEditingController();

  String _tripType = 'buy_sell';
  String _selectedCurrency = 'SYP';
  String _paymentType = 'debt';
  DateTime _selectedTripDate = DateTime.now();

  @override
  void dispose() {
    _truckIdController.dispose(); _driverNameController.dispose(); _materialTypeController.dispose();
    _quantityController.dispose(); _buyPriceController.dispose(); _sellPriceController.dispose();
    _driverWageController.dispose(); _quarryNameController.dispose(); _customerNameController.dispose();
    _fuelExpensesController.dispose(); _fuelStationController.dispose();
    _mechanicExpensesController.dispose(); _mechanicWorkshopController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context, initialDate: _selectedTripDate, firstDate: DateTime(2020), lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedTripDate) {
      setState(() { _selectedTripDate = picked; });
    }
  }
  // دالة فحص لوحة الشاحنة والأسماء وإظهار رسائل التأكيد والمنع قسرياً
  void _checkAndValidateTrip() async {
    String truckId = _truckIdController.text.trim();
    String driver = _driverNameController.text.trim();
    String customer = _customerNameController.text.trim();
    String quarry = _quarryNameController.text.trim();

    if (truckId.isEmpty || driver.isEmpty || customer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال رقم الشاحنة، السائق، والزبون قسرياً'), backgroundColor: Colors.red));
      return;
    }

    // 1. منع الإضافة قسرياً إذا كانت الشاحنة غير مسجلة مسبقاً بالتطبيق
    final List<Map<String, dynamic>> allTrucks = await dbHelper.getTrucks();
    bool truckExists = allTrucks.any((t) => t['truck_id'] == truckId);
    if (!truckExists) {
      _showErrorDialog('رقم الشاحنة ($truckId) غير مسجل في النظام! قُم بتسجيل الشاحنة أولاً من شاشة التأسيس قبل ربطها برحلة.');
      return;
    }

    // جلب قائمة الحسابات والعملاء للفحص المشترك
    final List<Map<String, dynamic>> allAccounts = await dbHelper.getAllAccountsWithBalances();

    // 2. 🌟 قفل الأمان المحاسبي المحدث: التحقق من ميزة السماح بالدَين للزبون 🌟
    final customerAccount = allAccounts.firstWhere(
          (a) => a['name'] == customer && a['type'] == 'customer',
      orElse: () => {},
    );

    // إذا كان الزبون مسجلاً مسبقاً، ولكنه (لا يملك حساب دائم - يسمح بالدَين)، وتم اختيار الدفع بالدَين أو الجزئي:
    if (customerAccount.isNotEmpty && customerAccount['is_permanent'] == 0) {
      if (_paymentType == 'debt' || _paymentType == 'partial') {
        _showErrorDialog('الزبون ($customer) مسجل كـ "حساب عابر/نقدي فقط"! لا يسمح له بالدَين أو الدفع الجزئي. الرجاء تعديل طريقة الدفع إلى "دفع نقدي كامل" أو تحويل حسابه إلى دائم من شاشة التأسيس.');
        return;
      }
    }

    // 3. التحقق من الأسماء المجهولة تماماً وعرض نافذة تأكيد لإنشائها
    List<String> newNames = [];
    if (!allAccounts.any((a) => a['name'] == driver && a['type'] == 'driver')) newNames.add("السائق: $driver");
    if (customerAccount.isEmpty) newNames.add("الزبون الجديد: $customer (سيعتبر حساب دائم افتراضياً عند الموافقة)");
    if (_tripType == 'buy_sell' && quarry.isNotEmpty) {
      if (!allAccounts.any((a) => a['name'] == quarry && a['type'] == 'quarry')) newNames.add("المقلع: $quarry");
    }

    if (newNames.isNotEmpty) {
      _showConfirmationDialog(newNames, _executeSaveTrip);
    } else {
      _executeSaveTrip();
    }
  }


  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.error, color: Colors.red), SizedBox(width: 8), Text('خطأ في التحقق')]),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً'))],
      ),
    );
  }

  void _showConfirmationDialog(List<String> names, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.warning, color: Colors.amber), SizedBox(width: 8), Text('تأكيد إنشاء حسابات جديدة')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الأسماء التالية غير مسجلة بالنظام مسبقاً، هل تريد اعتماد إنشاء حسابات مالية جديدة لها تلقائياً؟'),
            const SizedBox(height: 10),
            ...names.map((name) => Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E)))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء وتصحيح الاسم')),
          ElevatedButton(onPressed: () { Navigator.pop(ctx); onConfirm(); }, child: const Text('نعم، اعتمد وأنشئ الحسابات')),
        ],
      ),
    );
  }
  void _executeSaveTrip() async {
    double qty = double.tryParse(_quantityController.text) ?? 0.0;
    double buyPrice = double.tryParse(_buyPriceController.text) ?? 0.0;
    double sellPrice = double.tryParse(_sellPriceController.text) ?? 0.0;
    double driverWage = double.tryParse(_driverWageController.text) ?? 0.0;
    double fuelAmt = double.tryParse(_fuelExpensesController.text) ?? 0.0;
    double mechAmt = double.tryParse(_mechanicExpensesController.text) ?? 0.0;

    double totalSell = qty * sellPrice;
    double paidCash = _paymentType == 'full' ? totalSell : (_paymentType == 'partial' ? (double.tryParse(_paidAmountController.text) ?? 0.0) : 0.0);

    List<Map<String, dynamic>> fuelList = fuelAmt > 0 ? [{'amount': fuelAmt, 'station_name': _fuelStationController.text.trim().isEmpty ? 'محطة افتراضية' : _fuelStationController.text.trim()}] : [];
    List<Map<String, dynamic>> mechanicList = mechAmt > 0 ? [{'amount': mechAmt, 'workshop_name': _mechanicWorkshopController.text.trim().isEmpty ? 'ورشة افتراضية' : _mechanicWorkshopController.text.trim()}] : [];

    Map<String, dynamic> tripData = {
      'date': _selectedTripDate.toIso8601String().split('T').first, 'truck_id': _truckIdController.text.trim(), 'driver_name': _driverNameController.text.trim(),
      'material_type': _materialTypeController.text.trim(), 'quantity': qty, 'price_per_unit': sellPrice, 'buy_price_per_unit': buyPrice,
      'currency': _selectedCurrency, 'driver_wage': driverWage, 'discount_admin': fuelAmt + mechAmt, 'payment_type': _paymentType, 'paid_amount': paidCash,
    };

    await dbHelper.insertTripWithAccountingAdvanced(tripData, _tripType, buyPrice, sellPrice, fuelList, mechanicList, _quarryNameController.text.trim().isEmpty ? 'مقلع غير محدد' : _quarryNameController.text.trim(), _customerNameController.text.trim(), _paymentType, paidCash);

    _truckIdController.clear(); _driverNameController.clear(); _materialTypeController.clear(); _quantityController.clear(); _buyPriceController.clear(); _sellPriceController.clear(); _driverWageController.clear(); _quarryNameController.clear(); _customerNameController.clear(); _fuelExpensesController.clear(); _fuelStationController.clear(); _mechanicExpensesController.clear(); _mechanicWorkshopController.clear(); _paidAmountController.clear();
    setState(() { _selectedTripDate = DateTime.now(); _paymentType = 'debt'; });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تثبيت بيانات الفاتورة المعتمدة وحفظها بنجاح')));
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = _selectedTripDate.toIso8601String().split('T').first;
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
    appBar: AppBar(
    title: const Text('تسجيل حمولة ورحلة جديدة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), centerTitle: true,
    flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF0D47A1)]))),
    ),
    body: SingleChildScrollView(
    padding: const EdgeInsets.all(16.0),
    child: Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 4,
    child: Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
    children: [
    OutlinedButton.icon(
    onPressed: () => _selectDate(context), icon: const Icon(Icons.calendar_month, color: Color(0xFF1A237E)),
    label: Text('تاريخ الفاتورة: $formattedDate (اضغط لجدولة تاريخ قديم سابق)', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48), side: const BorderSide(color: Color(0xFF1A237E))),
    ),
    const SizedBox(height: 14),
    Row(
    children: [
    Expanded(child: DropdownButtonFormField<String>(value: _tripType, decoration: const InputDecoration(labelText: 'نوع الاتفاق والتشغيل', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'buy_sell', child: Text('تجارة عامة (بيع وشراء بضاعة)')), DropdownMenuItem(value: 'transport_only', child: Text('تقديم خدمة نقل فقط (أجار نقل)'))], onChanged: (val) => setState(() { _tripType = val!; }))),
    const SizedBox(width: 10),
    Expanded(child: DropdownButtonFormField<String>(value: _selectedCurrency, decoration: const InputDecoration(labelText: 'عملة الفاتورة', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'SYP', child: Text('ليرة سورية (SYP)')), DropdownMenuItem(value: 'USD', child: Text('دولار (USD) 💵'))], onChanged: (val) => setState(() => _selectedCurrency = val!))),
    ],
    ),
    const SizedBox(height: 12),
    if (_tripType == 'buy_sell') ...[TextField(controller: _quarryNameController, decoration: const InputDecoration(labelText: 'اسم مقلع الحجارة / الرمل', border: OutlineInputBorder())), const SizedBox(height: 12)],
    TextField(controller: _customerNameController, decoration: const InputDecoration(labelText: 'اسم الشخص أو الزبون المستلم', border: OutlineInputBorder())),
    const SizedBox(height: 12),
    TextField(controller: _truckIdController, decoration: const InputDecoration(labelText: 'رقم الشاحنة / السيارة المسجلة بالنظام', border: OutlineInputBorder())),
    const SizedBox(height: 12),
    TextField(controller: _driverNameController, decoration: const InputDecoration(labelText: 'اسم السائق الفعلي للرحلة', border: OutlineInputBorder())),
    const SizedBox(height: 12),
    TextField(controller: _materialTypeController, decoration: const InputDecoration(labelText: 'نوع المادة المشحونة', border: OutlineInputBorder())),
    const SizedBox(height: 12),
    TextField(controller: _quantityController, decoration: const InputDecoration(labelText: 'الكمية (طن / متر)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
    const SizedBox(height: 12),
    Row(
    children: [
    if (_tripType == 'buy_sell') ...[Expanded(child: TextField(controller: _buyPriceController, decoration: const InputDecoration(labelText: 'سعر الشراء للطن', border: OutlineInputBorder()), keyboardType: TextInputType.number)), const SizedBox(width: 10)],
    Expanded(child: TextField(controller: _sellPriceController, decoration: const InputDecoration(labelText: 'سعر البيع للطن', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
    ],
    ),
    const SizedBox(height: 12),
    TextField(controller: _driverWageController, decoration: const InputDecoration(labelText: 'مهمة / أجر السائق الصافي لهذه الرحلة', border: OutlineInputBorder()), keyboardType: TextInputType.number),
    const SizedBox(height: 16),
    const Divider(),
    Row(children: [Expanded(child: TextField(controller: _fuelExpensesController, decoration: const InputDecoration(labelText: 'قيمة أول تعبئة وقود', border: OutlineInputBorder()), keyboardType: TextInputType.number)), const SizedBox(width: 10), Expanded(child: TextField(controller: _fuelStationController, decoration: const InputDecoration(labelText: 'اسم محطة الوقود', border: OutlineInputBorder())))]),
    const SizedBox(height: 10),
    Row(children: [Expanded(child: TextField(controller: _mechanicExpensesController, decoration: const InputDecoration(labelText: 'قيمة فاتورة الميكانيكي الاولى', border: OutlineInputBorder()), keyboardType: TextInputType.number)), const SizedBox(width: 10), Expanded(child: TextField(controller: _mechanicWorkshopController, decoration: const InputDecoration(labelText: 'اسم ورشة التصليح', border: OutlineInputBorder())))]),
    const SizedBox(height: 16),
    const Divider(),
    DropdownButtonFormField<String>(
    value: _paymentType, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'طريقة تسوية دفع الفاتورة'),
    items: const [DropdownMenuItem(value: 'debt', child: Text('دَين كامل (ترحيل الفاتورة لذمة الزبون)')), DropdownMenuItem(value: 'full', child: Text('دفع نقدي كامل (كاش بالصندوق)')), DropdownMenuItem(value: 'partial', child: Text('دفع نقدي جزئي (دفعة كاش والباقي دَين)'))],
    onChanged: (val) => setState(() => _paymentType = val!),
    ),
    if (_paymentType == 'partial') ...[const SizedBox(height: 12), TextField(controller: _paidAmountController, decoration: const InputDecoration(labelText: 'المبلغ المدفوع كاش الآن', border: OutlineInputBorder(), prefixIcon: Icon(Icons.money)), keyboardType: TextInputType.number)],
    const SizedBox(height: 28),
    ElevatedButton.icon(
    onPressed: _checkAndValidateTrip, // استدعاء دالة الفحص الأمني المانعة
    icon: const Icon(Icons.save_alt, color: Colors.white),
    label: const Text('ترحيل وتثبيت بيانات الفاتورة المطورة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    )
    ],
    ),
    ),
    ),),),);}}