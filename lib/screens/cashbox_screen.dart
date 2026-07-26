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
  String _transactionType = 'income'; // income (وارد) أو expense (صادر)

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  // تحديث الرصيد الحالي من الجهاز
  Future<void> _loadBalance() async {
    double balance = await dbHelper.getCashboxBalance();
    setState(() {
      _currentBalance = balance;
    });
  }

  // دالة حفظ العملية المالية
  void _saveTransaction() async {
    if (_detailsController.text.trim().isEmpty || _amountController.text.trim().isEmpty) return;

    double amount = double.tryParse(_amountController.text) ?? 0.0;
    double inc = _transactionType == 'income' ? amount : 0.0;
    double exp = _transactionType == 'expense' ? amount : 0.0;

    await dbHelper.insertTransaction(_detailsController.text.trim(), inc, exp);

    _detailsController.clear();
    _amountController.clear();
    _loadBalance(); // إعادة تحديث الرصيد المعروض

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل القيد المالي في الصندوق بنجاح')));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('إدارة الصندوق المالي والقيود')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // كارت عرض رصيد الصندوق الإجمالي الحالي للشركة
              Card(
                color: Colors.blue.shade800,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
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

              // كارت إضافة قيد مالي جديد يدوي
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text('تسجيل حركة مالية يدوية (قبض / صرف)', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      TextField(controller: _detailsController, decoration: const InputDecoration(labelText: 'البيان (مثال: دفعة من الزبون فادي / تصليح فرام)')),
                      TextField(controller: _amountController, decoration: const InputDecoration(labelText: 'المبلغ المالي'), keyboardType: TextInputType.number),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Radio<String>(value: 'income', groupValue: _transactionType, onChanged: (v) => setState(() => _transactionType = v!)),
                          const Text('وارد (قبض للشركة)'),
                          const SizedBox(width: 20),
                          Radio<String>(value: 'expense', groupValue: _transactionType, onChanged: (v) => setState(() => _transactionType = v!)),
                          const Text('صادر (صرف ومصاريف)'),
                        ],
                      ),
                      ElevatedButton.icon(onPressed: _saveTransaction, icon: const Icon(Icons.account_balance_wallet), label: const Text('تثبيت الحركة في الصندوق'))
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('سجل الحركات المالية الأخيرة:', style: TextStyle(fontWeight: FontWeight.bold)),

              // استعراض حركات الصندوق المخزنة على الجهاز
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
                        return ListTile(
                          leading: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: isIncome ? Colors.green : Colors.red),
                          title: Text(item['details'] ?? 'بدون بيان'),
                          subtitle: Text('التاريخ: ${item['date']}'),
                          trailing: Text(
                            isIncome ? '+${item['income'].toStringAsFixed(0)}' : '-${item['expense'].toStringAsFixed(0)}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: isIncome ? Colors.green : Colors.red, fontSize: 16),
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
