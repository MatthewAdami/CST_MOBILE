import 'package:cst_mobile/screens/dashboard_screen.dart';
import 'package:cst_mobile/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _SplashGate(),
    );
  }
}

class _SplashGate extends StatefulWidget {
  const _SplashGate();
  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    if (!mounted) return;
    if (token.isNotEmpty) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const StudentDashboard()));
    } else {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: Color(0xFF0B1F3A),
        body: Center(
            child: CircularProgressIndicator(color: Color(0xFF7C3AED))),
      );
}