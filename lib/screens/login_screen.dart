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
  final String _correctPassword = "1234";
  String _errorMessage = "";

  void _verifyPassword() async {
    if (_passwordController.text == _correctPassword) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } else {
      setState(() {
        _errorMessage = "رمز المرور غير صحيح! أعد المحاولة.";
        _passwordController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF263238)], // تدرج لوني مصحح ومحمي للخصوصية
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
                    child: const Icon(Icons.shield, size: 80, color: Colors.amber),
                  ),
                  const SizedBox(height: 24),
                  const Text('بوابة الوصول الآمنة', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                  const Text('قاعدة البيانات مشفرة ومحفوظة محلياً على الجهاز', style: TextStyle(color: Colors.white60, fontSize: 13)),
                  const SizedBox(height: 32),
                  Card(
                    elevation: 12,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const Text('أدخل رمز الأمان للدخول', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 24, letterSpacing: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)), // كود لون مصحح
                            decoration: InputDecoration(
                              hintText: '••••',
                              hintStyle: const TextStyle(color: Colors.grey, letterSpacing: 12),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                          if (_errorMessage.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(_errorMessage, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          ],
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _verifyPassword,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 54),
                              backgroundColor: const Color(0xFF1A237E), // كود لون مصحح
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 2,
                            ),
                            child: const Text('تحقق وافتح النظام', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
