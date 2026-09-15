import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/feature/home/transaction_day_group.dart';
import 'package:mobile/feature/transaction/transaction.dart';
import 'package:mobile/feature/transaction/transaction_api.dart';
import 'package:mobile/feature/transaction/transaction_page.dart';
import 'package:mobile/feature/transaction/transaction_summary.dart';

class HomeLedgerController extends ChangeNotifier {
  HomeLedgerController({required this.transactionApi, DateTime? initialMonth})
    : selectedMonth = _monthOf(initialMonth ?? DateTime.now());

  static const _pageSize = 20;

  final TransactionApi transactionApi;

  bool _loading = true;
  bool _loadingFirstPage = false;
  bool _loadingMore = false;
  String? _loadMoreError;
  String _message = '';
  List<Transaction> _transactions = const [];
  TransactionSummary _summary = TransactionSummary.empty;
  String? _nextCursor;
  bool _hasMore = false;
  int _listGeneration = 0;

  DateTime selectedMonth;

  bool get loading => _loading;
  bool get loadingFirstPage => _loadingFirstPage;
  bool get loadingMore => _loadingMore;
  bool get busy => _loadingFirstPage || _loadingMore;
  String? get loadMoreError => _loadMoreError;
  String get message => _message;
  // 不可修改列表 只能开辟新的内存地址 驱使视图更新
  List<Transaction> get transactions => UnmodifiableListView(_transactions);
  TransactionSummary get summary => _summary;
  bool get hasMore => _hasMore;
  List<TransactionDayGroup> get dayGroups =>
      groupTransactionsByDay(_transactions);

  DateTime get monthStart => _monthOf(selectedMonth);
  DateTime get monthEnd =>
      DateTime(selectedMonth.year, selectedMonth.month + 1, 1);

  bool get canGoNextMonth {
    final currentMonth = _monthOf(DateTime.now());
    return selectedMonth.isBefore(currentMonth);
  }

  Future<void> changeMonth(int offset) async {
    if (busy) return;

    final targetMonth = DateTime(
      selectedMonth.year,
      selectedMonth.month + offset,
      1,
    );
    if (targetMonth.isAfter(_monthOf(DateTime.now()))) return;

    selectedMonth = targetMonth;
    _resetList();
    notifyListeners();
    await loadFirstPage(showFullScreenLoading: true);
  }

  Future<void> reloadSelectedHousehold() async {
    _resetList();
    notifyListeners();
    await loadFirstPage(showFullScreenLoading: true);
  }

  Future<void> loadFirstPage({bool showFullScreenLoading = false}) async {
    if (_loadingFirstPage) return;

    _loadingFirstPage = true;
    final generation = ++_listGeneration;
    _message = '';
    if (showFullScreenLoading) _loading = true;
    notifyListeners();

    final startAt = monthStart;
    final endAt = monthEnd;
    try {
      final results = await Future.wait<Object>([
        transactionApi.listPage(
          limit: _pageSize,
          startAt: startAt,
          endAt: endAt,
        ),
        transactionApi.getSummary(startAt: startAt, endAt: endAt),
      ]);

      if (generation != _listGeneration) return;
      final page = results[0] as TransactionPage;
      _transactions = page.items;
      _nextCursor = page.nextCursor;
      _summary = results[1] as TransactionSummary;
      _hasMore = page.hasMore;
      _loadMoreError = null;
    } on UnauthorizedException {
      rethrow;
    } on ApiException catch (error) {
      _message = error.message;
    } catch (_) {
      _message = '账单加载失败';
    } finally {
      _loadingFirstPage = false;
      if (showFullScreenLoading) _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_loadingMore || _loadingFirstPage || !_hasMore) return;

    final cursor = _nextCursor;
    if (cursor == null) {
      _hasMore = false;
      _loadMoreError = '分页数据不正确';
      notifyListeners();
      return;
    }

    final generation = _listGeneration;
    _loadingMore = true;
    _loadMoreError = null;
    notifyListeners();

    try {
      final page = await transactionApi.listPage(
        cursor: cursor,
        limit: _pageSize,
        startAt: monthStart,
        endAt: monthEnd,
      );
      if (generation != _listGeneration) return;

      final existingIds = _transactions.map((item) => item.id).toSet();
      final newItems = page.items
          .where((item) => existingIds.add(item.id))
          .toList(growable: false);
      _transactions = [..._transactions, ...newItems];
      _nextCursor = page.nextCursor;
      _hasMore = page.hasMore;
    } on UnauthorizedException {
      rethrow;
    } on ApiException catch (error) {
      if (generation == _listGeneration) {
        _loadMoreError = error.message;
      }
    } catch (_) {
      if (generation == _listGeneration) {
        _loadMoreError = '加载更多失败';
      }
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  void _resetList() {
    _transactions = const [];
    _summary = TransactionSummary.empty;
    _nextCursor = null;
    _hasMore = false;
    _message = '';
    _loadMoreError = null;
  }

  static DateTime _monthOf(DateTime date) => DateTime(date.year, date.month, 1);
}
