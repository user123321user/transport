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

  // قائمة تخزين الرحلات المسترجعة للسائق المحدد
  List<Map<String, dynamic>> _driverTrips = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _driverNameController.dispose();
    super.dispose();
  }
  // الدالة المصححة برمجياً والتي تقضي على خطأ الـ Compilation الفاشل
  void _fetchDriverData() async {
    String driverName = _driverNameController.text.trim();
    if (driverName.isEmpty) return;

    setState(() { _isLoading = true; });

    // الحل الهندسي: استخدام المحرك المتقدم للبحث باسم السائق مباشرة في الداتابيز المحدثة
    final trips = await dbHelper.searchTripsAdvanced(driverName, null, null);

    setState(() {
      _driverTrips = trips;
      _isLoading = false;
    });
  }
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        appBar: AppBar(
          title: const Text('كشف مستحقات ورواتب السائقين', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _driverNameController,
                          decoration: const InputDecoration(labelText: 'أدخل اسم السائق لجرد حساب رحلاته', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _fetchDriverData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A237E),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(80, 54),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Icon(Icons.search),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerRight, child: Text('سجل ومهمات الرحلات التابعة للسائق:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              const SizedBox(height: 8),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _driverTrips.isEmpty
                    ? const Center(child: Text('لا توجد رحلات مسجلة لهذا الاسم، أو حقل البحث فارغ.'))
                    : ListView.builder(
                  itemCount: _driverTrips.length,
                  itemBuilder: (context, index) {
                    final trip = _driverTrips[index];
                    String curr = trip['currency'] ?? 'SYP';
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.assignment, color: Color(0xFF1A237E)),
                        title: Text('رحلة شاحنة رقم: ${trip['truck_id']} | مادة: ${trip['material_type'] ?? "غير محدد"}'),
                        subtitle: Text('التاريخ: ${trip['date']} | الكمية: ${trip['quantity']}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('الأجرة المستحقة:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text(
                              '${trip['driver_wage'] ?? 0} $curr',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14),
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
