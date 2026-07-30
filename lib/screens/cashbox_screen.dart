import 'package:flutter/material.dart';
import '../data/database_helper.dart';

class CashboxScreen extends StatefulWidget {
  const CashboxScreen({Key? key}) : super(key: key);

  @override
  State<CashboxScreen> createState() => _CashboxScreenState();
}

class _CashboxScreenState extends State<CashboxScreen> {
  final dbHelper = DatabaseHelper.instance;
  double _currentBalance = 0.0;

  final _detailsController = TextEditingController();
  final _amountController = TextEditingController();
  String _transactionType = 'income';

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    double balance = await dbHelper.getCashboxBalance();
    setState(() { _currentBalance = balance; });
  }

  void _saveTransaction() async {
    if (_detailsController.text.trim().isEmpty || _amountController.text.trim().isEmpty) return;

    double amount = double.tryParse(_amountController.text) ?? 0.0;
    double inc = _transactionType == 'income' ? amount : 0.0;
    double exp = _transactionType == 'expense' ? amount : 0.0;

    await dbHelper.insertTransaction(_detailsController.text.trim(), inc, exp);

    _detailsController.clear();
    _amountController.clear();
    _loadBalance();

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل القيد المالي في الصندوق بنجاح')));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        appBar: AppBar(
          title: const Text('إدارة الصندوق المالي والقيود', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 4,
                child: Container(
                  padding: const EdgeInsets.all(20.0),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF0D47A1)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('رصيد الصندوق الحالي:', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('${_currentBalance.toStringAsFixed(0)} ل.س', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text('تسجيل حركة مالية يدوية (قبض / صرف)', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      TextField(controller: _detailsController, decoration: const InputDecoration(labelText: 'البيان (مثال: دفعة من الزبون فادي)', border: OutlineInputBorder())),
                      const SizedBox(height: 10),
                      TextField(controller: _amountController, decoration: const InputDecoration(labelText: 'المبلغ المالي', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Radio<String>(value: 'income', groupValue: _transactionType, activeColor: const Color(0xFF1A237E), onChanged: (v) => setState(() => _transactionType = v!)),
                          const Text('وارد (قبض)'),
                          const SizedBox(width: 20),
                          Radio<String>(value: 'expense', groupValue: _transactionType, activeColor: const Color(0xFF1A237E), onChanged: (v) => setState(() => _transactionType = v!)),
                          const Text('صادر (مصروف)'),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _saveTransaction,
                        icon: const Icon(Icons.account_balance_wallet),
                        label: const Text('تثبيت الحركة في الصندوق'),
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
              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerRight, child: Text('سجل الحركات المالية الأخيرة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: dbHelper.getCashboxTransactions(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    if (snapshot.data!.isEmpty) return const Center(child: Text('لا توجد حركات مالية مسجلة بعد.'));
                    return ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final item = snapshot.data![index];
                        bool isIncome = item['income'] > 0;
                        return Card(
                          child: ListTile(
                            leading: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: isIncome ? Colors.green : Colors.red),
                            title: Text(item['details'] ?? 'بدون بيان'),
                            subtitle: Text('التاريخ: ${item['date']}'),
                            trailing: Text(
                              isIncome ? '+${item['income'].toStringAsFixed(0)}' : '-${item['expense'].toStringAsFixed(0)}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: isIncome ? Colors.green : Colors.red, fontSize: 16),
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
