import 'package:flutter/material.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/feature/home/home_ledger_controller.dart';
import 'package:mobile/feature/home/widgets/home_content.dart';
import 'package:mobile/feature/household/household_session.dart';
import 'package:mobile/feature/household/household_api.dart';
import 'package:mobile/feature/household/household_overview_page.dart';
import 'package:mobile/feature/household/widgets/household_switcher_sheet.dart';
import 'package:mobile/feature/transaction/add_transaction.dart';
import 'package:mobile/feature/transaction/transaction.dart';
import 'package:mobile/feature/transaction/transaction_api.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.email,
    required this.onLogout,
    required this.transactionApi,
    required this.householdApi,
    required this.householdSession,
    required this.onCreateHousehold,
  });

  final String email;
  final Future<void> Function() onLogout;
  final TransactionApi transactionApi;
  final HouseholdApi householdApi;
  final HouseholdSession householdSession;
  final Future<void> Function() onCreateHousehold;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();
  late final HomeLedgerController _ledgerController;

  @override
  void initState() {
    super.initState();
    _ledgerController = HomeLedgerController(
      transactionApi: widget.transactionApi,
    )..addListener(_handleLedgerChanged);
    _scrollController.addListener(_handleScroll);
    _loadFirstPage(showFullScreenLoading: true);
  }

  void _handleLedgerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ledgerController.removeListener(_handleLedgerChanged);
    _ledgerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFirstPage({bool showFullScreenLoading = false}) async {
    final hadData = _ledgerController.transactions.isNotEmpty;
    try {
      await _ledgerController.loadFirstPage(
        showFullScreenLoading: showFullScreenLoading,
      );
    } on UnauthorizedException {
      if (mounted) await widget.onLogout();
      return;
    }
    if (!mounted) return;
    if (hadData && _ledgerController.message.isNotEmpty) {
      _showRequestError(_ledgerController.message);
      return;
    }
    if (_ledgerController.message.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadMoreIfNeeded());
    }
  }

  Future<void> _changeMonth(int offset) async {
    try {
      await _ledgerController.changeMonth(offset);
    } on UnauthorizedException {
      if (mounted) await widget.onLogout();
      return;
    }
    if (mounted && _ledgerController.message.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadMoreIfNeeded());
    }
  }

  Future<void> _reloadSelectedHousehold() async {
    if (!mounted) return;
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    try {
      await _ledgerController.reloadSelectedHousehold();
    } on UnauthorizedException {
      if (mounted) await widget.onLogout();
      return;
    }
    if (mounted && _ledgerController.message.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadMoreIfNeeded());
    }
  }

  Future<void> _openHouseholdSwitcher() async {
    if (_ledgerController.busy) return;
    final currentHousehold = widget.householdSession.selectedHousehold;
    if (currentHousehold == null) return;
    final selectedHousehold = await showHouseholdSwitcherSheet(
      context: context,
      households: widget.householdSession.households,
      selectedHouseholdId: currentHousehold.id,
      onCreateHousehold: () async {
        final previousHouseholdId = widget.householdSession.selectedHouseholdId;
        await widget.onCreateHousehold();
        if (!mounted) return;
        final currentHouseholdId = widget.householdSession.selectedHouseholdId;
        if (currentHouseholdId != null &&
            currentHouseholdId != previousHouseholdId) {
          await _reloadSelectedHousehold();
        }
      },
    );
    if (!mounted || selectedHousehold == null) return;
    if (selectedHousehold.id == currentHousehold.id) return;
    try {
      await widget.householdSession.select(selectedHousehold);
      if (mounted) await _reloadSelectedHousehold();
    } catch (_) {
      if (mounted) _showRequestError('切换家庭失败，请稍后重试');
    }
  }

  Future<void> _openHouseholdOverview() async {
    final household = widget.householdSession.selectedHousehold;
    if (household == null) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder:
            (pageContext) => HouseholdOverviewPage(
              household: household,
              householdApi: widget.householdApi,
              onUnauthorized: () async {
                if (pageContext.mounted) Navigator.of(pageContext).pop();
                await widget.onLogout();
              },
            ),
      ),
    );
  }

  void _handleScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 200) {
      _loadMoreTransactions();
    }
  }

  void _loadMoreIfNeeded() {
    if (mounted &&
        _scrollController.hasClients &&
        _scrollController.position.extentAfter < 200) {
      _loadMoreTransactions();
    }
  }

  Future<void> _loadMoreTransactions() async {
    try {
      await _ledgerController.loadMore();
    } on UnauthorizedException {
      if (mounted) await widget.onLogout();
      return;
    }
    if (mounted && _ledgerController.loadMoreError == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadMoreIfNeeded());
    }
  }

  void _showRequestError(String text) {
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
    if (_ledgerController.loadingMore) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 20, 16, 96),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_ledgerController.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        child: Center(
          child: OutlinedButton.icon(
            onPressed: _loadMoreTransactions,
            icon: const Icon(Icons.refresh),
            label: const Text('加载失败，点击重试'),
          ),
        ),
      );
    }
    return const SizedBox(height: 96);
  }

  Future<void> _openTransactionEditor({Transaction? transaction}) async {
    final household = widget.householdSession.selectedHousehold;
    if (household == null || !household.canWrite) {
      _showRequestError('只读成员不能修改账单');
      return;
    }
    final change = await Navigator.push<TransactionChange>(
      context,
      MaterialPageRoute(
        builder:
            (context) => AddTransaction(
              transaction: transaction,
              transactionApi: widget.transactionApi,
            ),
      ),
    );
    if (change == null) return;
    await _loadFirstPage();
    if (mounted) _showChangeSuccess(change);
  }

  void _showChangeSuccess(TransactionChange change) {
    final text = switch (change) {
      TransactionChange.created => '账单已生成',
      TransactionChange.updated => '账单已更新',
      TransactionChange.deleted => '账单已删除',
    };
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
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
    final currentHousehold = widget.householdSession.selectedHousehold;
    if (currentHousehold == null) {
      return const Scaffold(body: Center(child: Text('当前没有可用家庭')));
    }
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: InkWell(
          onTap: _ledgerController.busy ? null : _openHouseholdSwitcher,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    currentHousehold.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _ledgerController.busy ? null : _openHouseholdOverview,
            tooltip: '家庭成员',
            icon: const Icon(Icons.group_outlined),
          ),
          IconButton(
            onPressed: widget.onLogout,
            tooltip: '退出登录',
            icon: const Icon(Icons.logout_outlined),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (_ledgerController.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_ledgerController.message.isNotEmpty &&
              _ledgerController.transactions.isEmpty) {
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
                    Text(
                      _ledgerController.message,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed:
                          () => _loadFirstPage(showFullScreenLoading: true),
                      icon: const Icon(Icons.refresh),
                      label: const Text('重新加载'),
                    ),
                  ],
                ),
              ),
            );
          }
          return HomeContent(
            scrollController: _scrollController,
            selectedMonth: _ledgerController.selectedMonth,
            monthLoading: _ledgerController.busy,
            canGoNextMonth: _ledgerController.canGoNextMonth,
            summary: _ledgerController.summary,
            groups: _ledgerController.dayGroups,
            footer: _buildListFooter(),
            onRefresh: _loadFirstPage,
            onPreviousMonth: () => _changeMonth(-1),
            onNextMonth: () => _changeMonth(1),
            onTransactionTap: (transaction) {
              _openTransactionEditor(transaction: transaction);
            },
          );
        },
      ),
      floatingActionButton:
          currentHousehold.canWrite
              ? FloatingActionButton(
                onPressed: () => _openTransactionEditor(),
                child: const Icon(Icons.add),
              )
              : null,
    );
  }
}
