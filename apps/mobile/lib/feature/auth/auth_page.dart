import 'package:flutter/material.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/token_storage.dart';
import "auth_api.dart";

class AuthPage extends StatefulWidget {
  // 加成功的回调
  const AuthPage({
    super.key,
    required this.onLoginSuccess,
    required this.authApi,
    required this.tokenStorage,
  });

  final Future<void> Function() onLoginSuccess;
  final AuthApi authApi;
  final TokenStorage tokenStorage;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  // 邮箱controller
  final emailController = TextEditingController();
  // 密码controller
  final passwordController = TextEditingController();
  // 存token
  bool loading = false;
  String message = '';

  // 组件销毁 释放内存
  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // 注册请求
  Future<void> register() async {
    try {
      setState(() {
        loading = true;
        message = '';
      });
      final result = await widget.authApi.register(
        email: emailController.text,
        password: passwordController.text,
      );

      setState(() {
        loading = false;
        message = result.toString();
      });
    } catch (e) {
      setState(() {
        loading = false;
        message = "注册失败";
      });
    } finally {
      // 避免页面销毁后继续执行setState
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> login() async {
    try {
      setState(() {
        loading = true;
        message = '';
      });
      final result = await widget.authApi.login(
        email: emailController.text,
        password: passwordController.text,
      );
      // 登录成功保存token到本地存储 下次app启动时直接读取
      final token = result["data"]?["token"] as String?;
      // 登陆成功
      if (token == null) {
        throw const ApiException("服务器登录异常");
      }
      await widget.tokenStorage.saveToken(token);
      await widget.onLoginSuccess();
      if (!mounted) return;
      setState(() {
        loading = false;
      });
    } catch (e) {
      await widget.tokenStorage.clearToken();

      setState(() {
        loading = false;
        message = "登录失败 $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // 视图层
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("记账软件")),
      body: Padding(
        padding: EdgeInsets.all(10),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: "邮箱"),
            ),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: "密码"),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            if (loading) const CircularProgressIndicator(),
            if (!loading)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        register();
                      },
                      child: Center(child: Text("注册")),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        login();
                      },
                      child: Center(child: Text("登录")),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(message),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
