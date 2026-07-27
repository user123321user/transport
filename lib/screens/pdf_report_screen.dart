import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart'; // تحتوي على مكتبة جلب خطوط جوجل السحابية آلياً
import '../data/database_helper.dart';

class PdfReportScreen extends StatefulWidget {
  const PdfReportScreen({Key? key}) : super(key: key);

  @override
  State<PdfReportScreen> createState() => _PdfReportScreenState();
}

class _PdfReportScreenState extends State<PdfReportScreen> {
  final dbHelper = DatabaseHelper.instance;
  DateTimeRange? _selectedDateRange;
  String _reportType = 'trips';
  final _nameController = TextEditingController();

  Future<void> _generateAndPrintPdf() async {
    if (_selectedDateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء تحديد نطاق التاريخ أولاً')));
      return;
    }

    String startStr = _selectedDateRange!.start.toIso8601String().split('T').first;
    String endStr = _selectedDateRange!.end.toIso8601String().split('T').first;

    final pdf = pw.Document();
    List<Map<String, dynamic>> data = [];
    String title = "";

    // 1. الحل الجذري للمربعات: جرد وجلب خط (Cairo) العربي سحابياً برمشة عين وبدون أصول يدوية
    final pw.Font arabicFont = await PdfGoogleFonts.cairoRegular();

    if (_reportType == 'trips') {
      title = "تقرير حركة الرحلات الشامل";
      data = await dbHelper.searchTripsAdvanced(_nameController.text.trim(), startStr, endStr);
    } else if (_reportType == 'cashbox') {
      title = "كشف حركة الصندوق المالي";
      data = await dbHelper.getCashboxByDateRange(startStr, endStr);
    } else if (_reportType == 'accounts') {
      title = "كشف أرصدة ديون العملاء والمقالع";
      data = await dbHelper.getAllAccountsWithBalances();
    } else if (_reportType == 'drivers') {
      title = "كشف الحساب الأسبوعي للسائق: ${_nameController.text}";
      data = await dbHelper.getDriverTripsByDateRange(_nameController.text.trim(), startStr, endStr);
    }

    // 2. مصفوفة بيانات الجدول الحسابي
    List<List<String>> tableData = [];

    if (_reportType == 'trips' || _reportType == 'drivers') {
      tableData.add(['رقم الحركة', 'الشاحنة', 'السائق', 'المادة', 'الكمية', 'التاريخ']);
      for (var row in data) {
        tableData.add([
          row['trip_id'].toString(),
          row['truck_id'] ?? '',
          row['driver_name'] ?? '',
          row['material_type'] ?? '',
          row['quantity'].toString(),
          row['date'].toString()
        ]);
      }
    } else if (_reportType == 'cashbox') {
      tableData.add(['رقم القيد', 'البيان', 'الوارد (+)', 'الصادر (-)', 'التاريخ']);
      for (var row in data) {
        tableData.add([
          row['transaction_id'].toString(),
          row['details'] ?? '',
          row['income'].toString(),
          row['expense'].toString(),
          row['date'].toString()
        ]);
      }
    } else if (_reportType == 'accounts') {
      tableData.add(['المعرف', 'اسم العميل', 'التصنيف', 'الرصيد المالي الحالي']);
      for (var row in data) {
        tableData.add([
          row['account_id'].toString(),
          row['name'] ?? '',
          row['type'] ?? '',
          row['balance'].toString()
        ]);
      }
    }

    // 3. دمج التوجيه العربي والتأكد من إرسال الخط لتصحيح إشارات الـ XXXX
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: arabicFont), // الخط العربي يسري على كامل الملف
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl, // الكتابة والترتيب من اليمين لليسار
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(child: pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(height: 6),
                pw.Center(child: pw.Text("الفترة الزمنية من: $startStr إلى: $endStr", style: const pw.TextStyle(fontSize: 12))),
                pw.SizedBox(height: 10),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 14),

                // توليد جدول فليكسيبل متناسق مع الحسابات العربية
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  cellAlignment: pw.Alignment.centerRight,
                  data: tableData,
                ),
              ],
            ),
          );
        },
      ),
    );

    // 4. فتح واجهة الهاتف المباشرة للطباعة أو التصدير كملف
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        appBar: AppBar(
          title: const Text('استخراج طباعة التقارير PDF', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _reportType,
                        decoration: const InputDecoration(labelText: 'اختر قسم الكشف المراد استخراجه طباعته', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'trips', child: Text('جرد سجل الرحلات والحمولات')),
                          DropdownMenuItem(value: 'cashbox', child: Text('كشف قيود الصندوق المالي')),
                          DropdownMenuItem(value: 'accounts', child: Text('كشف ديون العملاء والمقالع')),
                          DropdownMenuItem(value: 'drivers', child: Text('كشف الحساب الأسبوعي للسائقين')),
                        ],
                        onChanged: (val) => setState(() { _reportType = val!; }),
                      ),
                      const SizedBox(height: 12),

                      if (_reportType == 'drivers' || _reportType == 'trips') ...[
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'اسم السائق / أو نص البحث لفلترته بالكشف', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                      ],

                      ElevatedButton.icon(
                        onPressed: () async {
                          final DateTimeRange? picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) setState(() { _selectedDateRange = picked; });
                        },
                        icon: const Icon(Icons.date_range),
                        label: Text(_selectedDateRange == null
                            ? 'اضغط لتحديد تاريخ البداية والنهاية للكشف'
                            : 'من: ${_selectedDateRange!.start.toIso8601String().split('T').first} إلى: ${_selectedDateRange!.end.toIso8601String().split('T').first}'),
                        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                      ),
                      const SizedBox(height: 20),

                      ElevatedButton.icon(
                        onPressed: _generateAndPrintPdf,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('توليد واستخراج ملف PDF والطباعة', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A237E),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 54),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      )
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
