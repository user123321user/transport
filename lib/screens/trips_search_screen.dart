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
    _performSearch();
  }

  void _performSearch() async {
    String? startStr = _selectedDateRange?.start.toIso8601String().split('T').first;
    String? endStr = _selectedDateRange?.end.toIso8601String().split('T').first;

    final results = await dbHelper.searchTripsAdvanced(_searchController.text.trim(), startStr, endStr);
    setState(() { _searchResults = results; });
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) {
      setState(() { _selectedDateRange = picked; });
      _performSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        appBar: AppBar(
          title: const Text('البحث المتقدم وفلترة الرحلات', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
                onChanged: (_) => _performSearch(),
              ),
              const SizedBox(height: 12),
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
                    IconButton(icon: const Icon(Icons.history_toggle_off, color: Colors.red), onPressed: () { setState(() { _selectedDateRange = null; }); _performSearch(); })
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
              Expanded(
                child: _searchResults.isEmpty
                    ? const Center(child: Text('لا توجد نتائج مطابقة لخيارات البحث الحالية.'))
                    : ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final item = _searchResults[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.manage_search, color: Color(0xFF1A237E)),
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
