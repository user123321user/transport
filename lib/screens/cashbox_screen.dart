import 'package:flutter/material.dart';
import '../data/database_helper.dart';

class CashboxScreen extends StatefulWidget {
  const CashboxScreen({Key? key}) : super(key: key);

  @override
  State<CashboxScreen> createState() => _CashboxScreenState();
}

class _CashboxScreenState extends State<CashboxScreen> {
  final dbHelper = DatabaseHelper.instance;

  // متغيرات عرض أرصدة الحسابين المنفصلين تماماً
  double _balanceSyp = 0.0;
  double _balanceUsd = 0.0;

  final _detailsController = TextEditingController();
  final _amountController = TextEditingController();
  String _transactionType = 'income'; // وارد (income) أو صادر (expense)
  String _selectedCurrency = 'SYP';    // ليرة سورية (SYP) أو دولار (USD)

  // كواشف نصوص حاسبة التحويل الذكي بين الحسابين الماليين
  final _transferAmountUsdController = TextEditingController();
  final _exchangeRateController = TextEditingController();
  String _transferDirection = 'USD_TO_SYP'; // اتجاه التحويل الافتراضي

  @override
  void initState() {
    super.initState();
    _loadDualBalances();
  }

  // دالة جلب الأرصدة المستقلة من قاعدة البيانات
  Future<void> _loadDualBalances() async {
    Map<String, double> balances = await dbHelper.getDualCashboxBalances();
    setState(() {
      _balanceSyp = balances['SYP'] ?? 0.0;
      _balanceUsd = balances['USD'] ?? 0.0;
    });
  }
  // دالة ترحيل الحركات المالية اليدوية المحدثة بناءً على العملة المختارة
  void _saveTransaction() async {
    if (_detailsController.text.trim().isEmpty || _amountController.text.trim().isEmpty) return;
    double amount = double.tryParse(_amountController.text) ?? 0.0;

    await dbHelper.insertTransactionMutiCurrency(
      _detailsController.text.trim(),
      amount,
      _selectedCurrency,
      _transactionType,
    );

    _detailsController.clear();
    _amountController.clear();
    _loadDualBalances();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تسجيل الحركة في حساب العملة المحدد بنجاح')),
    );
  }

  // تنفيذ عملية التحويل المزدوجة الفورية بين الصندوقين وإعادة احتساب الرصيد
  void _executeCurrencyTransfer() async {
    if (_transferAmountUsdController.text.isEmpty || _exchangeRateController.text.isEmpty) return;

    double usd = double.tryParse(_transferAmountUsdController.text) ?? 0.0;
    double rate = double.tryParse(_exchangeRateController.text) ?? 0.0;

    await dbHelper.transferBetweenCurrencies(usd, rate, _transferDirection);

    _transferAmountUsdController.clear();
    _exchangeRateController.clear();
    _loadDualBalances();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تمت عملية التحويل المالي وتثبيت القيود المزدوجة بالصندوق')),
    );
    setState(() {});
  }
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        appBar: AppBar(
          title: const Text('إدارة الحسابات المزدوجة والتحويل', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          centerTitle: true,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF0D47A1)]),
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // أولاً: كروت عرض أرصدة الحسابين المنفصلين تماماً
              Row(
                children: [
                  Expanded(
                    child: Card(
                      color: Colors.green.shade700,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text('حساب الليرة السورية', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('${_balanceSyp.toStringAsFixed(0)} ل.س', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Card(
                      color: Colors.indigo.shade700,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text('حساب الدولار الصافي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('\$ ${_balanceUsd.toStringAsFixed(1)}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ثانياً: حاسبة التحويل الفوري المزدوج بين الصندوقين
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text('بوابة التحويل المالي الذكي بين العملتين', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _transferDirection,
                        decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                        items: const [
                          DropdownMenuItem(value: 'USD_TO_SYP', child: Text('تحويل من (صادر دولار ➔ وارد سوري)')),
                          DropdownMenuItem(value: 'SYP_TO_USD', child: Text('تحويل من (صادر سوري ➔ وارد دولار)')),
                        ],
                        onChanged: (val) => setState(() => _transferDirection = val!),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: _transferAmountUsdController, decoration: const InputDecoration(labelText: 'قيمة الدولار (\$)', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: _exchangeRateController, decoration: const InputDecoration(labelText: 'سعر الصرف (ل.س)', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _executeCurrencyTransfer,
                        icon: const Icon(Icons.sync_alt),
                        label: const Text('اعتماد التحويل المالي وتثبيت القيود'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 44)),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ثالثاً: تسجيل حركة قيد يدوي فوري بالصندوق مع اختيار نوع العملة
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text('تسجيل قيد حركة مالية مباشرة بالصندوق', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      TextField(controller: _detailsController, decoration: const InputDecoration(labelText: 'البيان والتفاصيل', border: OutlineInputBorder())),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: _amountController, decoration: const InputDecoration(labelText: 'المبلغ المالي', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedCurrency,
                              decoration: const InputDecoration(border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'SYP', child: Text('ليرة سورية (SYP)')),
                                DropdownMenuItem(value: 'USD', child: Text('دولار أمريكي (USD)')),
                              ],
                              onChanged: (val) => setState(() => _selectedCurrency = val!),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Radio<String>(value: 'income', groupValue: _transactionType, activeColor: const Color(0xFF1A237E), onChanged: (v) => setState(() => _transactionType = v!)),
                          const Text('وارد (قبض)'),
                          const SizedBox(width: 24),
                          Radio<String>(value: 'expense', groupValue: _transactionType, activeColor: const Color(0xFF1A237E), onChanged: (v) => setState(() => _transactionType = v!)),
                          const Text('صادر (مصروف)'),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _saveTransaction,
                        icon: const Icon(Icons.check_circle),
                        label: const Text('تثبيت الحركة بالصندوق العملة المحدد'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
