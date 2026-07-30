import 'package:flutter/material.dart';
import '../data/database_helper.dart';

class SystemSetupScreen extends StatefulWidget {
  const SystemSetupScreen({Key? key}) : super(key: key);

  @override
  State<SystemSetupScreen> createState() => _SystemSetupScreenState();
}

class _SystemSetupScreenState extends State<SystemSetupScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final dbHelper = DatabaseHelper.instance;

  final _truckIdController = TextEditingController();
  String _selectedTruckType = 'رأس ومقطورة';

  final _accountNameController = TextEditingController();
  final _initialBalanceController = TextEditingController();
  String _selectedAccountType = 'customer';
  bool _isPermanentAccount = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _truckIdController.dispose();
    _accountNameController.dispose();
    _initialBalanceController.dispose();
    super.dispose();
  }

  void _saveTruck() async {
    if (_truckIdController.text.trim().isEmpty) return;
    await dbHelper.insertTruck(_truckIdController.text.trim(), _selectedTruckType);
    _truckIdController.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الشاحنة بنجاح محلياً')));
    setState(() {});
  }

  void _saveAccount() async {
    if (_accountNameController.text.trim().isEmpty) return;
    double balance = double.tryParse(_initialBalanceController.text) ?? 0.0;

    await dbHelper.insertAccount(
      _accountNameController.text.trim(),
      _selectedAccountType,
      _isPermanentAccount ? 1 : 0,
      balance,
    );

    _accountNameController.clear();
    _initialBalanceController.clear();
    setState(() { _isPermanentAccount = false; });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء الحساب بنجاح في جهازك')));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        appBar: AppBar(
          title: const Text('إعدادات النظام التأسيسية', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF0D47A1)]),
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.amber,
            tabs: const [
              Tab(icon: Icon(Icons.local_shipping), text: 'إدارة الشاحنات'),
              Tab(icon: Icon(Icons.people), text: 'إدارة الحسابات والعملاء'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildTrucksTab(),
            _buildAccountsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildTrucksTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _truckIdController,
                    decoration: const InputDecoration(labelText: 'رقم الشاحنة (مثال: 123)', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedTruckType,
                    decoration: const InputDecoration(labelText: 'نوع الشاحنة', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'رأس ومقطورة', child: Text('رأس ومقطورة')),
                      DropdownMenuItem(value: 'تريلات طويلة', child: Text('شاحنة ذات تريلة طويلة')),
                    ],
                    onChanged: (val) => setState(() => _selectedTruckType = val!),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _saveTruck,
                    icon: const Icon(Icons.add),
                    label: const Text('تسجيل الشاحنة في الجهاز'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Align(alignment: Alignment.centerRight, child: Text(' الشاحنات المسجلة حالياً:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: dbHelper.getTrucks(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final item = snapshot.data![index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.local_shipping, color: Color(0xFF1A237E)),
                        title: Text('شاحنة رقم: ${item['truck_id']}'),
                        subtitle: Text('النوع: ${item['type']}'),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAccountsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: _accountNameController,
                  decoration: const InputDecoration(labelText: 'اسم الشخص / الجهة التعاملية', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedAccountType,
                  decoration: const InputDecoration(labelText: 'تصنيف الحساب المالي', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'customer', child: Text('زبون (مثل: فادي)')),
                    DropdownMenuItem(value: 'quarry', child: Text('مقلع حجارة / رمل')),
                    DropdownMenuItem(value: 'station', child: Text('محطة وقود')),
                    DropdownMenuItem(value: 'mechanic', child: Text('ورشة تصليح / ميكانيكي')),
                    DropdownMenuItem(value: 'driver', child: Text('سائق شاحنة')),
                  ],
                  onChanged: (val) => setState(() => _selectedAccountType = val!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _initialBalanceController,
                  decoration: const InputDecoration(labelText: 'الرصيد الافتتاحي (إن وجد)', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('هل يملك حساب دائم بالشركة؟ (يسمح بالدَين)'),
                  value: _isPermanentAccount,
                  activeColor: const Color(0xFF1A237E),
                  onChanged: (val) => setState(() => _isPermanentAccount = val),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _saveAccount,
                  icon: const Icon(Icons.person_add),
                  label: const Text('إنشاء الحساب المالي محلياً'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text('إدارة وأمان البيانات (نسخ احتياطي يدوياً):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueGrey)),
                ),
                const SizedBox(height: 12),

                ElevatedButton.icon(
                  onPressed: () async {
                    String result = await dbHelper.exportDatabaseBackup();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result), backgroundColor: const Color(0xFF1A237E)));
                    }
                  },
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('أخذ نسخة احتياطية وحفظها في التنزيلات'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                ElevatedButton.icon(
                  onPressed: () async {
                    String result = await dbHelper.importDatabaseBackup();
                    if (context.mounted) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('حالة استعادة البيانات'),
                          content: Text(result),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً'))
                          ],
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.cloud_download),
                  label: const Text('استعادة البيانات من النسخة الاحتياطية'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade800,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


}
