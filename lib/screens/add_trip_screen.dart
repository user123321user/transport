import 'package:flutter/material.dart';
import '../data/database_helper.dart';

class AddTripScreen extends StatefulWidget {
  const AddTripScreen({Key? key}) : super(key: key);

  @override
  State<AddTripScreen> createState() => _AddTripScreenState();
}

class _AddTripScreenState extends State<AddTripScreen> {
  final dbHelper = DatabaseHelper.instance;
  final _formKey = GlobalKey<FormState>();

  String _tripType = 'buy_sell';

  final _truckController = TextEditingController();
  final _driverController = TextEditingController();
  final _quarryController = TextEditingController();
  final _customerController = TextEditingController();
  final _materialController = TextEditingController();

  final _quantityController = TextEditingController();
  final _buyPriceController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _expensesController = TextEditingController();

  double _totalBuy = 0.0;
  double _totalSell = 0.0;
  double _netProfit = 0.0;

  void _calculateTotals() {
    double qty = double.tryParse(_quantityController.text) ?? 0.0;
    double buyPrice = double.tryParse(_buyPriceController.text) ?? 0.0;
    double sellPrice = double.tryParse(_sellPriceController.text) ?? 0.0;
    double expenses = double.tryParse(_expensesController.text) ?? 0.0;

    setState(() {
      if (_tripType == 'buy_sell') {
        _totalBuy = qty * buyPrice;
        _totalSell = qty * sellPrice;
        _netProfit = _totalSell - (_totalBuy + expenses);
      } else {
        _totalBuy = 0.0;
        _totalSell = qty * sellPrice;
        _netProfit = _totalSell - expenses;
      }
    });
  }

  void _saveTripData() async {
    if (!_formKey.currentState!.validate()) return;

    Map<String, dynamic> trip = {
      'date': DateTime.now().toIso8601String().split('T').first,
      'truck_id': _truckController.text.trim(),
      'driver_name': _driverController.text.trim(),
      'loading_place': _quarryController.text.trim(),
      'unloading_place': _customerController.text.trim(),
      'material_type': _materialController.text.trim(),
      'quantity': double.tryParse(_quantityController.text) ?? 0.0,
      'price_per_unit': double.tryParse(_sellPriceController.text) ?? 0.0,
      'discount_admin': double.tryParse(_expensesController.text) ?? 0.0,
    };

    double qty = double.tryParse(_quantityController.text) ?? 0.0;
    double buyPrice = double.tryParse(_buyPriceController.text) ?? 0.0;
    double sellPrice = double.tryParse(_sellPriceController.text) ?? 0.0;
    double expenses = double.tryParse(_expensesController.text) ?? 0.0;

    await dbHelper.insertTripWithAccounting(
      trip,
      _tripType,
      qty * buyPrice,
      qty * sellPrice,
      expenses,
      _quarryController.text.trim(),
      _customerController.text.trim(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الرحلة، وتحديث الصندوق، وتقييد ديون الحسابات')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        appBar: AppBar(
          title: const Text('تسجيل رحلة جديدة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF0D47A1)]),
            ),
          ),
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'buy_sell', label: Text('بيع وشراء')),
                      ButtonSegment(value: 'transport_only', label: Text('نقل فقط')),
                    ],
                    selected: {_tripType},
                    onSelectionChanged: (Set<String> val) {
                      setState(() {
                        _tripType = val.first;
                        _calculateTotals();
                      });
                    },
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(controller: _truckController, decoration: const InputDecoration(labelText: 'رقم الشاحنة', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'مطلوب' : null),
                const SizedBox(height: 12),
                TextFormField(controller: _driverController, decoration: const InputDecoration(labelText: 'اسم السائق', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'مطلوب' : null),
                const SizedBox(height: 12),
                if (_tripType == 'buy_sell') ...[
                  TextFormField(controller: _quarryController, decoration: const InputDecoration(labelText: ' المصدر', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'مطلوب' : null),
                  const SizedBox(height: 12),
                ],
                TextFormField(controller: _customerController, decoration: const InputDecoration(labelText: 'اسم الزبون / المستلم', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'مطلوب' : null),
                const SizedBox(height: 12),
                TextFormField(controller: _materialController, decoration: const InputDecoration(labelText: 'نوع المادة', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                const Divider(),
                const Text('تفاصيل الرحلة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                TextFormField(controller: _quantityController, decoration: const InputDecoration(labelText: 'الكمية (متر / طن)', border: OutlineInputBorder()), keyboardType: TextInputType.number, onChanged: (_) => _calculateTotals()),
                const SizedBox(height: 12),
                if (_tripType == 'buy_sell') ...[
                  TextFormField(controller: _buyPriceController, decoration: const InputDecoration(labelText: 'سعر الشراء للوحدة', border: OutlineInputBorder()), keyboardType: TextInputType.number, onChanged: (_) => _calculateTotals()),
                  const SizedBox(height: 12),
                ],
                TextFormField(controller: _sellPriceController, decoration: InputDecoration(labelText: _tripType == 'buy_sell' ? 'سعر البيع للوحدة' : 'أجار النقل للوحدة', border: const OutlineInputBorder()), keyboardType: TextInputType.number, onChanged: (_) => _calculateTotals()),
                const SizedBox(height: 12),
                TextFormField(controller: _expensesController, decoration: const InputDecoration(labelText: 'إجمالي مصاريف الرحلة (محروقات + طريق)', border: OutlineInputBorder()), keyboardType: TextInputType.number, onChanged: (_) => _calculateTotals()),
                const SizedBox(height: 20),
                Card(
                  color: Colors.blueGrey.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        if (_tripType == 'buy_sell') Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('إجمالي الشراء:'), Text('${_totalBuy.toStringAsFixed(0)} ل.س')]),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_tripType == 'buy_sell' ? 'إجمالي البيع:' : 'إجمالي أجار النقل:'), Text('${_totalSell.toStringAsFixed(0)} ل.س')]),
                        const Divider(),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text('صافي الربح:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                          Text('${_netProfit.toStringAsFixed(0)} ل.س', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))
                        ]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    onPressed: _saveTripData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(200, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('حفظ الرحلة'),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
