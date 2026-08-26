package transactions

import "time"

type TransactionType string

const (
	TypeIncome  TransactionType = "income"  //收入
	TypeExpense TransactionType = "expense" //支出
)

type Transaction struct {
	Id         int64           `json:"id"`
	UserId     int64           `json:"userId"`
	Type       TransactionType `json:"type"`
	Amount     int64           `json:"amount"`
	Category   string          `json:"category"`
	Note       string          `json:"note"`
	CreatedAt  time.Time       `json:"createdAt"`
	OccurredAt time.Time       `json:"occurredAt"`
}

type CreateTransactionRequest struct {
	Type       TransactionType `json:"type" binding:"required,oneof=income expense"`
	Amount     int64           `json:"amount" binding:"required,gt=0"`
	Category   string          `json:"category" binding:"required,max=20"`
	Note       string          `json:"note" binding:"max=200"`
	OccurredAt time.Time       `json:"occurredAt" binding:"required"`
}

type UpdateTransactionRequest struct {
	Type       TransactionType `json:"type" binding:"required,oneof=income expense"`
	Amount     int64           `json:"amount" binding:"required,gt=0"`
	Category   string          `json:"category" binding:"required,max=20"`
	Note       string          `json:"note" binding:"max=200"`
	OccurredAt time.Time       `json:"occurredAt" binding:"required"`
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
	Cursor string `form:"cursor" binding:"omitempty"`

	// 每页最少 1 条，最多 50 条。
	Limit int `form:"limit" binding:"omitempty,gte=1,lte=50"`

	StartAt time.Time `form:"startAt" binding:"required" time_format:"2006-01-02T15:04:05Z07:00"`

	EndAt time.Time `form:"endAt" binding:"required" time_format:"2006-01-02T15:04:05Z07:00"`
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
	NextCursor *string `json:"nextCursor,omitempty"`
	// 表示是否还有下一页
	HasMore bool `json:"hasMore"`
}

type TransactionCategorySummary struct {
	Type     TransactionType `json:"type"`
	Category string          `json:"category"`
	Amount   int64           `json:"amount"`
}

type TransactionSummary struct {
	Income     int64                        `json:"income"`
	Expense    int64                        `json:"expense"`
	Balance    int64                        `json:"balance"`
	Categories []TransactionCategorySummary `json:"categories"`
}

// 增加汇总查询模型
type SummaryTransactionsQuery struct {
	StartAt time.Time `form:"startAt" binding:"required" time_format:"2006-01-02T15:04:05Z07:00"`

	EndAt time.Time `form:"endAt" binding:"required" time_format:"2006-01-02T15:04:05Z07:00"`
}
