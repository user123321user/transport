import 'package:flutter/material.dart';
import 'screens/system_setup_screen.dart';
import 'screens/add_trip_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NaqelApp());
}

class NaqelApp extends StatelessWidget {
  const NaqelApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'شركة نمل للنقل',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
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
        appBar: AppBar(title: const Text('نظام شركة النقل محلياً')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.settings),
                  label: const Text('1. إعدادات النظام وتأسيس الحسابات'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SystemSetupScreen())),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(300, 50)),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_road),
                  label: const Text('2. تسجيل رحلة جديدة وحساب التكاليف'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTripScreen())),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(300, 50)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
