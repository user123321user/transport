import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // مسؤولة عن قراءة ملف الخط المحلي من الـ Assets
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء تحديد مجال التاريخ أولاً')),
      );
      return;
    }

    String startStr = _selectedDateRange!.start.toIso8601String().split('T').first;
    String endStr = _selectedDateRange!.end.toIso8601String().split('T').first;

    final pdf = pw.Document();
    List<Map<String, dynamic>> data = [];
    String title = "";

    // 1. تحميل بايتات ملف خط Cairo المحلي المضمون والمستقر تماماً
    final ByteData fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
    final pw.Font arabicFont = pw.Font.ttf(fontData);

    if (_reportType == 'trips') {
      title = "تقرير حركة الرحلات الشامل";
      data = await dbHelper.searchTripsAdvanced(_nameController.text.trim(), startStr, endStr);
    } else if (_reportType == 'cashbox') {
      title = "كشف الصندوق المالي";
      data = await dbHelper.getCashboxByDateRange(startStr, endStr);
    } else if (_reportType == 'accounts') {
      title = "كشف أرصدة ديون العملاء والمقالع";
      data = await dbHelper.getAllAccountsWithBalances();
    } else if (_reportType == 'drivers') {
      title = "كشف الحساب الأسبوعي للسائق: ${_nameController.text}";
      data = await dbHelper.getDriverTripsByDateRange(_nameController.text.trim(), startStr, endStr);
    }

    List<pw.TableRow> tableRows = [];

    // العناوين الرئيسية للجدول
    List<String> headers = [];
    if (_reportType == 'trips' || _reportType == 'drivers') {
      headers = ['رقم الحركة', 'الشاحنة', 'السائق', 'المادة', 'الكمية', 'التاريخ'];
    } else if (_reportType == 'cashbox') {
      headers = ['رقم القيد', 'البيان', 'الوارد (+)', 'الصادر (-)', 'التاريخ'];
    } else if (_reportType == 'accounts') {
      headers = ['المعرف', 'اسم العميل', 'التصنيف', 'الرصيد الحالي'];
    }

    tableRows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: headers.map((headerText) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Center(
              child: pw.Text(
                headerText,
                style: pw.TextStyle(font: arabicFont, fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
            ),
          );
        }).toList(),
      ),
    );

    // إضافة البيانات وحقن الخط الموضعي داخل كل خلية نصية على حدة
    for (var row in data) {
      List<String> rowCells = [];
      if (_reportType == 'trips' || _reportType == 'drivers') {
        rowCells = [
          row['trip_id'].toString(),
          row['truck_id'] ?? '',
          row['driver_name'] ?? '',
          row['material_type'] ?? '',
          row['quantity'].toString(),
          row['date'].toString()
        ];
      } else if (_reportType == 'cashbox') {
        rowCells = [
          row['transaction_id'].toString(),
          row['details'] ?? '',
          row['income'].toString(),
          row['expense'].toString(),
          row['date'].toString()
        ];
      } else if (_reportType == 'accounts') {
        rowCells = [
          row['account_id'].toString(),
          row['name'] ?? '',
          row['type'] ?? '',
          row['balance'].toString()
        ];
      }

      tableRows.add(
        pw.TableRow(
          children: rowCells.map((cellText) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  cellText,
                  style: pw.TextStyle(font: arabicFont, fontSize: 10),
                ),
              ),
            );
          }).toList(),
        ),
      );
    }

    // 2. تطبيق التوجيه وإجبار المحرك على استخدام الخط الموضعي
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: arabicFont),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(child: pw.Text(title, style: pw.TextStyle(font: arabicFont, fontSize: 20, fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(height: 6),
                pw.Center(child: pw.Text("الفترة الزمنية من: $startStr إلى: $endStr", style: pw.TextStyle(font: arabicFont, fontSize: 12))),
                pw.SizedBox(height: 10),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 14),

                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  children: tableRows,
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        appBar: AppBar(
          title: const Text('استخراج التقارير PDF', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
                        decoration: const InputDecoration(labelText: 'اختر نوع الكشف المطلوب توليده', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'trips', child: Text('كشف سجل الرحلات والحمولات')),
                          DropdownMenuItem(value: 'cashbox', child: Text('كشف الصندوق المالي')),
                          DropdownMenuItem(value: 'accounts', child: Text('كشف ديون العملاء والمقالع')),
                          DropdownMenuItem(value: 'drivers', child: Text('كشف الحساب للسائقين')),
                        ],
                        onChanged: (val) => setState(() { _reportType = val!; }),
                      ),
                      const SizedBox(height: 12),

                      if (_reportType == 'drivers' || _reportType == 'trips') ...[
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'اسم السائق', border: OutlineInputBorder()),
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
                            ? 'اضغط لتحديد مجال التاريخ للكشف'
                            : 'من: ${_selectedDateRange!.start.toIso8601String().split('T').first} إلى: ${_selectedDateRange!.end.toIso8601String().split('T').first}'),
                        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                      ),
                      const SizedBox(height: 20),

                      ElevatedButton.icon(
                        onPressed: _generateAndPrintPdf,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('استخراج ملف PDF', style: TextStyle(fontWeight: FontWeight.bold)),
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
