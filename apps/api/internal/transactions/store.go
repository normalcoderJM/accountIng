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
func (s *Store) Create(ctx context.Context, userId int64, householdId int64, req CreateTransactionRequest) (Transaction, error) {
	const query = `
	INSERT INTO transactions(
	household_id,user_id,type,amount,category,note,occurred_at)
	SELECT $1,$2,$3,$4,$5,$6,$7
	WHERE EXISTS (
	SELECT 1
	FROM household_members
	WHERE household_id = $1
	AND user_id = $2
	AND status = 'active'
	AND role IN ('owner','admin','member')
	)
	RETURNING
	id,household_id,user_id,type,amount,category,note,occurred_at,created_at`

	var transaction Transaction
	err := s.db.QueryRowContext(ctx, query, householdId, userId, req.Type, req.Amount, req.Category, req.Note, req.OccurredAt).Scan(
		&transaction.Id,
		&transaction.HouseholdId,
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
func (s *Store) ListPageByHouseholdId(
	ctx context.Context,
	userId int64,
	householdId int64,
	startAt time.Time,
	endAt time.Time,
	cursor *transactionCursor,
	limit int) ([]Transaction, error) {
	// 第一页数据
	const firstPageQuery = `
	SELECT
	t.id,
	t.household_id,
	t.user_id,
	t.type,
	t.amount,
	t.category,
	t.note,
	t.occurred_at,
	t.created_at
	FROM transactions AS t
	WHERE
	t.household_id = $1
	 AND t.occurred_at >= $3
	 AND t.occurred_at < $4
	 AND EXISTS(
	 SELECT 1
	 FROM household_members AS member
	 WHERE member.household_id = t.household_id
	 AND member.user_id = $2
	 AND member.status = 'active'
	 )
	ORDER BY t.occurred_at DESC, t.id DESC
	LIMIT $5
	`
	// 下一页数据
	const nextPageQuery = `SELECT
	t.id,
	t.household_id,
	t.user_id,
	t.type,
	t.amount,
	t.category,
	t.note,
	t.occurred_at,
	t.created_at
	FROM transactions AS t
	WHERE t.household_id = $1
	AND t.occurred_at >=$3
	AND t.occurred_at < $4
	AND (t.occurred_at,t.id) < ($5,$6)
	AND EXISTS(
	SELECT 1
	FROM household_members AS member
	WHERE member.household_id = t.household_id
	AND member.user_id = $2
	AND member.status ='active'
	)
	ORDER BY t.occurred_at DESC, t.id DESC
	LIMIT $7
	`
	//多查询一条 用来判断后面是否还有数据
	queryLimit := limit + 1
	var (
		rows *sql.Rows
		err  error
	)
	if cursor == nil {
		rows, err = s.db.QueryContext(
			ctx, firstPageQuery, householdId, userId, startAt, endAt, queryLimit,
		)
		// // 第一次请求没有页码
		// rows, err = s.db.QueryContext(
		// 	ctx, firstPageQuery, userId, queryLimit,
		// )
	} else {
		// 下一页只查询ID 小于上一页最后一条的数据
		rows, err = s.db.QueryContext(
			ctx, nextPageQuery, householdId, userId, startAt, endAt, cursor.OccurredAt, cursor.Id, queryLimit,
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
			&transaction.HouseholdId,
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
func (s *Store) SummaryByHouseholdId(
	ctx context.Context,
	userId int64,
	householdId int64,
	startAt time.Time,
	endAt time.Time) (TransactionSummary, error) {
	const query = `SELECT
	t.type,
	t.category,
	SUM(t.amount)::BIGINT AS total_amount
	FROM transactions AS t
	WHERE t.household_id = $1
	AND t.occurred_at >=$3
	AND t.occurred_at <$4
	AND EXISTS (
	SELECT 1
	FROM household_members AS member
	WHERE member.household_id = t.household_id
	AND member.user_id = $2
	AND member.status = 'active'
	)
	GROUP BY t.type,t.category
	ORDER BY t.type ASC,total_amount DESC,t.category ASC
	`

	rows, err := s.db.QueryContext(ctx, query, householdId, userId, startAt, endAt)
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
func (s *Store) Update(
	ctx context.Context,
	userId int64,
	householdId int64,
	id int64,
	req UpdateTransactionRequest) (Transaction, error) {
	const query = `
		UPDATE transactions AS transaction
		SET type =$1,
		amount = $2,
		category = $3,
		note = $4,
		occurred_at = $5
		WHERE transaction.id = $6 AND transaction.household_id = $7
		AND EXISTS(
		SELECT 1
		FROM household_members AS member
		WHERE member.household_id = transaction.household_id
		AND member.user_id = $8
		AND member.status = 'active'
		AND member.role IN ('owner','admin','member')
		)
		RETURNING
		transaction.id,
		transaction.household_id,
		transaction.user_id,
		transaction.type,
		transaction.amount,
		transaction.category,
		transaction.note,
		transaction.occurred_at,
		transaction.created_at
	`
	var transaction Transaction

	err := s.db.QueryRowContext(
		ctx, query, req.Type, req.Amount, req.Category, req.Note, req.OccurredAt, id, householdId, userId,
	).Scan(
		&transaction.Id,
		&transaction.HouseholdId,
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
func (s *Store) Delete(ctx context.Context, userId int64, householdId int64, id int64) error {
	const query = `
	DELETE FROM transactions AS transaction
	WHERE transaction.household_id = $1 AND transaction.id = $2
	AND EXISTS(
	SELECT 1
	FROM household_members AS member
	WHERE member.household_id = transaction.household_id
	AND member.user_id = $3
	AND member.status = 'active'
	AND member.role IN ('owner','admin','member')
	)
	`
	result, err := s.db.ExecContext(ctx, query, householdId, id, userId)
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
