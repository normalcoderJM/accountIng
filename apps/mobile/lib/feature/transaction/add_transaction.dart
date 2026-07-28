import 'package:flutter/material.dart';
import 'package:mobile/core/token_storage.dart';
import 'package:mobile/feature/transaction/transaction_api.dart';

class AddTransaction extends StatefulWidget {
  const AddTransaction({super.key});

  @override
  State<AddTransaction> createState() => _AddTransactionState();
}

class _AddTransactionState extends State<AddTransaction> {
  final amountController = TextEditingController();
  final categoryController = TextEditingController();
  final noteController = TextEditingController();

  final tokenStorage = TokenStorage();
  final transactionApi = TransactionApi(baseUrl: "http://localhost:8080");

  String type = "expense";
  bool loading = false;
  String message = "";

  @override
  void dispose() {
    amountController.dispose();
    categoryController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      loading = true;
      message = "";
    });

    try {
      final token = await tokenStorage.readToken();
      if (token == null) {
        setState(() {
          loading = false;
          message = "请重新登录";
        });
        return;
      }
      final amountText = amountController.text.trim();
      final categoryText = categoryController.text.trim();
      final noteText = noteController.text.trim();
      final amount = (double.parse(amountText) * 100).round();
      final result = await transactionApi.create(
        token: token,
        type: type,
        amount: amount,
        category: categoryText,
        note: noteText,
      );
      if (!mounted) return;
      if (result["code"] == 0) {
        // 返回上一级页面 并且刷新页面
        Navigator.pop(context, true);
        return;
      }
    } catch (e) {
      setState(() {
        loading = false;
        message = "保存失败";
      });
    } finally {
      setState(() {
        loading = false;
        message = "";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("新增账单")),
      body: Column(
        children: [
          DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: "类型"),
            items: [
              DropdownMenuItem(child: Text("收入"), value: "income"),
              DropdownMenuItem(child: Text("支出"), value: "expense"),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                type = value;
              });
            },
          ),
          TextField(
            controller: amountController,
            decoration: InputDecoration(labelText: "金额"),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: categoryController,
            decoration: InputDecoration(labelText: "分类"),
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
          ),
          TextField(
            controller: noteController,
            decoration: InputDecoration(labelText: "备注"),
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          if (message.isNotEmpty) Text(message),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: loading ? null : submit,
              child: Text(loading ? "保存中..." : "保存"),
            ),
          ),
        ],
      ),
    );
  }
}
