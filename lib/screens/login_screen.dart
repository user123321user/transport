import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _passwordController = TextEditingController();
  final String _correctPassword = "1234"; // رمز المرور السري الخاص بك
  String _errorMessage = "";

  void _verifyPassword() async {
    if (_passwordController.text == _correctPassword) {
      // 1. حفظ حالة نجاح تسجيل الدخول بشكل دائم على ذاكرة الجهاز المحلية
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);

      // 2. الانتقال لشاشة النظام الرئيسية وإتلاف شاشة القفل لمنع العودة إليها بالخلف
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else {
      setState(() {
        _errorMessage = "كلمة المرور غير صحيحة! أعد المحاولة.";
        _passwordController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.blueGrey.shade900,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_person, size: 80, color: Colors.indigo),
                    const SizedBox(height: 16),
                    const Text(
                      'نظام إدارة شركة النقل',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'الرجاء إدخل رمز المرور لفتح قاعدة البيانات المحلية',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, letterSpacing: 8),
                      decoration: const InputDecoration(
                        hintText: '••••',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    if (_errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(_errorMessage, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _verifyPassword,
                      icon: const Icon(Icons.lock_open),
                      label: const Text('دخول للنظام'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
