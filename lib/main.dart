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
  WidgetsFlutterBinding.ensureInitialized();
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
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A237E), // كحلي ملكي مصحح
          primary: const Color(0xFF1A237E),
          secondary: const Color(0xFF00B0FF), // أزرق سماوي مصحح
        ),
      ),
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
        backgroundColor: const Color(0xFFF5F7FB), // خلفية مريحة للعين مصححة
        appBar: AppBar(
          title: const Text('لوحة التحكم والنظام', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          centerTitle: true,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A237E), Color(0xFF0D47A1)], // تدرج مصحح
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.power_settings_new, color: Colors.redAccent, size: 28),
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
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D47A1), Color(0xFF1565C0)], // تدرج مصحح
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('مرحباً بك، المدير المسؤول', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  SizedBox(height: 4),
                  Text('شركة نمل للنقل والخدمات اللوجستية', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                padding: const EdgeInsets.all(16),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildMenuCard(context, 'تأسيس البيانات', Icons.app_registration, const Color(0xFF3F51B5), () => const SystemSetupScreen()),
                  _buildMenuCard(context, 'تسجيل رحلة', Icons.local_shipping, const Color(0xFF2E7D32), () => const AddTripScreen()),
                  _buildMenuCard(context, 'الصندوق المالي', Icons.account_balance_wallet, const Color(0xFFEF6C00), () => const CashboxScreen()),
                  _buildMenuCard(context, 'إيصالات الوزن', Icons.photo_library, const Color(0xFF00838F), () => const TripsListScreen()),
                  _buildMenuCard(context, 'كشوفات الديون', Icons.analytics, const Color(0xFFC62828), () => const AccountsLedgerScreen()),
                  _buildMenuCard(context, 'حساب السائقين', Icons.badge, const Color(0xFF4527A0), () => const DriverPayrollScreen()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.manage_search, size: 24),
                label: const Text('البحث المتقدم وفلترة الجرد الشامل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                  backgroundColor: const Color(0xFF1A237E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TripsSearchScreen())),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, IconData icon, Color color, Widget Function() targetScreen) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => targetScreen())),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecorations.menuCard(color),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
              child: Icon(icon, size: 36, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class BoxDecorations {
  static BoxDecoration menuCard(Color color) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [color, color.withAlpha(200)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: color.withAlpha(80),
          blurRadius: 10,
          offset: const Offset(0, 4),
        )
      ],
    );
  }
}
