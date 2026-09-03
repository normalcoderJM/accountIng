package transactions

import (
	"context"
	"strings"
	"time"
)

// Repository 定义service需要的数据操作
// store 只要实现这些方法 就自动满足repository接口
// 不需要写implements
type Repository interface {
	Create(ctx context.Context, userId int64, householdId int64, req CreateTransactionRequest) (Transaction, error)
	ListPageByHouseholdId(ctx context.Context, userId int64, householdId int64, startAt time.Time, endAt time.Time, cursor *transactionCursor, limit int) ([]Transaction, error)
	Update(ctx context.Context, userId int64, householdId int64, id int64, req UpdateTransactionRequest) (Transaction, error)
	Delete(ctx context.Context, userId int64, householdId int64, id int64) error
	SummaryByHouseholdId(ctx context.Context, userId int64, householdId int64, startAt time.Time, endAt time.Time) (TransactionSummary, error)
}

// 定义账单木块需要的家庭权限能力
type HouseholdAccess interface {
	RequireReadAccess(ctx context.Context, userId int64, householdId int64) error
	RequireWriteAccess(ctx context.Context, userId int64, householdId int64) error
}

// service负责账单业务逻辑 handler处理http store只处理sql service负责两者中间的业务流程
type Service struct {
	repository       Repository
	householdAccess  HouseholdAccess
	operationTimeout time.Duration
}

// newService 创建账单Service
func NewService(repository Repository, householdAccess HouseholdAccess, operationTimeout time.Duration) *Service {
	return &Service{
		repository:       repository,
		householdAccess:  householdAccess,
		operationTimeout: operationTimeout,
	}
}

// create创建账单
func (s *Service) Create(
	ctx context.Context,
	userId int64,
	householdId int64,
	req CreateTransactionRequest) (Transaction, error) {
	// 用户输入可能包含前后空格  在业务层统一清理 避免数据库保存脏数据
	req.Category = strings.TrimSpace(req.Category)
	req.Note = strings.TrimSpace(req.Note)
	// 数据库操作最多运行指定时间
	operationContext, cancel := context.WithTimeout(ctx, s.operationTimeout)
	defer cancel()
	// viewer或非家庭成员不能新增账单
	if err := s.householdAccess.RequireWriteAccess(operationContext, userId, householdId); err != nil {
		return Transaction{}, err
	}

	return s.repository.Create(
		operationContext,
		userId,
		householdId,
		req,
	)
}

// 分页
func (s *Service) ListPage(ctx context.Context, userId int64, householdId int64, query ListTransactionsQuery) (TransactionPage, error) {
	// 即使不是从http handler调用 也保证操作有值
	query.ApplyDefaults()

	if err := validateTransactionPeriod(query.StartAt, query.EndAt); err != nil {
		return TransactionPage{}, err
	}

	cursor, err := decodeTransactionCursor(query.Cursor)
	if err != nil {
		return TransactionPage{}, err
	}

	operationContext, cancel := context.WithTimeout(ctx, s.operationTimeout)
	defer cancel()
	// 检查当前用户是否有读取权限
	if err := s.householdAccess.RequireReadAccess(operationContext, userId, householdId); err != nil {
		return TransactionPage{}, err
	}
	// store 会查询limit+1条数据
	transactions, err := s.repository.ListPageByHouseholdId(
		operationContext, userId, householdId, query.StartAt, query.EndAt, cursor, query.Limit,
	)
	if err != nil {
		return TransactionPage{}, err
	}
	// 没有数据 返回[] 不返回null
	if transactions == nil {
		transactions = make([]Transaction, 0)
	}
	// 如果查询结果比客户端要求的数量更多 说明还有后面的数据
	hasMore := len(transactions) > query.Limit

	if hasMore {
		// 多查询的最后一条只用于判断是否还有下一页，
		// 不能返回给客户端。
		transactions = transactions[:query.Limit]
	}
	var nextCursor *string
	// 确定有下一页数据 才会生成nextCursor
	if hasMore && len(transactions) > 0 {
		value := encodeTransactionCursor(transactions[len(transactions)-1])

		nextCursor = &value

	}
	return TransactionPage{
		Items:      transactions,
		NextCursor: nextCursor,
		HasMore:    hasMore,
	}, nil
}

// Summary 返回当前用户全部账单的汇总
func (s *Service) Summary(ctx context.Context, userId int64, householdId int64, query SummaryTransactionsQuery) (TransactionSummary, error) {
	if err := validateTransactionPeriod(query.StartAt, query.EndAt); err != nil {
		return TransactionSummary{}, err
	}
	operationContext, cancel := context.WithTimeout(ctx, s.operationTimeout)
	defer cancel()
	// 检查当前用户是否有查看全部账单权限
	if err := s.householdAccess.RequireReadAccess(operationContext, userId, householdId); err != nil {
		return TransactionSummary{}, err
	}

	summary, err := s.repository.SummaryByHouseholdId(operationContext, userId, householdId, query.StartAt, query.EndAt)
	if err != nil {
		return TransactionSummary{}, err
	}
	if summary.Categories == nil {
		summary.Categories = make([]TransactionCategorySummary, 0)
	}
	// 结余属于业务计算 放在service
	summary.Balance = summary.Income - summary.Expense
	return summary, nil

}

// update 修改账单
func (s *Service) Update(ctx context.Context, userId int64, householdId int64, id int64, req UpdateTransactionRequest) (Transaction, error) {
	req.Category = strings.TrimSpace(req.Category)
	req.Note = strings.TrimSpace(req.Note)

	operationContext, cancel := context.WithTimeout(ctx, s.operationTimeout)
	defer cancel()

	if err := s.householdAccess.RequireWriteAccess(
		operationContext,
		userId,
		householdId,
	); err != nil {
		return Transaction{}, err
	}

	return s.repository.Update(
		operationContext, userId, householdId, id, req,
	)
}

// 删除账单
func (s *Service) Delete(ctx context.Context, userId int64, householdId int64, id int64) error {
	operationContext, cancel := context.WithTimeout(ctx, s.operationTimeout)
	defer cancel()

	if err := s.householdAccess.RequireWriteAccess(
		operationContext,
		userId,
		householdId,
	); err != nil {
		return err
	}

	return s.repository.Delete(
		operationContext, userId, householdId, id,
	)
}
