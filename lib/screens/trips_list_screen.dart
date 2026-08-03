import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../data/database_helper.dart';

class TripsListScreen extends StatefulWidget {
  const TripsListScreen({Key? key}) : super(key: key);

  @override
  State<TripsListScreen> createState() => _TripsListScreenState();
}

class _TripsListScreenState extends State<TripsListScreen> {
  final dbHelper = DatabaseHelper.instance;
  final ImagePicker _picker = ImagePicker();

  Future<void> _captureAndSaveReceipt(int tripId) async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);

    if (photo != null) {
      final directory = await getApplicationDocumentsDirectory();
      final String permanentPath = '${directory.path}/receipt_$tripId.png';
      final File savedImage = await File(photo.path).copy(permanentPath);

      final db = await dbHelper.database;
      await db.update('trips', {'receipt_image_path': savedImage.path}, where: 'trip_id = ?', whereArgs: [tripId]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التقاط الإيصال وحفظه بنجاح على الجهاز')));
        setState(() {});
      }
    }
  }

  void _showEditTripDialog(Map<String, dynamic> trip) {
    final truckController = TextEditingController(text: trip['truck_id']);
    final driverController = TextEditingController(text: trip['driver_name']);
    final materialController = TextEditingController(text: trip['material_type']);
    final quantityController = TextEditingController(text: trip['quantity']?.toString());
    final priceController = TextEditingController(text: trip['price_per_unit']?.toString());
    final wageController = TextEditingController(text: trip['driver_wage']?.toString() ?? '0');
    final expensesController = TextEditingController(text: trip['discount_admin']?.toString() ?? '0'); // حقل المصاريف المسترجع

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل بيانات الحقول للرحلة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: truckController, decoration: const InputDecoration(labelText: 'رقم الشاحنة')),
              TextField(controller: driverController, decoration: const InputDecoration(labelText: 'اسم السائق')),
              TextField(controller: materialController, decoration: const InputDecoration(labelText: 'نوع المادة')),
              TextField(controller: quantityController, decoration: const InputDecoration(labelText: 'الكمية'), keyboardType: TextInputType.number),
              TextField(controller: priceController, decoration: const InputDecoration(labelText: 'سعر الوحدة'), keyboardType: TextInputType.number),
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
                'price_per_unit': double.tryParse(priceController.text) ?? 0.0,
                'driver_wage': double.tryParse(wageController.text) ?? 0.0,
                'discount_admin': double.tryParse(expensesController.text) ?? 0.0, // حفظ المصاريف المعدلة
              };

              await dbHelper.updateTrip(trip['trip_id'], updatedData);
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('حفظ التعديلات'),
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
          title: const Text('سجل الرحلات وإيصالات الوزن', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF0D47A1)]),
            ),
          ),
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: dbHelper.getTripsWithImages(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            if (snapshot.data!.isEmpty) return const Center(child: Text('لا توجد رحلات مسجلة حتى الآن.'));

            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final trip = snapshot.data![index];
                final String? imgPath = trip['receipt_image_path'];

                return Card(
                  margin: const EdgeInsets.all(10),
                  child: ExpansionTile(
                    leading: const Icon(Icons.local_shipping, color: Color(0xFF1A237E)),
                    title: Text('شاحنة رقم: ${trip['truck_id']} - ${trip['material_type'] ?? "بدون مادة"}'),
                    subtitle: Text('الأجرة: ${trip['driver_wage'] ?? 0} | المصاريف: ${trip['discount_admin'] ?? 0} | الكمية: ${trip['quantity']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showEditTripDialog(trip),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await dbHelper.deleteTrip(trip['trip_id']);
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            imgPath != null && File(imgPath).existsSync()
                                ? Image.file(File(imgPath), height: 200, width: double.infinity, fit: BoxFit.cover)
                                : const Text('لا توجد صورة إيصال مرفقة لهذه الرحلة.'),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () => _captureAndSaveReceipt(trip['trip_id']),
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('تصوير وصل الوزن بالكاميرا'),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
