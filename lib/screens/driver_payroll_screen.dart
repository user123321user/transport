import 'package:flutter/material.dart';
import '../data/database_helper.dart';

class DriverPayrollScreen extends StatefulWidget {
  const DriverPayrollScreen({Key? key}) : super(key: key);

  @override
  State<DriverPayrollScreen> createState() => _DriverPayrollScreenState();
}

class _DriverPayrollScreenState extends State<DriverPayrollScreen> {
  final dbHelper = DatabaseHelper.instance;
  final _driverNameController = TextEditingController();

  List<Map<String, dynamic>> _driverTrips = [];
  int _totalTripsCount = 0;
  double _totalQuantityMoved = 0.0;
  double _totalExpensesGiven = 0.0;
  bool _hasSearched = false;

  void _searchDriverPayroll() async {
    if (_driverNameController.text.trim().isEmpty) return;
    final trips = await dbHelper.getTripsByDriver(_driverNameController.text.trim());

    int count = trips.length;
    double qty = 0.0;
    double exp = 0.0;

    for (var trip in trips) {
      qty += (trip['quantity'] ?? 0.0);
      exp += (trip['discount_admin'] ?? 0.0);
    }

    setState(() {
      _driverTrips = trips;
      _totalTripsCount = count;
      _totalQuantityMoved = qty;
      _totalExpensesGiven = exp;
      _hasSearched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        appBar: AppBar(
          title: const Text('كشف الحساب الأسبوعي للسائقين', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF0D47A1)]),
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _driverNameController,
                          decoration: const InputDecoration(labelText: 'أدخل اسم السائق لجرده', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _searchDriverPayroll,
                        icon: const Icon(Icons.search),
                        label: const Text('جرد الحساب'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A237E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_hasSearched) ...[
                Card(
                  color: Colors.teal.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text('الخلاصة المالية للسائق: ${_driverNameController.text}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Divider(),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('عدد الرحلات المنجزة:'), Text('$_totalTripsCount رحلة')]),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الكميات الكلية:'), Text('$_totalQuantityMoved')]),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('العهد والمصاريف المستلمة:'), Text('${_totalExpensesGiven.toStringAsFixed(0)} ل.س', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: _driverTrips.length,
                    itemBuilder: (context, index) {
                      final item = _driverTrips[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.directions_car, color: Color(0xFF1A237E)),
                          title: Text('شاحنة: ${item['truck_id']} | مادة: ${item['material_type']}'),
                          trailing: Text('مصاريفها: ${(item['discount_admin'] ?? 0.0).toStringAsFixed(0)} ل.س'),
                        ),
                      );
                    },
                  ),
                )
              ] else
                const Expanded(child: Center(child: Text('أدخل اسم السائق واضغط جرد.')))
            ],
          ),
        ),
      ),
    );
  }
}
