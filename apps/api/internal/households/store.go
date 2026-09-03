package households

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

// create创建家庭 创建家庭的人为家庭创建者  启用事务 创建家庭和家庭的创建者必须同时成功 如果其中之一失败 则整体事务回滚
func (s *Store) Create(ctx context.Context, userId int64, name string) (Household, error) {
	// 开始数据库事务
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return Household{}, err
	}
	// 函数中途任何位置return 都会尝试回滚整个事务 如果最后已经commit rollback 会返回sql.errTxDone 这里不需要处理这个错误
	defer tx.Rollback()

	const createHouseholdQuery = `
		INSERT INTO households(name,created_by_user_id)
		VALUES($1,$2)
		RETURNING id,name,created_by_user_id,created_at,updated_at`

	var household Household
	err = tx.QueryRowContext(ctx, createHouseholdQuery, name, userId).Scan(
		&household.Id,
		&household.Name,
		&household.CreatedByUserId,
		&household.CreatedAt,
		&household.UpdatedAt,
	)
	if err != nil {
		return Household{}, err
	}
	const createOwnerQuery = `
		INSERT INTO household_members(
		household_id,user_id,role,status)
		VALUES($1,$2,$3,'active')
	`
	_, err = tx.ExecContext(ctx, createOwnerQuery, household.Id, userId, RoleOwner)
	if err != nil {
		return Household{}, err
	}

	// 两次insert都成功以后才提交
	if err := tx.Commit(); err != nil {
		return Household{}, err
	}
	return household, nil
}

// 查询当前用户家人的全部有效家庭
func (s *Store) ListByUserId(ctx context.Context, userId int64) ([]HouseholdListItem, error) {
	const query = `
	SELECT
	h.id,h.name,current_member.role,COUNT(all_members.id) AS member_count,h.created_at
	FROM household_members AS current_member 
	JOIN households AS h 
	ON h.id = current_member.household_id
	LEFT JOIN household_members AS all_members
	ON all_members.household_id = h.id
	AND all_members.status = 'active'
	WHERE current_member.user_id = $1
	AND current_member.status = 'active'
	GROUP BY h.id,h.name,current_member.role,h.created_at
	ORDER BY h.created_at ASC,
	h.id ASC
	`
	rows, err := s.db.QueryContext(ctx, query, userId)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	// 初始化空切片 返回空数组 而不是null
	households := make([]HouseholdListItem, 0)
	for rows.Next() {
		var household HouseholdListItem
		if err := rows.Scan(
			&household.Id, &household.Name, &household.Role, &household.MemberCount, &household.CreatedAt,
		); err != nil {
			return nil, err
		}
		households = append(households, household)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return households, nil
}

// 查询用户在指定家庭中的有效角色
// 如果该用户已经不是家庭成员 则会返回sql.errRows
func (s *Store) GetActiveMemberRole(ctx context.Context, userId int64, householdId int64) (MemberRole, error) {
	const query = `SELECT role 
	FROM household_members
	WHERE user_id = $1
	AND household_id = $2
	AND status = 'active'`
	var role MemberRole

	err := s.db.QueryRowContext(ctx, query, userId, householdId).Scan(&role)
	if err != nil {
		return "", err
	}
	return role, nil
}
