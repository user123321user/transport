import 'package:flutter/material.dart';
import '../data/database_helper.dart';

class AddTripScreen extends StatefulWidget {
  const AddTripScreen({Key? key}) : super(key: key);

  @override
  State<AddTripScreen> createState() => _AddTripScreenState();
}

class _AddTripScreenState extends State<AddTripScreen> {
  final dbHelper = DatabaseHelper.instance;

  // تعريف كواشف النصوص (Controllers) لكافة الحقول المطلوبة بالرحلة
  final _truckIdController = TextEditingController();
  final _driverNameController = TextEditingController();
  final _materialTypeController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _driverWageController = TextEditingController();
  final _expensesController = TextEditingController();

  String _tripType = 'buy_sell';
  String _selectedCurrency = 'SYP'; // المتغير الأساسي لاختيار العملة للرحلة (SYP أو USD)
  String _quarryName = '';
  String _customerName = '';

  @override
  void dispose() {
    _truckIdController.dispose();
    _driverNameController.dispose();
    _materialTypeController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _driverWageController.dispose();
    _expensesController.dispose();
    super.dispose();
  }
  void _saveTrip() async {
    if (_truckIdController.text.isEmpty || _driverNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال رقم الشاحنة واسم السائق كحد أدنى')));
      return;
    }

    double qty = double.tryParse(_quantityController.text) ?? 0.0;
    double price = double.tryParse(_priceController.text) ?? 0.0;
    double driverWage = double.tryParse(_driverWageController.text) ?? 0.0;
    double exp = double.tryParse(_expensesController.text) ?? 0.0;

    double totalBuy = qty * price * 0.8;
    double totalSell = qty * price;

    // تجهيز مصفوفة البيانات بالكامل وحقن نوع العملة المحددة (دولار أو سوري)
    Map<String, dynamic> tripData = {
      'date': DateTime.now().toIso8601String().split('T').first,
      'truck_id': _truckIdController.text.trim(),
      'driver_name': _driverNameController.text.trim(),
      'material_type': _materialTypeController.text.trim(),
      'quantity': qty,
      'price_per_unit': price,
      'currency': _selectedCurrency, // ترحيل نوع العملة المختارة
      'driver_wage': driverWage,
      'discount_admin': exp,
    };

    // استدعاء الدالة المحدثة ثنائية العملة من الداتابيز
    await dbHelper.insertTripWithAccountingMuti(
        tripData,
        _tripType,
        totalBuy,
        totalSell,
        exp,
        _quarryName.isEmpty ? 'مقلع افتراضي' : _quarryName,
        _customerName.isEmpty ? 'زبون افتراضي' : _customerName
    );

    _truckIdController.clear();
    _driverNameController.clear();
    _materialTypeController.clear();
    _quantityController.clear();
    _priceController.clear();
    _driverWageController.clear();
    _expensesController.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل الرحلة بالعملة المحددة وترحيل الحسابات بنجاح')));
    }
  }
  @override
  Widget build(BuildContext context) {
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
                  DropdownButtonFormField<String>(
                    value: _tripType,
                    decoration: const InputDecoration(labelText: 'نوع الاتفاق والرحلة', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'buy_sell', child: Text('تجارة عامة (شراء وبيع حمولة)')),
                      DropdownMenuItem(value: 'transport_only', child: Text('تقديم خدمة نقل فقط (أجار نقل)')),
                    ],
                    onChanged: (val) => setState(() => _tripType = val!),
                  ),
                  const SizedBox(height: 12),
                  // حقل اختيار العملة المدمج للرحلة بالتساوي
                  DropdownButtonFormField<String>(
                    value: _selectedCurrency,
                    decoration: const InputDecoration(labelText: 'عملة الفاتورة والأسعار للرحلة', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'SYP', child: Text('ليرة سورية (SYP)')),
                      DropdownMenuItem(value: 'USD', child: Text('دولار أمريكي (USD) 💵')),
                    ],
                    onChanged: (val) => setState(() => _selectedCurrency = val!),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: _truckIdController, decoration: const InputDecoration(labelText: 'رقم الشاحنة / السيارة', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: _driverNameController, decoration: const InputDecoration(labelText: 'اسم السائق الفعلي', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: _materialTypeController, decoration: const InputDecoration(labelText: 'نوع المادة المشحونة (بحص، رمل...)', border: OutlineInputBorder())),
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
                  const SizedBox(height: 12),
                  TextField(controller: _expensesController, decoration: const InputDecoration(labelText: 'إجمالي مصاريف الرحلة التشغيلية (وقود / طريق)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _saveTrip,
                    icon: const Icon(Icons.save_alt, color: Colors.white),
                    label: const Text('ترحيل وتثبيت بيانات الرحلة مالياً', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
