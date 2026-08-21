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
	Create(ctx context.Context, userId int64, req CreateTransactionRequest) (Transaction, error)
	ListByUserId(ctx context.Context, userId int64) ([]Transaction, error)
	Update(ctx context.Context, userId int64, id int64, req UpdateTransactionRequest) (Transaction, error)
	Delete(ctx context.Context, userId int64, id int64) error
}

// service负责账单业务逻辑 handler处理http store只处理sql service负责两者中间的业务流程
type Service struct {
	repository       Repository
	operationTimeout time.Duration
}

// newService 创建账单Service
func NewService(repository Repository, operationTimeout time.Duration) *Service {
	return &Service{
		repository:       repository,
		operationTimeout: operationTimeout,
	}
}

// create创建账单
func (s *Service) Create(
	ctx context.Context,
	userId int64,
	req CreateTransactionRequest) (Transaction, error) {
	// 用户输入可能包含前后空格  在业务层统一清理 避免数据库保存脏数据
	req.Category = strings.TrimSpace(req.Category)
	req.Note = strings.TrimSpace(req.Note)
	// 数据库操作最多运行指定时间
	operationContext, cancel := context.WithTimeout(ctx, s.operationTimeout)
	defer cancel()
	return s.repository.Create(
		operationContext,
		userId,
		req,
	)
}

// list 返回当前用户账单
func (s *Service) List(ctx context.Context, userId int64) ([]Transaction, error) {
	operationContext, cancel := context.WithTimeout(ctx, s.operationTimeout)
	defer cancel()
	return s.repository.ListByUserId(
		operationContext, userId,
	)
}

// update 修改账单
func (s *Service) Update(ctx context.Context, userId int64, id int64, req UpdateTransactionRequest) (Transaction, error) {
	req.Category = strings.TrimSpace(req.Category)
	req.Note = strings.TrimSpace(req.Note)

	operationContext, cancel := context.WithTimeout(ctx, s.operationTimeout)
	defer cancel()

	return s.repository.Update(
		operationContext, userId, id, req,
	)
}

// 删除账单
func (s *Service) Delete(ctx context.Context, userId int64, id int64) error {
	operationContext, cancel := context.WithTimeout(ctx, s.operationTimeout)
	defer cancel()

	return s.repository.Delete(
		operationContext, userId, id,
	)
}
