import 'package:flutter/material.dart';
import '../data/database_helper.dart';

class CashboxScreen extends StatefulWidget {
  const CashboxScreen({Key? key}) : super(key: key);

  @override
  State<CashboxScreen> createState() => _CashboxScreenState();
}

class _CashboxScreenState extends State<CashboxScreen> {
  final dbHelper = DatabaseHelper.instance;

  double _balanceSyp = 0.0;
  double _balanceUsd = 0.0;

  final _amountController = TextEditingController();
  String _transactionType = 'income'; // income (وارد/قبض من زبون) أو expense (صادر/دفع لجهة)
  String _selectedCurrency = 'SYP';

  final _transferAmountUsdController = TextEditingController();
  final _exchangeRateController = TextEditingController();
  String _transferDirection = 'USD_TO_SYP';

  // متغيرات الربط المزدوج لأسماء الجهات
  List<Map<String, dynamic>> _allAccounts = [];
  Map<String, dynamic>? _selectedAccount; // الحساب المختار المتربط بالقيد

  @override
  void initState() {
    super.initState();
    _loadDualBalances();
    _loadAccountsList();
  }

  Future<void> _loadDualBalances() async {
    Map<String, double> balances = await dbHelper.getDualCashboxBalances();
    setState(() {
      _balanceSyp = balances['SYP'] ?? 0.0;
      _balanceUsd = balances['USD'] ?? 0.0;
    });
  }

  Future<void> _loadAccountsList() async {
    final list = await dbHelper.getAllAccountsWithBalances();
    setState(() { _allAccounts = list; });
  }

  // دالة الحفظ المحدثة بالقيد المزدوج التلقائي المتوازن
  void _saveDoubleEntryTransaction() async {
    if (_amountController.text.trim().isEmpty || _selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال المبلغ واختيار اسم الجهة للتسوية قسرياً'), backgroundColor: Colors.red));
      return;
    }
    double amount = double.tryParse(_amountController.text) ?? 0.0;

    // استدعاء محرك التوازن المالي المزدوج في قاعدة البيانات
    await dbHelper.insertPaymentWithDoubleEntry(
      _selectedAccount!['name'],
      _selectedAccount!['type'],
      amount,
      _selectedCurrency,
      _transactionType,
    );

    _amountController.clear();
    setState(() { _selectedAccount = null; });
    _loadDualBalances();
    _loadAccountsList(); // تحديث القائمة لرؤية انخفاض الدين فوراً

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل الحركة بالصندوق وتحديث كشف ديون العميل تلقائياً بنسبة 100%')));
  }

  void _executeCurrencyTransfer() async {
    if (_transferAmountUsdController.text.isEmpty || _exchangeRateController.text.isEmpty) return;
    double usd = double.tryParse(_transferAmountUsdController.text) ?? 0.0;
    double rate = double.tryParse(_exchangeRateController.text) ?? 0.0;

    await dbHelper.transferBetweenCurrencies(usd, rate, _transferDirection);
    _transferAmountUsdController.clear(); _exchangeRateController.clear(); _loadDualBalances();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت عملية التحويل المالي وتثبيت القيود المزدوجة بالصندوق')));
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
          flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF0D47A1)]))),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // 1. الكارت الموحد للأرصدة
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 4,
                child: Container(
                  padding: const EdgeInsets.all(20.0),
                  width: double.infinity,
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF0D47A1)]), borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('رصيد الصندوق بالليرة السورية:', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)), Text('${_balanceSyp.toStringAsFixed(0)} ل.س', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))]),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white30, thickness: 1),
                      const SizedBox(height: 12),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('رصيد الصندوق بالدولار الأمريكي:', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)), Text('\$ ${_balanceUsd.toStringAsFixed(1)}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. حاسبة التحويل الفوري
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text('بوابة التحويل المالي الذكي بين العملتين', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(value: _transferDirection, decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)), items: const [DropdownMenuItem(value: 'USD_TO_SYP', child: Text('تحويل من (صادر دولار ➔ وارد سوري)')), DropdownMenuItem(value: 'SYP_TO_USD', child: Text('تحويل من (صادر سوري ➔ وارد دولار)'))], onChanged: (val) => setState(() => _transferDirection = val!)),
                      const SizedBox(height: 10),
                      Row(children: [Expanded(child: TextField(controller: _transferAmountUsdController, decoration: const InputDecoration(labelText: 'قيمة الدولار (\$)', border: OutlineInputBorder()), keyboardType: TextInputType.number)), const SizedBox(width: 10), Expanded(child: TextField(controller: _exchangeRateController, decoration: const InputDecoration(labelText: 'سعر الصرف (ل.س)', border: OutlineInputBorder()), keyboardType: TextInputType.number))]),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(onPressed: _executeCurrencyTransfer, icon: const Icon(Icons.sync_alt), label: const Text('اعتماد التحويل المالي وتثبيت القيود'), style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 44)))
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. قيد حركة وتسوية ديون تلقائية باستخدام محرك الإكمال التلقائي الذكي والبحث التفاعلي
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text('تسجيل قيد حركة وتسوية ديون تلقائية (بحث ذكي)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                      const SizedBox(height: 14),

                      // 🌟 محرك البحث والإكمال التلقائي المطور للأسماء الضخمة بدلاً من الـ Dropdown 🌟
                      Autocomplete<Map<String, dynamic>>(
                        displayStringForOption: (Map<String, dynamic> option) {
                          String typeArabic = option['type'] == 'customer' ? 'زبون' : (option['type'] == 'quarry' ? 'مقلع' : (option['type'] == 'driver' ? 'سائق' : 'محطة/ورشة'));
                          return '${option['name']} ($typeArabic)';
                        },
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<Map<String, dynamic>>.empty();
                          }
                          // تصفية الأسماء والجهات فوراً أثناء كتابة أول حرفين
                          return _allAccounts.where((Map<String, dynamic> option) {
                            return option['name'].toString().toLowerCase().contains(textEditingValue.text.toLowerCase());
                          });
                        },
                        onSelected: (Map<String, dynamic> selection) {
                          setState(() { _selectedAccount = selection; });
                        },
                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                          return TextField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'اكتب اسم الجهة أو العميل للبحث عنه وتحديده قسرياً...',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person_search),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: _amountController, decoration: const InputDecoration(labelText: 'المبلغ المالي للدفعة', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                          const SizedBox(width: 10),
                          Expanded(child: DropdownButtonFormField<String>(value: _selectedCurrency, decoration: const InputDecoration(border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'SYP', child: Text('ليرة سورية (SYP)')), DropdownMenuItem(value: 'USD', child: Text('دولار أمريكي (USD)'))], onChanged: (val) => setState(() => _selectedCurrency = val!))),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Radio<String>(value: 'income', groupValue: _transactionType, activeColor: const Color(0xFF1A237E), onChanged: (v) => setState(() => _transactionType = v!)),
                          const Text('وارد (قبض من زبون)'),
                          const SizedBox(width: 16),
                          Radio<String>(value: 'expense', groupValue: _transactionType, activeColor: const Color(0xFF1A237E), onChanged: (v) => setState(() => _transactionType = v!)),
                          const Text('صادر (دفع لجهة)'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                          onPressed: _saveDoubleEntryTransaction,
                          icon: const Icon(Icons.swap_horizontal_circle),
                          label: const Text('تثبيت الحركة بالصندوق وتعديل الدين تلقائياً', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))
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
