import 'package:flutter/material.dart';
import 'package:mobile/app_gate.dart';
import 'package:mobile/core/api_client.dart';
import "package:mobile/core/token_storage.dart";
import "package:mobile/theme/app_theme.dart";

void main() {
  final tokenStorage = TokenStorage();
  final apiClient = ApiClient(
    baseUrl: "http://localhost:8080",
    tokenStorage: tokenStorage,
  );
  runApp(MainPage(tokenStorage: tokenStorage, apiClient: apiClient));
}

class MainPage extends StatelessWidget {
  const MainPage({
    super.key,
    required this.tokenStorage,
    required this.apiClient,
  });
  final TokenStorage tokenStorage;
  final ApiClient apiClient;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "家庭账本",
      theme: AppTheme.light,
      home: AppGate(tokenStorage: tokenStorage, apiClient: apiClient),
    );
  }
}
