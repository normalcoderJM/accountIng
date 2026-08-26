import 'package:flutter/material.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/feature/home/widgets/home_content.dart';
import 'package:mobile/feature/transaction/transaction.dart';
import 'package:mobile/feature/transaction/transaction_api.dart';
import 'package:mobile/feature/transaction/add_transaction.dart';
import 'package:mobile/feature/home/transaction_day_group.dart';
import 'package:mobile/feature/transaction/transaction_page.dart';
import 'package:mobile/feature/transaction/transaction_summary.dart';

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
  static const int _pageSize = 20;
  // 首页列表滚动控制器
  final ScrollController _scrollController = ScrollController();

  bool loading = true;
  // 防止首次加载、刷新、保存刷新 同时发起重复请求
  bool _loadingFirstPage = false;
  // 是否正在请求下一页。
  bool _loadingMore = false;

  // 下一页加载失败的信息。
  String? _loadMoreError;
  String message = "";
  List<Transaction> transactions = [];
  TransactionSummary summary = TransactionSummary.empty;
  // 下一页使用的游标
  String? nextCursor;
  // 当前选择月份
  late DateTime selectedMonth;
  // 后端判断是否还有下一页
  bool hasMore = false;
  // 每刷新一页就会递增 如果加载下一页还没完成 不能把旧数据追加进去
  int _listGeneration = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // 默认初始化当月第一天
    selectedMonth = DateTime(now.year, now.month, 1);
    // 监听列表滚动位置
    _scrollController.addListener(_handleScroll);
    // 页面第一次打开 显示全图加载状态
    loadTransaction(showFullScreenLoading: true);
  }

  // 当前选择的月份第一天 00:00
  DateTime get monthStart {
    return DateTime(selectedMonth.year, selectedMonth.month, 1);
  }

  // 下个月第一天 00:00
  DateTime get monthEnd {
    return DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
  }

  bool get canGoNextMonth {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    return selectedMonth.isBefore(currentMonth);
  }

  Future<void> changeMonth(int offset) async {
    // 请求期间不允许连续切换月份 避免旧请求覆盖新月份
    if (_loadingFirstPage || _loadingMore) {
      return;
    }
    final targetMonth = DateTime(
      selectedMonth.year,
      selectedMonth.month + offset,
      1,
    );
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    if (targetMonth.isAfter(currentMonth)) {
      return;
    }

    setState(() {
      selectedMonth = targetMonth;
      // 切换月份后 清理旧月份状态 防止请求失败时 显示错月份数据
      transactions = [];
      summary = TransactionSummary.empty;
      nextCursor = null;
      hasMore = false;
      message = '';
      _loadMoreError = null;
    });

    await loadTransaction(showFullScreenLoading: true);
  }

  @override
  void dispose() {
    // 卸载组件后 必须销毁监听
    _scrollController.dispose();
    super.dispose();
  }

  // 当距离列表底部不足200 加载下一页
  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    // extentAfter 表示当前位置下面还有多少可滚动内容。
    if (position.extentAfter < 200) {
      _loadMoreTransactions();
    }
  }

  // 加载第一页数据
  Future<void> loadTransaction({bool showFullScreenLoading = false}) async {
    // 已经有第一页请求执行 不再重复发送
    if (_loadingFirstPage) {
      return;
    }
    _loadingFirstPage = true;
    final generation = ++_listGeneration;
    if (mounted) {
      setState(() {
        message = "";
        if (showFullScreenLoading) {
          loading = true;
        }
      });
    }
    final startAt = monthStart;
    final endAt = monthEnd;
    try {
      // 不传cursor 表示始终重新加载第一页
      // final page = await widget.transactionApi.listPage(limit: _pageSize);
      final results = await Future.wait<Object>([
        widget.transactionApi.listPage(
          limit: _pageSize,
          startAt: startAt,
          endAt: endAt,
        ),
        widget.transactionApi.getSummary(startAt: startAt, endAt: endAt),
      ]);

      final page = results[0] as TransactionPage;
      final loadedSummary = results[1] as TransactionSummary;
      // 页面已经销毁 或者请求过期 都不更新ui
      if (!mounted || generation != _listGeneration) return;

      setState(() {
        // todo 下拉刷新暂时是替换旧数据 不是追加数据
        transactions = page.items;
        // 保存分页状态 下一步加载更多时使用
        nextCursor = page.nextCursor;
        summary = loadedSummary;
        hasMore = page.hasMore;
        message = "";
        _loadMoreError = null;
      });
      // 如果第一页数据不足以覆盖整个页面 但后端还有下一页
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadMoreIfNeeded();
      });
    } on UnauthorizedException {
      if (!mounted) return;
      // token失效时 由appGate清理登录状态并返回登录页
      await widget.onLogout();
    } on ApiException catch (e) {
      if (!mounted) return;

      _handleLoadError(e.message);
    } catch (error) {
      if (!mounted) return;
      _handleLoadError("账单加载失败");
    } finally {
      _loadingFirstPage = false;
      // 只有收进入页面才需要关闭全屏loading 下拉刷新动画由refreshIndicator自己控制
      if (showFullScreenLoading && mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void _loadMoreIfNeeded() {
    // 检查当前列表是否已经接近底部 首次加载数据可能不足以撑满屏幕 这时用户无法滚动 需要主动检查一次
    if (!mounted || !_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.extentAfter < 200) {
      _loadMoreTransactions();
    }
  }

  // 加载下一页账单
  Future<void> _loadMoreTransactions() async {
    //防止多个下一页请求同时执行
    if (_loadingMore) {
      return;
    }
    // 刷新第一页期间不加载下一页
    if (_loadingFirstPage) {
      return;
    }
    // 没有下一页
    if (!hasMore) {
      return;
    }
    final cursor = nextCursor;
    // hasMore为true时 正常情况下必须存在nextCursor
    if (cursor == null) {
      setState(() {
        hasMore = false;
        _loadMoreError = "分页数据不正确";
      });
      return;
    }
    // 保存当前列表版本 如果请求期间发生下拉刷新 这个版本就会失效
    final generation = _listGeneration;

    setState(() {
      _loadingMore = true;
      _loadMoreError = null;
    });

    try {
      final page = await widget.transactionApi.listPage(
        cursor: cursor,
        limit: _pageSize,
        startAt: monthStart,
        endAt: monthEnd,
      );
      // 刷新发生后 不能把就分页请求的数据追加到新列表
      if (!mounted || generation != _listGeneration) {
        return;
      }
      // 使用id去重 分页过程中如果新增账单 或后端数据发生变化 相邻两页理论上可能出现重复记录
      final existingIds = transactions
          .map((transaction) => transaction.id)
          .toSet();

      final newItems = page.items.where((transaction) {
        return existingIds.add(transaction.id);
      }).toList();

      setState(() {
        transactions = [...transactions, ...newItems];

        nextCursor = page.nextCursor;
        hasMore = page.hasMore;
        _loadMoreError = null;
      });

      // 如果追加一页后 扔没有撑满屏幕 继续检查
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadMoreIfNeeded();
      });
    } on UnauthorizedException {
      if (!mounted || generation != _listGeneration) {
        return;
      }
      await widget.onLogout();
    } on ApiException catch (e) {
      if (!mounted || generation != _listGeneration) {
        return;
      }
      setState(() {
        _loadMoreError = e.message;
      });
    } catch (e) {
      if (!mounted || generation != _listGeneration) {
        return;
      }
      setState(() {
        _loadMoreError = "加载更多失败";
      });
    } finally {
      // 不一致说明加载更多期间发生了第一页的刷新
      final requestBecameStale = generation != _listGeneration;
      // 请求已经失败 也要解除loadingMore 否则以后无法分页
      if (mounted) {
        setState(() {
          _loadingMore = false;
        });
        // 刷新后的第一页数据可能没撑满屏幕 旧请求结束后 重新检查 而不是直接自动重试失败请求
        if (requestBecameStale) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadMoreIfNeeded();
          });
        }
      } else {
        _loadingMore = false;
      }
    }
  }

  // 处理列表加载失败
  // 没有旧数据显示完整错误页 有旧数据则显示旧数据 用toolbar显示错误
  void _handleLoadError(String text) {
    if (transactions.isEmpty) {
      setState(() {
        message = text;
      });
      return;
    }
    final messenger = ScaffoldMessenger.of(context);

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildListFooter() {
    if (_loadingMore) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        child: Center(
          child: OutlinedButton.icon(
            onPressed: _loadMoreTransactions,
            label: Text("加载失败，点击重试"),
            icon: Icon(Icons.refresh),
          ),
        ),
      );
    }
    // 保留底部空间 避免被悬浮新增按钮遮挡
    return const SizedBox(height: 96);
  }

  List<TransactionDayGroup> get dayGroups {
    return groupTransactionsByDay(transactions);
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
          return HomeContent(
            scrollController: _scrollController,
            selectedMonth: selectedMonth,
            monthLoading: _loadingFirstPage || _loadingMore,
            canGoNextMonth: canGoNextMonth,
            summary: summary,
            groups: groups,
            footer: _buildListFooter(),
            onRefresh: () {
              return loadTransaction();
            },
            onPreviousMonth: () {
              changeMonth(-1);
            },
            onNextMonth: () {
              changeMonth(1);
            },
            onTransactionTap: (transaction) {
              openTransaction(transaction);
            },
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
