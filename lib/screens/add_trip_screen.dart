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
  final _loadingController = TextEditingController();
  final _unloadingController = TextEditingController();
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
      'date': DateTime.now().toIso8601String().split('T')[0],
      'truck_id': _truckController.text.trim(),
      'driver_name': _driverController.text.trim(),
      'loading_place': _loadingController.text.trim(),
      'unloading_place': _unloadingController.text.trim(),
      'material_type': _materialController.text.trim(),
      'quantity': double.tryParse(_quantityController.text) ?? 0.0,
      'price_per_unit': double.tryParse(_sellPriceController.text) ?? 0.0,
      'discount_admin': double.tryParse(_expensesController.text) ?? 0.0,
    };

    await dbHelper.insertTrip(trip);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تسجيل وحفظ بيانات الرحلة تلقائياً بالجهاز')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تسجيل رحلة شاحنة جديدة')),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'buy_sell', label: Text('بيع وشراء بضاعة')),
                    ButtonSegment(value: 'transport_only', label: Text('نقل فقط (أجار)')),
                  ],
                  selected: {_tripType},
                  onChanged: (val) {
                    setState(() {
                      _tripType = val.first;
                      _calculateTotals();
                    });
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(controller: _truckController, decoration: const InputDecoration(labelText: 'رقم الشاحنة'), validator: (v) => v!.isEmpty ? 'مطلوب' : null),
                TextFormField(controller: _driverController, decoration: const InputDecoration(labelText: 'اسم السائق'), validator: (v) => v!.isEmpty ? 'مطلوب' : null),
                TextFormField(controller: _loadingController, decoration: const InputDecoration(labelText: 'مكان التحميل')),
                TextFormField(controller: _unloadingController, decoration: const InputDecoration(labelText: 'مكان التنزيل / الزبون')),
                TextFormField(controller: _materialController, decoration: const InputDecoration(labelText: 'نوع المادة')),
                const SizedBox(height: 16),
                const Divider(),
                TextFormField(controller: _quantityController, decoration: const InputDecoration(labelText: 'الكمية (متر / طن)'), keyboardType: TextInputType.number, onChanged: (_) => _calculateTotals()),
                if (_tripType == 'buy_sell')
                  TextFormField(controller: _buyPriceController, decoration: const InputDecoration(labelText: 'سعر الشراء للوحدة'), keyboardType: TextInputType.number, onChanged: (_) => _calculateTotals()),
                TextFormField(controller: _sellPriceController, decoration: InputDecoration(labelText: _tripType == 'buy_sell' ? 'سعر البيع للوحدة' : 'أجار الوحدة أو النقلة'), keyboardType: TextInputType.number, onChanged: (_) => _calculateTotals()),
                TextFormField(controller: _expensesController, decoration: const InputDecoration(labelText: 'إجمالي مصاريف الرحلة'), keyboardType: TextInputType.number, onChanged: (_) => _calculateTotals()),
                const SizedBox(height: 20),
                Card(
                  color: Colors.blueGrey.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        if (_tripType == 'buy_sell') Row(alignment: MainAxisAlignment.spaceBetween, children: [const Text('إجمالي الشراء:'), Text('${_totalBuy.toStringAsFixed(0)} ل.س')]),
                        Row(alignment: MainAxisAlignment.spaceBetween, children: [Text(_tripType == 'buy_sell' ? 'إجمالي البيع:' : 'إجمالي أجار النقل:'), Text('${_totalSell.toStringAsFixed(0)} ل.س')]),
                        const Divider(),
                        Row(alignment: MainAxisAlignment.spaceBetween, children: [
                          const Text('صافي الربح المتوقع:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                          Text('${_netProfit.toStringAsFixed(0)} ل.س', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))
                        ]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton(onPressed: _saveTripData, child: const Text('حفظ الرحلة محلياً')),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
