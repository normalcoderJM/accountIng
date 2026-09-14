import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/token_storage.dart';
import 'package:mobile/theme/app_colors.dart';
import 'package:mobile/theme/app_dimensions.dart';
import "auth_api.dart";
import "auth_form.dart";

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    required this.onLoginSuccess,
    required this.authApi,
    required this.tokenStorage,
  });

  final Future<void> Function() onLoginSuccess;
  final AuthGateway authApi;
  final TokenStorage tokenStorage;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  AuthMode _mode = AuthMode.login;
  bool _loading = false;
  String? _errorMessage;

  bool get _isRegistering => _mode == AuthMode.register;

  void _changeMode(AuthMode mode) {
    if (_loading || mode == _mode) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _mode = mode;
      _errorMessage = null;
    });
  }

  Future<void> _authenticate(String email, String password) async {
    if (_loading) {
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final session =
          _isRegistering
              ? await widget.authApi.register(email: email, password: password)
              : await widget.authApi.login(email: email, password: password);

      await widget.tokenStorage.saveToken(session.token);
      TextInput.finishAutofillContext();
      if (!mounted) return;
      await widget.onLoginSuccess();
    } on ApiException catch (error) {
      await widget.tokenStorage.clearToken();
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      await widget.tokenStorage.clearToken();
      if (!mounted) return;
      setState(() {
        _errorMessage = _isRegistering ? "注册失败，请稍后再试" : "登录失败，请稍后再试";
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.lg,
                AppSpacing.page,
                AppSpacing.xl,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      constraints.maxHeight - AppSpacing.lg - AppSpacing.xl,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _AuthBrand(),
                        const SizedBox(height: AppSpacing.xxl),
                        _AuthModeSwitch(
                          mode: _mode,
                          enabled: !_loading,
                          onChanged: _changeMode,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          _isRegistering ? "创建你的账户" : "欢迎回来",
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _isRegistering
                              ? "从今天开始，和家人轻松管理每一笔收支"
                              : "登录后继续管理你的家庭账本",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        if (_errorMessage != null) ...[
                          _AuthErrorBanner(message: _errorMessage!),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        AuthForm(
                          key: ValueKey(_mode),
                          mode: _mode,
                          loading: _loading,
                          onSubmit: _authenticate,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isRegistering ? "已经有账户？" : "还没有账户？",
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                            TextButton(
                              onPressed:
                                  _loading
                                      ? null
                                      : () => _changeMode(
                                        _isRegistering
                                            ? AuthMode.login
                                            : AuthMode.register,
                                      ),
                              child: Text(_isRegistering ? "去登录" : "立即注册"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// 顶部title类
class _AuthBrand extends StatelessWidget {
  const _AuthBrand();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppRadius.extraLarge),
            boxShadow: const [
              BoxShadow(
                color: Color(0x24246B4E),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            size: 36,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          "家庭账本",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          "让每一笔收支都有迹可循",
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// 切换登录注册按钮类
class _AuthModeSwitch extends StatelessWidget {
  const _AuthModeSwitch({
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  final AuthMode mode;
  final bool enabled;
  final ValueChanged<AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment:
                mode == AuthMode.login
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _AuthModeButton(
                  label: "登录",
                  selected: mode == AuthMode.login,
                  enabled: enabled,
                  onPressed: () => onChanged(AuthMode.login),
                ),
              ),
              Expanded(
                child: _AuthModeButton(
                  label: "注册",
                  selected: mode == AuthMode.register,
                  enabled: enabled,
                  onPressed: () => onChanged(AuthMode.register),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuthModeButton extends StatelessWidget {
  const _AuthModeButton({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        foregroundColor:
            selected ? AppColors.primaryDark : AppColors.textSecondary,
        minimumSize: const Size.fromHeight(44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}

// 认证接口错误提示组件
class _AuthErrorBanner extends StatelessWidget {
  const _AuthErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
