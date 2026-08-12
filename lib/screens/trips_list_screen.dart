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

  Future<void> _showImageSourceSelection(int tripId) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(padding: EdgeInsets.all(16.0), child: Text('اختر مصدر صورة إيصال الوزن:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              const Divider(height: 1),
              ListTile(leading: const Icon(Icons.camera_alt, color: Color(0xFF1A237E)), title: const Text('التقاط بواسطة الكاميرا الآن'), onTap: () { Navigator.pop(ctx); _processAndSaveReceiptImage(tripId, ImageSource.camera); }),
              ListTile(leading: const Icon(Icons.photo_library, color: Colors.teal), title: const Text('اختيار صورة من معرض الصور'), onTap: () { Navigator.pop(ctx); _processAndSaveReceiptImage(tripId, ImageSource.gallery); }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processAndSaveReceiptImage(int tripId, ImageSource source) async {
    final XFile? selectedFile = await _picker.pickImage(source: source);
    if (selectedFile != null) {
      final directory = await getApplicationDocumentsDirectory();
      final String permanentPath = '${directory.path}/receipt_${tripId}_${DateTime.now().millisecondsSinceEpoch}.png';
      final File savedImage = await File(selectedFile.path).copy(permanentPath);
      final db = await dbHelper.database;
      await db.update('trips', {'receipt_image_path': savedImage.path}, where: 'trip_id = ?', whereArgs: [tripId]);
      setState(() {});
    }
  }
  // دالة تعديل الحقول الأساسية للرحلة (تمت إعادتها وربطها بالكامل لتصحيح المشكلة)
  void _showEditTripDialog(Map<String, dynamic> trip) {
    final truckController = TextEditingController(text: trip['truck_id']);
    final driverController = TextEditingController(text: trip['driver_name']);
    final materialController = TextEditingController(text: trip['material_type']);
    final quantityController = TextEditingController(text: trip['quantity']?.toString());
    final wageController = TextEditingController(text: trip['driver_wage']?.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل حقول معلومات الرحلة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: truckController, decoration: const InputDecoration(labelText: 'رقم الشاحنة')),
              TextField(controller: driverController, decoration: const InputDecoration(labelText: 'اسم السائق')),
              TextField(controller: materialController, decoration: const InputDecoration(labelText: 'نوع المادة')),
              TextField(controller: quantityController, decoration: const InputDecoration(labelText: 'الكمية'), keyboardType: TextInputType.number),
              TextField(controller: wageController, decoration: const InputDecoration(labelText: 'أجرة السائق المستحقة'), keyboardType: TextInputType.number),
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

  void _showAddExpenseDialog(int tripId, String type, String currency, String dateStr) {
    final amountController = TextEditingController();
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(type == 'fuel' ? 'إضافة فاتورة تعبئة وقود جديدة' : 'إضافة فاتورة إصلاح ميكانيكي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: amountController, decoration: const InputDecoration(labelText: 'المبلغ المالي'), keyboardType: TextInputType.number),
            TextField(controller: nameController, decoration: InputDecoration(labelText: type == 'fuel' ? 'اسم محطة الوقود' : 'اسم ورشة التصليح')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              double amt = double.tryParse(amountController.text) ?? 0.0;
              String name = nameController.text.trim();
              if (amt > 0 && name.isNotEmpty) {
                if (type == 'fuel') { await dbHelper.addSingleFuelToTrip(tripId, amt, name, dateStr, currency); }
                else { await dbHelper.addSingleMechanicToTrip(tripId, amt, name, dateStr, currency); }
                Navigator.pop(ctx);
                setState(() {});
              }
            },
            child: const Text('تثبيت وإضافة الفاتورة'),
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
          title: const Text('سجل الرحلات ومصاريف الطرق المتعددة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          centerTitle: true,
          flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF0D47A1)]))),
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
                int tripId = trip['trip_id'];
                String currency = trip['currency'] ?? 'SYP';
                String dateStr = trip['date'];

                return Card(
                  margin: const EdgeInsets.all(10),
                  child: ExpansionTile(
                    leading: const Icon(Icons.local_shipping, color: Color(0xFF1A237E)),
                    title: Text('شاحنة رقم: ${trip['truck_id']} - التاريخ: $dateStr'),
                    subtitle: Text('السائق: ${trip['driver_name']} | أجر السائق: ${trip['driver_wage']} $currency'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // إعادة حقن زر التعديل المفقود لتصحيح المشكلة بالكامل
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showEditTripDialog(trip),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async { await dbHelper.deleteTrip(tripId); setState(() {}); },
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('⛽ سجل فواتير تعبئة الوقود على الطريق:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                            FutureBuilder<List<Map<String, dynamic>>>(
                              future: dbHelper.getTripFuels(tripId),
                              builder: (context, fSnap) {
                                if (!fSnap.hasData || fSnap.data!.isEmpty) return const Text('لا توجد فواتير وقود مسجلة بعد لهذه الرحلة.');
                                return Column(children: fSnap.data!.map((f) => Text('• تم تعبئة بمبلغ: ${f['amount']} $currency من محطة: ${f['station_name']}')).toList());
                              },
                            ),
                            Row(children: [TextButton.icon(onPressed: () => _showAddExpenseDialog(tripId, 'fuel', currency, dateStr), icon: const Icon(Icons.add, size: 16), label: const Text('إضافة تعبئة وقود جديدة للرحلة'))]),
                            const SizedBox(height: 12),

                            const Text('🛠️ سجل فواتير الميكانيكي والتصليحات:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                            FutureBuilder<List<Map<String, dynamic>>>(
                              future: dbHelper.getTripMechanics(tripId),
                              builder: (context, mSnap) {
                                if (!mSnap.hasData || mSnap.data!.isEmpty) return const Text('لا توجد فواتير تصليح مسجلة بعد لهذه الرحلة.');
                                return Column(children: mSnap.data!.map((m) => Text('• تصليح بمبلغ: ${m['amount']} $currency في ورشة: ${m['workshop_name']}')).toList());
                              },
                            ),
                            Row(children: [TextButton.icon(onPressed: () => _showAddExpenseDialog(tripId, 'mechanic', currency, dateStr), icon: const Icon(Icons.add, size: 16), label: const Text('إضافة فاتورة تصليح ميكانيكي لاحقة'))]),
                            const SizedBox(height: 16),

                            if (trip['receipt_image_path'] != null && File(trip['receipt_image_path']).existsSync())
                              Image.file(File(trip['receipt_image_path']), height: 180, width: double.infinity, fit: BoxFit.cover),
                            const SizedBox(height: 12),
                            Center(child: ElevatedButton.icon(onPressed: () => _showImageSourceSelection(tripId), icon: const Icon(Icons.add_a_photo), label: const Text('إرفاق / تغيير صورة إيصال قبان الوزن')))
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
