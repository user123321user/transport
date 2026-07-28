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
                    subtitle: Text('السائق: ${trip['driver_name']} | الكمية: ${trip['quantity']}'),
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
