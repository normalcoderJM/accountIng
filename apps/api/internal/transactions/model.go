package transactions

import "time"

type TransactionType string

const (
	TypeIncome  TransactionType = "income"  //收入
	TypeExpense TransactionType = "expense" //支出
)

type Transaction struct {
	Id        int64           `json:"id"`
	UserId    int64           `json:"userId"`
	Type      TransactionType `json:"type"`
	Amount    int64           `json:"amount"`
	Category  string          `json:"category"`
	Note      string          `json:"note"`
	CreatedAt time.Time       `json:"createdAt"`
}

type CreateTransactionRequest struct {
	Type     TransactionType `json:"type" binding:"required,oneof=income expense"`
	Amount   int64           `json:"amount" binding:"required"`
	Category string          `json:"category" binding:"required"`
	Note     string          `json:"note"`
}
