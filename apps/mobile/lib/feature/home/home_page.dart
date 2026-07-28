import 'package:flutter/material.dart';
import 'package:mobile/feature/transaction/transaction.dart';
import 'package:mobile/feature/transaction/transaction_api.dart';
import 'package:mobile/feature/transaction/add_transaction.dart';
import '../../core/token_storage.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.email, required this.onLogout});
  final String email;
  final VoidCallback onLogout;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final tokenStorage = TokenStorage();
  final transactionApi = TransactionApi(baseUrl: "http://localhost:8080");

  bool loading = true;
  String message = "";
  List<Transaction> transactions = [];

  @override
  void initState() {
    super.initState();
    loadTransaction();
  }

  Future<void> loadTransaction() async {
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
      final result = await transactionApi.list(token);
      final data = result["data"] as List<dynamic>? ?? [];
      print("%v $data 这是啥 我感觉初始化没有调用呢");
      final items = data.map(
        (item) => Transaction.formJson(item as Map<String, dynamic>),
      );
      setState(() {
        transactions = items.toList();
      });
    } catch (e) {
      setState(() {
        loading = false;
        message = "账单加载失败";
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  String formatAmount(Transaction transaction) {
    final value = transaction.amount / 100;
    final sign = transaction.type == "expense" ? "-" : "+";

    return "$sign${value.toStringAsFixed(2)}";
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("记账软件"),
        actions: [
          TextButton(
            onPressed: () async {
              // 退出登录 清除token
              await tokenStorage.clearToken();
              widget.onLogout();
            },
            child: Text("退出登录"),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (loading) {
            return Center(child: CircularProgressIndicator());
          }
          if (message.isNotEmpty) {
            return Center(child: Text(message));
          }
          if (transactions.isEmpty) {
            return Center(child: Text("暂无账单"));
          }
          return ListView.separated(
            itemBuilder: (context, index) {
              final transaction = transactions[index];

              return ListTile(
                title: Text(transaction.category),
                subtitle: Text(transaction.note),
                trailing: Text(formatAmount(transaction)),
              );
            },
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemCount: transactions.length,
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (context) => const AddTransaction()),
          );
          if (created == true) {
            loadTransaction();
          }
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
