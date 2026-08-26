package transactions

import (
	"context"
	"database/sql"
	"time"
)

type Store struct {
	db *sql.DB
}

func NewStore(db *sql.DB) *Store {
	return &Store{db: db}
}

// 创建账单
func (s *Store) Create(ctx context.Context, userId int64, req CreateTransactionRequest) (Transaction, error) {
	const query = `
	INSERT INTO transactions(user_id,type,amount,category,note,occurred_at)
	VALUES($1,$2,$3,$4,$5,$6)
	RETURNING id,user_id,type,amount,category,note,occurred_at,created_at`

	var transaction Transaction
	err := s.db.QueryRowContext(ctx, query, userId, req.Type, req.Amount, req.Category, req.Note, req.OccurredAt).Scan(
		&transaction.Id,
		&transaction.UserId,
		&transaction.Type,
		&transaction.Amount,
		&transaction.Category,
		&transaction.Note,
		&transaction.OccurredAt,
		&transaction.CreatedAt,
	)
	if err != nil {
		return Transaction{}, err
	}
	return transaction, nil
}

// 账单分页
func (s *Store) ListPageByUserId(
	ctx context.Context,
	userId int64,
	startAt time.Time,
	endAt time.Time,
	cursor *transactionCursor,
	limit int) ([]Transaction, error) {
	const firstPageQuery = `SELECT id,user_id,type,amount,category,note,occurred_at,created_at
	FROM transactions
	WHERE user_id = $1 AND occurred_at  >= $2 AND occurred_at < $3
	ORDER BY occurred_at DESC, id DESC
	LIMIT $4
	`
	const nextPageQuery = `SELECT id,user_id,type,amount,category,note,occurred_at,created_at
	FROM transactions
	WHERE user_id = $1 AND occurred_at >= $2 AND occurred_at < $3 AND (occurred_at,id) < ($4,$5)
	ORDER BY occurred_at DESC, id DESC
	LIMIT $6
	`
	//多查询一条 用来判断后面是否还有数据
	queryLimit := limit + 1
	var (
		rows *sql.Rows
		err  error
	)
	if cursor == nil {
		rows, err = s.db.QueryContext(
			ctx, firstPageQuery, userId, startAt, endAt, queryLimit,
		)
		// // 第一次请求没有页码
		// rows, err = s.db.QueryContext(
		// 	ctx, firstPageQuery, userId, queryLimit,
		// )
	} else {
		// 下一页只查询ID 小于上一页最后一条的数据
		rows, err = s.db.QueryContext(
			ctx, nextPageQuery, userId, startAt, endAt, cursor.OccurredAt, cursor.Id, queryLimit,
		)
	}

	if err != nil {
		return nil, err
	}
	defer rows.Close()

	transactions := make([]Transaction, 0, queryLimit)
	for rows.Next() {
		var transaction Transaction
		err := rows.Scan(
			&transaction.Id,
			&transaction.UserId,
			&transaction.Type,
			&transaction.Amount,
			&transaction.Category,
			&transaction.Note,
			&transaction.OccurredAt,
			&transaction.CreatedAt,
		)
		if err != nil {
			return nil, err
		}
		transactions = append(transactions, transaction)
	}
	// rows.next()遍历过程中可能发生数据库错误 所以循环结束后需要检查一次
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return transactions, nil
}

// SummaryByUserId 查询指定时间范围内的账单汇总。
// 聚合必须由数据库完成，不能先把全部账单读取到 Go 内存中再计算。
// 数据库只向 Go 返回“类型 + 分类”的汇总结果，数据量远小于原始账单。
func (s *Store) SummaryByUserId(
	ctx context.Context,
	userId int64,
	startAt time.Time,
	endAt time.Time) (TransactionSummary, error) {
	const query = `SELECT type,category, SUM(amount)::BIGINT AS total_amount
	FROM transactions
	WHERE user_id = $1 AND occurred_at >= $2 AND occurred_at < $3
	GROUP BY type,category
	ORDER BY type ASC,total_amount DESC,category ASC
	`

	rows, err := s.db.QueryContext(ctx, query, userId, startAt, endAt)
	if err != nil {
		return TransactionSummary{}, err
	}
	defer rows.Close()

	summary := TransactionSummary{
		// 初始化空切片 保证JSON返回[]而不是null
		Categories: make([]TransactionCategorySummary, 0),
	}

	for rows.Next() {
		var categorySummary TransactionCategorySummary
		if err := rows.Scan(&categorySummary.Type, &categorySummary.Category, &categorySummary.Amount); err != nil {
			return TransactionSummary{}, err
		}

		summary.Categories = append(summary.Categories, categorySummary)
		// 总收入和总支持来自所有分类金额之和
		switch categorySummary.Type {
		case TypeIncome:
			summary.Income += categorySummary.Amount
		case TypeExpense:
			summary.Expense += categorySummary.Amount
		}

	}
	if err := rows.Err(); err != nil {
		return TransactionSummary{}, err
	}
	return summary, nil

}

// 修改账单接口
func (s *Store) Update(ctx context.Context, userId int64, id int64, req UpdateTransactionRequest) (Transaction, error) {
	const query = `
		UPDATE transactions SET type =$1,amount = $2,category = $3,note = $4,occurred_at = $5
		WHERE id = $6 AND user_id = $7
		RETURNING id,user_id,type,amount,category,note,occurred_at,created_at
	`
	var transaction Transaction

	err := s.db.QueryRowContext(
		ctx, query, req.Type, req.Amount, req.Category, req.Note, req.OccurredAt, id, userId,
	).Scan(
		&transaction.Id,
		&transaction.UserId,
		&transaction.Type,
		&transaction.Amount,
		&transaction.Category,
		&transaction.Note,
		&transaction.OccurredAt,
		&transaction.CreatedAt,
	)
	if err != nil {
		return Transaction{}, err
	}
	return transaction, nil
}

// 删除账单接口
func (s *Store) Delete(ctx context.Context, userId int64, id int64) error {
	const query = `DELETE FROM transactions WHERE user_id = $1 AND Id = $2`
	result, err := s.db.ExecContext(ctx, query, userId, id)
	if err != nil {
		return err
	}
	// RowsAffected数据库告诉我们实际删除了几行
	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rowsAffected == 0 {
		return sql.ErrNoRows
	}
	return nil
}
