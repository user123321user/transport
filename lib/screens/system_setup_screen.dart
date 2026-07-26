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
        appBar: AppBar(
          title: const Text('إعدادات النظام التأسيسية'),
          bottom: TabBar(
            controller: _tabController,
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
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _truckIdController,
                    decoration: const InputDecoration(labelText: 'رقم الشاحنة (مثال: 123)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedTruckType,
                    decoration: const InputDecoration(labelText: 'نوع الشاحنة'),
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
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('الشاحنات المسجلة حالياً:', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: dbHelper.getTrucks(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final item = snapshot.data![index];
                    return ListTile(
                      leading: const Icon(Icons.local_shipping, color: Colors.blue),
                      title: Text('شاحنة رقم: ${item['truck_id']}'),
                      subtitle: Text('النوع: ${item['type']}'),
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: _accountNameController,
                  decoration: const InputDecoration(labelText: 'اسم الشخص / الجهة التعاملية'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedAccountType,
                  decoration: const InputDecoration(labelText: 'تصنيف الحساب المالي'),
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
                  decoration: const InputDecoration(labelText: 'الرصيد الافتتاحي (إن وجد)'),
                  keyboardType: TextInputType.number,
                ),
                SwitchListTile(
                  title: const Text('هل يملك حساب دائم بالشركة؟ (يسمح بالدَين)'),
                  value: _isPermanentAccount,
                  onChanged: (val) => setState(() => _isPermanentAccount = val),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _saveAccount,
                  icon: const Icon(Icons.person_add),
                  label: const Text('إنشاء الحساب المالي محلياً'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
