import 'package:flutter/material.dart';
import '../data/database_helper.dart';

class TripsSearchScreen extends StatefulWidget {
  const TripsSearchScreen({Key? key}) : super(key: key);

  @override
  State<TripsSearchScreen> createState() => _TripsSearchScreenState();
}

class _TripsSearchScreenState extends State<TripsSearchScreen> {
  final dbHelper = DatabaseHelper.instance;
  final _searchController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // دالة تشغيل استعلام البحث المتقدم من الداتابيز
  void _performTripsSearch() async {
    setState(() { _isLoading = true; });

    String? startStr = _startDate?.toIso8601String().split('T').first;
    String? endStr = _endDate?.toIso8601String().split('T').first;

    final results = await dbHelper.searchTripsAdvanced(
      _searchController.text.trim(),
      startStr,
      endStr,
    );

    setState(() {
      _searchResults = results;
      _isLoading = false;
    });
  }
  // واجهة تعديل حقول الرحلة المسجلة من داخل واجهة نتائج استعلام البحث
  void _showEditTripDialog(Map<String, dynamic> trip) {
    final truckController = TextEditingController(text: trip['truck_id']);
    final driverController = TextEditingController(text: trip['driver_name']);
    final materialController = TextEditingController(text: trip['material_type']);
    final quantityController = TextEditingController(text: trip['quantity']?.toString());
    final wageController = TextEditingController(text: trip['driver_wage']?.toString());
    final expensesController = TextEditingController(text: trip['discount_admin']?.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل البيانات'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: truckController, decoration: const InputDecoration(labelText: 'رقم الشاحنة')),
              TextField(controller: driverController, decoration: const InputDecoration(labelText: 'اسم السائق')),
              TextField(controller: materialController, decoration: const InputDecoration(labelText: 'نوع المادة')),
              TextField(controller: quantityController, decoration: const InputDecoration(labelText: 'الكمية (طن / متر)'), keyboardType: TextInputType.number),
              TextField(controller: wageController, decoration: const InputDecoration(labelText: 'مهمة / أجرة السائق'), keyboardType: TextInputType.number),
              TextField(controller: expensesController, decoration: const InputDecoration(labelText: 'إجمالي مصاريف الرحلة'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              Map<String, dynamic> updatedData = {
                'truck_id': truckController.text.trim(),
                'driver_name': driverController.text.trim(),
                'material_type': materialController.text.trim(),
                'quantity': double.tryParse(quantityController.text) ?? 0.0,
                'driver_wage': double.tryParse(wageController.text) ?? 0.0,
                'discount_admin': double.tryParse(expensesController.text) ?? 0.0,
              };

              await dbHelper.updateTrip(trip['trip_id'], updatedData);
              Navigator.pop(ctx);
              _performTripsSearch(); // إعادة تحديث الفلترة تلقائياً لترى البيانات المحدثة فوراً
            },
            child: const Text('حفظ'),
          )
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        appBar: AppBar(
          title: const Text('البحث المتقدم في الرحلات', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          centerTitle: true,
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
              // كارت أدوات البحث والفلاتر الزمنية ونطاق التاريخ
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(labelText: 'ابحث برقم الشاحنة، السائق، أو نوع المادة', border: OutlineInputBorder(), prefixIcon: Icon(Icons.search)),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final DateTimeRange? picked = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _startDate = picked.start;
                                    _endDate = picked.end;
                                  });
                                }
                              },
                              icon: const Icon(Icons.date_range),
                              label: Text(_startDate == null
                                  ? 'حدد تاريخ التاريخ'
                                  : 'من: ${_startDate!.toIso8601String().split('T').first} إلى: ${_endDate!.toIso8601String().split('T').first}'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _performTripsSearch,
                        icon: const Icon(Icons.manage_search),
                        label: const Text('بحث', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerRight, child: Text('نتائج البحث:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              const SizedBox(height: 8),

              // عرض بطاقات النتائج المبحوث عنها وتزويدها بالأزرار التفاعلية لحل المشكلة
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _searchResults.isEmpty
                    ? const Center(child: Text('لا يوجد نتائج.'))
                    : ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final trip = _searchResults[index];
                    String currencySymbol = trip['currency'] == 'USD' ? '\$' : 'ل.س';
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.local_shipping, color: Color(0xFF1A237E)),
                        title: Text('شاحنة رقم: ${trip['truck_id']} - مادة: ${trip['material_type'] ?? "بدون مادة"}'),
                        subtitle: Text('الأجرة: ${trip['driver_wage'] ?? 0} $currencySymbol | المصاريف: ${trip['discount_admin'] ?? 0} $currencySymbol'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // زر التعديل الفوري المحقون بداخل واجهة البحث المتقدم
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showEditTripDialog(trip),
                            ),
                            // زر الحذف الفوري المحقون بداخل واجهة البحث المتقدم
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                await dbHelper.deleteTrip(trip['trip_id']);
                                _performTripsSearch(); // تحديث فوري ديناميكي للنتائج
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
