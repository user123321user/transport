import 'package:flutter/material.dart';
import '../data/database_helper.dart';

class AddTripScreen extends StatefulWidget {
  const AddTripScreen({Key? key}) : super(key: key);

  @override
  State<AddTripScreen> createState() => _AddTripScreenState();
}

class _AddTripScreenState extends State<AddTripScreen> {
  final dbHelper = DatabaseHelper.instance;

  // كواشف النصوص الأساسية للحمولة
  final _truckIdController = TextEditingController();
  final _driverNameController = TextEditingController();
  final _materialTypeController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _driverWageController = TextEditingController();

  // كواشف المصاريف المبدئية عند التأسيس
  final _fuelExpensesController = TextEditingController();
  final _fuelStationController = TextEditingController();
  final _mechanicExpensesController = TextEditingController();
  final _mechanicWorkshopController = TextEditingController();

  // كاشف حقل الدفع النقدي/الجزئي
  final _paidAmountController = TextEditingController();

  // متغيرات الاختيارات التشغيلية
  String _tripType = 'buy_sell';
  String _selectedCurrency = 'SYP';
  String _paymentType = 'debt'; // debt (دين)، full (كامل)، partial (جزئي)

  // المتغير الخاص بالتاريخ: افتراضياً يحمل تاريخ اليوم الحالي، ويقبل التغيير لتاريخ قديم
  DateTime _selectedTripDate = DateTime.now();

  @override
  void dispose() {
    _truckIdController.dispose(); _driverNameController.dispose(); _materialTypeController.dispose();
    _quantityController.dispose(); _priceController.dispose(); _driverWageController.dispose();
    _fuelExpensesController.dispose(); _fuelStationController.dispose();
    _mechanicExpensesController.dispose(); _mechanicWorkshopController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedTripDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedTripDate) {
      setState(() { _selectedTripDate = picked; });
    }
  }

  void _saveAdvancedTrip() async {
    if (_truckIdController.text.isEmpty || _driverNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال رقم الشاحنة واسم السائق كحد أدنى')));
      return;
    }

    double qty = double.tryParse(_quantityController.text) ?? 0.0;
    double price = double.tryParse(_priceController.text) ?? 0.0;
    double driverWage = double.tryParse(_driverWageController.text) ?? 0.0;
    double fuelAmt = double.tryParse(_fuelExpensesController.text) ?? 0.0;
    double mechAmt = double.tryParse(_mechanicExpensesController.text) ?? 0.0;

    double totalSell = qty * price;
    double paidCash = 0.0;
    if (_paymentType == 'full') paidCash = totalSell;
    if (_paymentType == 'partial') paidCash = double.tryParse(_paidAmountController.text) ?? 0.0;

    // تحويل تعبئة الوقود الأولى والمبدئية إلى مصفوفة تكرارية متوافقة مع قاعدة البيانات
    List<Map<String, dynamic>> fuelList = [];
    if (fuelAmt > 0) {
      fuelList.add({
        'amount': fuelAmt,
        'station_name': _fuelStationController.text.trim().isEmpty ? 'محطة افتراضية' : _fuelStationController.text.trim()
      });
    }

    // تحويل فاتورة الميكانيكي الأولى والمبدئية إلى مصفوفة تكرارية متوافقة مع قاعدة البيانات
    List<Map<String, dynamic>> mechanicList = [];
    if (mechAmt > 0) {
      mechanicList.add({
        'amount': mechAmt,
        'workshop_name': _mechanicWorkshopController.text.trim().isEmpty ? 'ورشة افتراضية' : _mechanicWorkshopController.text.trim()
      });
    }

    Map<String, dynamic> tripData = {
      'date': _selectedTripDate.toIso8601String().split('T').first,
      'truck_id': _truckIdController.text.trim(),
      'driver_name': _driverNameController.text.trim(),
      'material_type': _materialTypeController.text.trim(),
      'quantity': qty,
      'price_per_unit': price,
      'currency': _selectedCurrency,
      'driver_wage': driverWage,
      'discount_admin': fuelAmt + mechAmt, // مجموع مصاريف التشغيل للتقرير
      'payment_type': _paymentType,
      'paid_amount': paidCash,
    };

    // استدعاء الدالة الحسابية الشاملة والمطورة بداخل الداتابيز
    await dbHelper.insertTripWithAccountingAdvanced(
        tripData, _tripType, qty * price * 0.8, totalSell, fuelList, mechanicList,
        'مقلع افتراضي', 'زبون افتراضي', _paymentType, paidCash
    );

    // تنظيف الحقول وإعادة تعيين التاريخ والخيارات
    _truckIdController.clear(); _driverNameController.clear(); _materialTypeController.clear();
    _quantityController.clear(); _priceController.clear(); _driverWageController.clear();
    _fuelExpensesController.clear(); _fuelStationController.clear();
    _mechanicExpensesController.clear(); _mechanicWorkshopController.clear(); _paidAmountController.clear();

    setState(() {
      _selectedTripDate = DateTime.now();
      _paymentType = 'debt';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل الرحلة بالتاريخ والعملة المحددة بنجاح')));
    }
  }
  @override
  Widget build(BuildContext context) {
    String formattedDate = _selectedTripDate.toIso8601String().split('T').first;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        appBar: AppBar(
          title: const Text('تسجيل حمولة ورحلة جديدة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          centerTitle: true,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF0D47A1)]),
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _selectDate(context),
                    icon: const Icon(Icons.calendar_month, color: Color(0xFF1A237E)),
                    label: Text('تاريخ الرحلة المختار القديم/الحالي: $formattedDate (اضغط للتعديل)', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48), side: const BorderSide(color: Color(0xFF1A237E))),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _tripType,
                          decoration: const InputDecoration(labelText: 'نوع الاتفاق', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'buy_sell', child: Text('تجارة عامة (بيع وشراء)')),
                            DropdownMenuItem(value: 'transport_only', child: Text('تقديم خدمة نقل (أجار)')),
                          ],
                          onChanged: (val) => setState(() => _tripType = val!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedCurrency,
                          decoration: const InputDecoration(labelText: 'العملة', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'SYP', child: Text('ليرة سورية (SYP)')),
                            DropdownMenuItem(value: 'USD', child: Text('دولار (USD) 💵')),
                          ],
                          onChanged: (val) => setState(() => _selectedCurrency = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: _truckIdController, decoration: const InputDecoration(labelText: 'رقم الشاحنة / السيارة', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: _driverNameController, decoration: const InputDecoration(labelText: 'اسم السائق الفعلي', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: _materialTypeController, decoration: const InputDecoration(labelText: 'نوع المادة المشحونة', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _quantityController, decoration: const InputDecoration(labelText: 'الكمية المدخلة', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: _priceController, decoration: const InputDecoration(labelText: 'سعر المفرد للوحدة', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: _driverWageController, decoration: const InputDecoration(labelText: 'مهمة / أجر السائق الصافي للرحلة', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                  const SizedBox(height: 16),
                  const Divider(),
                  const Align(alignment: Alignment.centerRight, child: Text('إدخال فواتير مصاريف التشغيل التأسيسية للرحلة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _fuelExpensesController, decoration: const InputDecoration(labelText: 'قيمة أول تعبئة وقود', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: _fuelStationController, decoration: const InputDecoration(labelText: 'اسم محطة الوقود', border: OutlineInputBorder()))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _mechanicExpensesController, decoration: const InputDecoration(labelText: 'قيمة فاتورة الميكانيكي الاولى', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: _mechanicWorkshopController, decoration: const InputDecoration(labelText: 'اسم ورشة التصليح', border: OutlineInputBorder()))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const Align(alignment: Alignment.centerRight, child: Text('طريقة إدارة دفع الفاتورة للزبون:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey))),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _paymentType,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'debt', child: Text('دَين كامل (ترحيل الفاتورة بالكامل لذمة الزبون)')),
                      DropdownMenuItem(value: 'full', child: Text('دفع نقدي كامل (استلام كامل القيمة كاش في الصندوق)')),
                      DropdownMenuItem(value: 'partial', child: Text('دفع نقدي جزئي (دفعة كاش والباقي دَين)')),
                    ],
                    onChanged: (val) => setState(() => _paymentType = val!),
                  ),
                  if (_paymentType == 'partial') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _paidAmountController,
                      decoration: const InputDecoration(labelText: 'المبلغ المدفوع نقداً الآن (والباقي سيرحل تلقائياً كدين)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.money)),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    onPressed: _saveAdvancedTrip,
                    icon: const Icon(Icons.save_alt, color: Colors.white),
                    label: const Text('ترحيل وتثبيت بيانات الرحلة المطورة مالياً', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
