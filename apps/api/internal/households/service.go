package households

import (
	"context"
	"database/sql"
	"errors"
	"strings"
	"time"
	"unicode/utf8"
)

var (
	// 表示家庭名称不符合业务规则
	ErrInvalidHouseholdName = errors.New("invalid household name")
	// 表示家庭不存在或当前用户不是该家庭的有效成员 不刻意区分不存在和没有访问权 避免攻击者通过接口猜测家庭ID是否存在
	ErrHouseholdNotAccessible = errors.New("household not accessible")
	// 表示用户viewer 只能查看不能修改
	ErrHouseholdReadOnly = errors.New("household is read only")
)

// repository 定义service所需要的数据访问能力
// service 不直接依赖*Store 而是依赖接口
// 这样后续测试Service时 可以使用假的Repository 不需要真的f链接postgreSQL
type Repository interface {
	Create(ctx context.Context, userId int64, name string) (Household, error)
	ListByUserId(ctx context.Context, userId int64) ([]HouseholdListItem, error)
	GetActiveMemberRole(ctx context.Context, userId int64, householdId int64) (MemberRole, error)
}

// service 负责家庭账本业务逻辑 业务规则 名称校验 超时控制等
// handler 负责http store  负责sql
type Service struct {
	repository       Repository
	operationTimeout time.Duration
}

func NewService(repository Repository) *Service {
	return &Service{
		repository:       repository,
		operationTimeout: 3 * time.Second,
	}
}

// create创建一个家庭账本 store.create内部会同时 1.创建households记录 2.将创建人添加为owner 两个操作在同一个数据库事务中完成
func (s *Service) Create(ctx context.Context, userId int64, request CreateHouseholdRequest) (Household, error) {
	name := strings.TrimSpace(request.Name)
	// RuneCountInString计算的是用户看到的字符数 而不是len len计算字节数 一个中文通常占3个字节
	nameLength := utf8.RuneCountInString(name)
	if nameLength < 2 || nameLength > 40 {
		return Household{}, ErrInvalidHouseholdName
	}
	operationContext, cancel := context.WithTimeout(ctx, s.operationTimeout)
	defer cancel()
	return s.repository.Create(
		operationContext, userId, name,
	)

}

// list接口获取当前用户加入的全部家庭账本
func (s *Service) List(ctx context.Context, userId int64) ([]HouseholdListItem, error) {
	operationContext, cancel := context.WithTimeout(ctx, s.operationTimeout)
	defer cancel()

	items, err := s.repository.ListByUserId(operationContext, userId)
	if err != nil {
		return nil, err
	}
	// api返回[]而不是null
	if items == nil {
		items = make([]HouseholdListItem, 0)
	}
	return items, nil
}

// 检查用户是否可以查看家庭数据 owner admin member viweer 都可以读取 非成员或已经退出的成员不能读取
func (s *Service) RequireReadAccess(ctx context.Context, userId int64, householdId int64) error {
	if userId <= 0 || householdId <= 0 {
		return ErrHouseholdNotAccessible
	}

	operationContext, cancel := context.WithTimeout(ctx, s.operationTimeout)
	defer cancel()

	role, err := s.repository.GetActiveMemberRole(operationContext, userId, householdId)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return ErrHouseholdNotAccessible
		}
		return err
	}
	switch role {
	case RoleOwner, RoleAdmin, RoleMember, RoleViewer:
		return nil
	default:
		// 理论上数据库check约束会阻止非法角色 这里继续防御 避免脏数据导致权限绕过
		return ErrHouseholdNotAccessible
	}
}

// 检查用户是否可以修改家庭账本数据
func (s *Service) RequireWriteAccess(ctx context.Context, userId int64, householdId int64) error {
	if userId <= 0 || householdId <= 0 {
		return ErrHouseholdNotAccessible
	}
	operationContext, cancel := context.WithTimeout(ctx, s.operationTimeout)
	defer cancel()
	role, err := s.repository.GetActiveMemberRole(operationContext, userId, householdId)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return ErrHouseholdNotAccessible
		}
		return err
	}
	switch role {
	case RoleOwner, RoleAdmin, RoleMember:
		return nil
	case RoleViewer:
		return ErrHouseholdReadOnly
	default:
		return ErrHouseholdNotAccessible
	}
}
