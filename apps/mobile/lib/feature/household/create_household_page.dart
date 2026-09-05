import "package:flutter/material.dart";
import "package:mobile/core/api_client.dart";
import "package:mobile/feature/household/household_session.dart";
import "package:mobile/theme/app_colors.dart";
import "package:mobile/theme/app_dimensions.dart";

class CreateHouseholdPage extends StatefulWidget {
  const CreateHouseholdPage({
    super.key,
    required this.householdSession,
    required this.onCreated,
    required this.onLogout,
  });

  final HouseholdSession householdSession;
  final VoidCallback onCreated;
  final Future<void> Function() onLogout;

  @override
  State<CreateHouseholdPage> createState() => _CreateHouseholdPageState();
}

class _CreateHouseholdPageState extends State<CreateHouseholdPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await widget.householdSession.createAndSelect(_nameController.text);
      if (!mounted) {
        return;
      }
      widget.onCreated();
    } on UnauthorizedException {
      await widget.onLogout();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = "创建家庭失败，请稍后重试";
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("创建家庭"),

        // 当这个页面通过 Navigator.push 打开时，
        // Flutter 会自动显示左上角返回按钮。
        // 所以这里不需要自己再写返回按钮。
      ),
      body: SafeArea(
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Form(
                key: _formKey,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.xl,
                    AppSpacing.page,
                    AppSpacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "家庭名称",
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xs),

                      TextFormField(
                        controller: _nameController,
                        enabled: !_submitting,
                        textInputAction: TextInputAction.done,

                        // Flutter 会在输入框右下角显示 0/40。
                        maxLength: 40,

                        onFieldSubmitted: (_) {
                          _submit();
                        },
                        decoration: const InputDecoration(
                          hintText: "例如：我们家",
                          helperText: "2-40个字符",
                        ),
                        validator: (value) {
                          final name = value?.trim() ?? "";

                          if (name.isEmpty) {
                            return "请输入家庭名称";
                          }

                          if (name.length < 2) {
                            return "家庭名称至少需要2个字符";
                          }

                          if (name.length > 40) {
                            return "家庭名称不能超过40个字符";
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      const _PrivacyCard(),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        _RequestErrorMessage(message: _errorMessage!),
                      ],

                      // 正常屏幕把按钮推到底部；
                      // 小屏幕或者键盘弹出时页面仍可滚动。
                      const Spacer(),

                      const SizedBox(height: AppSpacing.xxl),

                      FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: _submitting
                              ? const Row(
                                  key: ValueKey("submitting"),
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: AppSpacing.sm),
                                    Text("正在创建..."),
                                  ],
                                )
                              : const Text("创建并开始记账", key: ValueKey("ready")),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "隐私与安全",
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    "家庭成员共同查看和管理账本。"
                    " 只有通过邀请加入的成员，才能访问家庭数据",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 网络错误 权限错误等请求错误显示在这个区域
class _RequestErrorMessage extends StatelessWidget {
  const _RequestErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
