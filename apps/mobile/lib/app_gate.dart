import 'package:flutter/material.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/token_storage.dart';
import 'package:mobile/feature/auth/auth_api.dart';
import 'package:mobile/feature/auth/auth_page.dart';
import 'package:mobile/feature/home/home_page.dart';
import 'package:mobile/feature/transaction/transaction_api.dart';

class AppGate extends StatefulWidget {
  const AppGate({
    super.key,
    required this.apiClient,
    required this.tokenStorage,
  });

  final ApiClient apiClient;
  final TokenStorage tokenStorage;

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  // late final 只初始化一次 后面不会重新赋值
  late final AuthApi authApi;
  late final TransactionApi transactionApi;
  bool loading = true;
  String? email;

  @override
  initState() {
    super.initState();

    authApi = AuthApi(apiClient: widget.apiClient);
    transactionApi = TransactionApi(apiClient: widget.apiClient);
    checkLogin();
  }

  Future<void> checkLogin() async {
    try {
      final token = await widget.tokenStorage.readToken();
      if (!mounted) return;
      if (token == null) {
        setState(() {
          loading = false;
          email = null;
        });
        return;
      }
      final result = await authApi.me();
      if (!mounted) return;
      final userEmail = result["data"]?["email"] as String?;
      if (userEmail == null) {
        await widget.tokenStorage.clearToken();
        setState(() {
          loading = false;
          email = null;
        });
        return;
      }
      setState(() {
        loading = false;
        email = userEmail;
      });
    } on UnauthorizedException {
      await widget.tokenStorage.clearToken();
      if (!mounted) return;
      setState(() {
        loading = false;
        email = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
      });
      debugPrint("检查登录状态失败:${e.message}");
    } catch (e) {
      setState(() {
        loading = false;
        email = null;
      });
    }
  }

  Future<void> logout() async {
    await widget.tokenStorage.clearToken();
    if (!mounted) return;
    setState(() {
      email = null;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(child: CircularProgressIndicator());
    }
    if (email == null) {
      return AuthPage(
        onLoginSuccess: checkLogin,
        authApi: authApi,
        tokenStorage: widget.tokenStorage,
      );
    }
    return HomePage(
      email: email!,
      onLogout: logout,
      transactionApi: transactionApi,
    );
  }
}
