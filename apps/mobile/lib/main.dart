import 'package:flutter/material.dart';
import 'package:mobile/app_gate.dart';
import 'package:mobile/feature/auth/auth_page.dart';

void main() {
  runApp(MainPage());
}

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: ("Accounting"),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: AppGate(),
    );
  }
}
