import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/system_setup_screen.dart';
import 'screens/add_trip_screen.dart';
import 'screens/cashbox_screen.dart';
import 'screens/trips_list_screen.dart';
import 'screens/accounts_ledger_screen.dart';
import 'screens/driver_payroll_screen.dart';
import 'screens/trips_search_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  // التأكد من تهيئة كل أدوات فلاتر قبل فحص الذاكرة
  WidgetsFlutterBinding.ensureInitialized();

  // قراءة الذاكرة الدائمة للجهاز لفحص حالة الدخول السابقة
  final prefs = await SharedPreferences.getInstance();
  final bool isKeyValid = prefs.getBool('is_logged_in') ?? false;

  runApp(NaqelApp(startScreen: isKeyValid ? const HomeScreen() : const LoginScreen()));
}

class NaqelApp extends StatelessWidget {
  final Widget startScreen;
  const NaqelApp({Key? key, required this.startScreen}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'شركة نمل للنقل',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      // الانطلاق من الشاشة المحددة بناءً على فحص الذاكرة المحلية
      home: startScreen,
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('نظام شركة النقل محلياً'),
          actions: [
            // زر لتسجيل الخروج وقفل التطبيق مجدداً إذا رغب صاحب العمل
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.red),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('is_logged_in', false);
                if (context.mounted) {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                }
              },
            )
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.settings),
                  label: const Text('1. إعدادات النظام وتأسيس الحسابات'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SystemSetupScreen())),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(300, 48)),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_road),
                  label: const Text('2. تسجيل رحلة جديدة وحساب التكاليف'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTripScreen())),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(300, 48)),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.monetization_on),
                  label: const Text('3. الصندوق المالي والقيود اليومية'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CashboxScreen())),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(300, 48), backgroundColor: Colors.amber.shade100),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.photo_library),
                  label: const Text('4. سجل الرحلات وإيصالات الوزن الورقية'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TripsListScreen())),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(300, 48), backgroundColor: Colors.green.shade100),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.assignment),
                  label: const Text('5. كشوفات الحسابات وجرد الديون كلياً'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountsLedgerScreen())),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(300, 48), backgroundColor: Colors.purple.shade100),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.badge),
                  label: const Text('6. كشف الحساب الأسبوعي للسائقين'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverPayrollScreen())),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(300, 48), backgroundColor: Colors.teal.shade100),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.saved_search),
                  label: const Text('7. البحث المتقدم وفلترة الرحلات والجرد'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TripsSearchScreen())),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(300, 48), backgroundColor: Colors.indigo.shade100),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
