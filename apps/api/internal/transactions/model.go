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
	Amount   int64           `json:"amount" binding:"required,gt=0"`
	Category string          `json:"category" binding:"required,max=20"`
	Note     string          `json:"note" binding:"max=200"`
}

type UpdateTransactionRequest struct {
	Type     TransactionType `json:"type" binding:"required,oneof=income expense"`
	Amount   int64           `json:"amount" binding:"required,gt=0"`
	Category string          `json:"category" binding:"required,max=20"`
	Note     string          `json:"note" binding:"max=200"`
}

const (
	// DefaultPageSize 是客户端没有传 limit 时的默认数量。
	DefaultPageSize = 20
	// MaxPageSize 防止客户端一次请求过多数据。
	MaxPageSize = 50
)

// ListTransactionsQuery 是账单列表接口的查询参数。
// 例如：GET /transactions?cursor=100&limit=20
type ListTransactionsQuery struct {
	// cursor=0 表示从第一页开始查询。
	Cursor int64 `form:"cursor" binding:"omitempty,gte=0"`

	// 每页最少 1 条，最多 50 条。
	Limit int `form:"limit" binding:"omitempty,gte=1,lte=50"`
}

// 补充默认分页参数
func (q *ListTransactionsQuery) ApplyDefaults() {
	if q.Limit == 0 {
		q.Limit = DefaultPageSize
	}
}

// 分页后的账单数据
type TransactionPage struct {
	// items 是本页账单
	Items []Transaction `json:"items"`
	// 没有下一页时不返回该字段
	NextCursor *int64 `json:"nextCursor,omitempty"`
	// 表示是否还有下一页
	HasMore bool `json:"hasMore"`
}
