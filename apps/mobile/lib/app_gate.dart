import "package:flutter/material.dart";
import "package:mobile/core/api_client.dart";
import "package:mobile/core/token_storage.dart";
import "package:mobile/feature/auth/auth_api.dart";
import "package:mobile/feature/auth/auth_page.dart";
import "package:mobile/feature/home/home_page.dart";
import "package:mobile/feature/household/create_household_page.dart";
import "package:mobile/feature/household/household_api.dart";
import "package:mobile/feature/household/household_onboarding_page.dart";
import "package:mobile/feature/household/household_session.dart";
import "package:mobile/feature/household/selected_household_storage.dart";
import "package:mobile/feature/transaction/transaction_api.dart";

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
  late final HouseholdApi householdApi;
  late final HouseholdSession householdSession;
  late final TransactionApi transactionApi;

  bool loading = true;
  String? email;
  String? startupError;

  @override
  void initState() {
    super.initState();
    // 认证登录接口
    authApi = AuthApi(apiClient: widget.apiClient);
    // 家庭接口
    householdApi = HouseholdApi(apiClient: widget.apiClient);
    // 家庭会话状态
    householdSession = HouseholdSession(
      householdApi: householdApi,
      storage: SelectedHouseholdStorage(),
    );
    // 账单api 不存储固定的家庭id 每次发送请求时 通关函数读取最新选中的家庭
    transactionApi = TransactionApi(
      apiClient: widget.apiClient,
      householdIdProvider: () {
        return householdSession.selectedHouseholdId;
      },
    );
    checkLogin();
  }

  @override
  void dispose() {
    // householdSessin继承changeNotifier 创建者AppGate负责在销毁时释放它
    householdSession.dispose();
    super.dispose();
  }

  Future<void> checkLogin() async {
    if (!loading && mounted) {
      setState(() {
        loading = true;
        startupError = null;
      });
    }
    try {
      final token = await widget.tokenStorage.readToken();
      if (token == null || token.isEmpty) {
        await householdSession.clear();
        if (!mounted) return;

        setState(() {
          loading = false;
          email = null;
        });
        return;
      }
      final result = await authApi.me();
      final data = result["data"];
      if (data is! Map<String, dynamic>) {
        throw const ApiException("用户数据格式不正确");
      }
      final userEmail = data["email"];
      if (userEmail is! String || userEmail.trim().isEmpty) {
        throw const ApiException("用户数据格式不正确");
      }

      // 登录状态通过后 再加载这个用户加入的家庭
      await householdSession.load();
      if (!mounted) {
        return;
      }

      setState(() {
        loading = false;
        email = userEmail.trim();
        startupError = null;
      });
    } on UnauthorizedException {
      await logout();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        loading = false;
        startupError = error.message;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        loading = false;
        startupError = "初始化失败，请检查网络或服务器状态";
      });
    }
  }

  Future<void> logout() async {
    // 家庭状态和本地家庭id都要清除
    await householdSession.clear();
    // 清除token
    await widget.tokenStorage.clearToken();
    if (!mounted) {
      return;
    }
    setState(() {
      email = null;
      loading = false;
      startupError = null;
    });
  }

  Future<void> openCreateHousehold() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (pageContext) {
          return CreateHouseholdPage(
            householdSession: householdSession,
            onCreated: () {
              Navigator.of(pageContext).pop();
            },
            onLogout: () async {
              Navigator.of(pageContext).pop();
              await logout();
            },
          );
        },
      ),
    );
    if (!mounted || email == null) {
      return;
    }
    // pus 对应的页面关闭后 重新执行build 如果家庭创建成功 此时selectedHousehold已经有值 build 将进入HomePage
    setState(() {});
  }

  Widget buildStartupError() {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 52,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(startupError ?? "初始化失败", textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: checkLogin,
                  label: const Text("重新加载"),
                  icon: const Icon(Icons.refresh),
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: logout, child: const Text("退出登录")),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (startupError != null) {
      return buildStartupError();
    }
    if (email == null) {
      return AuthPage(
        onLoginSuccess: checkLogin,
        authApi: authApi,
        tokenStorage: widget.tokenStorage,
      );
    }
    // 用户登录成功 但是还没有加入任何家庭
    if (householdSession.selectedHousehold == null) {
      return HouseholdOnboardingPage(
        onCreateHousehold: openCreateHousehold,
        // todo 目前邀请模块后端还未开发 不传回调时 按钮自动显示为禁用
        onLogout: logout,
      );
    }
    // 已经登录 并选中家庭
    return HomePage(
      email: email!,
      onLogout: logout,
      transactionApi: transactionApi,
      householdSession: householdSession,
      onCreateHousehold: openCreateHousehold,
    );
  }
}
