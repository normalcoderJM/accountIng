// Package errorcode 统一定义 API 业务错误码。
package errorcode

// Code 是接口返回的业务错误码类型。
//
// 使用独立类型可以避免在业务代码中随意传入普通 int。
type Code int

const (
	// Success 表示请求处理成功。
	Success Code = 0
)

// Auth 模块：40001 - 40909。
const (
	InvalidRegisterData Code = 40001
	InvalidLoginData    Code = 40002

	MissingAuthorization       Code = 40101
	InvalidAuthorizationHeader Code = 40102
	InvalidToken               Code = 40103
	InvalidTokenClaims         Code = 40104
	InvalidTokenUser           Code = 40105
	CurrentUserNotFound        Code = 40108
	InvalidCredentials         Code = 40109

	EmailAlreadyRegistered Code = 40901
)

// Auth 服务端错误：50001 - 50009。
const (
	HashPasswordFailed     Code = 50001
	CreateUserFailed       Code = 50002
	QueryLoginUserFailed   Code = 50003
	GenerateTokenFailed    Code = 50004
	MissingUserContext     Code = 50005
	InvalidUserContext     Code = 50006
	QueryCurrentUserFailed Code = 50007
)

// Transaction 模块：40011 - 40419。
const (
	InvalidTransactionCreateData   Code = 40011
	InvalidTransactionID           Code = 40012
	InvalidTransactionUpdateData   Code = 40013
	InvalidTransactionListQuery    Code = 40014
	InvalidTransactionSummaryQuery Code = 40015

	TransactionNotFound Code = 40411
)

// Household 模块：40021 - 40429。
const (
	InvalidHouseholdCreateData Code = 40021
	InvalidHouseholdID         Code = 40022

	// viewer 尝试新增、修改或删除家庭账单。
	HouseholdReadOnly Code = 40321

	// 家庭不存在，或者当前用户不是该家庭成员。
	HouseholdNotAccessible Code = 40421
)

// Transaction 服务端错误：50011 - 50019。
const (
	CreateTransactionFailed   Code = 50011
	ListTransactionsFailed    Code = 50012
	UpdateTransactionFailed   Code = 50013
	DeleteTransactionFailed   Code = 50014
	SummaryTransactionsFailed Code = 50015
)

// Household 服务端错误：50021 - 50029。
const (
	CreateHouseholdFailed      Code = 50021
	ListHouseholdsFailed       Code = 50022
	ListHouseholdMembersFailed Code = 50023
)
