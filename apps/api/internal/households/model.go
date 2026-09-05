package households

import "time"

// 家庭成员角色
type MemberRole string

const (
	RoleOwner  MemberRole = "owner"
	RoleAdmin  MemberRole = "admin"
	RoleMember MemberRole = "member"
	RoleViewer MemberRole = "viewer"
)

// 家庭数据库实体
type Household struct {
	Id              int64     `json:"id"`
	Name            string    `json:"name"`
	CreatedByUserId int64     `json:"createdByUserId"`
	CreatedAt       time.Time `json:"createdAt"`
	UpdatedAt       time.Time `json:"updatedAt"`
}

// 家庭成员数据实体
type HouseholdListItem struct {
	Id          int64      `json:"id"`
	Name        string     `json:"name"`
	Role        MemberRole `json:"role"`
	MemberCount int64      `json:"memberCount"`
	CreatedAt   time.Time  `json:"createdAt"`
}

// 创建家庭的请求参数
type CreateHouseholdRequest struct {
	Name string `json:"name" binding:"required,max=40"`
}

// 家庭成员列表数据
type HouseholdMemberListItem struct {
	MemberID int64      `json:"memberId"`
	UserID   int64      `json:"userId"`
	Email    string     `json:"email"`
	Role     MemberRole `json:"role"`
	JoinedAt time.Time  `json:"joinedAt"`
}
