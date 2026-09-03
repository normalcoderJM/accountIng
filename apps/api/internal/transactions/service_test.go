package transactions

import (
	"context"
	"errors"
	"testing"
	"time"
)

// fakeTransactionRepository 是测试使用的内存 Repository。
//
// 它不会连接 PostgreSQL，只负责：
//  1. 返回测试准备的数据；
//  2. 记录 Service 传入的参数；
//  3. 验证权限失败时 Repository 没有被调用。
type fakeTransactionRepository struct {
	createResult  Transaction
	createError   error
	createCalled  bool
	createRequest CreateTransactionRequest

	listResult []Transaction
	listError  error
	listCalled bool

	summaryResult TransactionSummary
	summaryError  error
	summaryCalled bool

	updateResult Transaction
	updateError  error
	updateCalled bool

	deleteError  error
	deleteCalled bool

	receivedUserId      int64
	receivedHouseholdId int64
	receivedCursorId    int64
	receivedLimit       int
}

// Create 实现 Repository.Create。
func (f *fakeTransactionRepository) Create(
	ctx context.Context,
	userId int64,
	householdId int64,
	req CreateTransactionRequest,
) (Transaction, error) {
	f.createCalled = true
	f.receivedUserId = userId
	f.receivedHouseholdId = householdId
	f.createRequest = req

	if f.createError != nil {
		return Transaction{}, f.createError
	}

	return f.createResult, nil
}

// ListPageByHouseholdId 实现家庭账单分页查询。
func (f *fakeTransactionRepository) ListPageByHouseholdId(
	ctx context.Context,
	userId int64,
	householdId int64,
	startAt time.Time,
	endAt time.Time,
	cursor *transactionCursor,
	limit int,
) ([]Transaction, error) {
	f.listCalled = true
	f.receivedUserId = userId
	f.receivedHouseholdId = householdId
	f.receivedLimit = limit

	if cursor != nil {
		f.receivedCursorId = cursor.Id
	}

	if f.listError != nil {
		return nil, f.listError
	}

	return f.listResult, nil
}

// SummaryByHouseholdId 实现家庭账单汇总查询。
func (f *fakeTransactionRepository) SummaryByHouseholdId(
	ctx context.Context,
	userId int64,
	householdId int64,
	startAt time.Time,
	endAt time.Time,
) (TransactionSummary, error) {
	f.summaryCalled = true
	f.receivedUserId = userId
	f.receivedHouseholdId = householdId

	if f.summaryError != nil {
		return TransactionSummary{}, f.summaryError
	}

	return f.summaryResult, nil
}

// Update 实现账单修改。
func (f *fakeTransactionRepository) Update(
	ctx context.Context,
	userId int64,
	householdId int64,
	id int64,
	req UpdateTransactionRequest,
) (Transaction, error) {
	f.updateCalled = true
	f.receivedUserId = userId
	f.receivedHouseholdId = householdId

	if f.updateError != nil {
		return Transaction{}, f.updateError
	}

	return f.updateResult, nil
}

// Delete 实现账单删除。
func (f *fakeTransactionRepository) Delete(
	ctx context.Context,
	userId int64,
	householdId int64,
	id int64,
) error {
	f.deleteCalled = true
	f.receivedUserId = userId
	f.receivedHouseholdId = householdId

	return f.deleteError
}

// fakeHouseholdAccess 模拟家庭权限服务。
type fakeHouseholdAccess struct {
	readError  error
	writeError error

	readCalled  bool
	writeCalled bool

	receivedUserId      int64
	receivedHouseholdId int64
}

func (f *fakeHouseholdAccess) RequireReadAccess(
	ctx context.Context,
	userId int64,
	householdId int64,
) error {
	f.readCalled = true
	f.receivedUserId = userId
	f.receivedHouseholdId = householdId

	return f.readError
}

func (f *fakeHouseholdAccess) RequireWriteAccess(
	ctx context.Context,
	userId int64,
	householdId int64,
) error {
	f.writeCalled = true
	f.receivedUserId = userId
	f.receivedHouseholdId = householdId

	return f.writeError
}

var (
	testStartAt = time.Date(
		2026,
		time.August,
		1,
		0,
		0,
		0,
		0,
		time.UTC,
	)

	testEndAt = time.Date(
		2026,
		time.September,
		1,
		0,
		0,
		0,
		0,
		time.UTC,
	)
)

const (
	testUserId      int64 = 7
	testHouseholdId int64 = 12
)

// TestServiceListPageHasMore 验证游标分页和家庭参数传递。
func TestServiceListPageHasMore(t *testing.T) {
	cursorText := encodeTransactionCursor(
		Transaction{
			Id: 40,
			OccurredAt: time.Date(
				2026,
				time.August,
				20,
				12,
				0,
				0,
				0,
				time.UTC,
			),
		},
	)

	repository := &fakeTransactionRepository{
		// limit=2，但是 Store 返回3条。
		// 第3条只用于判断是否还有下一页。
		listResult: []Transaction{
			{
				Id:          30,
				HouseholdId: testHouseholdId,
				OccurredAt: time.Date(
					2026,
					time.August,
					18,
					12,
					0,
					0,
					0,
					time.UTC,
				),
			},
			{
				Id:          29,
				HouseholdId: testHouseholdId,
				OccurredAt: time.Date(
					2026,
					time.August,
					18,
					11,
					0,
					0,
					0,
					time.UTC,
				),
			},
			{
				Id:          28,
				HouseholdId: testHouseholdId,
				OccurredAt: time.Date(
					2026,
					time.August,
					17,
					10,
					0,
					0,
					0,
					time.UTC,
				),
			},
		},
	}

	access := &fakeHouseholdAccess{}

	service := NewService(
		repository,
		access,
		time.Second,
	)

	page, err := service.ListPage(
		context.Background(),
		testUserId,
		testHouseholdId,
		ListTransactionsQuery{
			Cursor:  cursorText,
			Limit:   2,
			StartAt: testStartAt,
			EndAt:   testEndAt,
		},
	)
	if err != nil {
		t.Fatalf("分页查询不应该失败: %v", err)
	}

	if !access.readCalled {
		t.Fatal("查询家庭账单前应该检查读取权限")
	}

	if repository.receivedUserId != testUserId {
		t.Fatalf(
			"期望 userId 为 %d，实际得到 %d",
			testUserId,
			repository.receivedUserId,
		)
	}

	if repository.receivedHouseholdId != testHouseholdId {
		t.Fatalf(
			"期望 householdId 为 %d，实际得到 %d",
			testHouseholdId,
			repository.receivedHouseholdId,
		)
	}

	if repository.receivedCursorId != 40 {
		t.Fatalf(
			"期望 cursor ID 为 40，实际得到 %d",
			repository.receivedCursorId,
		)
	}

	if repository.receivedLimit != 2 {
		t.Fatalf(
			"期望 limit 为 2，实际得到 %d",
			repository.receivedLimit,
		)
	}

	if len(page.Items) != 2 {
		t.Fatalf(
			"期望客户端收到2条账单，实际得到%d条",
			len(page.Items),
		)
	}

	if !page.HasMore {
		t.Fatal("Store 返回3条而 limit=2，HasMore 应为 true")
	}

	if page.NextCursor == nil {
		t.Fatal("存在下一页时 NextCursor 不能为空")
	}

	decodedCursor, err := decodeTransactionCursor(
		*page.NextCursor,
	)
	if err != nil {
		t.Fatalf("NextCursor 解析失败: %v", err)
	}

	if decodedCursor == nil || decodedCursor.Id != 29 {
		t.Fatalf(
			"下一页游标应该指向 ID 29，实际得到 %+v",
			decodedCursor,
		)
	}
}

// TestServiceListPageUsesDefaultLimit 验证默认分页数量。
func TestServiceListPageUsesDefaultLimit(t *testing.T) {
	repository := &fakeTransactionRepository{
		listResult: []Transaction{},
	}

	access := &fakeHouseholdAccess{}

	service := NewService(
		repository,
		access,
		time.Second,
	)

	page, err := service.ListPage(
		context.Background(),
		testUserId,
		testHouseholdId,
		ListTransactionsQuery{
			StartAt: testStartAt,
			EndAt:   testEndAt,
		},
	)
	if err != nil {
		t.Fatalf("分页查询不应该失败: %v", err)
	}

	if repository.receivedLimit != DefaultPageSize {
		t.Fatalf(
			"期望默认 limit 为 %d，实际得到 %d",
			DefaultPageSize,
			repository.receivedLimit,
		)
	}

	if page.Items == nil {
		t.Fatal("空列表应该返回空切片，不能返回 nil")
	}

	if len(page.Items) != 0 {
		t.Fatalf("期望空列表，实际得到%d条", len(page.Items))
	}

	if page.HasMore {
		t.Fatal("空列表 HasMore 应为 false")
	}

	if page.NextCursor != nil {
		t.Fatal("空列表 NextCursor 应为 nil")
	}
}

// TestServiceListPageStopsWhenReadAccessDenied 验证权限失败后不查询账单。
func TestServiceListPageStopsWhenReadAccessDenied(t *testing.T) {
	expectedError := errors.New("household access denied")

	repository := &fakeTransactionRepository{}
	access := &fakeHouseholdAccess{
		readError: expectedError,
	}

	service := NewService(
		repository,
		access,
		time.Second,
	)

	_, err := service.ListPage(
		context.Background(),
		testUserId,
		testHouseholdId,
		ListTransactionsQuery{
			StartAt: testStartAt,
			EndAt:   testEndAt,
		},
	)

	if !errors.Is(err, expectedError) {
		t.Fatalf(
			"期望返回权限错误，实际得到 %v",
			err,
		)
	}

	if repository.listCalled {
		t.Fatal("读取权限失败后不应该继续查询 Repository")
	}
}

// TestServiceCreateTrimsInput 验证创建账单前清理字符串。
func TestServiceCreateTrimsInput(t *testing.T) {
	repository := &fakeTransactionRepository{
		createResult: Transaction{
			Id:          100,
			HouseholdId: testHouseholdId,
			UserId:      testUserId,
			Type:        TypeExpense,
			Amount:      6800,
			Category:    "餐饮",
			Note:        "家庭晚餐",
		},
	}

	access := &fakeHouseholdAccess{}

	service := NewService(
		repository,
		access,
		time.Second,
	)

	transaction, err := service.Create(
		context.Background(),
		testUserId,
		testHouseholdId,
		CreateTransactionRequest{
			Type:       TypeExpense,
			Amount:     6800,
			Category:   "  餐饮  ",
			Note:       "  家庭晚餐  ",
			OccurredAt: testStartAt,
		},
	)
	if err != nil {
		t.Fatalf("创建账单不应该失败: %v", err)
	}

	if !access.writeCalled {
		t.Fatal("创建账单前应该检查写入权限")
	}

	if !repository.createCalled {
		t.Fatal("写入权限通过后应该调用 Repository")
	}

	if repository.createRequest.Category != "餐饮" {
		t.Fatalf(
			"分类应该去除空格，实际得到 %q",
			repository.createRequest.Category,
		)
	}

	if repository.createRequest.Note != "家庭晚餐" {
		t.Fatalf(
			"备注应该去除空格，实际得到 %q",
			repository.createRequest.Note,
		)
	}

	if transaction.HouseholdId != testHouseholdId {
		t.Fatalf(
			"期望返回 householdId=%d，实际得到%d",
			testHouseholdId,
			transaction.HouseholdId,
		)
	}
}

// TestServiceCreateStopsWhenWriteAccessDenied 验证只读成员不能创建账单。
func TestServiceCreateStopsWhenWriteAccessDenied(t *testing.T) {
	expectedError := errors.New("household is read only")

	repository := &fakeTransactionRepository{}
	access := &fakeHouseholdAccess{
		writeError: expectedError,
	}

	service := NewService(
		repository,
		access,
		time.Second,
	)

	_, err := service.Create(
		context.Background(),
		testUserId,
		testHouseholdId,
		CreateTransactionRequest{
			Type:       TypeExpense,
			Amount:     100,
			Category:   "餐饮",
			OccurredAt: testStartAt,
		},
	)

	if !errors.Is(err, expectedError) {
		t.Fatalf(
			"期望返回写入权限错误，实际得到 %v",
			err,
		)
	}

	if repository.createCalled {
		t.Fatal("写入权限失败后不应该调用 Repository.Create")
	}
}

// TestServiceSummary 验证家庭账单汇总和结余计算。
func TestServiceSummary(t *testing.T) {
	repository := &fakeTransactionRepository{
		summaryResult: TransactionSummary{
			Income:  100000,
			Expense: 35000,
			Categories: []TransactionCategorySummary{
				{
					Type:     TypeIncome,
					Category: "工资",
					Amount:   100000,
				},
				{
					Type:     TypeExpense,
					Category: "餐饮",
					Amount:   35000,
				},
			},
		},
	}

	access := &fakeHouseholdAccess{}

	service := NewService(
		repository,
		access,
		time.Second,
	)

	summary, err := service.Summary(
		context.Background(),
		testUserId,
		testHouseholdId,
		SummaryTransactionsQuery{
			StartAt: testStartAt,
			EndAt:   testEndAt,
		},
	)
	if err != nil {
		t.Fatalf("汇总查询不应该失败: %v", err)
	}

	if !access.readCalled {
		t.Fatal("汇总前应该检查家庭读取权限")
	}

	if !repository.summaryCalled {
		t.Fatal("权限通过后应该查询 Repository")
	}

	if repository.receivedHouseholdId != testHouseholdId {
		t.Fatalf(
			"期望 householdId 为%d，实际得到%d",
			testHouseholdId,
			repository.receivedHouseholdId,
		)
	}

	if summary.Income != 100000 {
		t.Fatalf("期望收入100000，实际得到%d", summary.Income)
	}

	if summary.Expense != 35000 {
		t.Fatalf("期望支出35000，实际得到%d", summary.Expense)
	}

	if summary.Balance != 65000 {
		t.Fatalf("期望结余65000，实际得到%d", summary.Balance)
	}
}
