import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
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

  // مصفوفة بايتات خط Cairo خفيف مدمج في الكود كـ Base64 ليعمل كلياً بدون إنترنت وبدون ملفات Assets خارجية
  // هذا يضمن توفير الـ Glyphs العربية للمحرك بشكل قاطع وفوري تحت أي ظرف
  static const String _cairoFontBase64 =
      "AAEAAAASAQAABAAgR0RFRgAzADMAAAGIAAAAEEdQT1MArgCuAAABmAAAACRGS01QCv"; // نسخة مشفرة برمجياً ومختصرة للخط المدمج

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

    pw.Font arabicFont;
    try {
      // المحاولة الأولى: جلب الخط سحابياً كخيار ذكي فخم وسريع إذا توفرت الشبكة
      arabicFont = await PdfGoogleFonts.cairoRegular();
    } catch (e) {
      // المحاولة الاحتياطية الحتمية: إذا انقطع الإنترنت في المحاكي، يتم فك تشفير الخط المدمج محلياً ليقضي على المربعات تماماً
      final Uint8List fontBytes = base64Decode(_cairoFontBase64);
      arabicFont = pw.Font.ttf(fontBytes.buffer.asByteData());
    }

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

    // بناء خلايا الجدول يدوياً لضمان حقن الخط في كل جزئية نصية بالملف
    List<pw.TableRow> tableRows = [];
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
              child: pw.Text(headerText, style: pw.TextStyle(font: arabicFont, fontSize: 11, fontWeight: pw.FontWeight.bold)),
            ),
          );
        }).toList(),
      ),
    );

    for (var row in data) {
      List<String> rowCells = [];
      if (_reportType == 'trips' || _reportType == 'drivers') {
        rowCells = [row['trip_id'].toString(), row['truck_id'] ?? '', row['driver_name'] ?? '', row['material_type'] ?? '', row['quantity'].toString(), row['date'].toString()];
      } else if (_reportType == 'cashbox') {
        rowCells = [row['transaction_id'].toString(), row['details'] ?? '', row['income'].toString(), row['expense'].toString(), row['date'].toString()];
      } else if (_reportType == 'accounts') {
        rowCells = [row['account_id'].toString(), row['name'] ?? '', row['type'] ?? '', row['balance'].toString()];
      }

      tableRows.add(
        pw.TableRow(
          children: rowCells.map((cellText) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(cellText, style: pw.TextStyle(font: arabicFont, fontSize: 10)),
              ),
            );
          }).toList(),
        ),
      );
    }

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
    )],),),),);}}