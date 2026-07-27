import 'package:flutter/material.dart';
import '../data/database_helper.dart';

class AccountsLedgerScreen extends StatefulWidget {
  const AccountsLedgerScreen({Key? key}) : super(key: key);

  @override
  State<AccountsLedgerScreen> createState() => _AccountsLedgerScreenState();
}

class _AccountsLedgerScreenState extends State<AccountsLedgerScreen> {
  final dbHelper = DatabaseHelper.instance;

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
        backgroundColor: const Color(0xFFF5F7FB),
        appBar: AppBar(
          title: const Text('كشوفات الحسابات وجرد الديون', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF0D47A1)]),
            ),
          ),
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: dbHelper.getAllAccountsWithBalances(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            if (snapshot.data!.isEmpty) return const Center(child: Text('لا توجد حسابات مسجلة حالياً.'));

            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final account = snapshot.data![index];
                double balance = account['balance'] ?? 0.0;
                bool isPermanent = account['is_permanent'] == 1;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: balance >= 0 ? Colors.green.shade100 : Colors.red.shade100,
                      child: Icon(
                        account['type'] == 'customer' ? Icons.person : Icons.business,
                        color: balance >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                    title: Text(account['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('التصنيف: ${_getArabicType(account['type'])} | ${isPermanent ? "حساب دائم" : "نقدي فوري"}'),
                    trailing: Text(
                      '${balance.toStringAsFixed(0)} ل.س',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
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
