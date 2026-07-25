import 'package:flutter/material.dart';

import "auth_api.dart";

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  // 邮箱controller
  final emailController = TextEditingController();
  // 密码controller
  final passwordController = TextEditingController();
  final authApi = AuthApi(baseUrl: "http://localhost:8080");
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
    setState(() {
      loading = true;
      message = '';
    });
    final result = await authApi.register(
      email: emailController.text,
      password: passwordController.text,
    );
    print("$result 当前login");

    setState(() {
      loading = false;
      message = result.toString();
    });
  }

  Future<void> login() async {
    setState(() {
      loading = true;
      message = '';
    });
    final result = await authApi.login(
      email: emailController.text,
      password: passwordController.text,
    );
    print("$result 当前login");
    setState(() {
      loading = false;
      message = result.toString();
    });
  }

  // 视图层
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
                  // Text(message),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
