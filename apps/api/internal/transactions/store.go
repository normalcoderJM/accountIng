package transactions

import (
	"context"
	"database/sql"
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
	INSERT INTO transactions(user_id,type,amount,category,note)
	VALUES($1,$2,$3,$4,$5)
	RETURNING id,user_id,type,amount,category,note,created_at`

	var transaction Transaction
	err := s.db.QueryRowContext(ctx, query, userId, req.Type, req.Amount, req.Category, req.Note).Scan(
		&transaction.Id,
		&transaction.UserId,
		&transaction.Type,
		&transaction.Amount,
		&transaction.Category,
		&transaction.Note,
		&transaction.CreatedAt,
	)
	if err != nil {
		return Transaction{}, err
	}
	return transaction, nil
}

// 通过userId 查询账单列表
func (s *Store) ListByUserId(ctx context.Context, userId int64) ([]Transaction, error) {
	const query = `
	SELECT id,user_id,type,amount,category,note,created_at
	FROM transactions
	WHERE user_id=$1
	ORDER BY created_at DESC`
	// 查询多条
	rows, err := s.db.QueryContext(ctx, query, userId)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	transactions := make([]Transaction, 0) //空切片
	// 一行一行遍历数据库结果。
	for rows.Next() {
		var transaction Transaction
		err := rows.Scan(
			&transaction.Id,
			&transaction.UserId,
			&transaction.Type,
			&transaction.Amount,
			&transaction.Category,
			&transaction.Note,
			&transaction.CreatedAt,
		)
		if err != nil {
			return nil, err
		}
		transactions = append(transactions, transaction)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return transactions, nil
}

// 修改账单接口
func (s *Store) Update(ctx context.Context, userId int64, id int64, req UpdateTransactionRequest) (Transaction, error) {
	const query = `
		UPDATE transactions SET type =$1,amount = $2,category = $3,note = $4
		WHERE id = $5 AND user_id = $6
		RETURNING id,user_id,type,amount,category,note,created_at
	`
	var transaction Transaction

	err := s.db.QueryRowContext(
		ctx, query, req.Type, req.Amount, req.Category, req.Note, id, userId,
	).Scan(
		&transaction.Id,
		&transaction.UserId,
		&transaction.Type,
		&transaction.Amount,
		&transaction.Category,
		&transaction.Note,
		&transaction.CreatedAt,
	)
	if err != nil {
		return Transaction{}, err
	}
	return transaction, nil
}

// 删除账单接口
func (s *Store) Delete(ctx context.Context, id int64, userId int64) (Transaction error) {
	const query = `DELETE FROM transactions WHERE Id = $1 AND user_id = $2`
	result, err := s.db.ExecContext(ctx, query, id, userId)
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
