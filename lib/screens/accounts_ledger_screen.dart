import 'package:flutter/material.dart';
import '../data/database_helper.dart';

class AccountsLedgerScreen extends StatefulWidget {
  const AccountsLedgerScreen({Key? key}) : super(key: key);

  @override
  State<AccountsLedgerScreen> createState() => _AccountsLedgerScreenState();
}

class _AccountsLedgerScreenState extends State<AccountsLedgerScreen> {
  final dbHelper = DatabaseHelper.instance;

  // كاشف نصوص الفلترة والبحث الفوري بداخل دفتر الأستاذ وكشوفات الديون
  final _ledgerSearchController = TextEditingController();
  String _ledgerSearchQuery = '';

  @override
  void dispose() {
    _ledgerSearchController.dispose();
    super.dispose();
  }
  void _showEditAccountDialog(int id, String currentName, String currentType, int isPermanent, double balSyp, double balUsd) {
    final nameController = TextEditingController(text: currentName);
    final sypController = TextEditingController(text: balSyp.toString());
    final usdController = TextEditingController(text: balUsd.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل أرصدة كشف دفتر الأستاذ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم الجهة')),
            const SizedBox(height: 8),
            TextField(controller: sypController, decoration: const InputDecoration(labelText: 'رصيد ليرة سورية (SYP)'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: usdController, decoration: const InputDecoration(labelText: 'رصيد دولار أمريكي (USD)'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              await dbHelper.updateAccount(
                  id,
                  nameController.text.trim(),
                  currentType,
                  isPermanent,
                  double.tryParse(sypController.text) ?? 0.0,
                  double.tryParse(usdController.text) ?? 0.0
              );
              Navigator.pop(ctx);
              setState(() {}); // تحديث فوري للكشف
            },
            child: const Text('حفظ التعديلات'),
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
          title: const Text('دفتر الأستاذ وكشوفات الديون العامة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          centerTitle: true,
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
              // 🔍 شريط البحث الذكي التفاعلي للفلترة أثناء الكتابة فوراً 🔍
              TextField(
                controller: _ledgerSearchController,
                decoration: const InputDecoration(
                  labelText: 'ابحث باسم الزبون، المقلع، السائق، أو المحطة...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search, color: Color(0xFF1A237E)),
                ),
                onChanged: (value) {
                  setState(() {
                    _ledgerSearchQuery = value.trim().toLowerCase();
                  });
                },
              ),
              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerRight, child: Text('كشوف الذمم المالية المتراكمة حالياً:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueGrey))),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: dbHelper.getAllAccountsWithBalances(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    if (snapshot.data!.isEmpty) return const Center(child: Text('لا توجد حسابات مسجلة بعد في دفتر الأستاذ.'));

                    // تصفية كشوفات الديون والأسماء تلقائياً بناءً على محرك البحث
                    final filteredLedger = snapshot.data!.where((item) {
                      String name = (item['name'] ?? '').toString().toLowerCase();
                      return name.contains(_ledgerSearchQuery);
                    }).toList();

                    if (filteredLedger.isEmpty) return const Center(child: Text('لا توجد نتائج تطابق نص البحث المكتوب.'));

                    return ListView.builder(
                      itemCount: filteredLedger.length,
                      itemBuilder: (context, index) {
                        final item = filteredLedger[index];
                        int accId = item['account_id'];
                        double sypBal = item['balance_syp'] ?? 0.0;
                        double usdBal = item['balance_usd'] ?? 0.0;

                        // ترجمة نوع التصنيف للعربية بشكل أنيق بالواجهة
                        String typeArabic = item['type'] == 'customer' ? 'زبون' : (item['type'] == 'quarry' ? 'مقلع' : (item['type'] == 'station' ? 'محطة' : (item['type'] == 'driver' ? 'سائق' : 'ميكانيكي')));

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: const Icon(Icons.account_balance_wallet, color: Color(0xFF1A237E)),
                            title: Text('${item['name']} ($typeArabic)'),
                            subtitle: Text('سوري: ${sypBal.toStringAsFixed(0)} ل.س | دولار: \$ ${usdBal.toStringAsFixed(1)}'),
                              // التعديل المصلح: الإبقاء على الحذف (أو إخفاؤه أيضاً حسب رغبتك) وإلغاء زر التعديل العشوائي
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // تم إخفاء وعزل زر الـ edit من هنا لضمان التوازن المحاسبي عبر شاشة الصندوق حصراً
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () async {
                                      await dbHelper.deleteAccount(accId);
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ),
                                                        ),
                        );
                      },
                    );
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
