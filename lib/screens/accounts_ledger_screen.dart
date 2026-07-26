import 'package:flutter/material.dart';
import '../data/database_helper.dart';

class AccountsLedgerScreen extends StatefulWidget {
  const AccountsLedgerScreen({Key? key}) : super(key: key);

  @override
  State<AccountsLedgerScreen> createState() => _AccountsLedgerScreenState();
}

class _AccountsLedgerScreenState extends State<AccountsLedgerScreen> {
  final dbHelper = DatabaseHelper.instance;

  // دالة تحويل اسم التصنيف النصي إلى لغة عربية مفهومة للمستخدم
  String _getArabicType(String type) {
    switch (type) {
      case 'customer': return 'زبون تداول';
      case 'quarry': return 'مقلع حجارة/رمل';
      case 'station': return 'محطة وقود';
      case 'mechanic': return 'ورشة / ميكانيكي';
      case 'driver': return 'سائق شاحنة';
      default: return 'جهات أخرى';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('كشوفات الحسابات وجرد الديون')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: dbHelper.getAllAccountsWithBalances(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            if (snapshot.data!.isEmpty) return const Center(child: Text('لا توجد حسابات أو عملاء مسجلين بالنظام حالياً.'));

            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final account = snapshot.data![index];
                double balance = account['balance'] ?? 0.0;
                bool isPermanent = account['is_permanent'] == 1;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: balance >= 0 ? Colors.green.shade100 : Colors.red.shade100,
                      child: Icon(
                        account['type'] == 'customer' ? Icons.person : Icons.business,
                        color: balance >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                    title: Text(
                      account['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('التصنيف: ${_getArabicType(account['type'])}'),
                        Text(
                          isPermanent ? 'نوع الحساب: دائم (ذو ذمة مالية)' : 'نوع الحساب: مؤقت (نقدي فوري)',
                          style: TextStyle(color: isPermanent ? Colors.blue.shade700 : Colors.grey),
                        ),
                      ],
                    ),
                    trailing: Text(
                      '${balance.toStringAsFixed(0)} ل.س',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: balance >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
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
