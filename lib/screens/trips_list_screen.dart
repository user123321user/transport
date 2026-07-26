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

  // دالة تشغيل الكاميرا وحفظ الصورة في مكان آمن على الجهاز
  Future<void> _captureAndSaveReceipt(int tripId) async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);

    if (photo != null) {
      // 1. الحصول على مجلد التخزين الدائم على نظام الجهاز
      final directory = await getApplicationDocumentsDirectory();
      final String permanentPath = '${directory.path}/receipt_$tripId.png';

      // 2. نسخ الصورة المؤقتة إلى المسار الدائم خارج التطبيق
      final File savedImage = await File(photo.path).copy(permanentPath);

      // 3. تحديث مسار الصورة في جدول الرحلات بقاعدة البيانات
      final db = await dbHelper.database;
      await db.update(
        'trips',
        {'receipt_image_path': savedImage.path},
        where: 'trip_id = ?',
        whereArgs: [tripId],
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم التقاط الإيصال الورقي وحفظه بنجاح على الجهاز')),
      );
      setState(() {}); // إعادة بناء الواجهة لعرض الصورة فوراً
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('سجل الرحلات وإيصالات الوزن')),
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
                    leading: const Icon(Icons.local_shipping, color: Colors.blue),
                    title: Text('رحلة شاحنة رقم: ${trip['truck_id']} - ${trip['material_type']}'),
                    subtitle: Text('السائق: ${trip['driver_name']} | الكمية: ${trip['quantity']}'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            // عرض الصورة إذا كانت مخزنة على الجهاز أو إظهار زر الالتقاط
                            imgPath != null && File(imgPath).existsSync()
                                ? Image.file(File(imgPath), height: 200, fit: BoxFit.cover)
                                : const Text('لا توجد صورة إيصال ورقبان وزن مرفقة لهذه الرحلة.'),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () => _captureAndSaveReceipt(trip['trip_id']),
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('تصوير وصل الوزن / الإيصال بالكاميرا'),
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
