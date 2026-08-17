import 'package:flutter/material.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/feature/transaction/transaction.dart';
import 'package:mobile/feature/transaction/transaction_api.dart';
import 'package:mobile/feature/transaction/add_transaction.dart';
import 'package:mobile/feature/home/transaction_day_group.dart';
import 'package:mobile/feature/home/widgets/home_summary.dart';
import 'package:mobile/feature/home/widgets/transaction_day_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.email,
    required this.onLogout,
    required this.transactionApi,
  });
  final String email;
  final Future<void> Function() onLogout;
  final TransactionApi transactionApi;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool loading = true;
  String message = "";
  List<Transaction> transactions = [];

  @override
  void initState() {
    super.initState();
    loadTransaction(showFullScreenLoading: true);
  }

  Future<void> loadTransaction({bool showFullScreenLoading = false}) async {
    if (showFullScreenLoading && mounted) {
      setState(() {
        loading = true;
        message = "";
      });
    } else if (mounted) {
      setState(() {
        message = "";
      });
    }

    try {
      final result = await widget.transactionApi.list();

      final data = result["data"] as List<dynamic>? ?? [];
      final items = data
          .map((item) => Transaction.formJson(item as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        transactions = items;
      });
    } on UnauthorizedException {
      if (!mounted) return;
      // Token 失效时，由 AppGate 负责退出登录。
      await widget.onLogout();
      return;
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        message = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        message = "账单加载失败";
      });
    } finally {
      // 只有首次加载才显示全屏loading 刷新时不显示全屏loading
      if (showFullScreenLoading && mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  List<TransactionDayGroup> get dayGroups {
    return groupTransactionsByDay(transactions);
  }

  int get totalIncome {
    return transactions
        .where((transaction) => transaction.type == "income")
        .fold(0, (total, transaction) => total + transaction.amount);
  }

  int get totalExpense {
    return transactions
        .where((transaction) => transaction.type == "expense")
        .fold(0, (total, transaction) => total + transaction.amount);
  }

  int get balance {
    return totalIncome - totalExpense;
  }

  // 抽离打开弹窗逻辑
  Future<void> openTransaction(Transaction transaction) async {
    final change = await Navigator.push<TransactionChange>(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransaction(
          transaction: transaction,
          transactionApi: widget.transactionApi,
        ),
      ),
    );
    if (change == null) return;
    await loadTransaction();
    if (!mounted) return;
    showChangeSuccess(change);
  }

  // 显示成功状态
  void showChangeSuccess(TransactionChange change) {
    final text = switch (change) {
      TransactionChange.created => "账单已生成",
      TransactionChange.updated => "账单已更新",
      TransactionChange.deleted => "账单已删除",
    };

    final messagener = ScaffoldMessenger.of(context);

    messagener.hideCurrentSnackBar();

    messagener.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Text(text),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("记账软件"),
        actions: [TextButton(onPressed: widget.onLogout, child: Text("退出登录"))],
      ),
      body: Builder(
        builder: (context) {
          if (loading) {
            return Center(child: CircularProgressIndicator());
          }
          if (message.isNotEmpty && transactions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        loadTransaction(showFullScreenLoading: true);
                      },
                      label: Text("重新加载"),
                      icon: Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
            );
          }
          final groups = dayGroups;
          return Column(
            children: [
              HomeSummary(
                income: totalIncome,
                expense: totalExpense,
                balance: balance,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => loadTransaction(),
                  child: transactions.isEmpty
                      ? ListView(
                          // 即使内容没有占满整个屏幕 也允许用户下拉刷新
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(
                              height: 300,
                              child: Center(child: Text("暂无账单")),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 96),
                          itemCount: groups.length,
                          itemBuilder: (context, index) {
                            return TransactionDayCard(
                              group: groups[index],
                              onTransactionTap: (transaction) {
                                openTransaction(transaction);
                              },
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final change = await Navigator.push<TransactionChange>(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddTransaction(transactionApi: widget.transactionApi),
            ),
          );
          if (change != null) {
            await loadTransaction();
            if (!mounted) return;
            showChangeSuccess(change);
          }
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
