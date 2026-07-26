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

  // دالة البحث وجرد حساب السائق من قاعدة بيانات الجهاز
  void _searchDriverPayroll() async {
    if (_driverNameController.text.trim().isEmpty) return;

    final trips = await dbHelper.getTripsByDriver(_driverNameController.text.trim());

    int count = trips.length;
    double qty = 0.0;
    double exp = 0.0;

    for (var trip in trips) {
      qty += (trip['quantity'] ?? 0.0);
      exp += (trip['discount_admin'] ?? 0.0); // تم تخزين مصاريف الرحلة في هذا الحقل
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
        appBar: AppBar(title: const Text('كشف الحساب الأسبوعي للسائقين')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // قسم البحث باسم السائق
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _driverNameController,
                          decoration: const InputDecoration(
                            labelText: 'أدخل اسم السائق المراد جرده أسبوعياً',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _searchDriverPayroll,
                        icon: const Icon(Icons.search),
                        label: const Text('جرد الحساب'),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // عرض خلاصة الحساب المالي والإحصائي للسائق
              if (_hasSearched) ...[
                Card(
                  color: Colors.teal.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text('الخلاصة المالية للسائق: ${_driverNameController.text}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Divider(),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('إجمالي عدد الرحلات المنجزة:'), Text('$_totalTripsCount رحلة', style: const TextStyle(fontWeight: FontWeight.bold))]),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('إجمالي الكميات المشحونة الكلية:'), Text('$_totalQuantityMoved (متر / طن)', style: const TextStyle(fontWeight: FontWeight.bold))]),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('إجمالي عهدة المحروقات والمصاريف المستلمة:'), Text('${_totalExpensesGiven.toStringAsFixed(0)} ل.س', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red))]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('تفاصيل الرحلات المدرجة بالكشف الأسبوعي:', style: TextStyle(fontWeight: FontWeight.bold)),

                // قائمة الرحلات المفصلة الخاصة بهذا السائق
                Expanded(
                  child: _driverTrips.isEmpty
                      ? const Center(child: Text('لا توجد رحلات مسجلة لهذا السائق.'))
                      : ListView.builder(
                    itemCount: _driverTrips.length,
                    itemBuilder: (context, index) {
                      final item = _driverTrips[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.directions_car, color: Colors.teal),
                          title: Text('شاحنة: ${item['truck_id']} | المادة: ${item['material_type']}'),
                          subtitle: Text('التحميل: ${item['loading_place']} ➔ التنزيل: ${item['unloading_place']}'),
                          trailing: Text('مصاريفها: ${(item['discount_admin'] ?? 0.0).toStringAsFixed(0)} ل.س'),
                        ),
                      );
                    },
                  ),
                )
              ] else
                const Expanded(child: Center(child: Text('الرجاء إدخال اسم السائق والضغط على جرد الحساب لعرض البيانات.')))
            ],
          ),
        ),
      ),
    );
  }
}
