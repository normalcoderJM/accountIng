import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile/theme/app_dimensions.dart';

enum AuthMode { login, register }

class AuthForm extends StatefulWidget {
  const AuthForm({
    super.key,
    required this.mode,
    required this.loading,
    required this.onSubmit,
  });

  final AuthMode mode;
  final bool loading;
  final Future<void> Function(String email, String password) onSubmit;

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  bool get _isRegistering => widget.mode == AuthMode.register;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.loading || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();
    await widget.onSubmit(
      _emailController.text.trim(),
      _passwordController.text,
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? "";
    if (email.isEmpty) {
      return "请输入邮箱地址";
    }
    if (!RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").hasMatch(email)) {
      return "请输入有效的邮箱地址";
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? "";
    if (password.isEmpty) {
      return "请输入密码";
    }
    if (password.length < 6) {
      return "密码至少需要 6 个字符";
    }
    if (password.length > 72) {
      return "密码不能超过 72 个字符";
    }
    return null;
  }

  String? _validatePasswordConfirmation(String? value) {
    if (!_isRegistering) {
      return null;
    }
    if (value == null || value.isEmpty) {
      return "请再次输入密码";
    }
    if (value != _passwordController.text) {
      return "两次输入的密码不一致";
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      // 切换登录/注册会销毁当前表单，但这不代表认证成功。
      // 真正成功后由 AuthPage 主动结束并保存自动填充会话。
      onDisposeAction: AutofillContextAction.cancel,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const ValueKey("auth-email-field"),
              controller: _emailController,
              focusNode: _emailFocusNode,
              enabled: !widget.loading,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: _validateEmail,
              onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
              decoration: const InputDecoration(
                labelText: "邮箱",
                hintText: "name@example.com",
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const ValueKey("auth-password-field"),
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              enabled: !widget.loading,
              obscureText: !_passwordVisible,
              textInputAction:
                  _isRegistering ? TextInputAction.next : TextInputAction.done,
              autofillHints: [
                _isRegistering
                    ? AutofillHints.newPassword
                    : AutofillHints.password,
              ],
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: _validatePassword,
              onFieldSubmitted: (_) {
                if (_isRegistering) {
                  _confirmPasswordFocusNode.requestFocus();
                } else {
                  _submit();
                }
              },
              decoration: InputDecoration(
                labelText: "密码",
                hintText: _isRegistering ? "至少 6 个字符" : "请输入密码",
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _passwordVisible ? "隐藏密码" : "显示密码",
                  onPressed:
                      widget.loading
                          ? null
                          : () {
                            setState(() {
                              _passwordVisible = !_passwordVisible;
                            });
                          },
                  icon: Icon(
                    _passwordVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child:
                  _isRegistering
                      ? Column(
                        key: const ValueKey("register-confirm-section"),
                        children: [
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            key: const ValueKey("auth-confirm-password-field"),
                            controller: _confirmPasswordController,
                            focusNode: _confirmPasswordFocusNode,
                            enabled: !widget.loading,
                            obscureText: !_confirmPasswordVisible,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            validator: _validatePasswordConfirmation,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: "确认密码",
                              hintText: "请再次输入密码",
                              prefixIcon: const Icon(
                                Icons.verified_user_outlined,
                              ),
                              suffixIcon: IconButton(
                                tooltip:
                                    _confirmPasswordVisible ? "隐藏密码" : "显示密码",
                                onPressed:
                                    widget.loading
                                        ? null
                                        : () {
                                          setState(() {
                                            _confirmPasswordVisible =
                                                !_confirmPasswordVisible;
                                          });
                                        },
                                icon: Icon(
                                  _confirmPasswordVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                      : const SizedBox.shrink(
                        key: ValueKey("login-confirm-section"),
                      ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              key: const ValueKey("auth-submit-button"),
              onPressed: widget.loading ? null : _submit,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child:
                    widget.loading
                        ? const SizedBox.square(
                          key: ValueKey("auth-loading"),
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                        : Text(
                          _isRegistering ? "创建账户" : "登录",
                          key: ValueKey(widget.mode),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
