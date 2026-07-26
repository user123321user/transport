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

  List<Map<String, dynamic>> _searchResults = [];
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _performSearch(); // جلب كافة الرحلات عند فتح الشاشة كبداية
  }

  // دالة تنفيذ الفلترة المتقدمة من الجهاز
  void _performSearch() async {
    String? startStr = _selectedDateRange?.start.toIso8601String().split('T').first;
    String? endStr = _selectedDateRange?.end.toIso8601String().split('T').first;

    final results = await dbHelper.searchTripsAdvanced(
      _searchController.text.trim(),
      startStr,
      endStr,
    );

    setState(() {
      _searchResults = results;
    });
  }

  // دالة اختيار نطاق التاريخ (من تاريخ ... إلى تاريخ ...)
  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
      _performSearch(); // تحديث الفلترة تلقائياً بعد اختيار التاريخ
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('البحث المتقدم وفلترة الرحلات')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // شريط البحث النصي للفلترة الذكية
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'ابحث برقم الشاحنة، اسم السائق، أو المادة...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); _performSearch(); })
                      : null,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => _performSearch(), // فلترة فورية أثناء الكتابة
              ),
              const SizedBox(height: 12),

              // أزرار تحديد وتصفية التاريخ
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickDateRange,
                    icon: const Icon(Icons.date_range),
                    label: Text(_selectedDateRange == null
                        ? 'تحديد نطاق التاريخ (جرد دوري)'
                        : 'من: ${_selectedDateRange!.start.toIso8601String().split('T').first} إلى: ${_selectedDateRange!.end.toIso8601String().split('T').first}'),
                  ),
                  if (_selectedDateRange != null)
                    IconButton(
                      icon: const Icon(Icons.history_toggle_off, color: Colors.red),
                      onPressed: () {
                        setState(() { _selectedDateRange = null; });
                        _performSearch();
                      },
                    )
                ],
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('نتائج الفلترة والجرد:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Chip(label: Text('${_searchResults.length} رحلة مطابقة', style: const TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
              const Divider(),

              // عرض نتائج البحث المفلترة
              Expanded(
                child: _searchResults.isEmpty
                    ? const Center(child: Text('لا توجد نتائج مطابقة لخيارات البحث الحالية.'))
                    : ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final item = _searchResults[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: const Icon(Icons.manage_search, color: Colors.indigo),
                        title: Text('شاحنة رقم: ${item['truck_id']} (${item['material_type'] ?? 'بدون مادة'})'),
                        subtitle: Text('السائق: ${item['driver_name']} | التاريخ: ${item['date']}'),
                        trailing: Text('الكمية: ${item['quantity']} طن/متر', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
