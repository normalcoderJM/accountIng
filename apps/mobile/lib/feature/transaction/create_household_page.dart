import "package:flutter/material.dart";
import "package:mobile/core/api_client.dart";
import "package:mobile/feature/household/household_session.dart";

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
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: _submitting ? null : widget.onLogout,
            child: const Text("退出登录"),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.family_restroom,
                        color: colors.onPrimaryContainer,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "创建你的家庭账本",
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "家庭成员可以共同巨鹿收入和支出,以后还可以邀请家人、设置预算和管理共同账户",
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _nameController,
                      enabled: !_submitting,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        _submit();
                      },
                      decoration: const InputDecoration(
                        labelText: "家庭名称",
                        hintText: "例如:我们家",
                        prefixIcon: Icon(Icons.home_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final name = value?.trim() ?? "";

                        if (name.isEmpty) {
                          return "请输入家庭名称";
                        }
                        if (name.length < 2 || name.length > 40) {
                          return "家庭名称必须在2-40个字符之间";
                        }
                        return null;
                      },
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: colors.error),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      label: Text(_submitting ? "正在创建..." : "创建并开始记账"),
                      icon: _submitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
