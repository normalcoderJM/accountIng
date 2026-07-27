import 'package:flutter/material.dart';
import 'package:mobile/core/token_storage.dart';
import 'package:mobile/feature/auth/auth_api.dart';
import 'package:mobile/feature/auth/auth_page.dart';
import 'package:mobile/feature/home/home_page.dart';

class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  final tokenStorage = TokenStorage();
  final authApi = AuthApi(baseUrl: "http://localhost:8080");

  bool loading = true;
  String? email;
  @override
  initState() {
    super.initState();
    checkLogin();
  }

  Future<void> checkLogin() async {
    try {
      final token = await tokenStorage.readToken();
      if (token == null) {
        setState(() {
          loading = false;
          email = null;
        });
        return;
      }
      final result = await authApi.me(token);
      final userEmail = result["data"]?["email"] as String?;
      if (userEmail == null) {
        await tokenStorage.clearToken();
        setState(() {
          loading = true;
          email = null;
        });
        return;
      }
      setState(() {
        loading = false;
        email = userEmail;
      });
    } catch (e) {
      await tokenStorage.clearToken();
      setState(() {
        loading = false;
        email = null;
      });
    }
  }

  void logout() {
    setState(() {
      email = null;
    });
  }

  Widget build(BuildContext context) {
    if (loading) {
      return Center(child: CircularProgressIndicator());
    }
    if (email == null) {
      return AuthPage(onLoginSuccess: checkLogin);
    }
    return HomePage(email: email!, onLogout: logout);
  }
}
