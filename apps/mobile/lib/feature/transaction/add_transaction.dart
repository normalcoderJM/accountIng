import 'package:flutter/material.dart';
import 'package:mobile/feature/transaction/transaction.dart';
import 'package:mobile/feature/transaction/transaction_api.dart';
import 'package:mobile/core/api_client.dart';

class AddTransaction extends StatefulWidget {
  // 通过传参transaction确定是新增还是编辑
  const AddTransaction({
    super.key,
    this.transaction,
    required this.transactionApi,
  });

  final Transaction? transaction;

  final TransactionApi transactionApi;

  @override
  State<AddTransaction> createState() => _AddTransactionState();
}

class _AddTransactionState extends State<AddTransaction> {
  // GlobalKey<FormState> 用来让保存按钮触发表单中所有输入框的 validator
  final formKey = GlobalKey<FormState>();
  final amountController = TextEditingController();
  final categoryController = TextEditingController();
  final noteController = TextEditingController();

  bool showCustomCategoryInput = false;

  // 判断是否为编辑模式
  bool get isEditing => widget.transaction != null;

  String type = "income";
  bool loading = false;
  // 账单账期
  late DateTime occurredAt;
  static const expenseCategory = ["餐饮", "交通", "住房", "购物", "医疗", "娱乐", "其他"];
  static const incomeCategory = ["工资", "兼职", "奖金", "红包", "其他"];
  List<String> get categories {
    return type == "expense" ? expenseCategory : incomeCategory;
  }

  @override
  void initState() {
    super.initState();

    final transaction = widget.transaction;
    occurredAt = transaction?.occurredAt.toLocal() ?? DateTime.now();
    // 初始化选中第一个
    if (transaction == null) {
      type = "income";
      categoryController.text = incomeCategory.first;
      return;
    }
    // 编辑模式
    type = transaction.type;
    amountController.text = (transaction.amount / 100).toStringAsFixed(2);
    categoryController.text = transaction.category;
    noteController.text = transaction.note;
    // 如果旧账单分类不在预设分类内 就显示自定义输入框
    showCustomCategoryInput = !categories.contains(transaction.category);
  }

  Widget buildCategorySelector() {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "分类",
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: loading
                  ? null
                  : () {
                      setState(() {
                        showCustomCategoryInput = !showCustomCategoryInput;
                        // 打开自定义输入后 清除快捷分类
                        if (showCustomCategoryInput) {
                          categoryController.clear();
                        } else {
                          categoryController.text = categories.first;
                        }
                      });
                    },
              icon: Icon(
                showCustomCategoryInput ? Icons.close : Icons.edit_outlined,
              ),
              label: Text(showCustomCategoryInput ? "取消自定义" : "自定义"),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: categories.map((category) {
            final isSelected =
                !showCustomCategoryInput && categoryController.text == category;
            return ChoiceChip(
              label: Text(category),
              selected: isSelected,
              showCheckmark: false,
              selectedColor: colors.primaryContainer,
              backgroundColor: colors.surfaceContainerLow,
              side: BorderSide(
                color: isSelected ? colors.primary : colors.outlineVariant,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              onSelected: loading
                  ? null
                  : (isSelected) {
                      if (!isSelected) return;
                      setState(() {
                        categoryController.text = category;
                        showCustomCategoryInput = false;
                      });
                    },
            );
          }).toList(),
        ),
        if (showCustomCategoryInput) ...[
          const SizedBox(height: 14),
          TextFormField(
            controller: categoryController,
            autofocus: true,
            textInputAction: TextInputAction.next,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: InputDecoration(
              hintText: "例如：宠物、学习、礼物",
              prefixIcon: Icon(Icons.category_outlined),
              filled: true,
              fillColor: colors.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              labelText: "自定义分类",
            ),

            validator: (value) {
              if (!showCustomCategoryInput) return null;
              final text = value?.trim() ?? "";
              if (text.isEmpty) {
                return "请输入分类";
              }
              if (text.length > 20) {
                return "分类名称不能超过20个字符";
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  // 选择账期方法
  Future<void> selectOccurredDate() async {
    if (loading) return;
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: occurredAt,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime.now(),
      helpText: "请选择账单日期",
      cancelText: "取消",
      confirmText: "确定",
    );

    if (selectedDate == null || !mounted) {
      return;
    }
    setState(() {
      occurredAt = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedDate.hour,
        selectedDate.minute,
        selectedDate.second,
      );
    });
  }

  @override
  void dispose() {
    amountController.dispose();
    categoryController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> showRequestError(String text) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            size: 36,
          ),
          title: Text("请求失败"),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text("知道了"),
            ),
          ],
        );
      },
    );
  }

  // 弹出错误
  void showFormTip(String text) {
    if (!mounted) return;
    final messager = ScaffoldMessenger.of(context);
    messager.hideCurrentSnackBar();

    messager.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        backgroundColor: Theme.of(context).colorScheme.error,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> submit() async {
    if (loading) return;

    final isValid = formKey.currentState?.validate() ?? false;
    if (!isValid) {
      showFormTip("请检查表单输入是否正确");
      return;
    }
    // tryParse 转换失败后为null 不会让程序崩溃
    final amountText = double.parse(amountController.text.trim());
    final categoryText = categoryController.text.trim();
    final noteText = noteController.text.trim();

    FocusScope.of(context).unfocus();

    // 把键盘收起来

    setState(() {
      loading = true;
    });

    try {
      if (!mounted) return;

      final amount = (amountText * 100).round();
      if (isEditing) {
        await widget.transactionApi.update(
          id: widget.transaction!.id,
          type: type,
          amount: amount,
          category: categoryText,
          note: noteText,
          occurredAt: occurredAt,
        );
      } else {
        await widget.transactionApi.create(
          type: type,
          amount: amount,
          category: categoryText,
          note: noteText,
          occurredAt: occurredAt,
        );
      }

      if (!mounted) return;
      final change = isEditing
          ? TransactionChange.updated
          : TransactionChange.created;

      Navigator.pop(context, change);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
      });
      await showRequestError(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
      });
      await showRequestError("发生了未预期的错误，请稍后再试");
    }
  }

  Future<void> delete() async {
    if (!isEditing || loading) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text("删除账单"),
          content: Text("确定删除这条账单吗?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text("取消"),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text("删除"),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;
    setState(() {
      loading = true;
    });

    try {
      if (!mounted) return;

      await widget.transactionApi.delete(id: widget.transaction!.id);
      if (!mounted) return;
      Navigator.pop(context, TransactionChange.deleted);
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      await showRequestError(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
      });
      await showRequestError("删除失败,请稍后再试");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: isEditing ? Text("编辑账单") : Text("新增账单"),
        actions: [
          if (isEditing)
            IconButton(
              onPressed: loading ? null : delete,
              icon: Icon(Icons.delete),
              tooltip: "删除账单",
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: "income",
                    icon: Icon(Icons.add_circle_outline),
                    label: Text("收入"),
                  ),
                  ButtonSegment(
                    value: "expense",
                    icon: Icon(Icons.remove_circle_outline),
                    label: Text("支出"),
                  ),
                ],
                selected: {type},
                onSelectionChanged: loading
                    ? null
                    : (selection) {
                        final newType = selection.first;
                        setState(() {
                          type = newType;
                          showCustomCategoryInput = false;
                          // 切换类型时 重置分类第一个
                          categoryController.text = categories.first;
                        });
                      },
              ),
              const SizedBox(height: 16),
              Text(
                "金额",
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: amountController,
                autofocus: !isEditing,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: InputDecoration(
                  hintText: "0.00",
                  prefixText: "￥",
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                validator: (value) {
                  final text = value?.trim() ?? "";
                  final amount = double.tryParse(text);

                  if (text.isEmpty) {
                    return "请输入金额";
                  }
                  if (amount == null || !amount.isFinite) {
                    return "金额格式不正确";
                  }
                  if (amount <= 0) {
                    return "金额必须大于0";
                  }
                  if (amount > 999999999) {
                    return "金额超出允许范围";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              buildCategorySelector(),
              const SizedBox(height: 24),
              Text(
                "账单日期",
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Material(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: loading ? null : selectOccurredDate,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsetsGeometry.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "${occurredAt.year}年"
                            "${occurredAt.month}月"
                            "${occurredAt.day}日",
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "备注",
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteController,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "写点什么，可不填",
                  prefixIcon: Icon(Icons.notes_outlined),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key("save_transaction_button"),
                  onPressed: loading ? null : submit,
                  style: FilledButton.styleFrom(
                    minimumSize: Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: loading
                        ? const SizedBox(
                            key: ValueKey("loading"),
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isEditing ? "保存修改" : "保存",
                            key: ValueKey("text"),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
